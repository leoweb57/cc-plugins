---
title: Partitionner les grosses tables pour de meilleures performances
impact: MEDIUM-HIGH
impactDescription: Requêtes et maintenance 5 à 20 fois plus rapides sur les grosses tables
tags: partitioning, large-tables, time-series, performance
---

## Partitionner les grosses tables pour de meilleures performances

Le partitionnement découpe une grosse table en morceaux plus petits, ce qui améliore les performances des requêtes et des opérations de maintenance.

**Incorrect (une seule grosse table) :**

```sql
create table events (
  id bigint generated always as identity,
  created_at timestamptz,
  data jsonb
);

-- 500M rows, queries scan everything
select * from events where created_at > '2024-01-01';  -- Slow
vacuum events;  -- Takes hours, locks table
```

**Correct (partitionnée par plage de temps) :**

```sql
create table events (
  id bigint generated always as identity,
  created_at timestamptz not null,
  data jsonb
) partition by range (created_at);

-- Create partitions for each month
create table events_2024_01 partition of events
  for values from ('2024-01-01') to ('2024-02-01');

create table events_2024_02 partition of events
  for values from ('2024-02-01') to ('2024-03-01');

-- Queries only scan relevant partitions
select * from events where created_at > '2024-01-15';  -- Only scans events_2024_01+

-- Drop old data instantly
drop table events_2023_01;  -- Instant vs DELETE taking hours
```

Quand partitionner :

- Tables de plus de 100 M de lignes
- Données de séries temporelles avec des requêtes basées sur les dates
- Besoin de supprimer efficacement les anciennes données

Référence : [Table Partitioning](https://www.postgresql.org/docs/current/ddl-partitioning.html)
