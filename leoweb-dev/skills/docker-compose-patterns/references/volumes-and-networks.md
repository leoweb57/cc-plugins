# Volumes et réseaux

## Types de volumes

### Named volumes

Utilise des named volumes pour les données qui doivent survivre à la recréation des conteneurs :

```yaml
services:
  db:
    image: postgres:17
    volumes:
      - db-data:/var/lib/postgresql/data

volumes:
  db-data:
```

Les named volumes sont gérés par Docker. Ils survivent à `docker compose down` (mais pas à `docker compose down -v`, qui les supprime avec leurs données de façon irréversible). N'exécute jamais `down -v` pour contourner un problème de démarrage ou de connectivité : obtiens d'abord une confirmation explicite de l'utilisateur.

### Bind mounts

Utilise des bind mounts pour synchroniser des répertoires de l'hôte dans les conteneurs. Approprié uniquement pour le montage du code source en développement :

```yaml
services:
  web:
    build: .
    volumes:
      - ./src:/app/src
```

N'utilise pas de bind mounts pour les données de base de données : ils causent des problèmes de permissions et de mauvaises performances sur macOS et Windows.

### Volumes anonymes

Évite les volumes anonymes (volumes sans nom et sans chemin sur l'hôte). Ils sont difficiles à suivre et à nettoyer. Utilise toujours des named volumes.

### Montages tmpfs

Utilise `tmpfs` pour les données de travail éphémères qui ne doivent pas persister :

```yaml
services:
  app:
    image: myapp:1.0.0
    tmpfs:
      - /tmp
      - /app/cache
```

## Options de montage des volumes

- Utilise `:ro` pour monter les volumes en lecture seule quand le conteneur ne doit pas y écrire.
- Utilise `:cached` ou `:delegated` sur macOS uniquement quand les performances l'exigent et que les compromis sur la cohérence des données sont acceptables. Préfère Compose Watch (`develop.watch`) aux bind mounts avec options de performance.

## Patterns de volumes

### Exclure node_modules des bind mounts

Quand tu fais un bind mount d'un projet Node.js, exclus `node_modules` avec un volume anonyme pour empêcher les dépendances de l'hôte d'écraser celles du conteneur :

```yaml
services:
  web:
    build: .
    volumes:
      - ./:/app
      - /app/node_modules
```

Cela monte la racine du projet tout en conservant le `node_modules` propre au conteneur.

### Partager des données entre services

Utilise un named volume pour partager des fichiers entre services :

```yaml
services:
  generator:
    image: myapp:1.0.0
    volumes:
      - shared-data:/output

  consumer:
    image: nginx:1.27
    volumes:
      - shared-data:/usr/share/nginx/html:ro

volumes:
  shared-data:
```

## Réseaux

### Réseau par défaut

Compose crée un réseau par défaut pour chaque projet. Tous les services le rejoignent automatiquement. Les services peuvent se joindre entre eux en utilisant le nom du service comme hostname. Pour la plupart des stacks d'une seule application, le réseau par défaut suffit.

### Réseaux personnalisés pour l'isolation

Utilise des réseaux personnalisés quand tu as besoin d'isoler des groupes de services :

```yaml
services:
  web:
    image: myapp:1.0.0
    networks:
      - frontend
      - backend

  db:
    image: postgres:17
    networks:
      - backend

  proxy:
    image: nginx:1.27
    networks:
      - frontend

networks:
  frontend:
  backend:
```

Dans cet exemple, `proxy` ne peut pas joindre `db` directement car ils ne partagent aucun réseau. `web` fait le pont entre les deux.

### Réseaux externes

Utilise `external: true` pour référencer un réseau créé en dehors de ce fichier Compose :

```yaml
networks:
  shared:
    external: true
    name: my-shared-network
```

C'est utile quand plusieurs projets Compose doivent communiquer entre eux.

### Alias réseau

Utilise des alias pour donner à un service des hostnames supplémentaires sur un réseau précis :

```yaml
services:
  db:
    image: postgres:17
    networks:
      backend:
        aliases:
          - database
          - postgres
```

Les autres services du réseau `backend` peuvent joindre ce service sous les noms `db`, `database` ou `postgres`.
