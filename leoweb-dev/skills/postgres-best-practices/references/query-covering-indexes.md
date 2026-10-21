---
title: Utiliser des index couvrants pour éviter les accès à la table
impact: MEDIUM-HIGH
impactDescription: Requêtes 2 à 5 fois plus rapides en supprimant les heap fetches
tags: indexes, covering-index, include, index-only-scan
---

## Utiliser des index couvrants pour éviter les accès à la table

Les index couvrants incluent toutes les colonnes dont une requête a besoin, ce qui permet des index-only scans qui court-circuitent complètement la table.

**Incorrect (index scan + heap fetch) :**

```sql
create index users_email_idx on users (email);

-- Must fetch name and created_at from table heap
select email, name, created_at from users where email = 'user@example.com';
```

**Correct (index-only scan avec INCLUDE) :**

```sql
-- Include non-searchable columns in the index
create index users_email_idx on users (email) include (name, created_at);

-- All columns served from index, no table access needed
select email, name, created_at from users where email = 'user@example.com';
```

Utilise INCLUDE pour les colonnes que tu sélectionnes (SELECT) mais sur lesquelles tu ne filtres pas :

```sql
-- Searching by status, but also need customer_id and total
create index orders_status_idx on orders (status) include (customer_id, total);

select status, customer_id, total from orders where status = 'shipped';
```

Référence : [Index-Only Scans](https://www.postgresql.org/docs/current/indexes-index-only-scans.html)
