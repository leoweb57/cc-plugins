---
title: Activer pg_stat_statements pour analyser les requêtes
impact: LOW-MEDIUM
impactDescription: Identifier les requêtes les plus gourmandes en ressources
tags: pg-stat-statements, monitoring, statistics, performance
---

## Activer pg_stat_statements pour analyser les requêtes

pg_stat_statements suit les statistiques d'exécution de toutes les requêtes, ce qui aide à identifier les requêtes lentes et fréquentes.

**Incorrect (aucune visibilité sur les patterns de requêtes) :**

```sql
-- Database is slow, but which queries are the problem?
-- No way to know without pg_stat_statements
```

**Correct (activer et interroger pg_stat_statements) :**

```sql
-- Enable the extension
create extension if not exists pg_stat_statements;

-- Find slowest queries by total time
select
  calls,
  round(total_exec_time::numeric, 2) as total_time_ms,
  round(mean_exec_time::numeric, 2) as mean_time_ms,
  query
from pg_stat_statements
order by total_exec_time desc
limit 10;

-- Find most frequent queries
select calls, query
from pg_stat_statements
order by calls desc
limit 10;

-- Reset statistics after optimization
select pg_stat_statements_reset();
```

Métriques clés à surveiller :

```sql
-- Queries with high mean time (candidates for optimization)
select query, mean_exec_time, calls
from pg_stat_statements
where mean_exec_time > 100  -- > 100ms average
order by mean_exec_time desc;
```

Référence : [pg_stat_statements](https://supabase.com/docs/guides/database/extensions/pg_stat_statements)
