---
title: Utiliser des identifiants en minuscules pour la compatibilité
impact: MEDIUM
impactDescription: Éviter les bugs de sensibilité à la casse avec les outils, les ORM et les assistants IA
tags: naming, identifiers, case-sensitivity, schema, conventions
---

## Utiliser des identifiants en minuscules pour la compatibilité

PostgreSQL convertit en minuscules les identifiants non quotés. Les identifiants quotés en casse mixte exigent des guillemets à perpétuité et posent problème aux outils, aux ORM et aux assistants IA qui peuvent ne pas les reconnaître.

**Incorrect (identifiants en casse mixte) :**

```sql
-- Quoted identifiers preserve case but require quotes everywhere
CREATE TABLE "Users" (
  "userId" bigint PRIMARY KEY,
  "firstName" text,
  "lastName" text
);

-- Must always quote or queries fail
SELECT "firstName" FROM "Users" WHERE "userId" = 1;

-- This fails - Users becomes users without quotes
SELECT firstName FROM Users;
-- ERROR: relation "users" does not exist
```

**Correct (snake_case en minuscules) :**

```sql
-- Unquoted lowercase identifiers are portable and tool-friendly
CREATE TABLE users (
  user_id bigint PRIMARY KEY,
  first_name text,
  last_name text
);

-- Works without quotes, recognized by all tools
SELECT first_name FROM users WHERE user_id = 1;
```

Sources courantes d'identifiants en casse mixte :

```sql
-- ORMs often generate quoted camelCase - configure them to use snake_case
-- Migrations from other databases may preserve original casing
-- Some GUI tools quote identifiers by default - disable this

-- If stuck with mixed-case, create views as a compatibility layer
CREATE VIEW users AS SELECT "userId" AS user_id, "firstName" AS first_name FROM "Users";
```

Référence : [Identifiers and Key Words](https://www.postgresql.org/docs/current/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS)
