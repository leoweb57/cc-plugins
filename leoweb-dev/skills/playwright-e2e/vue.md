# Tester des applications Vue avec Playwright

> **Quand l'utiliser** : tester des applications Vue 3, y compris les composants Composition API, les stores Pinia, la navigation Vue Router, les apps Nuxt.js, les portals Teleport et les transitions. Couvre les tests E2E et le component testing expérimental avec `@playwright/experimental-ct-vue`.
> **Prérequis** : [core/configuration.md](configuration.md), [core/locators.md](locators.md)

## Référence rapide

```bash
# Install Playwright in a Vue project
npm init playwright@latest

# Component testing (experimental package, last published for Playwright 1.62; 1.62+ uses stories, see core/component-testing.md)
npm install -D @playwright/experimental-ct-vue

# Run E2E tests
npx playwright test

# Run component tests
npx playwright test -c playwright-ct.config.ts

# Debug a test with headed browser and inspector
npx playwright test tests/home.spec.ts --headed --debug
```

## Mise en place

### Configuration Playwright pour Vue (Vite)

**TypeScript**
```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  testMatch: '**/*.spec.ts',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? '50%' : undefined,

  use: {
    baseURL: 'http://localhost:5173',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'mobile',
      use: { ...devices['iPhone 14'] },
    },
  ],

  webServer: {
    command: process.env.CI
      ? 'npm run build && npx vite preview --port 5173'
      : 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests/e2e',
  testMatch: '**/*.spec.js',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? '50%' : undefined,

  use: {
    baseURL: 'http://localhost:5173',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'mobile',
      use: { ...devices['iPhone 14'] },
    },
  ],

  webServer: {
    command: process.env.CI
      ? 'npm run build && npx vite preview --port 5173'
      : 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
```

### Configuration du component testing

Cette configuration concerne le package expérimental, dont la dernière publication date de Playwright 1.62 ; à partir de la 1.62, utilise le modèle à base de stories décrit dans [component-testing.md](component-testing.md).

**TypeScript**
```typescript
// playwright-ct.config.ts
import { defineConfig, devices } from '@playwright/experimental-ct-vue';

export default defineConfig({
  testDir: './tests/components',
  testMatch: '**/*.ct.ts',

  use: {
    trace: 'on-first-retry',
    ctPort: 3100,
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
```

**JavaScript**
```javascript
// playwright-ct.config.js
const { defineConfig, devices } = require('@playwright/experimental-ct-vue');

module.exports = defineConfig({
  testDir: './tests/components',
  testMatch: '**/*.ct.js',

  use: {
    trace: 'on-first-retry',
    ctPort: 3100,
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
```

### Configuration de Nuxt.js

Nuxt nécessite une étape de build avant les tests et utilise le port 3000 par défaut.

**TypeScript**
```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  testMatch: '**/*.spec.ts',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,

  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  webServer: {
    command: process.env.CI
      ? 'npx nuxi build && npx nuxi preview'
      : 'npx nuxi dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    env: {
      NUXT_PUBLIC_API_BASE: 'http://localhost:3000/api',
    },
  },
});
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests/e2e',
  testMatch: '**/*.spec.js',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,

  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  webServer: {
    command: process.env.CI
      ? 'npx nuxi build && npx nuxi preview'
      : 'npx nuxi dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    env: {
      NUXT_PUBLIC_API_BASE: 'http://localhost:3000/api',
    },
  },
});
```

## Patterns

### Component testing avec `@playwright/experimental-ct-vue`

