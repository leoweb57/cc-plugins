# Test-Driven Development (TDD)

## Description

Strict test-driven development methodology requiring tests before implementation. The fundamental practice: "If you didn't watch the test fail, you don't know if it tests the right thing."

## When to Use

- New feature development
- Bug fixes (write test that reproduces bug first)
- Refactoring (ensure tests exist before changing)
- Any behavior change

## When NOT to Use (Requires Explicit Approval)

- Throwaway prototypes
- Generated/scaffolded code
- Pure configuration changes

---

## The Red-Green-Refactor Cycle

### 1. RED: Write Failing Test

Write a minimal test demonstrating the desired behavior:

```typescript
describe('calculateTotal', () => {
  it('should sum item prices', () => {
    const items = [{ price: 10 }, { price: 20 }];
    expect(calculateTotal(items)).toBe(30);
  });
});
```

### 2. VERIFY RED: Confirm Test Fails

Run the test and confirm it fails **for the right reason**:

```bash
npm test -- --grep "sum item prices"
# Expected: FAIL
# Reason: calculateTotal is not defined
```

**Critical**: The failure should be because the feature doesn't exist, not because of typos or syntax errors.

### 3. GREEN: Write Minimal Code

Write the simplest code that makes the test pass:

```typescript
function calculateTotal(items: Item[]): number {
  return items.reduce((sum, item) => sum + item.price, 0);
}
```

**Don't over-engineer**. If the test passes with simple code, stop.

### 4. VERIFY GREEN: Confirm Test Passes

Run the test and confirm it passes:

```bash
npm test -- --grep "sum item prices"
# Expected: PASS
```

### 5. REFACTOR: Clean Up

With green tests, refactor safely:
- Extract functions
- Rename variables
- Remove duplication
- Run tests after each change

---

## The Non-Negotiable Rule

**NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST**

This is not a guideline. It's a rule.

### What If I Already Wrote Code?

Delete it. Completely.

```
WRONG: "I'll keep this code as reference while writing tests"
RIGHT: Delete the code, write test, rewrite implementation
```

### Why So Strict?

- Code written before tests wasn't driven by tests
- Keeping it as reference leads to rationalization
- Tests written after code often just verify what was written
- True TDD produces different (usually better) designs

---

## Test Quality Standards

### One Behavior Per Test

```typescript
// BAD: Multiple behaviors
it('should validate and save user', () => {
  expect(validateUser(user)).toBe(true);
  expect(saveUser(user)).toBe(1);
});

// GOOD: Single behavior
it('should validate user email format', () => {
  expect(validateUser({ email: 'test@example.com' })).toBe(true);
});

it('should save valid user', () => {
  const user = createValidUser();
  expect(saveUser(user)).toBe(1);
});
```

### Clear Naming

Test names should describe the behavior:

```typescript
// BAD
it('test1', () => {});
it('calculateTotal', () => {});

// GOOD
it('should return 0 for empty cart', () => {});
it('should apply discount when coupon is valid', () => {});
```

### Real Code Over Mocks

Use real implementations when possible:

```typescript
// PREFER: Real database (test container)
const db = await startTestDatabase();
const result = await userRepo.save(user);

// AVOID: Excessive mocking
const mockDb = { save: jest.fn().mockResolvedValue(1) };
```

### Test Observable Behavior

Test what the code does, not how it does it:

```typescript
// BAD: Testing implementation
it('should call helper function', () => {
  calculateTotal(items);
  expect(helperFn).toHaveBeenCalled();
});

// GOOD: Testing behavior
it('should return correct total', () => {
  expect(calculateTotal(items)).toBe(30);
});
```

---

## Common Rationalizations (Reject These)

### "I'll write tests after"

Tests written after code verify what was written, not what should happen. The test can't prove the code is correct if it was shaped to match existing code.

### "Manual testing is enough"

Ad-hoc testing is not systematic. It misses edge cases, isn't repeatable, and doesn't prevent regressions.

### "This code is too simple to test"

Simple code breaks too. A test takes seconds and provides permanent verification.

### "I don't have time"

TDD is faster in the medium term. Debugging time saved far exceeds test-writing time.

### "I already wrote it, might as well keep it"

Sunk cost fallacy. Delete and rewrite properly.

---

## Edge Cases to Test

Always include tests for:

- Empty inputs
- Null/undefined values
- Boundary conditions
- Error scenarios
- Large inputs
- Invalid inputs

```typescript
describe('calculateTotal', () => {
  it('should return 0 for empty array', () => {
    expect(calculateTotal([])).toBe(0);
  });

  it('should handle null items array', () => {
    expect(() => calculateTotal(null)).toThrow();
  });

  it('should handle negative prices', () => {
    const items = [{ price: -10 }, { price: 20 }];
    expect(calculateTotal(items)).toBe(10);
  });
});
```

---

## TDD Catches Bugs

The methodology catches bugs before commit:
- Writing test first forces you to think about edge cases
- Seeing test fail proves it can catch failures
- Green bar confirms the fix works
- Test prevents regression forever

This is faster than:
1. Write code
2. Manual test (miss edge case)
3. Ship
4. Bug reported
5. Debug
6. Fix
7. Ship again

---
