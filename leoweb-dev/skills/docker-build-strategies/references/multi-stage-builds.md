# Patterns de builds multi-stage

Les builds multi-stage séparent les toolchains de build de l'image d'exécution. Chaque langage a un pattern courant.

## Structure générale

```dockerfile
# syntax=docker/dockerfile:1

# Stage 1: build
FROM <sdk-image> AS build
WORKDIR /src
RUN --mount=type=bind,source=<dependency-manifest>,target=<dependency-manifest> \
    <install-dependencies>
COPY . .
RUN <compile-or-bundle>

# Stage 2: runtime
FROM <minimal-base> AS runtime
WORKDIR /app
COPY --from=build --chown=appuser:appgroup /src/<artifact> .
USER appuser
ENTRYPOINT ["./artifact"]
```

## Go

Go produit des binaires statiques, donc le stage d'exécution peut utiliser `scratch` ou distroless.

```dockerfile
# syntax=docker/dockerfile:1

FROM golang:1.23-alpine AS build
WORKDIR /src
RUN --mount=type=bind,source=go.mod,target=go.mod \
    --mount=type=bind,source=go.sum,target=go.sum \
    --mount=type=cache,target=/go/pkg/mod \
    go mod download
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -ldflags="-s -w" -o /app/server ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot AS runtime
WORKDIR /app
COPY --from=build --link /app/server .
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["./server"]
```

Points clés :

- Utilise `CGO_ENABLED=0` pour obtenir un binaire entièrement statique quand cgo n'est pas nécessaire.
- Utilise `-ldflags="-s -w"` pour retirer les symboles de debug et réduire la taille du binaire.
- Mets en cache à la fois `/go/pkg/mod` (modules téléchargés) et `/root/.cache/go-build` (cache de compilation).
- Fais un bind mount de `go.mod`/`go.sum` dans l'étape `go mod download` au lieu de les `COPY` ; `go mod download` seul ne les réécrit pas. Le `COPY . .` complet du code source qui suit les fait quand même entrer dans l'image pour l'étape de build.
- Les images distroless static incluent un utilisateur `nonroot` intégré.
- Pour les modules `GOPRIVATE` récupérés via Git SSH, utilise `--mount=type=ssh` au lieu d'intégrer des clés ou des tokens. Remplis `known_hosts` dans le même `RUN`, associe la réécriture de la config git au téléchargement pour que la config ne persiste pas dans les stages suivants, et définis `GOPRIVATE` en ligne pour que `go mod download` contourne le proxy public et la base de checksums (`GOPRIVATE` implique `GONOSUMDB` et `GONOPROXY`) :
  ```dockerfile
  RUN --mount=type=ssh \
      --mount=type=cache,target=/go/pkg/mod \
      mkdir -p -m 0700 /root/.ssh && \
      ssh-keyscan -t ed25519 github.com >> /root/.ssh/known_hosts && \
      git config --global url."git@github.com:".insteadOf "https://github.com/" && \
      GOPRIVATE="github.com/your-org/*" go mod download
  ```
  Invoque avec `docker buildx build --ssh default .`, qui redirige l'agent SSH du shell qui lance le build. L'étape `RUN --mount=type=ssh` peut utiliser toutes les clés que liste `ssh-add -l`. Pour n'exposer que la clé de ce build, lance `ssh-agent bash` dans un terminal interactif, puis `ssh-add <key-file>`, et exécute le build dans ce shell. Pour passer directement un fichier de clé non chiffré sans agent, utilise `--ssh default=<key-file>` ; BuildKit rejette les clés protégées par une passphrase sous cette forme.

## Node.js

Les applications Node.js nécessitent le runtime Node, donc utilise une base slim pour le stage d'exécution.

```dockerfile
# syntax=docker/dockerfile:1

FROM node:22-alpine AS deps
WORKDIR /src
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=secret,id=npmrc,target=/root/.npmrc,required=false \
    --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev

FROM node:22-alpine AS build
WORKDIR /src
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=secret,id=npmrc,target=/root/.npmrc,required=false \
    --mount=type=cache,target=/root/.npm \
    npm ci
COPY . .
RUN npm run build

FROM node:22-alpine AS runtime
WORKDIR /app
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 --ingroup appgroup appuser
COPY --from=deps --chown=appuser:appgroup /src/node_modules ./node_modules
COPY --from=build --chown=appuser:appgroup /src/dist ./dist
COPY --from=build --chown=appuser:appgroup /src/package.json .
USER appuser
EXPOSE 3000
ENTRYPOINT ["node", "dist/index.js"]
```

Invoque avec l'identifiant de registre monté uniquement pendant `npm ci` :

```sh
docker buildx build --secret id=npmrc,src=$HOME/.npmrc .
```

Points clés :

