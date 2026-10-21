# Tester des applications Next.js avec Playwright

> **Quand l'utiliser** : tester des applications Next.js -- App Router, Pages Router, API routes, middleware, pages SSR, routes dynamiques et server components. Ce guide couvre les patterns de tests E2E propres au comportement de Next.js.
> **Prérequis** : [core/configuration.md](configuration.md), [core/locators.md](locators.md)

## Référence rapide

```bash
# Install Playwright in a Next.js project
npm init playwright@latest

# Run with Next.js dev server managed by Playwright
npx playwright test

# Run against a production build (recommended for CI)
npx playwright test --project=chromium

# Debug a single test with headed browser
npx playwright test tests/home.spec.ts --headed --debug
```

```
# .env.test — loaded by Next.js automatically when NODE_ENV=test
NEXT_PUBLIC_API_URL=http://localhost:3000/api
DATABASE_URL=postgresql://localhost:5432/test_db
NEXTAUTH_SECRET=test-secret-do-not-use-in-production
NEXTAUTH_URL=http://localhost:3000
```

## Mise en place

### Config Playwright pour Next.js

Le détail de configuration le plus important : utilise `webServer` pour laisser Playwright démarrer et gérer ton serveur Next.js.

**TypeScript**
```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';
import path from 'path';

export default defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.ts',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? '50%' : undefined,

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
    {
      name: 'mobile',
      use: { ...devices['iPhone 14'] },
    },
  ],

  webServer: {
    command: process.env.CI
      ? 'npm run build && npm run start' // production build in CI
      : 'npm run dev',                   // dev server locally
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    env: {
      NODE_ENV: process.env.CI ? 'production' : 'test',
    },
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
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'mobile',
      use: { ...devices['iPhone 14'] },
    },
  ],

  webServer: {
    command: process.env.CI
      ? 'npm run build && npm run start'
      : 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    env: {
      NODE_ENV: process.env.CI ? 'production' : 'test',
    },
  },
});
```

### Variables d'environnement avec `.env.test`

Next.js charge automatiquement `.env.test` quand `NODE_ENV=test`. Utilise-le pour les surcharges propres aux tests.

```bash
# .env.test (commit this -- no real secrets)
NEXT_PUBLIC_API_URL=http://localhost:3000/api
NEXT_PUBLIC_FEATURE_FLAG_NEW_CHECKOUT=true
DATABASE_URL=postgresql://localhost:5432/test_db

# .env.test.local (gitignored -- real test secrets)
NEXTAUTH_SECRET=test-secret-local
STRIPE_TEST_KEY=sk_test_xxx
```

```bash
# .gitignore
.env*.local
playwright-report/
playwright/.auth/
test-results/
```

## Patterns

### Tester les pages de l'App Router

