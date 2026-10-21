# Cache de layers

Les builds Docker sont incrémentaux. Chaque instruction crée un layer, et Docker réutilise les layers en cache quand les entrées n'ont pas changé. Comprendre les règles d'invalidation du cache est essentiel pour obtenir des builds rapides.

## Règles d'invalidation du cache

1. Le cache d'un layer est invalidé quand l'instruction elle-même change ou que l'une de ses entrées change.
2. Quand un layer est invalidé, tous les layers suivants le sont aussi.
3. Pour `COPY` et `ADD`, Docker calcule un checksum des fichiers copiés. Si le checksum diffère de celui du layer en cache, le cache est invalidé.
4. Pour `RUN`, la clé de cache est la chaîne de la commande. Le cache ne détecte pas les changements des fichiers récupérés via le réseau : utilise des cache mounts ou un épinglage explicite des versions pour gérer ça.

## Stratégie d'ordre des layers

Ordonne les instructions de la moins fréquemment modifiée à la plus fréquemment modifiée :

```
1. Base image (FROM)
2. System package installation
3. Dependency manifest (package.json, go.mod, requirements.txt), bind-mounted into the install step
4. Dependency installation (npm ci, go mod download, pip install)
5. Application source code copy
6. Application build
7. Runtime configuration (USER, EXPOSE, ENTRYPOINT)
```

L'idée clé : les manifestes de dépendances changent bien moins souvent que le code source de l'application. En copiant et en installant les dépendances avant de copier le code source, tu mets en cache l'étape coûteuse d'installation des dépendances pour la plupart des builds.

### Mauvais ordre

```dockerfile
# Invalidates dependency cache on every source change
COPY . .
RUN npm ci
RUN npm run build
```

### Bon ordre

```dockerfile
# Dependencies cached until package.json or lock file changes; the manifest
# is bind-mounted rather than COPY-ed, so it never enters a layer
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=cache,target=/root/.npm \
    npm ci
COPY . .
RUN npm run build
```

Le bind mount ne fonctionne que pour les commandes d'installation qui lisent le manifeste sans le réécrire (`npm ci`, `pip install -r`, `go mod download`). Si l'étape modifie le lockfile sur place (par ex. `npm install` sans lockfile, ou `go mod tidy`), fais plutôt un `COPY` du manifeste pour que l'écriture atterrisse dans l'image.

## Cache mounts BuildKit

Les cache mounts font persister les caches des gestionnaires de paquets d'un build à l'autre sans les intégrer dans le layer de l'image. C'est l'optimisation la plus efficace pour la vitesse d'installation des dépendances.

### Syntaxe

```dockerfile
RUN --mount=type=cache,target=<path> <command>
```

### Cibles courantes de cache mounts

| Gestionnaire de paquets | Cible du cache mount |
|---|---|
| Modules Go | `/go/pkg/mod` |
| Cache de build Go | `/root/.cache/go-build` |
| npm | `/root/.npm` |
| yarn | `/usr/local/share/.cache/yarn` |
| pnpm | `/root/.local/share/pnpm/store` |
| pip | `/root/.cache/pip` |
| Maven | `/root/.m2` |
| Gradle | `/root/.gradle` |
| apt | `/var/cache/apt` et `/var/lib/apt` (les deux en `sharing=locked`) |
| apk (Alpine) | `/etc/apk/cache` (`sharing=locked`, retirer `--no-cache`) |

La ligne apk suit la page [Local APK cache](https://wiki.alpinelinux.org/wiki/Local_APK_cache) du wiki Alpine, et non une doc vérifiée par Docker.

### Cache mount avec un utilisateur de build non-root

Quand le stage de build s'exécute avec un utilisateur non-root, précise `uid` et `gid` :

```dockerfile
RUN --mount=type=cache,target=/home/appuser/.cache/pip,uid=1001,gid=1001 \
    pip install -r requirements.txt
```

### Bind mounts pour les manifestes de dépendances

Fais un bind mount de `package.json`, `go.mod`/`go.sum` ou `requirements.txt` dans le `RUN` d'installation au lieu de les `COPY`, pour que le manifeste soit visible de la commande sans jamais être écrit dans un layer :

```dockerfile
RUN --mount=type=bind,source=go.mod,target=go.mod \
    --mount=type=bind,source=go.sum,target=go.sum \
    --mount=type=cache,target=/go/pkg/mod \
    go mod download
```

Ne fais cela que pour les commandes d'installation qui ne réécrivent pas le manifeste (`npm ci`, `pip install -r`, `go mod download`). Une commande qui modifie le lockfile sur place nécessite `COPY` pour que le changement soit capturé dans l'image.

### Bind mounts pour le code source

Utilise des bind mounts pour éviter de copier les fichiers source dans le layer de build quand le code source n'est nécessaire que pour la compilation, pas pour l'artefact final :

```dockerfile
RUN --mount=type=bind,source=.,target=/src \
    --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    cd /src && go build -o /app/server ./cmd/server
```

Cela garde le contexte de build complètement hors de l'historique des layers.

## COPY --link

`COPY --link` crée un layer indépendant de tous les layers précédents. Cela signifie que :

- Modifier un layer précédent n'invalide pas une copie `--link`.
- Docker peut paralléliser la création des layers.
- C'est particulièrement utile pour copier d'un stage de build vers le stage d'exécution.

Utilise `COPY --link` quand :

- Tu copies l'artefact final depuis un stage de build : `COPY --from=build --link /app/server .`
- Tu ajoutes des fichiers de configuration statiques qui ne dépendent pas du contenu des layers précédents.

N'utilise pas `COPY --link` quand :

- Le `COPY` dépend d'une structure de répertoires créée par une instruction `RUN` précédente (le layer `--link` ne peut pas la voir).

## Réduire le nombre de layers

Combine les commandes liées dans un seul `RUN` pour éviter les layers intermédiaires :

```dockerfile
# Good: single layer, cache mounts keep the apt cache and lists out of the image entirely
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl

# Bad: three layers, apt cache persists in the first layer
RUN apt-get update
RUN apt-get install -y curl
RUN rm -rf /var/lib/apt/lists/*
```

Mais ne combine pas à l'excès. Garde l'installation des dépendances et le build de l'application dans des instructions `RUN` séparées pour que le layer des dépendances soit mis en cache indépendamment.

## Déboguer le comportement du cache

Utilise `docker build --progress=plain` pour voir quelles étapes sont en cache (`CACHED`) et lesquelles sont ré-exécutées. Utilise `docker history <image>` pour inspecter la taille des layers et repérer ceux qui sont anormalement gros.
