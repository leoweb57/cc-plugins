# shadcn/ui

## Description

shadcn/ui component library patterns with Radix primitives and Tailwind styling.

## When to Use

- Building React component libraries
- Accessible UI components
- Customizable design systems

---

## Core Patterns

### Button Component

```tsx
import { Button } from "@/components/ui/button"

<Button variant="default">Primary</Button>
<Button variant="secondary">Secondary</Button>
<Button variant="outline">Outline</Button>
<Button variant="ghost">Ghost</Button>
<Button variant="destructive">Destructive</Button>
```

### Form with Validation

```tsx
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { Form, FormField, FormItem, FormLabel, FormControl } from "@/components/ui/form"
import { Input } from "@/components/ui/input"

const form = useForm({
  resolver: zodResolver(schema),
});

<Form {...form}>
  <FormField
    control={form.control}
    name="email"
    render={({ field }) => (
      <FormItem>
        <FormLabel>Email</FormLabel>
        <FormControl>
          <Input {...field} />
        </FormControl>
      </FormItem>
    )}
  />
</Form>
```

### Dialog

```tsx
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"

<Dialog>
  <DialogTrigger asChild>
    <Button>Open</Button>
  </DialogTrigger>
  <DialogContent>
    <DialogHeader>
      <DialogTitle>Title</DialogTitle>
    </DialogHeader>
    Content
  </DialogContent>
</Dialog>
```

## Best Practices

1. Use cn() for conditional classes
2. Compose primitives for custom components
3. Follow accessibility patterns
4. Customize via CSS variables
5. Use asChild for composition

## Common Pitfalls

- **Missing cn import**: Import from lib/utils
- **Wrong composition**: Use asChild properly
- **Hardcoded colors**: Use CSS variables
