---
title: Créer des index composites pour les requêtes multi-colonnes
impact: HIGH
impactDescription: Requêtes multi-colonnes 5 à 10 fois plus rapides
tags: indexes, composite-index, multi-column, query-optimization
---

## Créer des index composites pour les requêtes multi-colonnes

Quand les requêtes filtrent sur plusieurs colonnes, un index composite est plus efficace que des index distincts sur chaque colonne.

**Incorrect (des index séparés imposent un bitmap scan) :**

```sql
-- Two separate indexes
create index orders_status_idx on orders (status);
create index orders_created_idx on orders (created_at);

-- Query must combine both indexes (slower)
select * from orders where status = 'pending' and created_at > '2024-01-01';
```

**Correct (index composite) :**

```sql
-- Single composite index (leftmost column first for equality checks)
create index orders_status_created_idx on orders (status, created_at);

-- Query uses one efficient index scan
select * from orders where status = 'pending' and created_at > '2024-01-01';
```

**L'ordre des colonnes compte** : place les colonnes testées en égalité en premier, les colonnes de plage en dernier :

```sql
-- Good: status (=) before created_at (>)
create index idx on orders (status, created_at);

-- Works for: WHERE status = 'pending'
-- Works for: WHERE status = 'pending' AND created_at > '2024-01-01'
-- Does NOT work for: WHERE created_at > '2024-01-01' (leftmost prefix rule)
```

Référence : [Multicolumn Indexes](https://www.postgresql.org/docs/current/indexes-multicolumn.html)
