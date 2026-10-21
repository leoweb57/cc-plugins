---
name: docker-build-strategies
description: "Utilise ce skill pour écrire, relire ou optimiser des Dockerfiles, même si l'utilisateur dit simplement que son image est trop grosse, que son build est lent ou qu'il doit durcir un conteneur pour la production. Couvre les builds multi-stage, le cache de layers, .dockerignore, les utilisateurs non-root et l'optimisation de la taille des images."
license: Apache-2.0
compatibility: Requires Docker 23.0+ (BuildKit default). On Docker 20.10–22.x, set DOCKER_BUILDKIT=1 before building.
---

# Docker Build Strategies

## Vue d'ensemble

Ce skill fournit des règles et des patterns pour écrire et relire des Dockerfiles de qualité production. Applique-le quand la tâche principale porte sur la qualité du build d'image : builds multi-stage, comportement du cache, exécution non-root, hygiène du contexte de build et taille de l'image d'exécution.

## Quand utiliser ce skill

Active ce skill quand :

- Tu crées un nouveau Dockerfile pour n'importe quel langage ou framework
- Tu optimises un Dockerfile existant en taille, en vitesse ou en sécurité
- Tu relis un Dockerfile pour vérifier sa conformité aux bonnes pratiques
- Tu ajoutes un fichier `.dockerignore` à un projet

## Quand ne pas utiliser ce skill

N'utilise pas ce skill quand :

- Le projet n'a pas encore de setup Docker et que le besoin principal est un premier scaffold
- La tâche principale est de relier des services entre eux dans `compose.yaml`
- La tâche principale est de déboguer l'ordre de démarrage de Compose, le réseau ou les overrides de développement

## Principes essentiels

### Builds multi-stage

Utilise des builds multi-stage quand le projet a une étape de build ou quand les dépendances de build diffèrent de celles d'exécution. Sépare les dépendances de build de l'image d'exécution.

1. Nomme explicitement chaque stage (`FROM ... AS build`, `FROM ... AS runtime`).
2. Utilise la base la plus petite adaptée pour le stage d'exécution : variantes `distroless`, `alpine` ou `slim`.
3. Copie uniquement l'artefact final dans le stage d'exécution avec `COPY --from=build`.
4. Utilise `COPY --link` quand tu copies depuis un stage précédent ou que tu ajoutes des fichiers statiques : il améliore la réutilisation du cache en rendant le COPY indépendant des layers précédents.

Vois `references/multi-stage-builds.md` pour les patterns par langage (Go, Node, Python, Java).

### Cache de layers

Ordonne les instructions du Dockerfile de la moins fréquemment modifiée à la plus fréquemment modifiée.

