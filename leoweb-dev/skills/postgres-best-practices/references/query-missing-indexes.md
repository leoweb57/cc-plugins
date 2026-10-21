---
title: Ajouter des index sur les colonnes WHERE et JOIN
impact: CRITICAL
impactDescription: Requêtes 100 à 1000 fois plus rapides sur les grosses tables
tags: indexes, performance, sequential-scan, query-optimization
---

## Ajouter des index sur les colonnes WHERE et JOIN

Les requêtes qui filtrent ou joignent sur des colonnes non indexées provoquent des scans complets de la table, de plus en plus lents à mesure que les tables grossissent.

**Incorrect (sequential scan sur une grosse table) :**

```sql
-- No index on customer_id causes full table scan
select * from orders where customer_id = 123;

-- EXPLAIN shows: Seq Scan on orders (cost=0.00..25000.00 rows=100 width=85)
```

**Correct (index scan) :**

```sql
-- Create index on frequently filtered column
create index orders_customer_id_idx on orders (customer_id);

select * from orders where customer_id = 123;

-- EXPLAIN shows: Index Scan using orders_customer_id_idx (cost=0.42..8.44 rows=100 width=85)
```

Pour les colonnes de JOIN, indexe toujours le côté de la clé étrangère :

```sql
-- Index the referencing column
create index orders_customer_id_idx on orders (customer_id);

select c.name, o.total
from customers c
join orders o on o.customer_id = c.id;
```

Référence : [Query Optimization](https://supabase.com/docs/guides/database/query-optimization)
