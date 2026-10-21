---
title: Choisir la stratégie de clé primaire optimale
impact: HIGH
impactDescription: Meilleure localité des index, fragmentation réduite
tags: primary-key, identity, uuid, serial, schema
---

## Choisir la stratégie de clé primaire optimale

Le choix de la clé primaire influe sur les performances d'insertion, la taille des index et l'efficacité de la réplication.

**Incorrect (choix de PK problématiques) :**

```sql
-- identity is the SQL-standard approach
create table users (
  id serial primary key  -- Works, but IDENTITY is recommended
);

-- Random UUIDs (v4) cause index fragmentation
create table orders (
  id uuid default gen_random_uuid() primary key  -- UUIDv4 = random = scattered inserts
);
```

**Correct (stratégies de PK optimales) :**

```sql
-- Use IDENTITY for sequential IDs (SQL-standard, best for most cases)
create table users (
  id bigint generated always as identity primary key
);

-- For distributed systems needing UUIDs, use UUIDv7 (time-ordered)
-- Requires pg_uuidv7 extension: create extension pg_uuidv7;
create table orders (
  id uuid default uuid_generate_v7() primary key  -- Time-ordered, no fragmentation
);

-- Alternative: time-prefixed IDs for sortable, distributed IDs (no extension needed)
create table events (
  id text default concat(
    to_char(now() at time zone 'utc', 'YYYYMMDDHH24MISSMS'),
    gen_random_uuid()::text
  ) primary key
);
```

Recommandations :

- Base de données unique : `bigint identity` (séquentiel, 8 octets, standard SQL)
- IDs distribués ou exposés : UUIDv7 (nécessite pg_uuidv7) ou ULID (ordonné dans
  le temps, sans fragmentation)
- `serial` fonctionne, mais `identity` est le standard SQL et il est à privilégier
  pour les nouvelles applications
- Évite les UUID aléatoires (v4) comme clés primaires sur les grosses tables
  (fragmentation des index)

Référence :
[Identity Columns](https://www.postgresql.org/docs/current/sql-createtable.html#SQL-CREATETABLE-PARMS-GENERATED-IDENTITY)
