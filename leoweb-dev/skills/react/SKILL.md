# React

## Description

React component patterns, hooks, and state management best practices.

## When to Use

- Building React components
- Using React hooks
- Component state management

---

## Core Patterns

### Functional Components

```tsx
interface UserCardProps {
  user: User;
  onSelect?: (user: User) => void;
}

export function UserCard({ user, onSelect }: UserCardProps) {
  return (
    <div className="card" onClick={() => onSelect?.(user)}>
      <h3>{user.name}</h3>
      <p>{user.email}</p>
    </div>
  );
}
```

### Hooks

```tsx
// useState
const [count, setCount] = useState(0);

// useEffect
useEffect(() => {
  const subscription = subscribe();
  return () => subscription.unsubscribe();
}, [dependency]);

// useMemo
const expensive = useMemo(() => compute(data), [data]);

// useCallback
const handleClick = useCallback(() => {
  doSomething(id);
}, [id]);
```

### Custom Hooks

```tsx
function useUser(id: string) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    fetchUser(id)
      .then(setUser)
      .finally(() => setLoading(false));
  }, [id]);

  return { user, loading };
}
```

### Context Pattern

```tsx
const UserContext = createContext<User | null>(null);

export function UserProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);

  return (
    <UserContext.Provider value={user}>
      {children}
    </UserContext.Provider>
  );
}

export function useUser() {
  const context = useContext(UserContext);
  if (!context) throw new Error('useUser must be within UserProvider');
  return context;
}
```

## Best Practices

1. Keep components small and focused
2. Use TypeScript for props
3. Memoize expensive computations
4. Clean up effects properly
5. Lift state up when needed

## Common Pitfalls

- **Missing dependencies in hooks**: Include all dependencies
- **State updates on unmounted**: Use cleanup functions
- **Prop drilling**: Use context or composition
