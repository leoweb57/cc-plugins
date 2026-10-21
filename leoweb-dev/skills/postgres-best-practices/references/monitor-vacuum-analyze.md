---
title: Maintenir les statistiques des tables avec VACUUM et ANALYZE
impact: MEDIUM
impactDescription: Plans de requêtes 2 à 10 fois meilleurs grâce à des statistiques précises
tags: vacuum, analyze, statistics, maintenance, autovacuum
---

## Maintenir les statistiques des tables avec VACUUM et ANALYZE

Des statistiques périmées poussent le planner à prendre de mauvaises décisions. VACUUM récupère l'espace, ANALYZE met à jour les statistiques.

**Incorrect (statistiques périmées) :**

```sql
-- Table has 1M rows but stats say 1000
-- Query planner chooses wrong strategy
explain select * from orders where status = 'pending';
-- Shows: Seq Scan (because stats show small table)
-- Actually: Index Scan would be much faster
```

**Correct (maintenir des statistiques à jour) :**

```sql
-- Manually analyze after large data changes
analyze orders;

-- Analyze specific columns used in WHERE clauses
analyze orders (status, created_at);

-- Check when tables were last analyzed
select
  relname,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze
from pg_stat_user_tables
order by last_analyze nulls first;
```

Réglage de l'autovacuum pour les tables très sollicitées :

```sql
-- Increase frequency for high-churn tables
alter table orders set (
  autovacuum_vacuum_scale_factor = 0.05,     -- Vacuum at 5% dead tuples (default 20%)
  autovacuum_analyze_scale_factor = 0.02     -- Analyze at 2% changes (default 10%)
);

-- Check autovacuum status
select * from pg_stat_progress_vacuum;
```

Référence : [VACUUM](https://supabase.com/docs/guides/database/database-size#vacuum-operations)
