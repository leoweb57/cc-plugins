---
title: Titre clair et orienté action (ex. : "Use Partial Indexes for Filtered Queries")
impact: MEDIUM
impactDescription: 5-20x query speedup for filtered queries
tags: indexes, query-optimization, performance
---

## [Titre de la règle]

[Explication en 1-2 phrases du problème et de son importance. Concentre-toi sur l'impact sur les performances.]

**Incorrect (décris le problème) :**

```sql
-- Comment explaining what makes this slow/problematic
CREATE INDEX users_email_idx ON users(email);

SELECT * FROM users WHERE email = 'user@example.com' AND deleted_at IS NULL;
-- This scans deleted records unnecessarily
```

**Correct (décris la solution) :**

```sql
-- Comment explaining why this is better
CREATE INDEX users_active_email_idx ON users(email) WHERE deleted_at IS NULL;

SELECT * FROM users WHERE email = 'user@example.com' AND deleted_at IS NULL;
-- Only indexes active users, 10x smaller index, faster queries
```

[Optionnel : contexte supplémentaire, cas limites ou compromis]

Reference: [Postgres Docs](https://www.postgresql.org/docs/current/)
