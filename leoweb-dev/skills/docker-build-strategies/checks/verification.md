# Runbook de vérification

Utilise ces vérifications pour confirmer qu'un Dockerfile généré respecte les standards de qualité.

## Vérification par script

Lance le script fourni depuis la racine du projet (le répertoire qui contient le `Dockerfile`), avec le chemin du script résolu dans le répertoire du skill :

```bash
bash "<skill-dir>/scripts/verify-build.sh" [--help] [IMAGE_NAME]
```

Remplace `<skill-dir>` par le chemin absolu du répertoire de ce skill, le dossier qui contient `SKILL.md` et ce dossier `checks/`. Ne te place pas dans le répertoire du skill pour l'exécuter ; le script construit le répertoire courant.

Le nom d'image vaut par défaut `verify-build-test`. Le code de sortie est `0` quand les commandes de build et d'inspection réussissent ou que l'aide est demandée, le code non nul de la commande Docker en échec quand la vérification échoue, et `2` pour des arguments invalides.

## 1. Le build réussit

```bash
docker buildx build -t test-image .
```

Le build doit se terminer sans erreur. Utilise `--progress=plain` pour inspecter chaque étape en cas de débogage (évite ce flag en CI où les logs de build sont conservés, car il peut exposer le contenu de tout secret qu'une étape `RUN` afficherait par accident).

## 2. La taille de l'image est raisonnable

```bash
docker images test-image --format "{{.Size}}"
```

Bases de référence attendues pour une application minimale :

| Langage | Borne supérieure raisonnable |
|---|---|
| Go (distroless/scratch) | < 30 Mo |
| Node.js (Alpine) | < 200 Mo |
| Python (slim) | < 250 Mo |
| Java (JRE Alpine) | < 300 Mo |

Si l'image dépasse ces bornes, cherche :

- Un build multi-stage manquant (outils de build inclus dans l'image d'exécution)
- De gros fichiers inutiles copiés dans l'image
- Un `.dockerignore` manquant
- Des caches de paquets de l'OS intégrés dans un layer au lieu d'un cache mount BuildKit (`apt-get`/`apk`)

Utilise `docker history test-image` pour identifier les layers les plus gros.

## 3. S'exécute en non-root

```bash
docker run --rm test-image whoami
```

Sortie attendue : `appuser`, `nonroot` ou un autre nom d'utilisateur non-root. Ne doit pas renvoyer `root`.

Si l'image n'a pas `whoami` (par ex. distroless), vérifie avec :

```bash
docker inspect test-image --format '{{.Config.User}}'
```

La sortie doit être non vide et ne doit pas être `0` ni `root`.

## 4. Aucun secret dans l'image

### 4a. Vérification statique du pattern du Dockerfile (principale)

Avant de construire, vérifie que le Dockerfile ne fait pas de `COPY` de fichiers d'identifiants et ne passe pas d'identifiants via `ARG`/`ENV`. Toute correspondance ci-dessous est une fuite :

```bash
# Credential files copied into the build context
grep -nE "^(COPY|ADD) .*(\.npmrc|\.pypirc|\.netrc|pip\.conf|settings\.xml|\.env|\.aws/credentials|\.config/gcloud|\.azure/|\.vault-token|\.cargo/credentials|id_(rsa|dsa|ed25519|ecdsa)|service.account.*\.json|\.pem([[:space:]]|$)|\.p12([[:space:]]|$)|kubeconfig)" Dockerfile

# Credentials passed as build args (visible in docker history) — case-insensitive
grep -inE "^ARG .*(TOKEN|KEY|SECRET|PASSWORD)" Dockerfile

# Credentials baked into image env (visible to anyone with the image) — case-insensitive
grep -inE "^ENV .*(TOKEN|KEY|SECRET|PASSWORD)=" Dockerfile
```

Si le projet a besoin d'identifiants de registre, le Dockerfile doit utiliser `RUN --mount=type=secret` et l'invocation du build doit passer le secret :

```bash
docker buildx build --secret id=<id>,src=<host-path> --progress=plain .
```

La sortie de `--progress=plain` doit montrer le secret consommé dans la bonne étape `RUN` **sans afficher sa valeur**. Si tu vois le contenu du secret dans le log, le `RUN` le fait fuiter (par ex. via `echo`, `cat` ou une substitution shell dans une commande journalisée) : c'est une fuite dans les logs de build même si le layer lui-même est propre. Pour l'accès Git privé, utilise `--mount=type=ssh` et `docker buildx build --ssh default .`, puis lance les vérifications SSH du 4c.

### 4b. Filet de sécurité : scanner l'image construite

```bash
docker history test-image --no-trunc
```

Inspecte la sortie à la recherche d'instructions `ENV` ou d'étapes `COPY` qui pourraient inclure des fichiers `.env`, des clés d'API ou des identifiants.

**Note :** `docker history` ne montre que les layers de l'image finale exportée. Il ne révélera **pas** les identifiants qui ont été `COPY` dans un stage intermédiaire mais non reportés dans la suite : ces fichiers existent toujours dans le cache de build de BuildKit sur l'hôte du builder. La vérification statique du Dockerfile en 4a est le seul moyen de détecter cette classe de fuite. Cette étape n'est qu'un filet de sécurité.

### 4c. Redirection SSH pour l'accès Git privé

Si le Dockerfile utilise `RUN --mount=type=ssh`, vérifie à quoi le build peut accéder avant de le lancer :

```bash
# Every key listed here can be used by the RUN --mount=type=ssh step
ssh-add -l

# Host-key checking stays enabled (must return nothing)
grep -nE 'StrictHostKeyChecking[[:space:]=]+no' Dockerfile
```

- `ssh-add -l` ne doit lister que la clé dont ce build a besoin. S'il en liste davantage, lance le build depuis un agent dédié (dans un terminal interactif, `ssh-agent bash`, puis `ssh-add <key-file>`) plutôt que de retirer des clés de l'agent de l'utilisateur.
- Le `RUN` qui récupère via SSH remplit `/root/.ssh/known_hosts` dans la même étape (par exemple avec `ssh-keyscan`) au lieu de désactiver la vérification des clés d'hôte.
- `--ssh default=<key-file>` ne fonctionne qu'avec un fichier de clé non chiffré. BuildKit rejette les clés protégées par une passphrase sous cette forme (`this private key is passphrase protected`) : charge-les donc dans un agent et passe `--ssh default`.

## 5. Nombre de layers

```bash
docker history test-image --format "{{.CreatedBy}}" | wc -l
```

Une image bien structurée a en général 8 à 15 layers. Un nombre nettement supérieur peut indiquer un manque de consolidation des commandes.

## 6. WORKDIR, EXPOSE et ENTRYPOINT corrects

```bash
docker inspect test-image --format '{{.Config.WorkingDir}}'
docker inspect test-image --format '{{.Config.ExposedPorts}}'
docker inspect test-image --format '{{.Config.Entrypoint}}'
```

Vérifie que :

- `WorkingDir` est défini (ni vide ni `/`)
- `ExposedPorts` documente le port attendu
- `Entrypoint` utilise la forme exec (tableau JSON), pas la forme shell

## 7. .dockerignore existe

Vérifie qu'un fichier `.dockerignore` est présent à côté du Dockerfile et qu'il exclut au minimum :

- `.git/`
- `node_modules/`, `__pycache__/` ou les artefacts équivalents du langage
- `.env` et les fichiers de secrets
- Les répertoires de configuration d'IDE

## 8. Directive de syntaxe BuildKit

La première ligne du Dockerfile doit être :

```dockerfile
# syntax=docker/dockerfile:1
```

Cela active les fonctionnalités BuildKit comme les cache mounts et `COPY --link`.
