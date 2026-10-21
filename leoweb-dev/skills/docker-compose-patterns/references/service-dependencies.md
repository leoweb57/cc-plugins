# Dépendances entre services et ordre de démarrage

## Conditions de depends_on

La clé `depends_on` supporte trois conditions :

| Condition | Signification |
|---|---|
| `condition: service_started` | Attend seulement que le conteneur démarre (valeur par défaut si aucune condition n'est précisée). |
| `condition: service_healthy` | Attend que le health check du conteneur réussisse. |
| `condition: service_completed_successfully` | Attend que le conteneur s'exécute et se termine avec le code 0. Utile pour les conteneurs d'init/de migration. |

Utilise toujours `condition: service_healthy` pour les services d'infrastructure (bases de données, caches, message brokers). La condition `service_started` est insuffisante car un conteneur peut tourner avant que le processus qu'il contient n'accepte des connexions.

## Patterns de health check pour les services courants

### PostgreSQL

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-postgres}"]
  interval: 5s
  timeout: 3s
  retries: 3
  start_period: 10s
```

### MySQL / MariaDB

```yaml
healthcheck:
  test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
  interval: 5s
  timeout: 3s
  retries: 3
  start_period: 20s
```

MySQL peut mettre plus de temps à s'initialiser au premier lancement. Utilise un `start_period` de 20s ou plus.

### Redis

```yaml
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 5s
  timeout: 3s
  retries: 3
  start_period: 5s
```

### MongoDB

```yaml
healthcheck:
  test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
  interval: 5s
  timeout: 3s
  retries: 3
  start_period: 10s
```

### RabbitMQ

```yaml
healthcheck:
  test: ["CMD", "rabbitmq-diagnostics", "check_running"]
  interval: 10s
  timeout: 5s
  retries: 3
  start_period: 30s
```

RabbitMQ a un temps de démarrage plus long. Définis `start_period` à 30s au minimum.

### Elasticsearch

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -fs http://localhost:9200/_cluster/health || exit 1"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s
```

## Pattern des conteneurs d'init

Utilise `service_completed_successfully` pour les tâches ponctuelles comme les migrations de base de données :

```yaml
services:
  migrate:
    image: myapp:1.2.0
    command: ["./manage.py", "migrate"]
    depends_on:
      db:
        condition: service_healthy

  web:
    image: myapp:1.2.0
    depends_on:
      db:
        condition: service_healthy
      migrate:
        condition: service_completed_successfully
```

Cela garantit que les migrations se terminent avant le démarrage du service web.

## Comportement au redémarrage et dépendances

`depends_on` ne régit que l'ordre de démarrage initial. Il ne se redéclenche pas si une dépendance redémarre. Pour la résilience à l'exécution :

- Configure une logique de retry/reconnexion au niveau de l'application.
- Utilise `restart: unless-stopped` pour que les services se rétablissent après des défaillances transitoires.
- N'enchaîne pas de longs arbres de dépendances. Garde le graphe peu profond : les chaînes profondes allongent le temps de démarrage total et augmentent la fragilité.