1. Place les manifestes de dépendances (`package.json`, `go.mod`, `requirements.txt`) et les étapes d'installation avant la copie du code source de l'application. Fais un bind mount du manifeste dans l'étape d'installation au lieu de le `COPY`, pour qu'il n'entre jamais dans un layer : `RUN --mount=type=bind,source=package.json,target=package.json --mount=type=bind,source=package-lock.json,target=package-lock.json npm ci`. C'est sûr pour les commandes d'installation qui ne font que lire le manifeste (`npm ci`, `pip install -r`, `go mod download`) ; si une étape doit aussi réécrire le manifeste dans l'image, utilise `COPY` à la place.
2. Utilise les cache mounts BuildKit pour les caches des gestionnaires de paquets :
   - Go : `RUN --mount=type=cache,target=/go/pkg/mod go build ...`
   - Node : `RUN --mount=type=cache,target=/root/.npm npm ci`
   - Python : `RUN --mount=type=cache,target=/root/.cache/pip pip install ...`
   - apt : `RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked apt-get update && apt-get install -y ...` : pas besoin de `rm -rf /var/lib/apt/lists/*`, puisque le cache vit en dehors du layer de l'image. `sharing=locked` est obligatoire car apt a besoin d'un accès exclusif à ses répertoires de cache.
   - apk (Alpine, d'après le wiki Alpine et non une doc vérifiée par Docker ; `references/layer-caching.md` renvoie vers la source) : `RUN --mount=type=cache,target=/etc/apk/cache,sharing=locked apk add ...` : retire `--no-cache` pour que les paquets téléchargés atterrissent dans le répertoire de cache monté au lieu d'être jetés.
3. Épingle les tags d'image de base sur une version précise ou un digest : n'utilise jamais `latest` en production.
4. Combine les commandes `RUN` liées avec `&&` pour réduire le nombre de layers, mais garde séparées les étapes logiquement distinctes pour la granularité du cache.

Vois `references/layer-caching.md` pour les règles détaillées d'invalidation du cache et les patterns de cache mounts.

### Secrets de build et accès SSH

N'intègre jamais d'identifiants dans l'image. Utilise les secrets BuildKit et les montages SSH pour que les identifiants ne soient disponibles que pendant l'étape `RUN` précise qui en a besoin, et ne persistent jamais dans un layer ni dans la sortie de `docker history`.

1. **Ne** passe **PAS** d'identifiants via `ARG` ou `ENV`. Les deux finissent dans les layers de l'image et sont inspectables via `docker history`.
2. **Ne** `COPY` **PAS** de fichiers d'identifiants dans le contexte de build : `.npmrc`, `.pypirc`, `.netrc`, `pip.conf`, `settings.xml` de Maven, `.env`, identifiants cloud (`~/.aws/credentials`, `~/.config/gcloud/`, fichiers JSON de compte de service, `~/.azure/`), tokens de gestionnaire de secrets (`~/.vault-token`), tokens de registre de paquets (`~/.cargo/credentials.toml`), clés TLS (`*.pem`, `*.p12`), `kubeconfig`, clés SSH (`id_rsa`, `id_dsa`, `id_ed25519`, `id_ecdsa`). Même si le stage final ne les recopie pas, ils restent dans les layers intermédiaires et dans le cache de build.
3. **Ne** fais **PAS** d'echo, n'écris pas et ne développe pas la valeur du secret dans une commande `RUN` de manière à la persister dans un layer ou à l'émettre dans les logs de build. Accède au fichier du secret (par ex. `/run/secrets/<id>`, ou directement via le `target=` du montage) : jamais `echo "$(cat /run/secrets/X)"`, jamais de substitution dans un argument de shell qui serait journalisé avec `--progress=plain`.
4. **Utilise `RUN --mount=type=secret`** pour les identifiants de registre de gestionnaire de paquets :
   ```dockerfile
   RUN --mount=type=secret,id=npmrc,target=/root/.npmrc,required=false \
       --mount=type=cache,target=/root/.npm \
       npm ci --omit=dev
   ```
   Le secret n'est disponible qu'à l'intérieur de ce `RUN` et n'est jamais écrit dans un layer. Utilise `required=true` quand le build aura toujours besoin de l'identifiant (par ex. tous les paquets viennent d'un registre privé, donc l'absence du secret doit faire échouer le build immédiatement) ; n'utilise `required=false` que quand le secret est optionnel (le build peut réussir avec les seuls paquets publics).
5. **Utilise `RUN --mount=type=ssh`** pour récupérer des dépôts ou modules Git privés. Le conteneur de build n'a pas de `known_hosts` par défaut : remplis-le dans le même `RUN` :
   ```dockerfile
   RUN --mount=type=ssh \
       mkdir -p -m 0700 /root/.ssh && \
       ssh-keyscan github.com >> /root/.ssh/known_hosts && \
       git clone git@github.com:org/private-repo.git
   ```
   N'utilise PAS `StrictHostKeyChecking=no` comme raccourci : il désactive complètement la vérification de la clé d'hôte. `ssh-keyscan` accepte la clé d'hôte que le serveur présente à chaque exécution de l'étape ; rien n'est épinglé d'un build à l'autre. Pour une assurance plus forte, compare-la avec les empreintes de clés d'hôte publiées par le fournisseur, ou écris dans `known_hosts` la clé publiée au lieu de la scanner.
6. **Invoque buildx avec les sources de secrets et SSH :**
   ```bash
   # --ssh default forwards this shell's SSH agent (SSH_AUTH_SOCK); list every key the build can use:
   ssh-add -l

   docker buildx build \
       --secret id=npmrc,src=$HOME/.npmrc \
       --ssh default \
       .
   ```
   L'étape `RUN --mount=type=ssh` peut utiliser toutes les clés que liste `ssh-add -l`, donc n'expose que la clé dont ce build a besoin. Dans un terminal interactif, lance `ssh-agent bash` pour démarrer un shell avec un agent dédié, puis `ssh-add <key-file>`, vérifie que `ssh-add -l` ne liste que cette clé, et lance le build dans ce shell. Un outil qui démarre un nouveau shell à chaque commande perd cet agent entre les commandes : demande alors à l'utilisateur d'exécuter ces étapes. Sinon, passe directement un fichier de clé non chiffré, comme une deploy key dédiée, avec `--ssh default=<key-file>` ; BuildKit rejette les clés protégées par une passphrase sous cette forme, donc charge celles-ci dans un agent.
7. Les exclusions `.dockerignore` de `.env` et des fichiers d'identifiants sont une **défense en profondeur**, pas le mécanisme principal : garde-les, mais ne t'y fie pas comme unique protection.

Vois `references/multi-stage-builds.md` pour les patterns par langage (npm, pip, Maven, Go `GOPRIVATE`).

### .dockerignore

Génère toujours un `.dockerignore` à côté du Dockerfile. Exclus :

- `.git/`, `.github/`, `.vscode/`, `.idea/`
- `node_modules/`, `__pycache__/`, `.venv/`, `vendor/` (quand ils sont reconstruits dans le stage de build)
- `*.md`, `LICENSE`, `docs/`
- Les sorties de build, les artefacts de test et les configs d'IDE
- Les fichiers `.env` et tous les secrets

Vois `assets/dockerignore-example` pour un template complet.

### Utilisateur non-root

Configure toujours l'image finale pour qu'elle s'exécute avec un utilisateur non-root.

1. Crée un utilisateur et un groupe dédiés dans le stage d'exécution :
   ```dockerfile
   RUN addgroup --system --gid 1001 appgroup && \
       adduser --system --uid 1001 --ingroup appgroup appuser
   ```
2. Définis la propriété (ownership) des fichiers de l'application : `COPY --from=build --chown=appuser:appgroup /app /app`
3. Quand tu combines `--chown` avec `COPY --link`, utilise toujours l'UID:GID numérique que tu as attribué (par ex. `--chown=1001:1001` si tu as utilisé `--uid 1001 --gid 1001` ci-dessus), pas des utilisateurs nommés. `--link` crée un layer indépendant dans lequel les utilisateurs nommés des instructions `RUN` précédentes ne sont pas disponibles.
4. Place l'instruction `USER appuser` après toutes les opérations sur les fichiers et avant `ENTRYPOINT`/`CMD`.
5. Sur les images distroless, utilise l'utilisateur nonroot intégré : `USER nonroot:nonroot`.

### Optimisation de la taille de l'image

1. Préfère `FROM scratch` (binaires statiques Go), distroless ou des images basées sur Alpine pour le stage d'exécution.
2. Installe les paquets de l'OS avec un cache mount BuildKit plutôt que de faire un `rm -rf` du cache dans le même layer : vois « Cache de layers » ci-dessus. Le cache mount garde le cache des paquets complètement hors du layer de l'image, donc aucune étape de nettoyage n'est nécessaire.
3. N'installe ni documentation, ni pages man, ni outils de debug dans l'image d'exécution.
4. Utilise `.dockerignore` de façon agressive pour minimiser le contexte de build.

### Règles générales

- Inclus toujours une directive `# syntax=docker/dockerfile:1` en toute première ligne pour activer les fonctionnalités BuildKit.
- Définis `WORKDIR` avant toute instruction `COPY` ou `RUN` : ne te repose jamais sur le `/` par défaut.
- Préfère `ENTRYPOINT` en forme exec (`["binary"]`) à la forme shell.
- Ajoute `EXPOSE` pour documenter le port d'écoute.
- Ajoute des labels de métadonnées : `LABEL org.opencontainers.image.source=...`

## Skills liés

- Pour le scaffolding initial d'un projet Docker et le choix des fichiers à créer, utilise `docker-project-foundations`.
- Pour les dépendances entre services, les health checks, les overrides, les réseaux et les patterns de volumes, utilise `docker-compose-patterns`.
- Pour les commandes Docker CLI destructives (`docker system prune`, `docker rm -f`, nettoyage d'images/réseaux/builders) et un index transverse des garde-fous sur les commandes destructives, utilise `docker-destructive-guardrails`.

## Références

- `references/multi-stage-builds.md` : patterns multi-stage par langage pour Go, Node.js, Python et Java
- `references/layer-caching.md` : analyse approfondie de l'ordre des layers, de l'invalidation du cache et des cache mounts BuildKit

## Assets

- `assets/Dockerfile.go` : build Go multi-stage avec runtime distroless et utilisateur non-root
- `assets/Dockerfile.nodejs` : build Node.js multi-stage avec un bon cache de layers et un utilisateur non-root
- `assets/Dockerfile.python` : build Python avec environnement virtuel, ordre des layers et utilisateur non-root
- `assets/dockerignore-example` : template complet de `.dockerignore`

## Scripts

- **`scripts/verify-build.sh`** : construit le Dockerfile du répertoire courant, puis indique la taille de l'image et l'utilisateur configuré. Lance-le depuis la racine du projet (le répertoire qui contient le `Dockerfile`), avec le chemin du script résolu dans le répertoire de ce skill :
  ```bash
  bash "<skill-dir>/scripts/verify-build.sh" [--help] [IMAGE_NAME]
  ```
  Remplace `<skill-dir>` par le chemin absolu du dossier qui contient ce `SKILL.md` ; le chemin `scripts/` est relatif à ce dossier, pas au projet. Ne te place pas d'abord dans le répertoire du skill : le script construit ce qui se trouve dans le répertoire courant. Si le répertoire du skill ne peut pas être résolu, lance `docker build -t verify-build-test .`, puis `docker images verify-build-test` et `docker inspect verify-build-test --format '{{.Config.User}}'`. Le code de sortie est `0` quand toutes les commandes Docker réussissent ou que l'aide est demandée, le code non nul de la commande Docker en échec quand la vérification échoue, et `2` pour des arguments invalides.

## Vérifications

- `checks/verification.md` : runbook de vérification détaillé pour la revue manuelle.
