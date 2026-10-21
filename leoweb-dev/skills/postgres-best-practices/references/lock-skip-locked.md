---
title: Utiliser SKIP LOCKED pour un traitement de file non bloquant
impact: MEDIUM-HIGH
impactDescription: Débit multiplié par 10 pour les files de workers
tags: skip-locked, queue, workers, concurrency
---

## Utiliser SKIP LOCKED pour un traitement de file non bloquant

Quand plusieurs workers traitent une file, SKIP LOCKED permet à chacun de traiter des lignes différentes sans attendre.

**Incorrect (les workers se bloquent mutuellement) :**

```sql
-- Worker 1 and Worker 2 both try to get next job
begin;
select * from jobs where status = 'pending' order by created_at limit 1 for update;
-- Worker 2 waits for Worker 1's lock to release!
```

**Correct (SKIP LOCKED pour un traitement parallèle) :**

```sql
-- Each worker skips locked rows and gets the next available
begin;
select * from jobs
where status = 'pending'
order by created_at
limit 1
for update skip locked;

-- Worker 1 gets job 1, Worker 2 gets job 2 (no waiting)

update jobs set status = 'processing' where id = $1;
commit;
```

Pattern complet de file :

```sql
-- Atomic claim-and-update in one statement
update jobs
set status = 'processing', worker_id = $1, started_at = now()
where id = (
  select id from jobs
  where status = 'pending'
  order by created_at
  limit 1
  for update skip locked
)
returning *;
```

Référence : [SELECT FOR UPDATE SKIP LOCKED](https://www.postgresql.org/docs/current/sql-select.html#SQL-FOR-UPDATE-SHARE)
