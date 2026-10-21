---
name: docker-compose-patterns
description: "Utilise ce skill pour créer, modifier ou déboguer des configurations Docker Compose, même si l'utilisateur dit simplement qu'il doit relier des services entre eux, ajouter une base de données à sa stack ou mettre en place un environnement de développement local avec plusieurs conteneurs. Couvre les définitions de services, les health checks, l'ordre des dépendances, les volumes, les réseaux, les variables d'environnement et les overrides de développement."
license: Apache-2.0
compatibility: Requires Docker Compose v2 (compose.yaml format).
---

# Docker Compose Patterns

## Vue d'ensemble

Ce skill fournit des règles pour créer, relire et déboguer des configurations Docker Compose. Utilise-le quand l'artefact principal est `compose.yaml` ou `compose.override.yaml` et que la tâche porte sur le câblage des services plutôt que sur les détails internes de build des images.

## Quand utiliser ce skill

Active ce skill quand :

- Tu crées un nouveau `compose.yaml` pour un projet
- Tu ajoutes ou modifies des services dans un fichier Compose existant
- Tu mets en place des overrides de développement avec `compose.override.yaml`
- Tu débogues des problèmes d'ordre de démarrage ou de connectivité entre services

## Quand ne pas utiliser ce skill

N'utilise pas ce skill quand :

- Le projet n'a pas encore de setup Docker et que le besoin principal est un scaffold initial
- La tâche principale est d'écrire ou d'optimiser un `Dockerfile`
- La tâche principale est d'améliorer le cache de build, la taille de l'image ou la configuration de l'utilisateur d'exécution

## Principes essentiels

### Nom des fichiers

Utilise `compose.yaml` comme nom de fichier canonique. N'utilise pas `docker-compose.yml` ni `docker-compose.yaml` : ce sont des noms hérités (legacy).

### Définition des services

- Donne aux services des noms clairs, en minuscules, qui reflètent leur rôle : `web`, `db`, `cache`, `worker`.
- Épingle toujours les tags d'image sur une version précise. N'utilise jamais `latest` et n'omets jamais le tag.
- Définis `restart: unless-stopped` pour les services d'infrastructure de longue durée et pour les déploiements hors développement.
- N'ajoute `container_name` que si des outils externes ont besoin d'un nom prévisible. Sinon, laisse Compose générer les noms.

### Modélisation des dépendances

- Utilise `depends_on` avec `condition: service_healthy` pour les services qui doivent être prêts avant le démarrage de leurs dépendants.
- Tout service listé dans `depends_on` avec une condition de santé doit avoir un `healthcheck` défini.
- Ne te repose pas sur `depends_on` sans condition : il garantit seulement le démarrage du conteneur, pas sa disponibilité.

### Health checks

- Ajoute toujours un `healthcheck` aux services de base de données (Postgres, MySQL, Redis, MongoDB).
- Utilise l'outil client natif du service pour les health checks quand il existe (par ex. `pg_isready`, `redis-cli ping`, `mysqladmin ping`).
- Définis des valeurs raisonnables pour `interval`, `timeout`, `retries` et `start_period`. Commence avec : `interval: 5s`, `timeout: 3s`, `retries: 3`, `start_period: 10s`.

#### Health checks pour les images distroless ou scratch

Les images distroless, basées sur scratch et durcies (hardened) ne contiennent ni shell, ni curl, ni wget. N'intègre pas d'outils dans ces images : ça irait à l'encontre de leur raison d'être. Utilise plutôt un **sidecar de healthcheck** qui partage le network namespace de l'application :

```yaml
services:
  api:
    build:
      context: .
      target: runtime          # distroless / hardened image
    ports:
      - "8080:8080"
    # No healthcheck here — the image has no tools to run one

  api-health:
    image: curlimages/curl:8.22.0
    network_mode: "service:api"   # shares api's localhost
    entrypoint: ["sleep", "infinity"]  # keep sidecar alive for healthcheck
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 45s
    deploy:
      resources:
        limits:
          memory: 32M
```

Points clés :
- Le sidecar doit rester actif avec `entrypoint: ["sleep", "infinity"]` pour que Compose puisse exécuter le healthcheck à l'intérieur.
- `network_mode: "service:api"` fait pointer `localhost` dans le sidecar vers la loopback du conteneur api : aucune configuration réseau supplémentaire n'est nécessaire.
- Garde le sidecar léger avec une limite de ressources (32 Mo suffisent pour curl).
- Les services qui dépendent de la disponibilité de `api` doivent référencer le **sidecar**, pas directement api :

```yaml
  worker:
    depends_on:
      api-health:
        condition: service_healthy
```

### Volumes

- Utilise des named volumes pour les données qui doivent survivre à la recréation des conteneurs (données de base de données, fichiers uploadés).
- N'utilise des bind mounts que pour la synchronisation du code source en développement.
- Définis tous les named volumes dans la clé `volumes:` de premier niveau.
- Ne monte pas le socket Docker sauf si le service en a réellement besoin.

### Réseaux

- Pour les stacks d'une seule application, le réseau par défaut suffit. Ne crée pas de réseaux personnalisés, sauf si tu as besoin d'isoler des groupes de services.
- Quand tu crées des réseaux personnalisés, préfère le driver bridge et donne aux réseaux des noms descriptifs.
- Utilise la clé `networks:` de premier niveau pour définir tous les réseaux personnalisés.

### Variables d'environnement

