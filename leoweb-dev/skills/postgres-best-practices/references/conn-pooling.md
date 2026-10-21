---
title: Utiliser le connection pooling pour toutes les applications
impact: CRITICAL
impactDescription: Handle 10-100x more concurrent users
tags: connection-pooling, pgbouncer, performance, scalability
---

## Utiliser le connection pooling pour toutes les applications

Les connexions Postgres sont coûteuses (1-3 Mo de RAM chacune). Sans pooling, les applications épuisent les connexions sous charge.

**Incorrect (nouvelle connexion à chaque requête) :**

```sql
-- Each request creates a new connection
-- Application code: db.connect() per request
-- Result: 500 concurrent users = 500 connections = crashed database

-- Check current connections
select count(*) from pg_stat_activity;  -- 487 connections!
```

**Correct (connection pooling) :**

```sql
-- Use a pooler like PgBouncer between app and database
-- Application connects to pooler, pooler reuses a small pool to Postgres

-- Configure pool_size based on: (CPU cores * 2) + spindle_count
-- Example for 4 cores: pool_size = 10

-- Result: 500 concurrent users share 10 actual connections
select count(*) from pg_stat_activity;  -- 10 connections
```

Modes de pool :

- **Transaction mode** : la connexion est rendue après chaque transaction (le meilleur choix pour la plupart des applications)
- **Session mode** : la connexion est conservée pendant toute la session (nécessaire pour les prepared statements, les tables temporaires)

Reference: [Connection Pooling](https://supabase.com/docs/guides/database/connecting-to-postgres#connection-pooler)
