# PostgreSQL

## Description

PostgreSQL database patterns including queries, indexing, and optimization.

## When to Use

- PostgreSQL database operations
- SQL query optimization
- Schema design

---

## Core Patterns

### Basic Queries

```sql
-- Select with filtering
SELECT id, name, email
FROM users
WHERE active = true
ORDER BY created_at DESC
LIMIT 20 OFFSET 0;

-- Join
SELECT u.*, COUNT(p.id) as post_count
FROM users u
LEFT JOIN posts p ON p.user_id = u.id
GROUP BY u.id;
```

### Indexes

```sql
-- Single column index
CREATE INDEX idx_users_email ON users(email);

-- Composite index
CREATE INDEX idx_posts_user_date ON posts(user_id, created_at DESC);

-- Partial index
CREATE INDEX idx_active_users ON users(email) WHERE active = true;
```

### Migrations

```sql
-- Add column with default
ALTER TABLE users ADD COLUMN role VARCHAR(50) DEFAULT 'user';

-- Add constraint
ALTER TABLE users ADD CONSTRAINT unique_email UNIQUE (email);
```

## Best Practices

1. Use indexes for filtered/sorted columns
2. Use EXPLAIN ANALYZE for slow queries
3. Avoid SELECT * in production
4. Use transactions for multiple operations
5. Use connection pooling

## Common Pitfalls

- **N+1 queries**: Use JOINs or batch loading
- **Missing indexes**: Add indexes for WHERE/ORDER BY
- **Large transactions**: Keep transactions short
