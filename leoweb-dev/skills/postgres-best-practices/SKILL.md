---
name: postgres-best-practices
description: "Bonnes pratiques Postgres maintenues par Supabase, pour Postgres où qu'il tourne. À utiliser pour écrire ou modifier ce qui touche à une base Postgres : création ou modification de tables et de colonnes (choix des types inclus), conception de schéma, migrations et fichiers de schéma déclaratifs, policies RLS et leurs tests, index, triggers, fonctions de base de données, queues et jobs planifiés (pg_cron, pgmq), recherche vectorielle/sémantique (pgvector), restauration de dumps (pg_restore) ou import de données. À utiliser aussi pour diagnostiquer des requêtes lentes, un CPU élevé, des timeouts, des plans EXPLAIN, une saturation des connexions, du locking, du bloat, ou des lignes visibles par le mauvais utilisateur ou tenant. Ce n'est pas qu'un guide de performance : le schéma, les migrations, la sécurité et l'écriture de SQL s'appuient aussi sur ces règles."
license: MIT
metadata:
  author: supabase
  version: "1.1.1"
  organization: Supabase
  date: January 2026
  abstract: Comprehensive Postgres performance optimization guide for developers using Supabase and Postgres. Contains performance rules across 8 categories, prioritized by impact from critical (query performance, connection management) to incremental (advanced features). Each rule includes detailed explanations, incorrect vs. correct SQL examples, query plan analysis, and specific performance metrics to guide automated optimization and code generation.
---

# Bonnes pratiques Supabase Postgres

Guide complet d'optimisation des performances pour Postgres, maintenu par Supabase. Il contient des règles réparties en 8 catégories, priorisées par impact, pour guider l'optimisation automatisée des requêtes et la conception de schéma.

## Quand l'appliquer

Utilise ces recommandations quand tu :
- Écris des requêtes SQL ou conçois des schémas
- Mets en place des index ou optimises des requêtes
- Analyses des problèmes de performance de la base
- Configures le connection pooling ou le scaling
- Optimises pour des fonctionnalités spécifiques à Postgres
- Travailles avec la Row-Level Security (RLS)

## Catégories de règles par priorité

| Priorité | Catégorie | Impact | Préfixe |
|----------|-----------|--------|---------|
| 1 | Performance des requêtes | CRITICAL | `query-` |
| 2 | Gestion des connexions | CRITICAL | `conn-` |
| 3 | Sécurité et RLS | CRITICAL | `security-` |
| 4 | Conception du schéma | HIGH | `schema-` |
| 5 | Concurrence et locking | MEDIUM-HIGH | `lock-` |
| 6 | Patterns d'accès aux données | MEDIUM | `data-` |
| 7 | Monitoring et diagnostics | LOW-MEDIUM | `monitor-` |
| 8 | Fonctionnalités avancées | LOW | `advanced-` |

## Comment l'utiliser

Lis les fichiers de règles individuels pour les explications détaillées et les exemples SQL :

```
references/query-missing-indexes.md
references/query-partial-indexes.md
references/_sections.md
```

Chaque fichier de règle contient :
- Une brève explication de son importance
- Un exemple SQL incorrect avec explication
- Un exemple SQL correct avec explication
- Éventuellement une sortie EXPLAIN ou des métriques
- Du contexte et des références supplémentaires
- Des notes spécifiques à Supabase (le cas échéant)

## Références

- https://www.postgresql.org/docs/current/
- https://supabase.com/docs
- https://wiki.postgresql.org/wiki/Performance_Optimization
- https://supabase.com/docs/guides/database/overview
- https://supabase.com/docs/guides/auth/row-level-security