- Utilise `environment:` pour les valeurs non sensibles et peu nombreuses.
- Utilise `env_file:` pointant vers un fichier `.env` pour les listes de variables plus longues.
- Ne mets jamais de secrets (mots de passe, clés d'API) en dur dans `compose.yaml`. Utilise `env_file:` ou les Docker secrets.
- Quand des valeurs par défaut sont nécessaires dans le bloc `environment:` pour le développement local, utilise la substitution de variable avec valeur de repli : `${DB_PASSWORD:-postgres}`. N'écris jamais de valeurs en clair pour les champs de mot de passe.
- Ajoute `.env` au `.gitignore`.

### Overrides de développement

- Utilise `compose.override.yaml` pour les réglages réservés au développement. Compose le charge automatiquement avec `compose.yaml`.
- Mets dans le fichier d'override les bind mounts du code source, les ports de debug et les variables d'environnement de développement.
- Utilise `develop.watch` pour la synchronisation de fichiers et le rebuild automatique en développement quand c'est supporté.
- Garde les réglages orientés production dans le `compose.yaml` de base et n'override que ce qui change pour le développement.

### Compose Watch

- Préfère `develop.watch` aux bind mounts manuels pour les workflows de développement.
- Utilise `action: sync` pour les fichiers qui doivent être copiés dans le conteneur à chaque modification (code source).
- Utilise `action: rebuild` pour les fichiers qui nécessitent un rebuild complet de l'image (fichiers de dépendances comme `package.json`, `requirements.txt`).
- Utilise `action: sync+restart` pour les fichiers de configuration qui nécessitent un redémarrage du processus.

### Commandes destructives

Certaines commandes Compose suppriment des données de façon irréversible. Avant d'exécuter l'une des suivantes, indique exactement quelles données seront supprimées et obtiens une confirmation explicite de l'utilisateur : ne les lance pas comme effet de bord d'un débogage, d'un redémarrage ou d'un « nettoyage » de la stack :

- `docker compose down -v` / `docker compose down --volumes` : supprime les named volumes, y compris les données de base de données.
- `docker volume rm` / `docker volume prune` exécutés sur les volumes d'un projet Compose : supprime directement les volumes. Pour le cas autonome (sans projet Compose en jeu), vois plutôt `docker-destructive-guardrails`. Un volume référencé via `external: true` n'est pas non plus géré par le projet Compose (`down -v` n'y touchera pas) : traite-le comme le cas autonome, exécute d'abord `docker volume rm` sans `-f` et obtiens une confirmation explicite avant de le supprimer.
- `docker compose rm -v` : supprime les volumes anonymes attachés aux conteneurs supprimés.

Si le but est seulement de redémarrer des services ou de récupérer des conteneurs/réseaux, utilise `docker compose down` (sans `-v`) ou `docker compose restart` à la place : ces commandes laissent les named volumes intacts.

## Skills liés

- Pour le scaffolding initial d'un projet Docker et la création des fichiers de base, utilise `docker-project-foundations`.
- Pour les détails internes du Dockerfile, le cache de build, les builds multi-stage et `.dockerignore`, utilise `docker-build-strategies`.
- Pour les commandes Docker CLI destructives hors Compose (`docker system prune`, `docker rm -f`, nettoyage d'images/réseaux/builders, suppression de volumes autonomes) et un index transverse des garde-fous sur les commandes destructives, utilise `docker-destructive-guardrails`.

## Références

- `references/service-dependencies.md` : guide détaillé sur `depends_on`, les patterns de health check pour les bases de données courantes et les stratégies d'ordre de démarrage.
- `references/volumes-and-networks.md` : patterns pour les montages de volumes, les named volumes, les bind mounts et la configuration réseau.

## Assets

- `assets/compose-web-app.yaml` : application web multi-services complète (app + Postgres + Redis) avec health checks, dépendances et named volumes.
- `assets/compose-dev-override.yaml` : override de développement montrant les bind mounts, les ports de debug et la configuration de Compose Watch.
- `assets/bad-vs-good.md` : comparaisons avant/après des erreurs Compose courantes et de leurs corrections.

## Scripts

- **`scripts/verify-compose.sh`** : valide le projet Compose du répertoire courant avec `docker compose config --quiet`, sans afficher la configuration résolue. Lance-le depuis la racine du projet (le répertoire qui contient `compose.yaml`), avec le chemin du script résolu dans le répertoire de ce skill :
  ```bash
  bash "<skill-dir>/scripts/verify-compose.sh" [--help]
  ```
  Remplace `<skill-dir>` par le chemin absolu du dossier qui contient ce `SKILL.md` ; le chemin `scripts/` est relatif à ce dossier, pas au projet. Ne te place pas d'abord dans le répertoire du skill : le script valide le projet Compose présent dans le répertoire courant. Si le répertoire du skill ne peut pas être résolu, lance directement `docker compose config --quiet`. Le code de sortie est `0` quand la configuration Compose est valide ou que l'aide est demandée, le code non nul de `docker compose config --quiet` quand la validation échoue, et `2` pour des arguments invalides. Un simple `docker compose config` peut exposer dans la sortie de l'outil ou les logs les identifiants interpolés et ceux de `env_file` ; utilise la validation silencieuse par défaut. Les avertissements et erreurs de Compose sont quand même émis et peuvent contenir des détails sensibles.

## Vérifications

- `checks/verification.md` : runbook de vérification détaillé pour la revue manuelle.
