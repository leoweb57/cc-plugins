---
title: Choisir le bon type d'index pour tes données
impact: HIGH
impactDescription: Gain de 10 à 100 fois avec le bon type d'index
tags: indexes, btree, gin, gist, brin, hash, index-types
---

## Choisir le bon type d'index pour tes données

Chaque type d'index excelle sur des patterns de requêtes différents. Le B-tree par défaut n'est pas toujours optimal.

**Incorrect (B-tree pour de l'inclusion JSONB) :**

```sql
-- B-tree cannot optimize containment operators
create index products_attrs_idx on products (attributes);
select * from products where attributes @> '{"color": "red"}';
-- Full table scan - B-tree doesn't support @> operator
```

**Correct (GIN pour du JSONB) :**

```sql
-- GIN supports @>, ?, ?&, ?| operators
create index products_attrs_idx on products using gin (attributes);
select * from products where attributes @> '{"color": "red"}';
```

Guide des types d'index :

```sql
-- B-tree (default): =, <, >, BETWEEN, IN, IS NULL
create index users_created_idx on users (created_at);

-- GIN: arrays, JSONB, full-text search
create index posts_tags_idx on posts using gin (tags);

-- GiST: geometric data, range types, nearest-neighbor (KNN) queries
create index locations_idx on places using gist (location);

-- BRIN: large time-series tables (10-100x smaller)
create index events_time_idx on events using brin (created_at);

-- Hash: equality-only (slightly faster than B-tree for =)
create index sessions_token_idx on sessions using hash (token);
```

Référence : [Index Types](https://www.postgresql.org/docs/current/indexes-types.html)
