---
title: Utiliser des index partiels pour les requêtes filtrées
impact: HIGH
impactDescription: Index 5 à 20 fois plus petits, écritures et requêtes plus rapides
tags: indexes, partial-index, query-optimization, storage
---

## Utiliser des index partiels pour les requêtes filtrées

Les index partiels n'incluent que les lignes qui satisfont une condition WHERE, ce qui les rend plus petits et plus rapides quand les requêtes filtrent systématiquement sur la même condition.

**Incorrect (l'index complet inclut des lignes inutiles) :**

```sql
-- Index includes all rows, even soft-deleted ones
create index users_email_idx on users (email);

-- Query always filters active users
select * from users where email = 'user@example.com' and deleted_at is null;
```

**Correct (l'index partiel correspond au filtre de la requête) :**

```sql
-- Index only includes active users
create index users_active_email_idx on users (email)
where deleted_at is null;

-- Query uses the smaller, faster index
select * from users where email = 'user@example.com' and deleted_at is null;
```

Cas d'usage courants des index partiels :

```sql
-- Only pending orders (status rarely changes once completed)
create index orders_pending_idx on orders (created_at)
where status = 'pending';

-- Only non-null values
create index products_sku_idx on products (sku)
where sku is not null;
```

Référence : [Partial Indexes](https://www.postgresql.org/docs/current/indexes-partial.html)
