# Définitions des sections

Ce fichier définit les catégories de règles pour les bonnes pratiques Postgres. Les règles sont automatiquement rattachées aux sections d'après le préfixe de leur nom de fichier.

Prends les exemples ci-dessous à titre purement démonstratif. Remplace chaque section par les véritables catégories de règles des bonnes pratiques Postgres.

---

## 1. Performance des requêtes (query)
**Impact:** CRITICAL
**Description:** Requêtes lentes, index manquants, plans de requête inefficaces. La source la plus courante de problèmes de performance Postgres.

## 2. Gestion des connexions (conn)
**Impact:** CRITICAL
**Description:** Connection pooling, limites et stratégies serverless. Critique pour les applications à forte concurrence ou les déploiements serverless.

## 3. Sécurité et RLS (security)
**Impact:** CRITICAL
**Description:** Policies Row-Level Security, gestion des privilèges et patterns d'authentification.

## 4. Conception du schéma (schema)
**Impact:** HIGH
**Description:** Conception des tables, stratégies d'index, partitionnement et choix des types de données. Fondation de la performance à long terme.

## 5. Concurrence et locking (lock)
**Impact:** MEDIUM-HIGH
**Description:** Gestion des transactions, niveaux d'isolation, prévention des deadlocks et patterns de contention de locks.

## 6. Patterns d'accès aux données (data)
**Impact:** MEDIUM
**Description:** Élimination des requêtes N+1, opérations par lots, pagination par curseur et récupération efficace des données.

## 7. Monitoring et diagnostics (monitor)
**Impact:** LOW-MEDIUM
**Description:** Utilisation de pg_stat_statements, EXPLAIN ANALYZE, collecte de métriques et diagnostics de performance.

## 8. Fonctionnalités avancées (advanced)
**Impact:** LOW
**Description:** Recherche full-text, optimisation JSONB, PostGIS, extensions et fonctionnalités avancées de Postgres.
