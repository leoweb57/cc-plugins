# Erreurs Compose courantes : avant et après

## 1. Health checks manquants sur les dépendances de base de données

### Mauvais

```yaml
services:
  web:
    build: .
    depends_on:
      - db
  db:
    image: postgres:17
```

`depends_on` sans condition attend seulement que le conteneur démarre, pas que Postgres accepte les connexions. Le service web va planter au démarrage.

### Bon

```yaml
services:
  web:
    build: .
    depends_on:
      db:
        condition: service_healthy
  db:
    image: postgres:17
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 3
      start_period: 10s
```

---

## 2. Utilisation du tag `latest`

### Mauvais

```yaml
services:
  cache:
    image: redis:latest
```

`latest` est mutable. Les builds deviennent non reproductibles et peuvent casser sans prévenir.

### Bon

```yaml
services:
  cache:
    image: redis:7
```

Épingle sur une version majeure ou mineure précise.

---

## 3. Secrets en dur dans compose.yaml

### Mauvais

```yaml
services:
  db:
    image: postgres:17
    environment:
      POSTGRES_PASSWORD: supersecretpassword123
```

Les secrets présents dans le fichier Compose finissent dans le contrôle de version.

### Bon

```yaml
services:
  db:
    image: postgres:17
    env_file:
      - .env
```

Avec un `.env` contenant `POSTGRES_PASSWORD=supersecretpassword123` et `.env` listé dans `.gitignore`.

---

## 4. Bind mount pour les données de base de données

### Mauvais

```yaml
services:
  db:
    image: postgres:17
    volumes:
      - ./pgdata:/var/lib/postgresql/data
```

Les bind mounts pour le stockage d'une base de données causent des problèmes de permissions et de mauvaises performances d'I/O sur macOS et Windows.

### Bon

```yaml
services:
  db:
    image: postgres:17
    volumes:
      - db-data:/var/lib/postgresql/data

volumes:
  db-data:
```

Les named volumes sont gérés par Docker et fonctionnent correctement sur toutes les plateformes.

---

## 5. Nom de fichier hérité (legacy)

### Mauvais

```
docker-compose.yml
```

### Bon

```
compose.yaml
```

`compose.yaml` est le nom de fichier canonique. `docker-compose.yml` est un nom hérité.

---

## 6. Réglages de développement dans le fichier Compose de base

### Mauvais

Un unique `compose.yaml` avec des bind mounts, des ports de debug et des variables d'environnement de développement mélangés aux réglages de production.

### Bon

Un `compose.yaml` de base avec des valeurs par défaut adaptées à la production. Les réglages réservés au développement dans `compose.override.yaml`, que Compose charge automatiquement :

```yaml
# compose.override.yaml
services:
  web:
    ports:
      - "9229:9229"
    environment:
      LOG_LEVEL: debug
    develop:
      watch:
        - action: sync
          path: ./src
          target: /app/src
```

---

## 7. Aucune politique de redémarrage

### Mauvais

```yaml
services:
  web:
    image: myapp:1.0.0
```

Sans politique de redémarrage, le conteneur reste arrêté après un crash ou un redémarrage de l'hôte.

### Bon

```yaml
services:
  web:
    image: myapp:1.0.0
    restart: unless-stopped
```
