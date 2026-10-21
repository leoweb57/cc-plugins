---
title: Utiliser tsvector pour la recherche full-text
impact: MEDIUM
impactDescription: 100x faster than LIKE, with ranking support
tags: full-text-search, tsvector, gin, search
---

## Utiliser tsvector pour la recherche full-text

LIKE avec des wildcards ne peut pas utiliser d'index. La recherche full-text avec tsvector est plusieurs ordres de grandeur plus rapide.

**Incorrect (pattern matching avec LIKE) :**

```sql
-- Cannot use index, scans all rows
select * from articles where content like '%postgresql%';

-- Case-insensitive makes it worse
select * from articles where lower(content) like '%postgresql%';
```

**Correct (recherche full-text avec tsvector) :**

```sql
-- Add tsvector column and index
alter table articles add column search_vector tsvector
  generated always as (to_tsvector('english', coalesce(title,'') || ' ' || coalesce(content,''))) stored;

create index articles_search_idx on articles using gin (search_vector);

-- Fast full-text search
select * from articles
where search_vector @@ to_tsquery('english', 'postgresql & performance');

-- With ranking
select *, ts_rank(search_vector, query) as rank
from articles, to_tsquery('english', 'postgresql') query
where search_vector @@ query
order by rank desc;
```

Rechercher plusieurs termes :

```sql
-- AND: both terms required
to_tsquery('postgresql & performance')

-- OR: either term
to_tsquery('postgresql | mysql')

-- Prefix matching
to_tsquery('post:*')
```

Reference: [Full Text Search](https://supabase.com/docs/guides/database/full-text-search)
