# Tailwind CSS

## Description

Tailwind CSS utility-first styling with responsive design and component patterns.

## When to Use

- Styling React/Next.js components
- Responsive design
- Rapid UI development

---

## Core Patterns

### Layout

```html
<!-- Flexbox -->
<div class="flex items-center justify-between gap-4">
  <div>Left</div>
  <div>Right</div>
</div>

<!-- Grid -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
  <div>Item</div>
</div>

<!-- Container -->
<div class="container mx-auto px-4">
  Content
</div>
```

### Responsive

```html
<!-- Mobile-first breakpoints -->
<div class="w-full md:w-1/2 lg:w-1/3">
  <!-- sm: 640px, md: 768px, lg: 1024px, xl: 1280px -->
</div>

<h1 class="text-xl md:text-2xl lg:text-4xl">
  Responsive text
</h1>
```

### States

```html
<button class="
  bg-blue-500 hover:bg-blue-600
  focus:ring-2 focus:ring-blue-500 focus:ring-offset-2
  disabled:opacity-50 disabled:cursor-not-allowed
">
  Button
</button>
```

### Dark Mode

```html
<div class="bg-white dark:bg-gray-900 text-gray-900 dark:text-white">
  Content
</div>
```

## Best Practices

1. Use consistent spacing scale
2. Mobile-first design
3. Extract repeated patterns to components
4. Use @apply sparingly
5. Leverage dark mode utilities

## Common Pitfalls

- **Too many classes**: Extract to components
- **Inconsistent spacing**: Stick to scale
- **Missing responsive**: Test all breakpoints
