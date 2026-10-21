---
title: Optimiser les policies RLS pour la performance
impact: HIGH
impactDescription: Requêtes RLS 5 à 10 fois plus rapides avec les bons patterns
tags: rls, performance, security, optimization
---

## Optimiser les policies RLS pour la performance

Des policies RLS mal écrites peuvent causer de sérieux problèmes de performance. Utilise les sous-requêtes et les index de façon stratégique.

**Incorrect (fonction appelée pour chaque ligne) :**

```sql
create policy orders_policy on orders
  using (auth.uid() = user_id);  -- auth.uid() called per row!

-- With 1M rows, auth.uid() is called 1M times
```

**Correct (encapsuler les fonctions dans un SELECT) :**

```sql
create policy orders_policy on orders
  using ((select auth.uid()) = user_id);  -- Called once, cached

-- 100x+ faster on large tables
```

Utilise des fonctions security definer pour les vérifications complexes :

Les fonctions `SECURITY DEFINER` s'exécutent avec les privilèges de leur créateur et contournent le RLS sur toutes les tables qu'elles touchent. C'est ce qui les rend utiles pour les lookups internes, mais aussi dangereuses en cas de mauvais usage. Inclus toujours une vérification explicite de `auth.uid()` dans le corps de la fonction, garde-les dans un schéma non exposé, et révoque `EXECUTE` pour tout rôle qui ne doit pas les appeler directement.

```sql
-- Create helper function in a private schema
create or replace function private.is_team_member(team_id bigint)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.team_members
    -- always check the calling user's identity inside the function
    where team_id = $1 and user_id = (select auth.uid())
  );
$$;

-- Revoke direct execution from public roles
revoke execute on function private.is_team_member(bigint) from PUBLIC, anon, authenticated, service_role;

-- Use in policy (indexed lookup, not per-row check)
create policy team_orders_policy on orders
  using ((select private.is_team_member(team_id)));
```

Ajoute toujours des index sur les colonnes utilisées dans les policies RLS :

```sql
create index orders_user_id_idx on orders (user_id);
```

Référence : [RLS Performance](https://supabase.com/docs/guides/database/postgres/row-level-security#rls-performance-recommendations)
