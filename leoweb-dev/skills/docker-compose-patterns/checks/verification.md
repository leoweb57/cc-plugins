# Runbook de vérification des fichiers Compose générés

Exécute ces vérifications sur chaque `compose.yaml` généré avant de le considérer comme terminé.

## 1. Validation de la syntaxe et du schéma

Lance le script fourni depuis la racine du projet (le répertoire qui contient `compose.yaml`), avec le chemin du script résolu dans le répertoire du skill :

```bash
bash "<skill-dir>/scripts/verify-compose.sh" [--help]
```

Remplace `<skill-dir>` par le chemin absolu du répertoire de ce skill, le dossier qui contient `SKILL.md` et ce dossier `checks/`. Ne te place pas dans le répertoire du skill pour l'exécuter ; le script valide le projet Compose du répertoire courant.

Le code de sortie est `0` quand la configuration Compose est valide ou que l'aide est demandée, le code non nul de `docker compose config --quiet` quand la validation échoue, et `2` pour des arguments invalides.

Pour lancer directement la validation sous-jacente :

```bash
docker compose config --quiet
```

Cette commande analyse et valide le fichier Compose sans afficher la configuration résolue. Elle résout quand même les variables et lit les fichiers `env_file` des services. Si elle se termine avec un code non nul, corrige les erreurs signalées avant de poursuivre.

Un simple `docker compose config` affiche les identifiants interpolés et ceux de `env_file`. Ne capture pas cette sortie dans les logs de CI ni dans les transcriptions d'agent. S'il est nécessaire d'inspecter la configuration rendue, utilise une copie séparée avec des identifiants factices et relis-la en local. `--quiet` supprime l'affichage de la configuration, pas les avertissements ni les erreurs ; les diagnostics peuvent quand même contenir des détails sensibles.

## 2. Présence des health checks

Vérifie que chaque service de base de données, de cache ou de message broker a un `healthcheck` défini. Relis les fichiers source Compose, overrides compris, et confirme que ces services incluent `healthcheck.test`, `healthcheck.interval`, `healthcheck.timeout`, `healthcheck.retries` et `healthcheck.start_period`. Pour inspecter le rendu, suis la précaution des identifiants factices ci-dessus.

Services qui doivent avoir des health checks :

- PostgreSQL, MySQL, MariaDB
- Redis, Memcached
- MongoDB
- RabbitMQ, Kafka
- Elasticsearch

## 3. Ordre des dépendances

Pour chaque service avec `depends_on` :

- Confirme que `condition: service_healthy` est défini pour les dépendances d'infrastructure.
- Confirme que le service référencé a un `healthcheck` correspondant.
- Confirme qu'il n'existe aucune dépendance circulaire (Compose les rejette, mais vérifie l'intention).

## 4. Définitions des volumes

- Chaque volume référencé dans la liste `volumes:` d'un service au format `name:/path` doit avoir une entrée correspondante dans la clé `volumes:` de premier niveau.
- Les services de base de données doivent utiliser des named volumes, pas des bind mounts, pour leurs répertoires de données.
- Les bind mounts ne doivent apparaître que dans les fichiers d'override de développement.

## 5. Variables d'environnement et secrets

- Aucun mot de passe, clé d'API ou token en clair n'apparaît directement dans `compose.yaml`.
- Les valeurs sensibles utilisent `env_file:` ou les Docker secrets.
- Si `.env` est référencé, confirme que `.env` est dans `.gitignore`.

## 6. Ports publiés et montages de l'hôte

- Les ports publiés des datastores sont liés à la loopback, sauf si un accès distant à l'hôte est explicitement requis.
- Les services ne montent pas le socket Docker depuis `/var/run/docker.sock` ou `/run/docker.sock`.

## 7. Tags d'image

- Aucun service n'utilise le tag `latest` ni n'omet complètement le tag.
- Toutes les références d'image incluent une version explicite.

## 8. Vérification à l'exécution

Après `docker compose up -d` :

```bash
# Check all services are running and healthy
docker compose ps

# Verify health check status specifically
docker inspect --format='{{.State.Health.Status}}' <container_name>

# Check logs for startup errors
docker compose logs --tail=50

# Verify inter-service connectivity
docker compose exec web ping -c 1 db
```

## 9. Nom des fichiers

- Le fichier s'appelle `compose.yaml`, pas `docker-compose.yml` ni `docker-compose.yaml`.
- Les overrides de développement sont dans `compose.override.yaml`.
