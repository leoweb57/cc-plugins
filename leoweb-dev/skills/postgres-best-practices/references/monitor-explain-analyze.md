---
title: Utiliser EXPLAIN ANALYZE pour diagnostiquer les requêtes lentes
impact: LOW-MEDIUM
impactDescription: Identifier précisément les goulots d'étranglement de l'exécution des requêtes
tags: explain, analyze, diagnostics, query-plan
---

## Utiliser EXPLAIN ANALYZE pour diagnostiquer les requêtes lentes

EXPLAIN ANALYZE exécute la requête et affiche les temps réels, ce qui révèle les vrais goulots d'étranglement.

**Incorrect (deviner les problèmes de performance) :**

```sql
-- Query is slow, but why?
select * from orders where customer_id = 123 and status = 'pending';
-- "It must be missing an index" - but which one?
```

**Correct (utiliser EXPLAIN ANALYZE) :**

```sql
explain (analyze, buffers, format text)
select * from orders where customer_id = 123 and status = 'pending';

-- Output reveals the issue:
-- Seq Scan on orders (cost=0.00..25000.00 rows=50 width=100) (actual time=0.015..450.123 rows=50 loops=1)
--   Filter: ((customer_id = 123) AND (status = 'pending'::text))
--   Rows Removed by Filter: 999950
--   Buffers: shared hit=5000 read=15000
-- Planning Time: 0.150 ms
-- Execution Time: 450.500 ms
```

Les points clés à repérer :

```sql
-- Seq Scan on large tables = missing index
-- Rows Removed by Filter = poor selectivity or missing index
-- Buffers: read >> hit = data not cached, needs more memory
-- Nested Loop with high loops = consider different join strategy
-- Sort Method: external merge = work_mem too low
```

Référence : [EXPLAIN](https://supabase.com/docs/guides/database/inspect)
