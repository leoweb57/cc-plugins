---
title: Indexer les colonnes JSONB pour des requêtes efficaces
impact: MEDIUM
impactDescription: 10-100x faster JSONB queries with proper indexing
tags: jsonb, gin, indexes, json
---

## Indexer les colonnes JSONB pour des requêtes efficaces

Les requêtes JSONB sans index scannent toute la table. Utilise des index GIN pour les requêtes de containment.

**Incorrect (pas d'index sur le JSONB) :**

```sql
create table products (
  id bigint primary key,
  attributes jsonb
);

-- Full table scan for every query
select * from products where attributes @> '{"color": "red"}';
select * from products where attributes->>'brand' = 'Nike';
```

**Correct (index GIN pour le JSONB) :**

```sql
-- GIN index for containment operators (@>, ?, ?&, ?|)
create index products_attrs_gin on products using gin (attributes);

-- Now containment queries use the index
select * from products where attributes @> '{"color": "red"}';

-- For specific key lookups, use expression index
create index products_brand_idx on products ((attributes->>'brand'));
select * from products where attributes->>'brand' = 'Nike';
```

Choisir la bonne operator class :

```sql
-- jsonb_ops (default): supports all operators, larger index
create index idx1 on products using gin (attributes);

-- jsonb_path_ops: only @> operator, but 2-3x smaller index
create index idx2 on products using gin (attributes jsonb_path_ops);
```

Reference: [JSONB Indexes](https://www.postgresql.org/docs/current/datatype-json.html#JSON-INDEXING)
