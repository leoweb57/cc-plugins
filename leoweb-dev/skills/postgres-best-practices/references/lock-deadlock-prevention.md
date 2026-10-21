---
title: Prévenir les deadlocks avec un ordre de verrouillage cohérent
impact: MEDIUM-HIGH
impactDescription: Eliminate deadlock errors, improve reliability
tags: deadlocks, locking, transactions, ordering
---

## Prévenir les deadlocks avec un ordre de verrouillage cohérent

Les deadlocks surviennent quand des transactions verrouillent des ressources dans des ordres différents. Acquiers
toujours les locks dans un ordre cohérent.

**Incorrect (ordre de verrouillage incohérent) :**

```sql
-- Transaction A                    -- Transaction B
begin;                              begin;
update accounts                     update accounts
set balance = balance - 100         set balance = balance - 50
where id = 1;                       where id = 2;  -- B locks row 2

update accounts                     update accounts
set balance = balance + 100         set balance = balance + 50
where id = 2;  -- A waits for B     where id = 1;  -- B waits for A

-- DEADLOCK! Both waiting for each other
```

**Correct (verrouiller d'abord les lignes dans un ordre cohérent) :**

```sql
-- Explicitly acquire locks in ID order before updating
begin;
select * from accounts where id in (1, 2) order by id for update;

-- Now perform updates in any order - locks already held
update accounts set balance = balance - 100 where id = 1;
update accounts set balance = balance + 100 where id = 2;
commit;
```

Alternative : utiliser un seul statement pour mettre à jour de façon atomique :

```sql
-- Single statement acquires all locks atomically
begin;
update accounts
set balance = balance + case id
  when 1 then -100
  when 2 then 100
end
where id in (1, 2);
commit;
```

Détecter les deadlocks dans les logs :

```sql
-- Check for recent deadlocks
select * from pg_stat_database where deadlocks > 0;

-- Enable deadlock logging
set log_lock_waits = on;
set deadlock_timeout = '1s';
```

Reference:
[Deadlocks](https://www.postgresql.org/docs/current/explicit-locking.html#LOCKING-DEADLOCKS)
