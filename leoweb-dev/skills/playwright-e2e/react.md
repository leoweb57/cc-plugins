# Tester des applications React avec Playwright

> **Quand l'utiliser** : tester des applications React construites avec Create React App (CRA), Vite ou des bundlers personnalisés. Couvre les tests E2E, les tests de composants expérimentaux, la navigation React Router, les bibliothèques de formulaires, les portals, les error boundaries et la vérification du contexte/de l'état à travers l'UI.
> **Prérequis** : [core/configuration.md](configuration.md), [core/locators.md](locators.md)

## Référence rapide

```bash
# Install Playwright in a React project
npm init playwright@latest

# Component testing (experimental package, last published for Playwright 1.62; 1.62+ uses stories, see core/component-testing.md)
npm install -D @playwright/experimental-ct-react

# Run E2E tests
npx playwright test

# Run component tests
npx playwright test -c playwright-ct.config.ts

# Debug a specific test
npx playwright test tests/login.spec.ts --headed --debug
```

## Mise en place

### Configuration Playwright pour React (Vite)

**TypeScript**
```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.ts',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? '50%' : undefined,

  use: {
    baseURL: 'http://localhost:5173', // Vite default port
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
      ? 'npm run build && npx vite preview --port 5173' // Vite
      // ? 'npm run build && npx serve -s build -l 5173' // legacy CRA
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
  testDir: './tests',
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
      ? 'npm run build && npx serve -s build -l 5173'
      : 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
```

### Configuration du component testing

Le component testing monte des composants React individuels dans un vrai navigateur, sans serveur de développement complet. Cette configuration concerne le package expérimental, dont la dernière publication date de Playwright 1.62 ; à partir de la 1.62, utilise le modèle à base de stories décrit dans [component-testing.md](component-testing.md).

**TypeScript**
```typescript
// playwright-ct.config.ts
import { defineConfig, devices } from '@playwright/experimental-ct-react';

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
const { defineConfig, devices } = require('@playwright/experimental-ct-react');

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

## Patterns

### Component testing avec `@playwright/experimental-ct-react`

> **Package déprécié** : `@playwright/experimental-ct-react` n'est pas publié pour Playwright 1.63+. Playwright 1.62 a déplacé le component testing vers des stories montées depuis `@playwright/test`. N'utilise ce pattern que sur une suite figée en 1.62 ; consulte [component-testing.md](component-testing.md#comment-fonctionne-le-component-testing-162) pour le modèle actuel.

**À utiliser quand** : tu testes de façon isolée des composants interactifs complexes -- tableaux de données, wizards de formulaire, éditeurs de texte riche, dropdowns avec navigation au clavier. Le composant a besoin d'un vrai navigateur (pas de jsdom), mais pas d'une application complète.
**À éviter quand** : le comportement du composant dépend fortement de données backend ou du contexte de routing. Utilise plutôt des tests E2E.

**TypeScript**
```typescript
// tests/components/Counter.ct.ts
import { test, expect } from '@playwright/experimental-ct-react';
import Counter from '../../src/components/Counter';

test('increments count on button click', async ({ mount }) => {
  const component = await mount(<Counter initialCount={0} />);

  await expect(component.getByText('Count: 0')).toBeVisible();
  await component.getByRole('button', { name: 'Increment' }).click();
  await expect(component.getByText('Count: 1')).toBeVisible();
});

test('decrements count on button click', async ({ mount }) => {
  const component = await mount(<Counter initialCount={5} />);

  await component.getByRole('button', { name: 'Decrement' }).click();
  await expect(component.getByText('Count: 4')).toBeVisible();
});

test('calls onChange callback when count changes', async ({ mount }) => {
  const values: number[] = [];
  const component = await mount(
    <Counter initialCount={0} onChange={(val) => values.push(val)} />
  );

  await component.getByRole('button', { name: 'Increment' }).click();
  await component.getByRole('button', { name: 'Increment' }).click();

  expect(values).toEqual([1, 2]);
});

test('disables decrement at zero when min is set', async ({ mount }) => {
  const component = await mount(<Counter initialCount={0} min={0} />);

  await expect(component.getByRole('button', { name: 'Decrement' })).toBeDisabled();
});
```

**JavaScript**
```javascript
// tests/components/Counter.ct.js
const { test, expect } = require('@playwright/experimental-ct-react');
const Counter = require('../../src/components/Counter');

