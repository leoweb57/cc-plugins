---
title: Appliquer le principe du moindre privilège
impact: MEDIUM
impactDescription: Surface d'attaque réduite, meilleure traçabilité
tags: privileges, security, roles, permissions
---

## Appliquer le principe du moindre privilège

N'accorde que les permissions minimales nécessaires. N'utilise jamais un superuser pour les requêtes de l'application.

**Incorrect (permissions trop larges) :**

```sql
-- Application uses superuser connection
-- Or grants ALL to application role
grant all privileges on all tables in schema public to app_user;
grant all privileges on all sequences in schema public to app_user;

-- Any SQL injection becomes catastrophic
-- drop table users; cascades to everything
```

**Correct (droits minimaux et spécifiques) :**

```sql
-- Create role with no default privileges
create role app_readonly nologin;

-- Grant only SELECT on specific tables
grant usage on schema public to app_readonly;
grant select on public.products, public.categories to app_readonly;

-- Create role for writes with limited scope
create role app_writer nologin;
grant usage on schema public to app_writer;
grant select, insert, update on public.orders to app_writer;
grant usage on sequence orders_id_seq to app_writer;
-- No DELETE permission

-- Login role inherits from these
create role app_user login password 'xxx';
grant app_writer to app_user;
```

Révoquer les accès publics par défaut :

```sql
-- Revoke default public access
revoke all on schema public from public;
revoke all on all tables in schema public from public;
```

Référence : [Roles and Privileges](https://supabase.com/blog/postgres-roles-and-privileges)