**À utiliser quand** : tu testes des pages construites avec l'App Router de Next.js (répertoire `app/`). Les pages de l'App Router sont des server components par défaut et peuvent inclure du streaming, des suspense boundaries et des états de chargement.
**À éviter quand** : tu dois tester la logique isolée d'un server component -- utilise des tests unitaires pour cela. Les tests E2E vérifient le résultat rendu.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('App Router pages', () => {
  test('home page renders server component content', async ({ page }) => {
    await page.goto('/');

    // Server components render on the server -- by the time Playwright
    // sees the page, SSR content is already in the HTML
    await expect(page.getByRole('heading', { name: 'Welcome', level: 1 })).toBeVisible();
    await expect(page.getByRole('navigation', { name: 'Main' })).toBeVisible();
  });

  test('loading state shows while data streams in', async ({ page }) => {
    // Slow down the API to expose the loading state
    await page.route('**/api/dashboard/stats', async (route) => {
      await new Promise((resolve) => setTimeout(resolve, 2000));
      await route.continue();
    });

    await page.goto('/dashboard');

    // Verify the loading skeleton appears during streaming
    await expect(page.getByRole('progressbar')).toBeVisible();

    // Then verify the real content replaces it
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
    await expect(page.getByRole('progressbar')).toBeHidden();
  });

  test('suspense boundary shows fallback then resolves', async ({ page }) => {
    await page.goto('/products');

    // The product list may be inside a Suspense boundary
    // Playwright auto-waits, so just assert the final state
    await expect(page.getByRole('listitem')).toHaveCount(12);
  });

  test('nested layouts persist across navigation', async ({ page }) => {
    await page.goto('/dashboard/analytics');

    // Verify the dashboard layout sidebar is visible
    const sidebar = page.getByRole('navigation', { name: 'Dashboard' });
    await expect(sidebar).toBeVisible();

    // Navigate to a sibling route -- layout should persist (no full reload)
    await sidebar.getByRole('link', { name: 'Settings' }).click();
    await page.waitForURL('/dashboard/settings');

    // Sidebar is still there -- layout was not re-mounted
    await expect(sidebar).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('App Router pages', () => {
  test('home page renders server component content', async ({ page }) => {
    await page.goto('/');

    await expect(page.getByRole('heading', { name: 'Welcome', level: 1 })).toBeVisible();
    await expect(page.getByRole('navigation', { name: 'Main' })).toBeVisible();
  });

  test('loading state shows while data streams in', async ({ page }) => {
    await page.route('**/api/dashboard/stats', async (route) => {
      await new Promise((resolve) => setTimeout(resolve, 2000));
      await route.continue();
    });

    await page.goto('/dashboard');

    await expect(page.getByRole('progressbar')).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
    await expect(page.getByRole('progressbar')).toBeHidden();
  });

  test('suspense boundary shows fallback then resolves', async ({ page }) => {
    await page.goto('/products');

    await expect(page.getByRole('listitem')).toHaveCount(12);
  });

  test('nested layouts persist across navigation', async ({ page }) => {
    await page.goto('/dashboard/analytics');

    const sidebar = page.getByRole('navigation', { name: 'Dashboard' });
    await expect(sidebar).toBeVisible();

    await sidebar.getByRole('link', { name: 'Settings' }).click();
    await page.waitForURL('/dashboard/settings');

    await expect(sidebar).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible();
  });
});
```

### Tester le Pages Router (getServerSideProps / getStaticProps)

**À utiliser quand** : tu testes des pages construites avec le Pages Router (répertoire `pages/`) qui utilisent `getServerSideProps` ou `getStaticProps` pour récupérer des données.
**À éviter quand** : tu testes directement les fonctions de data fetching -- c'est un sujet de tests unitaires. Les tests E2E vérifient ce que voit l'utilisateur.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('Pages Router with SSR', () => {
  test('page with getServerSideProps renders fetched data', async ({ page }) => {
    await page.goto('/blog');

    // getServerSideProps fetches posts on the server -- verify they render
    await expect(page.getByRole('heading', { name: 'Blog', level: 1 })).toBeVisible();
    await expect(page.getByRole('article')).toHaveCount(10);

    // Verify server-fetched data appears (not a loading skeleton)
    await expect(page.getByRole('article').first()).toContainText(/\w+/);
  });

  test('page with getStaticProps shows pre-rendered content', async ({ page }) => {
    await page.goto('/about');

    // Static pages are pre-rendered at build time -- content is immediate
    await expect(page.getByRole('heading', { name: 'About Us' })).toBeVisible();
    await expect(page.getByText('Founded in 2020')).toBeVisible();
  });

  test('client-side navigation with next/link preserves SPA behavior', async ({ page }) => {
    await page.goto('/blog');

    // Click a next/link -- this should be a client-side transition, not a full reload
    const navigationPromise = page.waitForURL('/blog/my-first-post');
    await page.getByRole('link', { name: 'My First Post' }).click();
    await navigationPromise;

    await expect(page.getByRole('heading', { name: 'My First Post', level: 1 })).toBeVisible();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('Pages Router with SSR', () => {
  test('page with getServerSideProps renders fetched data', async ({ page }) => {
    await page.goto('/blog');

    await expect(page.getByRole('heading', { name: 'Blog', level: 1 })).toBeVisible();
    await expect(page.getByRole('article')).toHaveCount(10);
    await expect(page.getByRole('article').first()).toContainText(/\w+/);
  });

  test('page with getStaticProps shows pre-rendered content', async ({ page }) => {
    await page.goto('/about');

    await expect(page.getByRole('heading', { name: 'About Us' })).toBeVisible();
    await expect(page.getByText('Founded in 2020')).toBeVisible();
  });

  test('client-side navigation with next/link preserves SPA behavior', async ({ page }) => {
    await page.goto('/blog');

    const navigationPromise = page.waitForURL('/blog/my-first-post');
    await page.getByRole('link', { name: 'My First Post' }).click();
    await navigationPromise;

    await expect(page.getByRole('heading', { name: 'My First Post', level: 1 })).toBeVisible();
  });
});
```

### Tester les routes dynamiques (`[slug]`, `[...catchAll]`)

**À utiliser quand** : tu testes des pages avec des segments dynamiques comme `/blog/[slug]`, `/products/[id]`, ou des routes catch-all comme `/docs/[...path]`.
**À éviter quand** : la route est statique -- aucun segment dynamique n'est en jeu.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('dynamic routes', () => {
  test('dynamic [slug] page renders correct content', async ({ page }) => {
    await page.goto('/blog/nextjs-testing-guide');

    await expect(page.getByRole('heading', { level: 1 })).toContainText('Next.js Testing Guide');
    // Verify the slug maps to the correct content, not a 404
    await expect(page.getByText('Page not found')).toBeHidden();
  });

  test('non-existent slug shows 404 page', async ({ page }) => {
    const response = await page.goto('/blog/this-post-does-not-exist');

    // Next.js returns 404 for pages that call notFound() or return { notFound: true }
    expect(response?.status()).toBe(404);
    await expect(page.getByRole('heading', { name: '404' })).toBeVisible();
  });

  test('catch-all route handles nested paths', async ({ page }) => {
    await page.goto('/docs/getting-started/installation');

    await expect(page.getByRole('heading', { name: 'Installation' })).toBeVisible();

    // Navigate to a different docs path
    await page.goto('/docs/api/configuration');
    await expect(page.getByRole('heading', { name: 'Configuration' })).toBeVisible();
  });

  test('dynamic route with query parameters', async ({ page }) => {
    await page.goto('/products?category=electronics&sort=price-asc');

    await expect(page.getByRole('heading', { name: 'Electronics' })).toBeVisible();
    // Verify sort order is applied
    const prices = await page.getByTestId('product-price').allTextContents();
    const numericPrices = prices.map((p) => parseFloat(p.replace('$', '')));
    expect(numericPrices).toEqual([...numericPrices].sort((a, b) => a - b));
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('dynamic routes', () => {
  test('dynamic [slug] page renders correct content', async ({ page }) => {
    await page.goto('/blog/nextjs-testing-guide');

    await expect(page.getByRole('heading', { level: 1 })).toContainText('Next.js Testing Guide');
    await expect(page.getByText('Page not found')).toBeHidden();
  });

  test('non-existent slug shows 404 page', async ({ page }) => {
    const response = await page.goto('/blog/this-post-does-not-exist');

    expect(response?.status()).toBe(404);
    await expect(page.getByRole('heading', { name: '404' })).toBeVisible();
  });

  test('catch-all route handles nested paths', async ({ page }) => {
    await page.goto('/docs/getting-started/installation');

    await expect(page.getByRole('heading', { name: 'Installation' })).toBeVisible();

    await page.goto('/docs/api/configuration');
    await expect(page.getByRole('heading', { name: 'Configuration' })).toBeVisible();
  });

  test('dynamic route with query parameters', async ({ page }) => {
    await page.goto('/products?category=electronics&sort=price-asc');

    await expect(page.getByRole('heading', { name: 'Electronics' })).toBeVisible();
    const prices = await page.getByTestId('product-price').allTextContents();
    const numericPrices = prices.map((p) => parseFloat(p.replace('$', '')));
    expect(numericPrices).toEqual([...numericPrices].sort((a, b) => a - b));
  });
});
```

### Tester les API routes

**À utiliser quand** : tu testes les API routes de Next.js (`app/api/` ou `pages/api/`) directement avec le contexte `request` de Playwright, ou indirectement via des interactions UI qui les appellent.
**À éviter quand** : tu testes unitairement la logique d'un handler d'API en isolation -- utilise un framework de tests unitaires pour cela.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('API routes -- direct testing', () => {
  test('GET /api/products returns product list', async ({ request }) => {
    const response = await request.get('/api/products');

    expect(response.ok()).toBeTruthy();
    const body = await response.json();
    expect(body.products).toBeInstanceOf(Array);
    expect(body.products.length).toBeGreaterThan(0);
    expect(body.products[0]).toHaveProperty('id');
    expect(body.products[0]).toHaveProperty('name');
    expect(body.products[0]).toHaveProperty('price');
  });

  test('POST /api/products creates a new product', async ({ request }) => {
    const response = await request.post('/api/products', {
      data: {
        name: 'Test Product',
        price: 29.99,
        description: 'Created by Playwright',
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body.product.name).toBe('Test Product');
  });

  test('POST /api/products validates required fields', async ({ request }) => {
    const response = await request.post('/api/products', {
      data: { name: '' }, // missing required fields
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body.error).toContainEqual(
      expect.objectContaining({ field: 'price' })
    );
  });
});

test.describe('API routes -- indirect through UI', () => {
  test('form submission calls API and shows result', async ({ page }) => {
    await page.goto('/products/new');

    await page.getByLabel('Product name').fill('Widget');
    await page.getByLabel('Price').fill('19.99');
    await page.getByRole('button', { name: 'Create product' }).click();

    // The UI calls POST /api/products internally
    await expect(page.getByText('Product created successfully')).toBeVisible();
    await page.waitForURL('/products/**');
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('API routes -- direct testing', () => {
  test('GET /api/products returns product list', async ({ request }) => {
    const response = await request.get('/api/products');

    expect(response.ok()).toBeTruthy();
    const body = await response.json();
    expect(body.products).toBeInstanceOf(Array);
    expect(body.products.length).toBeGreaterThan(0);
    expect(body.products[0]).toHaveProperty('id');
    expect(body.products[0]).toHaveProperty('name');
    expect(body.products[0]).toHaveProperty('price');
  });

  test('POST /api/products creates a new product', async ({ request }) => {
    const response = await request.post('/api/products', {
      data: {
        name: 'Test Product',
        price: 29.99,
        description: 'Created by Playwright',
      },
    });

    expect(response.status()).toBe(201);
    const body = await response.json();
    expect(body.product.name).toBe('Test Product');
  });

  test('POST /api/products validates required fields', async ({ request }) => {
    const response = await request.post('/api/products', {
      data: { name: '' },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body.error).toContainEqual(
      expect.objectContaining({ field: 'price' })
    );
  });
});

test.describe('API routes -- indirect through UI', () => {
  test('form submission calls API and shows result', async ({ page }) => {
    await page.goto('/products/new');

    await page.getByLabel('Product name').fill('Widget');
    await page.getByLabel('Price').fill('19.99');
    await page.getByRole('button', { name: 'Create product' }).click();

    await expect(page.getByText('Product created successfully')).toBeVisible();
    await page.waitForURL('/products/**');
  });
});
```

### Tester le middleware

**À utiliser quand** : tu testes un middleware Next.js qui gère des redirections, des rewrites, des gardes d'authentification, un routage basé sur la géolocalisation ou la manipulation de headers.
**À éviter quand** : la logique du middleware est triviale -- une redirection de `/old` vers `/new` se vérifie avec un simple test de navigation.

> **Next.js 16+** : la convention de fichier `middleware` est dépréciée et renommée en `proxy` (`proxy.ts`, fonction `proxy` exportée). Playwright voit les mêmes redirections, rewrites et headers dans les deux cas, donc les tests ci-dessous s'appliquent sans changement.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('middleware', () => {
  test('unauthenticated user is redirected to login', async ({ page }) => {
    // Visit a protected page without auth cookies
    const response = await page.goto('/dashboard');

    // Middleware should redirect to /login
    expect(page.url()).toContain('/login');
    await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
  });

  test('middleware redirect preserves the return URL', async ({ page }) => {
    await page.goto('/dashboard/settings');

    // Should redirect to login with a callbackUrl or returnTo parameter
    const url = new URL(page.url());
    expect(url.pathname).toBe('/login');
    expect(url.searchParams.get('callbackUrl') || url.searchParams.get('returnTo'))
      .toContain('/dashboard/settings');
  });

  test('middleware sets security headers', async ({ page }) => {
    const response = await page.goto('/');

    const headers = response!.headers();
    expect(headers['x-frame-options']).toBe('DENY');
    expect(headers['x-content-type-options']).toBe('nosniff');
    expect(headers['referrer-policy']).toBe('strict-origin-when-cross-origin');
  });

  test('middleware rewrites based on locale', async ({ page, context }) => {
    // Set Accept-Language header to simulate a French user
    await context.setExtraHTTPHeaders({
      'Accept-Language': 'fr-FR,fr;q=0.9',
    });

    await page.goto('/');

    // Middleware should rewrite to the French locale
    await expect(page.getByText('Bienvenue')).toBeVisible();
  });

  test('middleware blocks unauthorized API access', async ({ request }) => {
    // Call a protected API route without authentication
    const response = await request.get('/api/admin/users');

    expect(response.status()).toBe(401);
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('middleware', () => {
  test('unauthenticated user is redirected to login', async ({ page }) => {
    const response = await page.goto('/dashboard');

    expect(page.url()).toContain('/login');
    await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
  });

  test('middleware redirect preserves the return URL', async ({ page }) => {
    await page.goto('/dashboard/settings');

    const url = new URL(page.url());
    expect(url.pathname).toBe('/login');
    expect(url.searchParams.get('callbackUrl') || url.searchParams.get('returnTo'))
      .toContain('/dashboard/settings');
  });

  test('middleware sets security headers', async ({ page }) => {
    const response = await page.goto('/');

    const headers = response.headers();
    expect(headers['x-frame-options']).toBe('DENY');
    expect(headers['x-content-type-options']).toBe('nosniff');
    expect(headers['referrer-policy']).toBe('strict-origin-when-cross-origin');
  });

  test('middleware rewrites based on locale', async ({ page, context }) => {
    await context.setExtraHTTPHeaders({
      'Accept-Language': 'fr-FR,fr;q=0.9',
    });

    await page.goto('/');

    await expect(page.getByText('Bienvenue')).toBeVisible();
  });

  test('middleware blocks unauthorized API access', async ({ request }) => {
    const response = await request.get('/api/admin/users');

    expect(response.status()).toBe(401);
  });
});
```

### Tester l'hydratation et la cohérence SSR/CSR

**À utiliser quand** : tu vérifies que le HTML rendu côté serveur correspond à la sortie hydratée côté client. Les hydration mismatches provoquent du flicker visuel, une interactivité cassée ou des erreurs React dans la console.
**À éviter quand** : la page n'a aucun composant client interactif -- les server components purs ne s'hydratent pas.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('hydration', () => {
  test('no hydration errors in console', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto('/');
    // Wait for hydration to complete -- interactive elements become clickable
    await page.getByRole('button', { name: 'Get started' }).click();

    // Filter for hydration-specific errors
    const hydrationErrors = consoleErrors.filter(
      (e) =>
        e.includes('Hydration') ||
        e.includes('hydration') ||
        e.includes('server-rendered') ||
        e.includes('did not match')
    );
    expect(hydrationErrors).toEqual([]);
  });

  test('interactive elements work after hydration', async ({ page }) => {
    await page.goto('/');

    // This button relies on a client component event handler
    // If hydration fails, the click will do nothing
    const counter = page.getByTestId('counter-value');
    await expect(counter).toHaveText('0');

    await page.getByRole('button', { name: 'Increment' }).click();
    await expect(counter).toHaveText('1');
  });

  test('date/time renders without hydration mismatch', async ({ page }) => {
    // Dates are a common source of hydration mismatch because server
    // and client may be in different timezones
    await page.goto('/dashboard');

    // Verify the date displays without flicker
    const dateElement = page.getByTestId('current-date');
    await expect(dateElement).toBeVisible();
    // Verify it contains a plausible date format, not "undefined" or garbled text
    await expect(dateElement).toHaveText(/\w+ \d{1,2}, \d{4}/);
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('hydration', () => {
  test('no hydration errors in console', async ({ page }) => {
    const consoleErrors = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto('/');
    await page.getByRole('button', { name: 'Get started' }).click();

    const hydrationErrors = consoleErrors.filter(
      (e) =>
        e.includes('Hydration') ||
        e.includes('hydration') ||
        e.includes('server-rendered') ||
        e.includes('did not match')
    );
    expect(hydrationErrors).toEqual([]);
  });

  test('interactive elements work after hydration', async ({ page }) => {
    await page.goto('/');

    const counter = page.getByTestId('counter-value');
    await expect(counter).toHaveText('0');

    await page.getByRole('button', { name: 'Increment' }).click();
    await expect(counter).toHaveText('1');
  });

  test('date/time renders without hydration mismatch', async ({ page }) => {
    await page.goto('/dashboard');

    const dateElement = page.getByTestId('current-date');
    await expect(dateElement).toBeVisible();
    await expect(dateElement).toHaveText(/\w+ \d{1,2}, \d{4}/);
  });
});
```

### Tester l'optimisation de next/image

**À utiliser quand** : tu vérifies que les composants `next/image` s'affichent correctement, chargent en lazy les images hors écran et servent des formats optimisés.
**À éviter quand** : tu n'utilises pas `next/image`, ou l'optimisation d'images n'est pas un sujet pour ton test.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('next/image', () => {
  test('hero image loads with correct attributes', async ({ page }) => {
    await page.goto('/');

    const heroImage = page.getByRole('img', { name: 'Hero banner' });
    await expect(heroImage).toBeVisible();

    // Verify next/image sets srcset for responsive loading
    const srcset = await heroImage.getAttribute('srcset');
    expect(srcset).toBeTruthy();
    expect(srcset).toContain('w='); // next/image adds width descriptors

    // Verify priority images are not lazy-loaded
    const loading = await heroImage.getAttribute('loading');
    expect(loading).not.toBe('lazy'); // priority images use eager loading
  });

  test('offscreen images lazy load on scroll', async ({ page }) => {
    await page.goto('/gallery');

    // Get an image that is below the fold
    const offscreenImage = page.getByRole('img', { name: 'Gallery item 20' });

    // Before scroll: image should not have loaded its src yet
    const initialSrc = await offscreenImage.getAttribute('src');
    // next/image uses a blur placeholder or empty src for lazy images

    // Scroll the image into view
    await offscreenImage.scrollIntoViewIfNeeded();
    await expect(offscreenImage).toBeVisible();

    // Verify the image has loaded (naturalWidth > 0 means the image loaded)
    const naturalWidth = await offscreenImage.evaluate(
      (img: HTMLImageElement) => img.naturalWidth
    );
    expect(naturalWidth).toBeGreaterThan(0);
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('next/image', () => {
  test('hero image loads with correct attributes', async ({ page }) => {
    await page.goto('/');

    const heroImage = page.getByRole('img', { name: 'Hero banner' });
    await expect(heroImage).toBeVisible();

    const srcset = await heroImage.getAttribute('srcset');
    expect(srcset).toBeTruthy();
    expect(srcset).toContain('w=');

    const loading = await heroImage.getAttribute('loading');
    expect(loading).not.toBe('lazy');
  });

  test('offscreen images lazy load on scroll', async ({ page }) => {
    await page.goto('/gallery');

    const offscreenImage = page.getByRole('img', { name: 'Gallery item 20' });

    await offscreenImage.scrollIntoViewIfNeeded();
    await expect(offscreenImage).toBeVisible();

    const naturalWidth = await offscreenImage.evaluate(
      (img) => img.naturalWidth
    );
    expect(naturalWidth).toBeGreaterThan(0);
  });
});
```

### Authentification avec NextAuth.js / Auth.js

**À utiliser quand** : tu testes des parcours de connexion dans des applications Next.js utilisant NextAuth.js ou Auth.js. Utilise un setup project pour t'authentifier une seule fois, puis réutilise `storageState` dans les tests.
**À éviter quand** : ton application n'utilise pas d'authentification par session.

**TypeScript**
```typescript
// playwright.config.ts (auth-specific excerpt)
import { defineConfig } from '@playwright/test';

export default defineConfig({
  projects: [
    {
      name: 'setup',
      testMatch: /auth\.setup\.ts/,
    },
    {
      name: 'authenticated',
      use: { storageState: 'playwright/.auth/user.json' },
      dependencies: ['setup'],
    },
    {
      name: 'unauthenticated',
      // No storageState -- tests run as logged-out user
      testMatch: '**/*.unauth.spec.ts',
    },
  ],
});
```

```typescript
// tests/auth.setup.ts
import { test as setup, expect } from '@playwright/test';

const authFile = 'playwright/.auth/user.json';

setup('authenticate via credentials', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('test@example.com');
  await page.getByLabel('Password').fill(process.env.TEST_PASSWORD!);
  await page.getByRole('button', { name: 'Sign in' }).click();

  // Wait for the redirect after successful login
  await page.waitForURL('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  // Save authentication state (cookies + localStorage)
  await page.context().storageState({ path: authFile });
});
```

```typescript
// tests/dashboard.spec.ts
import { test, expect } from '@playwright/test';

// This test runs with the authenticated storageState from the setup project
test('authenticated user sees dashboard', async ({ page }) => {
  await page.goto('/dashboard');

  // No login redirect -- auth cookies are already set
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  await expect(page.getByText('test@example.com')).toBeVisible();
});
```

**JavaScript**
```javascript
// tests/auth.setup.js
const { test: setup, expect } = require('@playwright/test');

const authFile = 'playwright/.auth/user.json';

setup('authenticate via credentials', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('test@example.com');
  await page.getByLabel('Password').fill(process.env.TEST_PASSWORD);
  await page.getByRole('button', { name: 'Sign in' }).click();

  await page.waitForURL('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  await page.context().storageState({ path: authFile });
});
```

```javascript
// tests/dashboard.spec.js
const { test, expect } = require('@playwright/test');

test('authenticated user sees dashboard', async ({ page }) => {
  await page.goto('/dashboard');

  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  await expect(page.getByText('test@example.com')).toBeVisible();
});
```

## Conseils spécifiques au framework

### Serveur de dev vs build de production

| Scénario | Commande | Compromis |
|---|---|---|
| Développement local | `npm run dev` | Hot reload, itération rapide, mais ne teste pas le comportement de production (minification, optimisation, edge runtime du middleware) |
| Pipeline de CI | `npm run build && npm run start` | Teste le vrai bundle de production ; détecte les erreurs de build et les cas limites du middleware |
| Smoke test rapide | `npm run dev` en CI avec `reuseExistingServer: false` | CI plus rapide, mais passe à côté des bugs propres à la production |

**Recommandation** : utilise `npm run dev` en local pour un feedback rapide. Utilise `npm run build && npm run start` en CI pour tester le vrai artefact de production.

### Les server components ne peuvent pas être testés en isolation

Les server components Next.js s'exécutent sur le serveur et produisent du HTML. Playwright teste la sortie rendue. Tu ne peux pas importer et rendre un server component dans un test Playwright. À la place :

1. Teste le HTML final rendu via la navigation (`page.goto`)
2. Vérifie que les données récupérées côté serveur apparaissent dans la page
3. Utilise des tests d'API routes pour valider séparément la couche de données

### Gérer les redirections Next.js

Les redirections Next.js (configurées dans `next.config.js`, dans le middleware, ou via `redirect()` dans les server actions) sont transparentes pour Playwright. Après `page.goto()`, vérifie `page.url()` pour confirmer la destination finale.

### Compatibilité Turbopack

Next.js 16+ utilise Turbopack par défaut pour `next dev` et `next build`, donc aucun flag n'est nécessaire. Sur Next.js 15, active-le avec `--turbopack` dans ton `webServer.command` :

```typescript
webServer: {
  command: process.env.CI
    ? 'npm run build && npm run start'
    : 'npx next dev --turbopack',
  url: 'http://localhost:3000',
  reuseExistingServer: !process.env.CI,
},
```

### Plusieurs entrées webServer (Next.js + backend d'API)

Si ton application Next.js consomme une API backend séparée :

```typescript
webServer: [
  {
    command: 'npm run dev:api',
    url: 'http://localhost:4000/health',
    reuseExistingServer: !process.env.CI,
  },
  {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
],
```

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| `await page.waitForTimeout(3000)` après une navigation | Les transitions côté client de Next.js sont rapides ; des attentes arbitraires sont inutiles et fragiles | `await page.waitForURL('/expected-path')` ou `await expect(locator).toBeVisible()` |
| Tester `getServerSideProps` en l'important et en l'appelant directement | Il dépend de `context` (req/res) que Playwright ne peut pas fournir ; c'est un sujet de tests unitaires | Navigue vers la page et vérifie la sortie rendue |
| Mocker tes propres API routes avec `page.route()` | Tu testes une fiction ; ton handler d'API peut avoir des bugs que le mock masque | Laisse la vraie API route traiter les requêtes ; ne mocke que les services externes |
| Utiliser `page.goto('http://localhost:3000/path')` avec une URL complète | Casse quand le port ou l'hôte change ; ignore `baseURL` | Utilise `page.goto('/path')` et configure `baseURL` dans la config |
| Lancer `npm run build && npm run start` en local à chaque exécution de tests | Boucle de feedback extrêmement lente pendant le développement | Utilise `npm run dev` en local avec `reuseExistingServer: true` ; réserve les builds de production à la CI |
| Tester `next/image` en vérifiant des chemins d'URL exacts | `next/image` réécrit les URLs d'images via `/_next/image` ; les chemins changent entre dev et prod | Vérifie le texte `alt`, la visibilité, `naturalWidth > 0` et la présence de `srcset` |
| Sauter `.env.test` et coder en dur les valeurs de test dans la config | Les valeurs se dispersent entre la config et les fichiers de test ; difficile à maintenir | Utilise `.env.test` pour les valeurs de test partagées ; `.env.test.local` pour les secrets |
| Tester les server actions en les appelant comme des fonctions | Les server actions sont liées au runtime Next.js ; les appeler hors d'un contexte de requête échoue | Déclenche les server actions via leur UI (soumissions de formulaire, clics sur des boutons) |
| Ignorer les erreurs de console dans les tests SSR | Les hydration mismatches et les erreurs serveur apparaissent dans la console et révèlent de vrais bugs | Écoute les erreurs de `page.on('console')` et fais échouer le test si des warnings d'hydratation apparaissent |

## Voir aussi

- [core/configuration.md](configuration.md) -- patterns de configuration Playwright de base, dont `webServer`
- [core/authentication.md](authentication.md) -- setup projects d'authentification et réutilisation de `storageState`
- [core/api-testing.md](api-testing.md) -- tester directement les API routes avec le contexte `request`
- [core/network-mocking.md](network-mocking.md) -- mocker les API externes appelées par les API routes Next.js
- [core/when-to-mock.md](when-to-mock.md) -- quand mocker et quand appeler les vrais services
- [core/react.md](react.md) -- patterns spécifiques à React applicables aux composants client Next.js
- [ci/ci-github-actions.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/ci-github-actions.md) -- configuration de la CI avec cache de `npm run build` pour Next.js
