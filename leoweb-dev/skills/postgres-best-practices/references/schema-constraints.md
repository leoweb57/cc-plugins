---
title: Ajouter des contraintes en toute sécurité dans les migrations
impact: HIGH
impactDescription: Évite les échecs de migration et permet des changements de schéma idempotents
tags: constraints, migrations, schema, alter-table
---

## Ajouter des contraintes en toute sécurité dans les migrations

PostgreSQL ne supporte pas `ADD CONSTRAINT IF NOT EXISTS`. Les migrations qui utilisent cette syntaxe échouent.

**Incorrect (provoque une erreur de syntaxe) :**

```sql
-- ERROR: syntax error at or near "not" (SQLSTATE 42601)
alter table public.profiles
add constraint if not exists profiles_birthchart_id_unique unique (birthchart_id);
```

**Correct (création de contrainte idempotente) :**

```sql
-- Use DO block to check before adding
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_birthchart_id_unique'
    and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
    add constraint profiles_birthchart_id_unique unique (birthchart_id);
  end if;
end $$;
```

Pour tous les types de contraintes :

```sql
-- Check constraints
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'check_age_positive'
  ) then
    alter table users add constraint check_age_positive check (age > 0);
  end if;
end $$;

-- Foreign keys
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_birthchart_id_fkey'
  ) then
    alter table profiles
    add constraint profiles_birthchart_id_fkey
    foreign key (birthchart_id) references birthcharts(id);
  end if;
end $$;
```

Vérifier si une contrainte existe :

```sql
-- Query to check constraint existence
select conname, contype, pg_get_constraintdef(oid)
from pg_constraint
where conrelid = 'public.profiles'::regclass;

-- contype values:
-- 'p' = PRIMARY KEY
-- 'f' = FOREIGN KEY
-- 'u' = UNIQUE
-- 'c' = CHECK
```

Référence : [Constraints](https://www.postgresql.org/docs/current/ddl-constraints.html)