> **Package déprécié** : `@playwright/experimental-ct-vue` n'est pas publié pour Playwright 1.63+. Playwright 1.62 a déplacé le component testing vers des stories montées depuis `@playwright/test`. N'utilise ce pattern que sur une suite figée en 1.62 ; consulte [component-testing.md](component-testing.md#comment-fonctionne-le-component-testing-162) pour le modèle actuel.

**À utiliser quand** : tu testes de façon isolée des composants Vue interactifs complexes -- tableaux de données, composants de formulaire, dropdowns de sélection personnalisés, éditeurs riches. Le composant a besoin d'un vrai navigateur, mais pas d'une application complète.
**À éviter quand** : le composant dépend fortement de stores Pinia, de Vue Router ou de données backend. Utilise plutôt des tests E2E, ou fournis les dépendances dans la configuration de ton test de composant.

**TypeScript**
```typescript
// tests/components/Counter.ct.ts
import { test, expect } from '@playwright/experimental-ct-vue';
import Counter from '../../src/components/Counter.vue';

test('renders with initial count and increments', async ({ mount }) => {
  const component = await mount(Counter, {
    props: {
      initialCount: 0,
    },
  });

  await expect(component.getByText('Count: 0')).toBeVisible();
  await component.getByRole('button', { name: 'Increment' }).click();
  await expect(component.getByText('Count: 1')).toBeVisible();
});

test('emits update event when count changes', async ({ mount }) => {
  const emittedValues: number[] = [];
  const component = await mount(Counter, {
    props: {
      initialCount: 5,
    },
    on: {
      update: (value: number) => emittedValues.push(value),
    },
  });

  await component.getByRole('button', { name: 'Increment' }).click();
  await component.getByRole('button', { name: 'Increment' }).click();

  expect(emittedValues).toEqual([6, 7]);
});

test('respects max prop', async ({ mount }) => {
  const component = await mount(Counter, {
    props: {
      initialCount: 9,
      max: 10,
    },
  });

  await component.getByRole('button', { name: 'Increment' }).click();
  await expect(component.getByText('Count: 10')).toBeVisible();

  // At max -- button should be disabled
  await expect(component.getByRole('button', { name: 'Increment' })).toBeDisabled();
});

test('renders with slot content', async ({ mount }) => {
  const component = await mount(Counter, {
    props: { initialCount: 0 },
    slots: {
      default: '<span class="custom-label">Items in cart</span>',
    },
  });

  await expect(component.getByText('Items in cart')).toBeVisible();
});
```

**JavaScript**
```javascript
// tests/components/Counter.ct.js
const { test, expect } = require('@playwright/experimental-ct-vue');
const Counter = require('../../src/components/Counter.vue');

test('renders with initial count and increments', async ({ mount }) => {
  const component = await mount(Counter, {
    props: {
      initialCount: 0,
    },
  });

  await expect(component.getByText('Count: 0')).toBeVisible();
  await component.getByRole('button', { name: 'Increment' }).click();
  await expect(component.getByText('Count: 1')).toBeVisible();
});

test('emits update event when count changes', async ({ mount }) => {
  const emittedValues = [];
  const component = await mount(Counter, {
    props: {
      initialCount: 5,
    },
    on: {
      update: (value) => emittedValues.push(value),
    },
  });

  await component.getByRole('button', { name: 'Increment' }).click();
  await component.getByRole('button', { name: 'Increment' }).click();

  expect(emittedValues).toEqual([6, 7]);
});

test('renders with slot content', async ({ mount }) => {
  const component = await mount(Counter, {
    props: { initialCount: 0 },
    slots: {
      default: '<span class="custom-label">Items in cart</span>',
    },
  });

  await expect(component.getByText('Items in cart')).toBeVisible();
});
```

### Tester les stores Pinia à travers l'UI

**À utiliser quand** : tu vérifies que les stores Pinia produisent le bon comportement d'UI. Playwright teste le rendu, pas directement le store. Si l'UI est correcte, le store l'est aussi.
**À éviter quand** : tu testes la logique pure d'un store (getters, actions sans effet de bord sur l'UI) -- utilise des tests unitaires avec Vitest pour cela.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('Pinia cart store (tested through UI)', () => {
  test('adding items updates the cart across the app', async ({ page }) => {
    await page.goto('/products');

    const cartBadge = page.getByTestId('cart-count');

    // Initially empty
    await expect(cartBadge).toHaveText('0');

    // Add first item -- Pinia store action is triggered
    await page.getByRole('listitem')
      .filter({ hasText: 'Vue T-Shirt' })
      .getByRole('button', { name: 'Add to cart' })
      .click();
    await expect(cartBadge).toHaveText('1');

    // Add second item
    await page.getByRole('listitem')
      .filter({ hasText: 'Pinia Sticker Pack' })
      .getByRole('button', { name: 'Add to cart' })
      .click();
    await expect(cartBadge).toHaveText('2');

    // Navigate to cart page -- store state persists
    await page.getByRole('link', { name: 'Cart' }).click();
    await page.waitForURL('/cart');

    await expect(page.getByText('Vue T-Shirt')).toBeVisible();
    await expect(page.getByText('Pinia Sticker Pack')).toBeVisible();
    await expect(page.getByText('Total: $29.98')).toBeVisible();
  });

  test('removing items from cart updates total', async ({ page }) => {
    // Navigate to a pre-populated cart (seed via API or navigate through adding items)
    await page.goto('/products');
    await page.getByRole('listitem')
      .filter({ hasText: 'Vue T-Shirt' })
      .getByRole('button', { name: 'Add to cart' })
      .click();

    await page.getByRole('link', { name: 'Cart' }).click();
    await page.waitForURL('/cart');

    await page.getByRole('button', { name: 'Remove Vue T-Shirt' }).click();

    await expect(page.getByText('Your cart is empty')).toBeVisible();
    await expect(page.getByTestId('cart-count')).toHaveText('0');
  });

  test('store persists after page reload when using pinia-plugin-persistedstate', async ({ page }) => {
    await page.goto('/products');

    await page.getByRole('listitem')
      .filter({ hasText: 'Vue T-Shirt' })
      .getByRole('button', { name: 'Add to cart' })
      .click();

    // Reload the page -- persisted store should restore state
    await page.reload();

    await expect(page.getByTestId('cart-count')).toHaveText('1');
  });
});