test('increments count on button click', async ({ mount }) => {
  const component = await mount(<Counter initialCount={0} />);

  await expect(component.getByText('Count: 0')).toBeVisible();
  await component.getByRole('button', { name: 'Increment' }).click();
  await expect(component.getByText('Count: 1')).toBeVisible();
});

test('decrements count on button click', async ({ mount }) => {
  const component = await mount(<Counter initialCount={5} />);

  await component.getByRole('button', { name: 'Decrement' }).click();
  await expect(component.getByText('Count: 4')).toBeVisible();
});

test('calls onChange callback when count changes', async ({ mount }) => {
  const values = [];
  const component = await mount(
    <Counter initialCount={0} onChange={(val) => values.push(val)} />
  );

  await component.getByRole('button', { name: 'Increment' }).click();
  await component.getByRole('button', { name: 'Increment' }).click();

  expect(values).toEqual([1, 2]);
});
```

### Tester les hooks indirectement à travers l'UI

**À utiliser quand** : tu vérifies que des hooks personnalisés produisent le bon comportement d'UI. Playwright ne peut pas appeler les hooks directement -- teste-les à travers les composants qui les consomment.
**À éviter quand** : la logique du hook est du calcul pur sans effet de bord sur l'UI -- utilise un framework de tests unitaires pour cela.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('useDebounce hook (tested through SearchInput)', () => {
  test('debounced search triggers after user stops typing', async ({ page }) => {
    await page.goto('/search');

    // Set up a response interceptor to track API calls
    const apiCalls: string[] = [];
    await page.route('**/api/search*', async (route) => {
      apiCalls.push(route.request().url());
      await route.continue();
    });

    // Type quickly -- the debounce hook should batch these
    await page.getByRole('textbox', { name: 'Search' }).pressSequentially('playwright', {
      delay: 50,
    });

    // Wait for results to appear (debounce has fired)
    await expect(page.getByRole('listitem')).toHaveCount(5);

    // The debounced hook should have made 1-2 API calls, not 10 (one per keystroke)
    expect(apiCalls.length).toBeLessThanOrEqual(2);
  });
});

test.describe('usePagination hook (tested through ProductList)', () => {
  test('pagination controls navigate between pages', async ({ page }) => {
    await page.goto('/products');

    await expect(page.getByText('Page 1 of 5')).toBeVisible();

    await page.getByRole('button', { name: 'Next page' }).click();
    await expect(page.getByText('Page 2 of 5')).toBeVisible();

    await page.getByRole('button', { name: 'Previous page' }).click();
    await expect(page.getByText('Page 1 of 5')).toBeVisible();

    // First page: previous should be disabled
    await expect(page.getByRole('button', { name: 'Previous page' })).toBeDisabled();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('useDebounce hook (tested through SearchInput)', () => {
  test('debounced search triggers after user stops typing', async ({ page }) => {
    await page.goto('/search');

    const apiCalls = [];
    await page.route('**/api/search*', async (route) => {
      apiCalls.push(route.request().url());
      await route.continue();
    });

    await page.getByRole('textbox', { name: 'Search' }).pressSequentially('playwright', {
      delay: 50,
    });

    await expect(page.getByRole('listitem')).toHaveCount(5);
    expect(apiCalls.length).toBeLessThanOrEqual(2);
  });
});

test.describe('usePagination hook (tested through ProductList)', () => {
  test('pagination controls navigate between pages', async ({ page }) => {
    await page.goto('/products');

    await expect(page.getByText('Page 1 of 5')).toBeVisible();

    await page.getByRole('button', { name: 'Next page' }).click();
    await expect(page.getByText('Page 2 of 5')).toBeVisible();

    await page.getByRole('button', { name: 'Previous page' }).click();
    await expect(page.getByText('Page 1 of 5')).toBeVisible();

    await expect(page.getByRole('button', { name: 'Previous page' })).toBeDisabled();
  });
});
```

### Tester le contexte et les changements d'état via les interactions utilisateur

