---
title: Garder les transactions courtes pour réduire la contention de locks
impact: MEDIUM-HIGH
impactDescription: 3-5x throughput improvement, fewer deadlocks
tags: transactions, locking, contention, performance
---

## Garder les transactions courtes pour réduire la contention de locks

Les transactions longues détiennent des locks qui bloquent les autres requêtes. Garde les transactions aussi courtes que possible.

**Incorrect (transaction longue avec des appels externes) :**

```sql
begin;
select * from orders where id = 1 for update;  -- Lock acquired

-- Application makes HTTP call to payment API (2-5 seconds)
-- Other queries on this row are blocked!

update orders set status = 'paid' where id = 1;
commit;  -- Lock held for entire duration
```

**Correct (périmètre de transaction minimal) :**

```sql
-- Validate data and call APIs outside transaction
-- Application: response = await paymentAPI.charge(...)

-- Only hold lock for the actual update
begin;
update orders
set status = 'paid', payment_id = $1
where id = $2 and status = 'pending'
returning *;
commit;  -- Lock held for milliseconds
```

Utilise `statement_timeout` pour empêcher les transactions qui s'emballent :

```sql
-- Abort queries running longer than 30 seconds
set statement_timeout = '30s';

-- Or per-session
set local statement_timeout = '5s';
```

Reference: [Transaction Management](https://www.postgresql.org/docs/current/tutorial-transactions.html)