test.describe('Pinia auth store (tested through UI)', () => {
  test('login updates auth state across all components', async ({ page }) => {
    await page.goto('/');

    await expect(page.getByRole('link', { name: 'Sign in' })).toBeVisible();

    await page.getByRole('link', { name: 'Sign in' }).click();
    await page.getByLabel('Email').fill('user@example.com');
    await page.getByLabel('Password').fill('password123');
    await page.getByRole('button', { name: 'Sign in' }).click();

    await page.waitForURL('/dashboard');

    // Header updates (uses auth store)
    await expect(page.getByText('user@example.com')).toBeVisible();
    // Navigation updates (uses auth store for conditional routes)
    await expect(page.getByRole('link', { name: 'Admin' })).toBeVisible();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('Pinia cart store (tested through UI)', () => {
  test('adding items updates the cart across the app', async ({ page }) => {
    await page.goto('/products');

    const cartBadge = page.getByTestId('cart-count');
    await expect(cartBadge).toHaveText('0');

    await page.getByRole('listitem')
      .filter({ hasText: 'Vue T-Shirt' })
      .getByRole('button', { name: 'Add to cart' })
      .click();
    await expect(cartBadge).toHaveText('1');

    await page.getByRole('listitem')
      .filter({ hasText: 'Pinia Sticker Pack' })
      .getByRole('button', { name: 'Add to cart' })
      .click();
    await expect(cartBadge).toHaveText('2');

    await page.getByRole('link', { name: 'Cart' }).click();
    await page.waitForURL('/cart');

    await expect(page.getByText('Vue T-Shirt')).toBeVisible();
    await expect(page.getByText('Pinia Sticker Pack')).toBeVisible();
  });

  test('store persists after page reload when using pinia-plugin-persistedstate', async ({ page }) => {
    await page.goto('/products');

    await page.getByRole('listitem')
      .filter({ hasText: 'Vue T-Shirt' })
      .getByRole('button', { name: 'Add to cart' })
      .click();

    await page.reload();
    await expect(page.getByTestId('cart-count')).toHaveText('1');
  });
});
```

### Tester la navigation Vue Router

**À utiliser quand** : tu testes le routing côté client avec Vue Router. Vérifie les transitions de routes, les navigation guards, les paramètres d'URL et le comportement de l'historique du navigateur.
**À éviter quand** : tu testes le routing basé sur les fichiers de Nuxt.js -- les patterns sont similaires, mais Nuxt ajoute des problématiques côté serveur.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('Vue Router navigation', () => {
  test('client-side navigation does not cause full page reload', async ({ page }) => {
    await page.goto('/');

    await page.evaluate(() => {
      (window as any).__testMarker = 'no-reload';
    });

    await page.getByRole('link', { name: 'Products' }).click();
    await page.waitForURL('/products');

    const marker = await page.evaluate(() => (window as any).__testMarker);
    expect(marker).toBe('no-reload');
  });

  test('dynamic route params render correct content', async ({ page }) => {
    await page.goto('/products/42');

    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    await expect(page.getByText('Product #42')).toBeVisible();
  });

  test('navigation guard redirects unauthenticated users', async ({ page }) => {
    // Visit a route guarded by router.beforeEach
    await page.goto('/admin/users');

    // Guard should redirect to login
    await expect(page).toHaveURL(/\/login/);
    await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
  });

  test('named routes and nested views render correctly', async ({ page }) => {
    await page.goto('/settings');

    // Parent layout
    await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible();
    await expect(page.getByRole('navigation', { name: 'Settings' })).toBeVisible();

    // Default child route
    await expect(page.getByRole('heading', { name: 'General', level: 2 })).toBeVisible();

    // Navigate to sibling child route
    await page.getByRole('link', { name: 'Notifications' }).click();
    await page.waitForURL('/settings/notifications');

    // Parent layout persists, child content changes
    await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Notifications', level: 2 })).toBeVisible();
  });

  test('browser back/forward works with Vue Router', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('link', { name: 'Products' }).click();
    await page.waitForURL('/products');
    await page.getByRole('link', { name: 'About' }).click();
    await page.waitForURL('/about');

    await page.goBack();
    await expect(page).toHaveURL(/\/products/);

    await page.goBack();
    await expect(page).toHaveURL(/\/$/);

    await page.goForward();
    await expect(page).toHaveURL(/\/products/);
  });

  test('query parameters update reactive computed properties', async ({ page }) => {
    await page.goto('/products?sort=price-asc&category=electronics');

    await expect(page.getByRole('heading', { name: 'Electronics' })).toBeVisible();

    // Change sort via UI (updates route query params)
    await page.getByRole('combobox', { name: 'Sort by' }).selectOption('name-asc');
    await expect(page).toHaveURL(/sort=name-asc/);
  });

  test('404 catch-all route displays not found page', async ({ page }) => {
    await page.goto('/this-page-does-not-exist');

    await expect(page.getByRole('heading', { name: 'Page Not Found' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Go home' })).toBeVisible();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('Vue Router navigation', () => {
  test('client-side navigation does not cause full page reload', async ({ page }) => {
    await page.goto('/');

    await page.evaluate(() => {
      window.__testMarker = 'no-reload';
    });

    await page.getByRole('link', { name: 'Products' }).click();
    await page.waitForURL('/products');

    const marker = await page.evaluate(() => window.__testMarker);
    expect(marker).toBe('no-reload');
  });

  test('dynamic route params render correct content', async ({ page }) => {
    await page.goto('/products/42');

    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    await expect(page.getByText('Product #42')).toBeVisible();
  });

  test('navigation guard redirects unauthenticated users', async ({ page }) => {
    await page.goto('/admin/users');

    await expect(page).toHaveURL(/\/login/);
    await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
  });

  test('browser back/forward works with Vue Router', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('link', { name: 'Products' }).click();
    await page.waitForURL('/products');
    await page.getByRole('link', { name: 'About' }).click();
    await page.waitForURL('/about');

    await page.goBack();
    await expect(page).toHaveURL(/\/products/);

    await page.goBack();
    await expect(page).toHaveURL(/\/$/);
  });
});
```

### Tester Teleport (portals)

**À utiliser quand** : tu testes des composants rendus via `<Teleport>` de Vue -- modales, notifications, menus en overlay. Teleport déplace des éléments DOM vers un autre emplacement (souvent `body`), mais Playwright voit le document entier.
**À éviter quand** : le composant n'est pas téléporté -- il est rendu en ligne dans son parent.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('Teleport components', () => {
  test('modal teleported to body is visible and interactive', async ({ page }) => {
    await page.goto('/products');

    await page.getByRole('button', { name: 'Delete' }).first().click();

    // Modal is teleported to <body> with <Teleport to="body">
    // Playwright sees it like any other element
    const modal = page.getByRole('dialog', { name: 'Confirm deletion' });
    await expect(modal).toBeVisible();

    await modal.getByRole('button', { name: 'Cancel' }).click();
    await expect(modal).toBeHidden();
  });

  test('teleported notification appears above all content', async ({ page }) => {
    await page.goto('/settings');

    await page.getByRole('button', { name: 'Save' }).click();

    // Notification teleported to #notifications container
    const notification = page.getByRole('alert');
    await expect(notification).toBeVisible();
    await expect(notification).toContainText('Settings saved');

    // Auto-dismiss
    await expect(notification).toBeHidden({ timeout: 10_000 });
  });

  test('teleported dropdown closes on outside click', async ({ page }) => {
    await page.goto('/dashboard');

    await page.getByRole('button', { name: 'User menu' }).click();

    const menu = page.getByRole('menu');
    await expect(menu).toBeVisible();

    // Click outside the menu
    await page.locator('body').click({ position: { x: 10, y: 10 } });
    await expect(menu).toBeHidden();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('Teleport components', () => {
  test('modal teleported to body is visible and interactive', async ({ page }) => {
    await page.goto('/products');

    await page.getByRole('button', { name: 'Delete' }).first().click();

    const modal = page.getByRole('dialog', { name: 'Confirm deletion' });
    await expect(modal).toBeVisible();

    await modal.getByRole('button', { name: 'Cancel' }).click();
    await expect(modal).toBeHidden();
  });

  test('teleported notification appears above all content', async ({ page }) => {
    await page.goto('/settings');

    await page.getByRole('button', { name: 'Save' }).click();

    const notification = page.getByRole('alert');
    await expect(notification).toBeVisible();
    await expect(notification).toContainText('Settings saved');

    await expect(notification).toBeHidden({ timeout: 10_000 });
  });

  test('teleported dropdown closes on outside click', async ({ page }) => {
    await page.goto('/dashboard');

    await page.getByRole('button', { name: 'User menu' }).click();

    const menu = page.getByRole('menu');
    await expect(menu).toBeVisible();

    await page.locator('body').click({ position: { x: 10, y: 10 } });
    await expect(menu).toBeHidden();
  });
});
```

### Tester les transitions et les animations

**À utiliser quand** : tu vérifies que les composants Vue `<Transition>` et `<TransitionGroup>` fonctionnent correctement -- les éléments apparaissent, disparaissent et se réordonnent comme prévu. Concentre-toi sur l'état final, pas sur l'animation elle-même.
**À éviter quand** : tu testes les keyframes exactes d'une animation CSS -- les tests de régression visuelle conviennent mieux à une validation au pixel près.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('transitions', () => {
  test('list items animate in when added', async ({ page }) => {
    await page.goto('/todo');

    await page.getByRole('textbox', { name: 'New task' }).fill('Buy groceries');
    await page.getByRole('button', { name: 'Add' }).click();

    // The item should be visible after the enter transition completes
    // Playwright auto-waits for visibility, handling the transition automatically
    await expect(page.getByText('Buy groceries')).toBeVisible();
  });

  test('deleted items animate out and are removed from DOM', async ({ page }) => {
    await page.goto('/todo');

    // Add an item first
    await page.getByRole('textbox', { name: 'New task' }).fill('Temporary task');
    await page.getByRole('button', { name: 'Add' }).click();
    await expect(page.getByText('Temporary task')).toBeVisible();

    // Delete it
    await page.getByRole('listitem')
      .filter({ hasText: 'Temporary task' })
      .getByRole('button', { name: 'Delete' })
      .click();

    // After the leave transition, the element should be gone
    await expect(page.getByText('Temporary task')).toBeHidden();
  });

  test('page transition completes between routes', async ({ page }) => {
    await page.goto('/');

    await page.getByRole('link', { name: 'About' }).click();
    await page.waitForURL('/about');

    // After the route transition animation, content should be visible
    await expect(page.getByRole('heading', { name: 'About' })).toBeVisible();
  });

  test('disable animations for faster, more reliable tests', async ({ page }) => {
    // Disable all CSS animations and transitions for deterministic testing
    await page.addStyleTag({
      content: `
        *, *::before, *::after {
          animation-duration: 0s !important;
          animation-delay: 0s !important;
          transition-duration: 0s !important;
          transition-delay: 0s !important;
        }
      `,
    });

    await page.goto('/todo');

    await page.getByRole('textbox', { name: 'New task' }).fill('Instant task');
    await page.getByRole('button', { name: 'Add' }).click();

    // With animations disabled, elements appear/disappear instantly
    await expect(page.getByText('Instant task')).toBeVisible();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('transitions', () => {
  test('list items animate in when added', async ({ page }) => {
    await page.goto('/todo');

    await page.getByRole('textbox', { name: 'New task' }).fill('Buy groceries');
    await page.getByRole('button', { name: 'Add' }).click();

    await expect(page.getByText('Buy groceries')).toBeVisible();
  });

  test('deleted items animate out and are removed from DOM', async ({ page }) => {
    await page.goto('/todo');

    await page.getByRole('textbox', { name: 'New task' }).fill('Temporary task');
    await page.getByRole('button', { name: 'Add' }).click();
    await expect(page.getByText('Temporary task')).toBeVisible();

    await page.getByRole('listitem')
      .filter({ hasText: 'Temporary task' })
      .getByRole('button', { name: 'Delete' })
      .click();

    await expect(page.getByText('Temporary task')).toBeHidden();
  });

  test('disable animations for faster, more reliable tests', async ({ page }) => {
    await page.addStyleTag({
      content: `
        *, *::before, *::after {
          animation-duration: 0s !important;
          animation-delay: 0s !important;
          transition-duration: 0s !important;
          transition-delay: 0s !important;
        }
      `,
    });

    await page.goto('/todo');

    await page.getByRole('textbox', { name: 'New task' }).fill('Instant task');
    await page.getByRole('button', { name: 'Add' }).click();

    await expect(page.getByText('Instant task')).toBeVisible();
  });
});
```

### Tester les composants Composition API

**À utiliser quand** : tu testes des composants construits avec la Composition API de Vue 3 (`<script setup>`, fonction `setup()`). Du point de vue de Playwright, les composants Composition API et Options API sont identiques -- tu testes le rendu.
**À éviter quand** : tu veux tester des fonctions composables de façon isolée -- utilise Vitest pour cela.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('composition API patterns', () => {
  test('computed properties update the UI reactively', async ({ page }) => {
    await page.goto('/calculator');

    await page.getByLabel('Price').fill('100');
    await page.getByLabel('Quantity').fill('3');

    // Computed total should update reactively
    await expect(page.getByTestId('total')).toHaveText('$300.00');

    // Apply discount
    await page.getByLabel('Discount (%)').fill('10');
    await expect(page.getByTestId('total')).toHaveText('$270.00');
  });

  test('watcher triggers side effect on value change', async ({ page }) => {
    await page.goto('/settings');

    // Changing the language triggers a watcher that reloads translations
    await page.getByRole('combobox', { name: 'Language' }).selectOption('fr');

    // Watcher fetches French translations -- UI updates
    await expect(page.getByRole('heading', { name: 'Parametres' })).toBeVisible();
  });

  test('composable hook (useSearch) provides debounced search', async ({ page }) => {
    await page.goto('/products');

    const searchInput = page.getByRole('textbox', { name: 'Search products' });
    await searchInput.pressSequentially('vue stickers', { delay: 50 });

    // useSearch composable debounces and fetches results
    await expect(page.getByRole('listitem')).toHaveCount(3);
    await expect(page.getByText('Vue Sticker Pack')).toBeVisible();
  });

  test('provide/inject context works across component tree', async ({ page }) => {
    await page.goto('/dashboard');

    // Theme is provided at the app root and injected in child components
    await page.getByRole('switch', { name: 'Dark mode' }).click();

    // All components using inject('theme') should update
    await expect(page.locator('body')).toHaveClass(/dark/);
    await expect(page.getByRole('navigation')).toHaveCSS('background-color', /rgb\(30/);
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('composition API patterns', () => {
  test('computed properties update the UI reactively', async ({ page }) => {
    await page.goto('/calculator');

    await page.getByLabel('Price').fill('100');
    await page.getByLabel('Quantity').fill('3');

    await expect(page.getByTestId('total')).toHaveText('$300.00');

    await page.getByLabel('Discount (%)').fill('10');
    await expect(page.getByTestId('total')).toHaveText('$270.00');
  });

  test('watcher triggers side effect on value change', async ({ page }) => {
    await page.goto('/settings');

    await page.getByRole('combobox', { name: 'Language' }).selectOption('fr');
    await expect(page.getByRole('heading', { name: 'Parametres' })).toBeVisible();
  });

  test('composable hook (useSearch) provides debounced search', async ({ page }) => {
    await page.goto('/products');

    const searchInput = page.getByRole('textbox', { name: 'Search products' });
    await searchInput.pressSequentially('vue stickers', { delay: 50 });

    await expect(page.getByRole('listitem')).toHaveCount(3);
    await expect(page.getByText('Vue Sticker Pack')).toBeVisible();
  });
});
```

### Tester les patterns spécifiques à Nuxt.js

**À utiliser quand** : tu testes des applications Nuxt 3+ avec rendu côté serveur, auto-imports, routes serveur (`/server/api/`) et middleware.
**À éviter quand** : tu testes une SPA Vue simple sans Nuxt.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('Nuxt-specific patterns', () => {
  test('SSR page renders server-fetched data', async ({ page }) => {
    await page.goto('/blog');

    // useFetch/useAsyncData runs on the server -- content is in the initial HTML
    await expect(page.getByRole('article')).toHaveCount(10);
    await expect(page.getByRole('article').first()).toContainText(/\w+/);
  });

  test('Nuxt server route returns correct data', async ({ request }) => {
    const response = await request.get('/api/products');

    expect(response.ok()).toBeTruthy();
    const body = await response.json();
    expect(body).toBeInstanceOf(Array);
    expect(body[0]).toHaveProperty('id');
  });

  test('Nuxt middleware redirects unauthenticated users', async ({ page }) => {
    await page.goto('/admin');

    // definePageMeta({ middleware: 'auth' }) in the page triggers redirect
    await expect(page).toHaveURL(/\/login/);
  });

  test('NuxtLink enables client-side navigation', async ({ page }) => {
    await page.goto('/');

    await page.evaluate(() => {
      (window as any).__testMarker = 'no-reload';
    });

    await page.getByRole('link', { name: 'Blog' }).click();
    await page.waitForURL('/blog');

    const marker = await page.evaluate(() => (window as any).__testMarker);
    expect(marker).toBe('no-reload');
  });

  test('useHead sets meta tags for SEO', async ({ page }) => {
    await page.goto('/blog/my-post');

    const title = await page.title();
    expect(title).toContain('My Post');

    const description = await page.locator('meta[name="description"]').getAttribute('content');
    expect(description).toBeTruthy();
    expect(description!.length).toBeGreaterThan(50);
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('Nuxt-specific patterns', () => {
  test('SSR page renders server-fetched data', async ({ page }) => {
    await page.goto('/blog');

    await expect(page.getByRole('article')).toHaveCount(10);
    await expect(page.getByRole('article').first()).toContainText(/\w+/);
  });

  test('Nuxt server route returns correct data', async ({ request }) => {
    const response = await request.get('/api/products');

    expect(response.ok()).toBeTruthy();
    const body = await response.json();
    expect(body).toBeInstanceOf(Array);
    expect(body[0]).toHaveProperty('id');
  });

  test('Nuxt middleware redirects unauthenticated users', async ({ page }) => {
    await page.goto('/admin');

    await expect(page).toHaveURL(/\/login/);
  });

  test('NuxtLink enables client-side navigation', async ({ page }) => {
    await page.goto('/');

    await page.evaluate(() => {
      window.__testMarker = 'no-reload';
    });

    await page.getByRole('link', { name: 'Blog' }).click();
    await page.waitForURL('/blog');

    const marker = await page.evaluate(() => window.__testMarker);
    expect(marker).toBe('no-reload');
  });
});
```

## Conseils spécifiques au framework

### Vue DevTools et Playwright

Vue DevTools est une extension de navigateur. Elle n'interfère pas avec les tests Playwright, car Playwright lance son propre profil de navigateur sans extensions. Ne compte pas sur Vue DevTools pour le debug en CI -- utilise les traces Playwright à la place.

### Tester le two-way binding `v-model`

`v-model` sur les champs de formulaire fonctionne via des événements HTML standards. Les méthodes `fill()`, `check()` et `selectOption()` de Playwright déclenchent automatiquement les bons événements. Aucun traitement particulier n'est nécessaire.

```typescript
// This works for any v-model input -- no special Vue handling needed
await page.getByLabel('Username').fill('janedoe');
await page.getByRole('checkbox', { name: 'Remember me' }).check();
await page.getByRole('combobox', { name: 'Role' }).selectOption('admin');
```

### Vue vs Nuxt : différences de configuration

| Aspect | Vue 3 (Vite) | Nuxt 3+ |
|---|---|---|
| Port par défaut | `5173` | `3000` |
| Commande de dev | `npm run dev` (vite) | `npx nuxi dev` |
| Build + preview | `npm run build && npx vite preview` | `npx nuxi build && npx nuxi preview` |
| SSR | Optionnel (`vue/server-renderer`) | Intégré |
| Routes d'API | Backend externe | `/server/api/` intégré |
| Variables d'environnement | préfixe `VITE_*` | préfixe `NUXT_PUBLIC_*` côté client, `NUXT_*` côté serveur |
| Routing basé sur les fichiers | Non (utilise la config vue-router) | Oui (automatique depuis `app/pages/` dans Nuxt 4+, `pages/` dans Nuxt 3) |

### Component testing : fournir Pinia et Router

Avec `@playwright/experimental-ct-vue` (figé sur Playwright 1.62 ; voir la note de dépréciation plus haut), les composants qui dépendent de Pinia ou de Vue Router ont besoin que ces dépendances soient fournies. Configure le wrapper de test :

```typescript
// playwright/index.ts (component testing setup)
import { beforeMount } from '@playwright/experimental-ct-vue/hooks';
import { createPinia } from 'pinia';
import { createMemoryHistory, createRouter } from 'vue-router';

beforeMount(async ({ app, hooksConfig }) => {
  // Install Pinia for all component tests
  const pinia = createPinia();
  app.use(pinia);

  // Install a minimal router if the component uses <RouterLink> or useRoute()
  if (hooksConfig?.routes) {
    const router = createRouter({
      history: createMemoryHistory(),
      routes: hooksConfig.routes,
    });
    app.use(router);
  }
});
```

### Gérer les warnings Vue dans les tests

Vue émet des warnings au runtime (validation des props, composants manquants, etc.) qui peuvent révéler de vrais problèmes :

```typescript
test('no Vue warnings during render', async ({ page }) => {
  const warnings: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'warning' && msg.text().includes('[Vue warn]')) {
      warnings.push(msg.text());
    }
  });

  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  expect(warnings).toEqual([]);
});
```

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| `page.evaluate(() => app.__vue_app__.config.globalProperties.$store)` | Accède aux internals de Vue ; casse aux montées de version ; teste l'implémentation | Asserte sur l'UI que l'état produit |
| `page.locator('[data-v-abc123]')` (hash de style scopé) | Vue génère des hashs d'attributs scopés aléatoires ; ils changent à chaque build | Utilise `getByRole`, `getByText`, `getByTestId` |
| Importer des fichiers `.vue` dans les tests E2E | Les tests E2E tournent dans Node.js ; les fichiers `.vue` nécessitent une compilation Vite/Webpack | Utilise le component testing (stories + `mount`, voir [component-testing.md](component-testing.md)) pour les tests de composants |
| `page.waitForTimeout(300)` pour attendre la fin d'une transition | Les durées de transition varient ; les attentes arbitraires sont fragiles | `await expect(locator).toBeVisible()` fait de l'auto-waiting à travers les transitions |
| Mocker les stores Pinia en patchant `window.__pinia` | Fragile ; dépend des internals de Pinia ; peut ne pas déclencher la réactivité | Contrôle l'état via les interactions UI ou mocke les réponses API que le store consomme |
| Tester les composables en les appelant via `page.evaluate` | Les composables dépendent du contexte setup de Vue ; les appeler hors d'un composant échoue | Teste les composables à travers les composants qui les utilisent, ou en tests unitaires avec Vitest |
| Utiliser `page.locator('.v-btn')` pour les composants Vuetify | Les noms de classes de Vuetify sont internes et changent entre les versions | `page.getByRole('button', { name: 'Submit' })` fonctionne quelle que soit la bibliothèque de composants |
| Ne pas tester la navigation au clavier des composants personnalisés | Les bibliothèques de composants Vue ont souvent un support clavier incomplet | Teste `Tab`, `Enter`, `Escape`, `ArrowDown/Up` sur les dropdowns, modales et onglets |
| Lancer le serveur de dev Nuxt en CI | Le mode dev inclut le surcoût du hot reload, des builds plus lents et des warnings de développement | Utilise `npx nuxi build && npx nuxi preview` en CI |

## Voir aussi

- [core/locators.md](locators.md) -- stratégies de locators pour toute bibliothèque de composants Vue (Vuetify, PrimeVue, Quasar)
- [core/assertions-and-waiting.md](assertions-and-waiting.md) -- assertions avec auto-waiting pour la réactivité de Vue
- [core/component-testing.md](component-testing.md) -- patterns approfondis de component testing
- [core/forms-and-validation.md](forms-and-validation.md) -- patterns de test de formulaires pour VeeValidate et FormKit
- [core/accessibility.md](accessibility.md) -- tests d'accessibilité pour les bibliothèques de composants Vue
- [core/test-architecture.md](test-architecture.md) -- quand utiliser des tests E2E, de composants ou unitaires
- [core/nextjs.md](nextjs.md) -- comparaison : patterns de test Nuxt vs Next.js
