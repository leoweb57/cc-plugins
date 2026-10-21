---
title: Activer le Row Level Security pour les données multi-tenant
impact: CRITICAL
impactDescription: Isolation des tenants garantie par la base de données, prévention des fuites de données
tags: rls, row-level-security, multi-tenant, security
---

## Activer le Row Level Security pour les données multi-tenant

Le Row Level Security (RLS) applique le contrôle d'accès aux données au niveau de la base de données et garantit que chaque utilisateur ne voit que ses propres données.

**Incorrect (filtrage uniquement côté application) :**

```sql
-- Relying only on application to filter
select * from orders where user_id = $current_user_id;

-- Bug or bypass means all data is exposed!
select * from orders;  -- Returns ALL orders
```

**Correct (RLS appliqué par la base de données) :**

```sql
-- Enable RLS on the table
alter table orders enable row level security;

-- Create policy for users to see only their orders
create policy orders_user_policy on orders
  for all
  using (user_id = current_setting('app.current_user_id')::bigint);

-- Force RLS even for table owners
alter table orders force row level security;

-- Set user context and query
set app.current_user_id = '123';
select * from orders;  -- Only returns orders for user 123
```

Policy pour le rôle authenticated :

```sql
create policy orders_user_policy on orders
  for all
  to authenticated
  using (user_id = auth.uid());
```

Référence : [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