**À utiliser quand** : tu vérifies que le contexte React (thème, auth, locale) et la gestion d'état (Redux, Zustand, Jotai) produisent les bons changements d'UI.
**À éviter quand** : tu veux faire des assertions sur l'objet d'état brut -- Playwright teste l'UI, pas l'état interne. Si l'UI est correcte, l'état l'est aussi.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('theme context', () => {
  test('dark mode toggle changes the visual theme', async ({ page }) => {
    await page.goto('/settings');

    // Verify initial light mode
    const body = page.locator('body');
    await expect(body).not.toHaveClass(/dark/);

    // Toggle dark mode
    await page.getByRole('switch', { name: 'Dark mode' }).click();

    // Verify dark mode is applied
    await expect(body).toHaveClass(/dark/);

    // Verify the toggle state persists after navigation
    await page.getByRole('link', { name: 'Home' }).click();
    await expect(page.locator('body')).toHaveClass(/dark/);
  });
});

test.describe('shopping cart state', () => {
  test('adding items updates cart badge across pages', async ({ page }) => {
    await page.goto('/products');

    // Cart badge should show 0 or be hidden
    const cartBadge = page.getByTestId('cart-count');

    // Add first item
    await page.getByRole('listitem')
      .filter({ hasText: 'Running Shoes' })
      .getByRole('button', { name: 'Add to cart' })
      .click();
    await expect(cartBadge).toHaveText('1');

    // Add second item
    await page.getByRole('listitem')
      .filter({ hasText: 'Trail Jacket' })
      .getByRole('button', { name: 'Add to cart' })
      .click();
    await expect(cartBadge).toHaveText('2');

    // Navigate to a different page -- cart count persists (global state)
    await page.getByRole('link', { name: 'About' }).click();
    await expect(cartBadge).toHaveText('2');
  });
});

