# MongoDB

## Description

MongoDB patterns including document design, queries, and aggregation.

## When to Use

- MongoDB database operations
- Document-based data modeling
- Aggregation pipelines

---

## Core Patterns

### Document Operations

```javascript
// Insert
db.users.insertOne({
  email: 'user@example.com',
  name: 'John',
  createdAt: new Date()
});

// Find
db.users.find({ active: true }).sort({ createdAt: -1 }).limit(20);

// Update
db.users.updateOne(
  { _id: ObjectId('...') },
  { $set: { name: 'Jane' } }
);
```

### Aggregation

```javascript
db.orders.aggregate([
  { $match: { status: 'completed' } },
  { $group: {
    _id: '$userId',
    totalSpent: { $sum: '$amount' },
    orderCount: { $count: {} }
  }},
  { $sort: { totalSpent: -1 } }
]);
```

### Indexes

```javascript
// Single field
db.users.createIndex({ email: 1 }, { unique: true });

// Compound
db.posts.createIndex({ userId: 1, createdAt: -1 });
```

## Best Practices

1. Embed frequently accessed data
2. Use references for large/independent data
3. Create indexes for query patterns
4. Use aggregation for complex queries
5. Avoid unbounded arrays

## Common Pitfalls

- **Unbounded arrays**: Limit array size
- **Missing indexes**: Analyze query patterns
- **Over-embedding**: Consider data access patterns
