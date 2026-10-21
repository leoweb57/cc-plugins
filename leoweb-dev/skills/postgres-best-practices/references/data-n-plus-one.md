---
title: Éliminer les requêtes N+1 avec le batch loading
impact: MEDIUM-HIGH
impactDescription: 10-100x fewer database round trips
tags: n-plus-one, batch, performance, queries
---

## Éliminer les requêtes N+1 avec le batch loading

Les requêtes N+1 exécutent une requête par élément dans une boucle. Regroupe-les en une seule requête à l'aide de tableaux ou de JOIN.

**Incorrect (requêtes N+1) :**

```sql
-- First query: get all users
select id from users where active = true;  -- Returns 100 IDs

-- Then N queries, one per user
select * from orders where user_id = 1;
select * from orders where user_id = 2;
select * from orders where user_id = 3;
-- ... 97 more queries!

-- Total: 101 round trips to database
```

**Correct (une seule requête groupée) :**

```sql
-- Collect IDs and query once with ANY
select * from orders where user_id = any(array[1, 2, 3, ...]);

-- Or use JOIN instead of loop
select u.id, u.name, o.*
from users u
left join orders o on o.user_id = u.id
where u.active = true;

-- Total: 1 round trip
```

Pattern côté application :

```sql
-- Instead of looping in application code:
-- for user in users: db.query("SELECT * FROM orders WHERE user_id = $1", user.id)

-- Pass array parameter:
select * from orders where user_id = any($1::bigint[]);
-- Application passes: [1, 2, 3, 4, 5, ...]
```

Reference: [N+1 Query Problem](https://supabase.com/docs/guides/database/query-optimization)