- Utilise un stage `deps` séparé qui n'installe que les dépendances de production (`--omit=dev`).
- Utilise un stage `build` avec toutes les dépendances pour la compilation/le bundling.
- Copie le `node_modules` de production depuis le stage `deps`, pas depuis le stage `build`.
- Fais un bind mount de `package.json`/`package-lock.json` dans `npm ci` au lieu de les `COPY` : `npm ci` ne réécrit jamais le lockfile. Utilise plutôt `COPY` si la commande d'installation peut le modifier (par ex. `npm install` sans lockfile correspondant).
- **Ne fais jamais de `COPY .npmrc`** : les identifiants de registre doivent être montés avec `--mount=type=secret`, pas copiés dans un layer.
- Si le projet utilise un bundler qui produit une sortie standalone (par ex. le mode standalone de Next.js), copie uniquement la sortie standalone et ignore complètement `node_modules`.

## Python

Les applications Python utilisent un environnement virtuel pour isoler les dépendances. Copie le venv dans le stage d'exécution.

```dockerfile
# syntax=docker/dockerfile:1

FROM python:3.13-slim AS build
WORKDIR /src
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN --mount=type=bind,source=requirements.txt,target=requirements.txt \
    --mount=type=secret,id=pip-conf,target=/etc/pip.conf,required=false \
    --mount=type=cache,target=/root/.cache/pip \
    pip install --no-compile -r requirements.txt
COPY . .

FROM python:3.13-slim AS runtime
WORKDIR /app
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 --ingroup appgroup appuser
COPY --from=build --chown=appuser:appgroup /opt/venv /opt/venv
COPY --from=build --chown=appuser:appgroup /src /app
ENV PATH="/opt/venv/bin:$PATH"
USER appuser
EXPOSE 8000
ENTRYPOINT ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0"]
```

Points clés :

- Construis l'environnement virtuel dans le stage de build et copie-le en entier dans le stage d'exécution.
- Définis `PATH` pour utiliser le venv dans les deux stages.
- Utilise `--no-compile` pendant le pip install pour ignorer la génération des `.pyc` (Python compilera au premier import).
- Fais un bind mount de `requirements.txt` dans l'étape `pip install` au lieu de le `COPY` : `pip install -r` ne réécrit pas le fichier.
- Pour les projets Poetry ou PDM, exporte d'abord vers `requirements.txt` ou utilise l'export intégré de l'outil.
- Pour les index de paquets privés, passe `pip.conf` via `--mount=type=secret,id=pip-conf,target=/etc/pip.conf` au lieu de `COPY pip.conf` (qui fuiterait dans un layer). Invoque avec `docker buildx build --secret id=pip-conf,src=$HOME/.config/pip/pip.conf .` (chemin XDG, pip ≥ 19.1) ou l'ancien `$HOME/.pip/pip.conf`.

## Java

Les applications Java se compilent en JARs. Utilise un JDK pour le build et un JRE pour l'exécution.

```dockerfile
# syntax=docker/dockerfile:1

FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /src
COPY pom.xml .
COPY .mvn .mvn
COPY mvnw .
RUN --mount=type=cache,target=/root/.m2 \
    --mount=type=secret,id=maven-settings,target=/root/.m2/settings.xml,required=false \
    ./mvnw dependency:go-offline -B
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 \
    --mount=type=secret,id=maven-settings,target=/root/.m2/settings.xml,required=false \
    ./mvnw package -DskipTests -B

FROM eclipse-temurin:21-jre-alpine AS runtime
WORKDIR /app
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 -G appgroup appuser
COPY --from=build --chown=appuser:appgroup /src/target/*.jar app.jar
USER appuser
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

Points clés :

- Utilise `dependency:go-offline` (Maven) ou une tâche de résolution de dépendances Gradle pour mettre les dépendances en cache avant de copier le code source.
- Mets en cache le répertoire `.m2` ou `.gradle` avec un cache mount.
- Utilise une image JRE (pas JDK) pour le stage d'exécution.
- Pour les images natives GraalVM, le stage d'exécution peut utiliser `scratch` ou distroless, comme pour Go.
- Pour les dépôts Maven privés, passe `~/.m2/settings.xml` via `--mount=type=secret,id=maven-settings,target=/root/.m2/settings.xml` au lieu de `COPY settings.xml`. Invoque avec `docker buildx build --secret id=maven-settings,src=$HOME/.m2/settings.xml .`.

## Quand ajouter des stages

Ajoute des stages intermédiaires quand :

- Tu as besoin d'une résolution de dépendances séparée (dépendances de production vs de développement, comme en Node.js).
- Tu veux lancer les tests dans un stage dédié sans polluer les stages de build ou d'exécution.
- Tu génères des assets (CSS, fichiers statiques) avec un outil distinct du build principal de l'application.

Nomme chaque stage. Ne te fie jamais aux indices numériques de stages.