test.describe('auth context', () => {
  test('login updates the UI across all components consuming auth context', async ({ page }) => {
    await page.goto('/');

    // Unauthenticated state
    await expect(page.getByRole('link', { name: 'Sign in' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Sign out' })).toBeHidden();

    // Log in
    await page.getByRole('link', { name: 'Sign in' }).click();
    await page.getByLabel('Email').fill('user@example.com');
    await page.getByLabel('Password').fill('password123');
    await page.getByRole('button', { name: 'Sign in' }).click();

    // Authenticated state -- multiple components update
    await expect(page.getByRole('link', { name: 'Sign in' })).toBeHidden();
    await expect(page.getByText('user@example.com')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Sign out' })).toBeVisible();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('theme context', () => {
  test('dark mode toggle changes the visual theme', async ({ page }) => {
    await page.goto('/settings');

    const body = page.locator('body');
    await expect(body).not.toHaveClass(/dark/);

    await page.getByRole('switch', { name: 'Dark mode' }).click();

    await expect(body).toHaveClass(/dark/);

    await page.getByRole('link', { name: 'Home' }).click();
    await expect(page.locator('body')).toHaveClass(/dark/);
  });
});

test.describe('shopping cart state', () => {
  test('adding items updates cart badge across pages', async ({ page }) => {
    await page.goto('/products');

    const cartBadge = page.getByTestId('cart-count');

    await page.getByRole('listitem')
      .filter({ hasText: 'Running Shoes' })
      .getByRole('button', { name: 'Add to cart' })
      .click();
    await expect(cartBadge).toHaveText('1');

    await page.getByRole('listitem')
      .filter({ hasText: 'Trail Jacket' })
      .getByRole('button', { name: 'Add to cart' })
      .click();
    await expect(cartBadge).toHaveText('2');

    await page.getByRole('link', { name: 'About' }).click();
    await expect(cartBadge).toHaveText('2');
  });
});
```

### Tester la navigation React Router

**À utiliser quand** : tu testes le routing côté client avec React Router v6+. Vérifie les transitions de routes, les paramètres d'URL, les routes protégées et le comportement de l'historique du navigateur.
**À éviter quand** : ton application n'utilise que du routing côté serveur (le App Router de Next.js fonctionne différemment -- voir [core/nextjs.md](nextjs.md)).

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('React Router navigation', () => {
  test('client-side navigation does not cause full page reload', async ({ page }) => {
    await page.goto('/');

    // Store a marker in window to detect full reload
    await page.evaluate(() => {
      (window as any).__testMarker = 'no-reload';
    });

    // Navigate via a React Router Link
    await page.getByRole('link', { name: 'Products' }).click();
    await page.waitForURL('/products');

    // If the page fully reloaded, the marker would be gone
    const marker = await page.evaluate(() => (window as any).__testMarker);
    expect(marker).toBe('no-reload');
  });

  test('URL params update the page content', async ({ page }) => {
    await page.goto('/products?category=electronics');

    await expect(page.getByRole('heading', { name: 'Electronics' })).toBeVisible();

    // Change category via UI interaction (which updates the URL param)
    await page.getByRole('link', { name: 'Clothing' }).click();
    await page.waitForURL('/products?category=clothing');

    await expect(page.getByRole('heading', { name: 'Clothing' })).toBeVisible();
  });

  test('nested routes render parent and child layouts', async ({ page }) => {
    await page.goto('/settings/profile');

    // Parent layout (Settings)
    await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible();
    await expect(page.getByRole('navigation', { name: 'Settings' })).toBeVisible();

    // Child route (Profile)
    await expect(page.getByRole('heading', { name: 'Profile', level: 2 })).toBeVisible();

    // Navigate to sibling route
    await page.getByRole('link', { name: 'Notifications' }).click();
    await page.waitForURL('/settings/notifications');

    // Parent layout persists
    await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Notifications', level: 2 })).toBeVisible();
  });

  test('browser back button works with client-side routing', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('link', { name: 'Products' }).click();
    await page.waitForURL('/products');
    await page.getByRole('link', { name: 'About' }).click();
    await page.waitForURL('/about');

    // Go back
    await page.goBack();
    await expect(page).toHaveURL(/\/products/);

    await page.goBack();
    await expect(page).toHaveURL(/\/$/);
  });

  test('protected route redirects unauthenticated users', async ({ page }) => {
    await page.goto('/admin');

    // React Router's protected route should redirect to login
    await expect(page).toHaveURL(/\/login/);
    await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
  });

  test('404 route shows not found page', async ({ page }) => {
    await page.goto('/this-route-does-not-exist');

    await expect(page.getByRole('heading', { name: 'Page Not Found' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Go home' })).toBeVisible();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('React Router navigation', () => {
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

  test('URL params update the page content', async ({ page }) => {
    await page.goto('/products?category=electronics');

    await expect(page.getByRole('heading', { name: 'Electronics' })).toBeVisible();

    await page.getByRole('link', { name: 'Clothing' }).click();
    await page.waitForURL('/products?category=clothing');

    await expect(page.getByRole('heading', { name: 'Clothing' })).toBeVisible();
  });

  test('browser back button works with client-side routing', async ({ page }) => {
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

  test('protected route redirects unauthenticated users', async ({ page }) => {
    await page.goto('/admin');

    await expect(page).toHaveURL(/\/login/);
    await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
  });
});
```

### Tester les bibliothèques de formulaires (React Hook Form, Formik)

**À utiliser quand** : tu testes des formulaires construits avec react-hook-form, Formik ou des bibliothèques similaires. Playwright interagit avec le DOM, donc la bibliothèque de formulaires est transparente -- teste l'expérience utilisateur, pas les internals de la bibliothèque.
**À éviter quand** : tu testes la bibliothèque de formulaires elle-même. Tu testes le comportement de TON formulaire.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('registration form (react-hook-form)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/register');
  });

  test('shows validation errors on submit with empty fields', async ({ page }) => {
    await page.getByRole('button', { name: 'Create account' }).click();

    // react-hook-form shows errors after submit attempt
    await expect(page.getByText('Email is required')).toBeVisible();
    await expect(page.getByText('Password is required')).toBeVisible();
  });

  test('shows inline validation on blur', async ({ page }) => {
    const emailInput = page.getByLabel('Email');
    await emailInput.fill('not-an-email');
    await emailInput.blur();

    // react-hook-form with mode: 'onBlur' validates immediately
    await expect(page.getByText('Invalid email address')).toBeVisible();
  });

  test('password requirements update in real time', async ({ page }) => {
    const passwordInput = page.getByLabel('Password', { exact: true });

    await passwordInput.fill('short');
    await expect(page.getByText('At least 8 characters')).toHaveClass(/text-red/);

    await passwordInput.fill('longenough');
    await expect(page.getByText('At least 8 characters')).toHaveClass(/text-green/);

    await passwordInput.fill('LongEnough1!');
    await expect(page.getByText('Contains uppercase')).toHaveClass(/text-green/);
    await expect(page.getByText('Contains number')).toHaveClass(/text-green/);
    await expect(page.getByText('Contains special character')).toHaveClass(/text-green/);
  });

  test('successful registration submits form and redirects', async ({ page }) => {
    await page.getByLabel('Full name').fill('Jane Doe');
    await page.getByLabel('Email').fill('jane@example.com');
    await page.getByLabel('Password', { exact: true }).fill('Str0ng!Pass');
    await page.getByLabel('Confirm password').fill('Str0ng!Pass');
    await page.getByLabel('I agree to the terms').check();

    await page.getByRole('button', { name: 'Create account' }).click();

    await page.waitForURL('/dashboard');
    await expect(page.getByText('Welcome, Jane')).toBeVisible();
  });

  test('disables submit button while form is submitting', async ({ page }) => {
    // Slow down the API to observe the submitting state
    await page.route('**/api/register', async (route) => {
      await new Promise((resolve) => setTimeout(resolve, 1000));
      await route.fulfill({
        status: 201,
        contentType: 'application/json',
        body: JSON.stringify({ id: 1, email: 'jane@example.com' }),
      });
    });

    await page.getByLabel('Full name').fill('Jane Doe');
    await page.getByLabel('Email').fill('jane@example.com');
    await page.getByLabel('Password', { exact: true }).fill('Str0ng!Pass');
    await page.getByLabel('Confirm password').fill('Str0ng!Pass');
    await page.getByLabel('I agree to the terms').check();

    await page.getByRole('button', { name: 'Create account' }).click();

    // Button should show loading state
    await expect(page.getByRole('button', { name: /Creating|Loading|Submitting/ })).toBeDisabled();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('registration form (react-hook-form)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/register');
  });

  test('shows validation errors on submit with empty fields', async ({ page }) => {
    await page.getByRole('button', { name: 'Create account' }).click();

    await expect(page.getByText('Email is required')).toBeVisible();
    await expect(page.getByText('Password is required')).toBeVisible();
  });

  test('shows inline validation on blur', async ({ page }) => {
    const emailInput = page.getByLabel('Email');
    await emailInput.fill('not-an-email');
    await emailInput.blur();

    await expect(page.getByText('Invalid email address')).toBeVisible();
  });

  test('successful registration submits form and redirects', async ({ page }) => {
    await page.getByLabel('Full name').fill('Jane Doe');
    await page.getByLabel('Email').fill('jane@example.com');
    await page.getByLabel('Password', { exact: true }).fill('Str0ng!Pass');
    await page.getByLabel('Confirm password').fill('Str0ng!Pass');
    await page.getByLabel('I agree to the terms').check();

    await page.getByRole('button', { name: 'Create account' }).click();

    await page.waitForURL('/dashboard');
    await expect(page.getByText('Welcome, Jane')).toBeVisible();
  });
});
```

### Tester les portals React (modales, tooltips, dropdowns)

**À utiliser quand** : tu testes des composants rendus via `ReactDOM.createPortal()` -- modales, dialogs, tooltips, menus déroulants, notifications toast. Ils sont rendus en dehors de la hiérarchie DOM parente, mais Playwright voit le document entier.
**À éviter quand** : le composant n'est pas un portal -- il est rendu en ligne.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('portals', () => {
  test('modal opens and is accessible', async ({ page }) => {
    await page.goto('/products');

    await page.getByRole('button', { name: 'Delete product' }).first().click();

    // Modal is rendered via a portal to document.body, but Playwright
    // sees it like any other element
    const modal = page.getByRole('dialog', { name: 'Confirm deletion' });
    await expect(modal).toBeVisible();

    // Verify focus is trapped inside the modal
    await expect(modal.getByRole('button', { name: 'Cancel' })).toBeFocused();

    // Verify backdrop/overlay blocks interaction with elements behind
    // (Playwright will auto-wait for the element to be actionable)
    await modal.getByRole('button', { name: 'Delete' }).click();
    await expect(modal).toBeHidden();
  });

  test('modal closes on Escape key', async ({ page }) => {
    await page.goto('/products');
    await page.getByRole('button', { name: 'Delete product' }).first().click();

    const modal = page.getByRole('dialog', { name: 'Confirm deletion' });
    await expect(modal).toBeVisible();

    await page.keyboard.press('Escape');
    await expect(modal).toBeHidden();
  });

  test('tooltip shows on hover and hides on leave', async ({ page }) => {
    await page.goto('/dashboard');

    const triggerButton = page.getByRole('button', { name: 'Info' });
    await triggerButton.hover();

    // Tooltip rendered via portal
    await expect(page.getByRole('tooltip')).toBeVisible();
    await expect(page.getByRole('tooltip')).toContainText('Click for more details');

    // Move mouse away
    await page.mouse.move(0, 0);
    await expect(page.getByRole('tooltip')).toBeHidden();
  });

  test('toast notifications stack and auto-dismiss', async ({ page }) => {
    await page.goto('/settings');

    // Trigger multiple toasts
    await page.getByRole('button', { name: 'Save' }).click();
    await expect(page.getByText('Settings saved')).toBeVisible();

    // Toast should auto-dismiss after a delay
    await expect(page.getByText('Settings saved')).toBeHidden({ timeout: 10_000 });
  });

  test('dropdown menu rendered via portal positions correctly', async ({ page }) => {
    await page.goto('/dashboard');

    await page.getByRole('button', { name: 'More actions' }).click();

    const menu = page.getByRole('menu');
    await expect(menu).toBeVisible();
    await expect(menu.getByRole('menuitem', { name: 'Edit' })).toBeVisible();
    await expect(menu.getByRole('menuitem', { name: 'Delete' })).toBeVisible();

    // Click a menu item
    await menu.getByRole('menuitem', { name: 'Edit' }).click();
    await expect(menu).toBeHidden();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('portals', () => {
  test('modal opens and is accessible', async ({ page }) => {
    await page.goto('/products');

    await page.getByRole('button', { name: 'Delete product' }).first().click();

    const modal = page.getByRole('dialog', { name: 'Confirm deletion' });
    await expect(modal).toBeVisible();
    await expect(modal.getByRole('button', { name: 'Cancel' })).toBeFocused();

    await modal.getByRole('button', { name: 'Delete' }).click();
    await expect(modal).toBeHidden();
  });

  test('modal closes on Escape key', async ({ page }) => {
    await page.goto('/products');
    await page.getByRole('button', { name: 'Delete product' }).first().click();

    const modal = page.getByRole('dialog', { name: 'Confirm deletion' });
    await expect(modal).toBeVisible();

    await page.keyboard.press('Escape');
    await expect(modal).toBeHidden();
  });

  test('tooltip shows on hover and hides on leave', async ({ page }) => {
    await page.goto('/dashboard');

    await page.getByRole('button', { name: 'Info' }).hover();
    await expect(page.getByRole('tooltip')).toBeVisible();

    await page.mouse.move(0, 0);
    await expect(page.getByRole('tooltip')).toBeHidden();
  });
});
```

### Tester les error boundaries

**À utiliser quand** : tu vérifies que les error boundaries React interceptent proprement les erreurs de rendu et affichent une UI de repli plutôt qu'un écran blanc.
**À éviter quand** : tu testes la gestion d'erreurs dans des event handlers ou du code asynchrone -- les error boundaries n'interceptent que les erreurs de rendu.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('error boundaries', () => {
  test('error boundary shows fallback UI when child crashes', async ({ page }) => {
    // Capture console errors to verify the error was thrown
    const consoleErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto('/dashboard');

    // Trigger an action that causes a component to throw during render
    // (e.g., a component that crashes on specific data)
    await page.route('**/api/dashboard/widgets', (route) => {
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ widgets: null }), // null causes .map() to throw
      });
    });

    await page.reload();

    // Error boundary should catch the error and show fallback
    await expect(page.getByText('Something went wrong')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Try again' })).toBeVisible();

    // The rest of the page should still be functional
    await expect(page.getByRole('navigation', { name: 'Main' })).toBeVisible();
  });

  test('retry button in error boundary recovers the component', async ({ page }) => {
    let requestCount = 0;
    await page.route('**/api/dashboard/widgets', (route) => {
      requestCount++;
      if (requestCount === 1) {
        // First request: return bad data that crashes the component
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ widgets: null }),
        });
      } else {
        // Subsequent requests: return good data
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ widgets: [{ id: 1, name: 'Sales' }] }),
        });
      }
    });

    await page.goto('/dashboard');

    // Error boundary shows fallback
    await expect(page.getByText('Something went wrong')).toBeVisible();

    // Click retry -- component re-mounts with good data
    await page.getByRole('button', { name: 'Try again' }).click();

    // Component recovers
    await expect(page.getByText('Something went wrong')).toBeHidden();
    await expect(page.getByText('Sales')).toBeVisible();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('error boundaries', () => {
  test('error boundary shows fallback UI when child crashes', async ({ page }) => {
    const consoleErrors = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.route('**/api/dashboard/widgets', (route) => {
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ widgets: null }),
      });
    });

    await page.goto('/dashboard');

    await expect(page.getByText('Something went wrong')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Try again' })).toBeVisible();
    await expect(page.getByRole('navigation', { name: 'Main' })).toBeVisible();
  });

  test('retry button in error boundary recovers the component', async ({ page }) => {
    let requestCount = 0;
    await page.route('**/api/dashboard/widgets', (route) => {
      requestCount++;
      if (requestCount === 1) {
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ widgets: null }),
        });
      } else {
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ widgets: [{ id: 1, name: 'Sales' }] }),
        });
      }
    });

    await page.goto('/dashboard');

    await expect(page.getByText('Something went wrong')).toBeVisible();
    await page.getByRole('button', { name: 'Try again' }).click();

    await expect(page.getByText('Something went wrong')).toBeHidden();
    await expect(page.getByText('Sales')).toBeVisible();
  });
});
```

## Conseils spécifiques au framework

### CRA vs Vite : principales différences

Create React App a été déprécié par l'équipe React en février 2025 ; les nouvelles applications utilisent Vite ou un framework. Le tableau aide quand tu testes une application CRA héritée.

| Aspect | Create React App (CRA) | Vite |
|---|---|---|
| Port par défaut | `3000` | `5173` |
| Sortie du build | `build/` | `dist/` |
| Servir le build de production | `npx serve -s build -l 3000` | `npx vite preview --port 5173` |
| Variables d'environnement | préfixe `REACT_APP_*` | préfixe `VITE_*` |
| Temps de démarrage du serveur de dev | Lent (Webpack) | Rapide (esbuild) |

Adapte ton `webServer.command` et ta `baseURL` en conséquence.

### React Strict Mode et effets doublés

En développement, React Strict Mode exécute les effets deux fois. Cela peut provoquer des comportements inattendus dans les tests (ex. : appels API en double). Tes tests doivent y être résilients :

- N'asserte pas sur un nombre exact d'appels API en mode développement
- Si tu testes le nombre d'appels API, exécute-les contre un build de production ou tiens compte des invocations doublées

### Tester Suspense et les composants lazy

```typescript
// React.lazy() components show a fallback while loading
test('lazy-loaded route shows spinner then content', async ({ page }) => {
  await page.goto('/');

  // Navigate to a lazy route
  await page.getByRole('link', { name: 'Reports' }).click();

  // The reports module loads lazily -- you may briefly see a spinner
  // Playwright auto-waits for the final content
  await expect(page.getByRole('heading', { name: 'Reports' })).toBeVisible();
});
```

### Component testing : quand l'utiliser vs l'E2E

| Scénario | Utiliser le component testing | Utiliser l'E2E |
|---|---|---|
| Dropdown complexe avec navigation au clavier | Oui -- test isolé avec mount() | Oui aussi -- vérifier qu'il fonctionne dans la page |
| Tableau de données avec tri, filtrage, pagination | Oui -- contrôle direct des props | Oui aussi -- vérifier l'intégration API |
| Bouton qui soumet un formulaire | Non -- trivial en isolation | Oui -- tester le flux complet du formulaire |
| Composant de bascule de thème | Oui -- vérifier les changements visuels | Oui aussi -- vérifier la persistance |
| Formulaire de login connecté au contexte d'auth | Non -- trop de dépendances | Oui -- tester le vrai flux |

### Détecter les fuites mémoire dans les tests de longue durée

Si ton application React met à jour l'état de composants démontés (le warning « Can't perform a React state update on an unmounted component »), détecte-les :

```typescript
test('no state-update-on-unmounted warnings during navigation', async ({ page }) => {
  const warnings: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'warning' && msg.text().includes('unmounted')) {
      warnings.push(msg.text());
    }
  });

  // Rapid navigation to trigger unmount edge cases
  await page.goto('/dashboard');
  await page.getByRole('link', { name: 'Settings' }).click();
  await page.goBack();
  await page.getByRole('link', { name: 'Profile' }).click();
  await page.goBack();

  expect(warnings).toEqual([]);
});
```

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| `page.evaluate(() => store.getState())` pour asserter l'état Redux | Couple les tests à l'implémentation ; un changement de forme de l'état casse les tests | Asserte sur l'UI que l'état produit : `expect(cartBadge).toHaveText('3')` |
| Importer des composants React dans les fichiers de test E2E | Les tests E2E tournent dans Node.js, pas dans le navigateur ; les imports de composants échouent | Utilise le component testing (stories + `mount`, voir [component-testing.md](component-testing.md)) pour les composants, l'E2E pour les tests d'application complète |
| `page.waitForTimeout(500)` après des changements d'état React | React regroupe les mises à jour ; le timing varie selon les machines | Utilise `expect(locator).toHaveText('new value')` qui réessaie automatiquement |
| Tester l'état interne d'un composant avec `page.evaluate` | Fragile ; casse au moindre refactoring ; teste l'implémentation, pas le comportement | Interagis via l'UI et asserte sur la sortie visible |
| Mocker `useState` ou `useEffect` dans les tests Playwright | Playwright s'exécute dans le contexte du navigateur, pas dans l'arbre de composants React | Laisse les hooks s'exécuter naturellement ; contrôle les entrées (réponses API, props via le component testing) |
| Utiliser `page.locator('.MuiButton-root')` pour Material UI | Les noms de classes changent entre les versions de MUI et sont générés dynamiquement | `page.getByRole('button', { name: 'Submit' })` fonctionne quelle que soit la bibliothèque de composants |
| Tester chaque composant avec le component testing | Surcoût du montage dans le navigateur pour des composants simples ; doublon avec les tests unitaires | Utilise le component testing pour les widgets interactifs complexes ; les tests unitaires pour la logique pure ; l'E2E pour les flux |
| Ne pas tester la navigation au clavier des composants personnalisés | Les régressions d'accessibilité sont fréquentes dans les dropdowns, modales et onglets personnalisés | Teste les interactions `Tab`, `Enter`, `Escape`, `ArrowDown` dans les tests de composants |
| Asserter sur React DevTools ou les internals `__REACT_FIBER__` | Les propriétés internes de React ne sont pas stables d'une version à l'autre | Interagis uniquement avec le DOM rendu et asserte dessus |

## Voir aussi

- [core/locators.md](locators.md) -- stratégies de locators qui fonctionnent avec n'importe quelle bibliothèque de composants React
- [core/assertions-and-waiting.md](assertions-and-waiting.md) -- assertions avec auto-waiting pour les changements d'état React
- [core/forms-and-validation.md](forms-and-validation.md) -- patterns de test de formulaires applicables à react-hook-form et Formik
- [core/component-testing.md](component-testing.md) -- guide approfondi du component testing
- [core/accessibility.md](accessibility.md) -- tester les patterns ARIA dans les bibliothèques de composants React
- [core/test-architecture.md](test-architecture.md) -- quand utiliser des tests E2E, de composants ou unitaires
- [core/nextjs.md](nextjs.md) -- patterns spécifiques à Next.js pour les applications React avec SSR
