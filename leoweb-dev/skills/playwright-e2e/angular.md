# Tester des applications Angular avec Playwright

> **Quand l'utiliser** : tester des applications Angular -- formulaires réactifs, composants Angular Material, navigation Angular Router, modules lazy-loaded, signals, observables et détection de changements pilotée par Zone.js. Ce guide couvre les patterns de test E2E propres au comportement d'Angular.
> **Prérequis** : [core/configuration.md](configuration.md), [core/locators.md](locators.md)

## Référence rapide

```bash
# Install Playwright in an Angular project
npm init playwright@latest

# Run tests with Angular dev server managed by Playwright
npx playwright test

# Run against a production build (recommended for CI)
npx playwright test --project=chromium

# Debug a single test
npx playwright test tests/home.spec.ts --headed --debug

# Generate tests with codegen
npx playwright codegen http://localhost:4200
```

## Mise en place

### Configuration Playwright pour Angular

**TypeScript**
```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  testMatch: '**/*.spec.ts',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? '50%' : undefined,

  use: {
    baseURL: 'http://localhost:4200',
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
      ? 'npx ng build && npx http-server dist/your-app/browser -p 4200 -s'
      : 'npx ng serve',
    url: 'http://localhost:4200',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000, // Angular builds can be slow
  },
});
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './e2e',
  testMatch: '**/*.spec.js',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? '50%' : undefined,

  use: {
    baseURL: 'http://localhost:4200',
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
      ? 'npx ng build && npx http-server dist/your-app/browser -p 4200 -s'
      : 'npx ng serve',
    url: 'http://localhost:4200',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
```

### Intégration avec Angular CLI

Les projets Angular qui utilisaient auparavant Protractor peuvent adopter Playwright comme remplaçant direct. Le répertoire de tests se trouve par convention dans `e2e/` dans les projets Angular.

```
your-angular-app/
  src/
  e2e/
    tests/
      home.spec.ts
      auth.spec.ts
      products.spec.ts
    fixtures/
      auth.fixture.ts
  playwright.config.ts
  angular.json
  package.json
```

Ajoute des scripts dans `package.json` :

```json
{
  "scripts": {
    "e2e": "playwright test",
    "e2e:headed": "playwright test --headed",
    "e2e:debug": "playwright test --debug",
    "e2e:report": "playwright show-report"
  }
}
```

### Configuration de l'environnement

Angular utilise `environment.ts` et `environment.prod.ts` pour la configuration au build. Pour les réglages propres aux tests, utilise des variables d'environnement transmises via la configuration Playwright.

**TypeScript**
```typescript
// playwright.config.ts (excerpt)
webServer: {
  command: process.env.CI
    ? 'npx ng build --configuration=production && npx http-server dist/your-app/browser -p 4200 -s'
    : 'npx ng serve --configuration=development',
  url: 'http://localhost:4200',
  reuseExistingServer: !process.env.CI,
  timeout: 120_000,
  env: {
    NG_APP_API_URL: 'http://localhost:4200/api',
  },
},
```

## Patterns

### Stratégies de locators spécifiques à Angular

**À utiliser quand** : tu cibles des éléments dans des templates Angular. Angular génère des motifs d'attributs spécifiques (`_ngcontent-*`, `_nghost-*`, `ng-reflect-*`) que tu dois éviter dans les locators. Utilise toujours des locators sémantiques.
**À éviter quand** : tu es tenté d'utiliser les attributs `[_ngcontent-abc123]` ou `[ng-reflect-model]` -- ils sont internes et changent à chaque build.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('Angular locator strategies', () => {
  test('prefer role-based locators over Angular internals', async ({ page }) => {
    await page.goto('/dashboard');

    // GOOD: Role-based locators work with Angular Material and native HTML
    await page.getByRole('button', { name: 'Create project' }).click();
    await expect(page.getByRole('heading', { name: 'New Project' })).toBeVisible();

    // GOOD: Label-based for form fields
    await page.getByLabel('Project name').fill('My Project');

    // GOOD: Text-based for non-interactive content
    await expect(page.getByText('3 projects total')).toBeVisible();

    // BAD (never do this):
    // page.locator('[_ngcontent-abc]')  -- changes every build
    // page.locator('[ng-reflect-model]') -- debug attribute, stripped in prod
    // page.locator('app-dashboard .mat-card') -- component selector + internal class
  });

  test('use test IDs for complex Angular components', async ({ page }) => {
    await page.goto('/analytics');

    // Angular components with no semantic role need test IDs
    const chart = page.getByTestId('revenue-chart');
    await expect(chart).toBeVisible();

    // Configure the testIdAttribute if your team uses a different attribute
    // In playwright.config.ts: use: { testIdAttribute: 'data-cy' }
  });

  test('scope locators within Angular component boundaries', async ({ page }) => {
    await page.goto('/users');

    // Scope within a table to find specific rows
    const userTable = page.getByRole('table', { name: 'Users' });
    const adminRow = userTable.getByRole('row').filter({
      has: page.getByRole('cell', { name: 'Admin' }),
    });
    await adminRow.getByRole('button', { name: 'Edit' }).click();

    await expect(page.getByRole('dialog', { name: 'Edit User' })).toBeVisible();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('Angular locator strategies', () => {
  test('prefer role-based locators over Angular internals', async ({ page }) => {
    await page.goto('/dashboard');

    await page.getByRole('button', { name: 'Create project' }).click();
    await expect(page.getByRole('heading', { name: 'New Project' })).toBeVisible();

    await page.getByLabel('Project name').fill('My Project');
    await expect(page.getByText('3 projects total')).toBeVisible();
  });

  test('use test IDs for complex Angular components', async ({ page }) => {
    await page.goto('/analytics');

    const chart = page.getByTestId('revenue-chart');
    await expect(chart).toBeVisible();
  });

  test('scope locators within Angular component boundaries', async ({ page }) => {
    await page.goto('/users');

    const userTable = page.getByRole('table', { name: 'Users' });
    const adminRow = userTable.getByRole('row').filter({
      has: page.getByRole('cell', { name: 'Admin' }),
    });
    await adminRow.getByRole('button', { name: 'Edit' }).click();

    await expect(page.getByRole('dialog', { name: 'Edit User' })).toBeVisible();
  });
});
```

### Tester les formulaires réactifs

**À utiliser quand** : tu testes des formulaires réactifs Angular (`FormGroup`, `FormControl`, `FormArray`). Playwright interagit avec le DOM rendu, donc les formulaires réactifs sont transparents -- teste l'expérience utilisateur.
**À éviter quand** : tu testes la logique de validation d'un formulaire de façon isolée -- utilise des tests unitaires Angular TestBed pour cela.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('reactive forms', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/register');
  });

  test('shows validation errors for invalid inputs', async ({ page }) => {
    // Touch and blur each field to trigger Angular's touched + dirty validators
    const emailInput = page.getByLabel('Email');
    await emailInput.click();
    await emailInput.blur();

    await expect(page.getByText('Email is required')).toBeVisible();

    await emailInput.fill('not-an-email');
    await emailInput.blur();

    await expect(page.getByText('Invalid email format')).toBeVisible();
  });

  test('cross-field validation (password match)', async ({ page }) => {
    await page.getByLabel('Password', { exact: true }).fill('Str0ng!Pass');
    await page.getByLabel('Confirm password').fill('different-password');
    await page.getByLabel('Confirm password').blur();

    await expect(page.getByText('Passwords do not match')).toBeVisible();

    // Fix the mismatch
    await page.getByLabel('Confirm password').fill('Str0ng!Pass');
    await page.getByLabel('Confirm password').blur();

    await expect(page.getByText('Passwords do not match')).toBeHidden();
  });

  test('dynamic FormArray -- add and remove items', async ({ page }) => {
    await page.goto('/profile/edit');

    // Add a phone number (FormArray push)
    await page.getByRole('button', { name: 'Add phone number' }).click();

    const phoneInputs = page.getByLabel(/Phone number/);
    await expect(phoneInputs).toHaveCount(2); // default + new one

    await phoneInputs.nth(1).fill('+1-555-0199');

    // Remove the first phone number
    await page.getByRole('button', { name: 'Remove phone 1' }).click();
    await expect(phoneInputs).toHaveCount(1);
    await expect(phoneInputs.first()).toHaveValue('+1-555-0199');
  });

  test('submit button disabled when form is invalid', async ({ page }) => {
    const submitButton = page.getByRole('button', { name: 'Create account' });

    // Form starts invalid -- button should be disabled
    await expect(submitButton).toBeDisabled();

    // Fill all required fields
    await page.getByLabel('Full name').fill('Jane Doe');
    await page.getByLabel('Email').fill('jane@example.com');
    await page.getByLabel('Password', { exact: true }).fill('Str0ng!Pass');
    await page.getByLabel('Confirm password').fill('Str0ng!Pass');
    await page.getByLabel('I agree to the terms').check();

    // Now the form is valid -- button should be enabled
    await expect(submitButton).toBeEnabled();
  });

  test('async validator shows loading state', async ({ page }) => {
    // Slow down the username availability check
    await page.route('**/api/check-username*', async (route) => {
      await new Promise((resolve) => setTimeout(resolve, 1000));
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ available: true }),
      });
    });

    await page.getByLabel('Username').fill('janedoe');
    await page.getByLabel('Username').blur();

    // Async validator fires -- shows a loading indicator
    await expect(page.getByTestId('username-checking')).toBeVisible();

    // After the check completes
    await expect(page.getByTestId('username-checking')).toBeHidden();
    await expect(page.getByText('Username is available')).toBeVisible();
  });

  test('form submission posts correct data', async ({ page }) => {
    let submittedData: Record<string, unknown> = {};
    await page.route('**/api/register', async (route) => {
      submittedData = route.request().postDataJSON();
      await route.fulfill({
        status: 201,
        contentType: 'application/json',
        body: JSON.stringify({ id: 1 }),
      });
    });

    await page.getByLabel('Full name').fill('Jane Doe');
    await page.getByLabel('Email').fill('jane@example.com');
    await page.getByLabel('Password', { exact: true }).fill('Str0ng!Pass');
    await page.getByLabel('Confirm password').fill('Str0ng!Pass');
    await page.getByLabel('I agree to the terms').check();
    await page.getByRole('button', { name: 'Create account' }).click();

    expect(submittedData).toMatchObject({
      name: 'Jane Doe',
      email: 'jane@example.com',
    });
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('reactive forms', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/register');
  });

  test('shows validation errors for invalid inputs', async ({ page }) => {
    const emailInput = page.getByLabel('Email');
    await emailInput.click();
    await emailInput.blur();

    await expect(page.getByText('Email is required')).toBeVisible();

    await emailInput.fill('not-an-email');
    await emailInput.blur();

    await expect(page.getByText('Invalid email format')).toBeVisible();
  });

  test('cross-field validation (password match)', async ({ page }) => {
    await page.getByLabel('Password', { exact: true }).fill('Str0ng!Pass');
    await page.getByLabel('Confirm password').fill('different-password');
    await page.getByLabel('Confirm password').blur();

    await expect(page.getByText('Passwords do not match')).toBeVisible();

    await page.getByLabel('Confirm password').fill('Str0ng!Pass');
    await page.getByLabel('Confirm password').blur();

    await expect(page.getByText('Passwords do not match')).toBeHidden();
  });

  test('submit button disabled when form is invalid', async ({ page }) => {
    const submitButton = page.getByRole('button', { name: 'Create account' });

    await expect(submitButton).toBeDisabled();

    await page.getByLabel('Full name').fill('Jane Doe');
    await page.getByLabel('Email').fill('jane@example.com');
    await page.getByLabel('Password', { exact: true }).fill('Str0ng!Pass');
    await page.getByLabel('Confirm password').fill('Str0ng!Pass');
    await page.getByLabel('I agree to the terms').check();

    await expect(submitButton).toBeEnabled();
  });
});
```

### Tester les composants Angular Material

**À utiliser quand** : tu testes des applications utilisant Angular Material (mat-button, mat-input, mat-select, mat-dialog, mat-table, etc.). Les composants Angular Material utilisent des attributs ARIA corrects, ce qui les rend accessibles aux locators basés sur les rôles.
**À éviter quand** : tu utilises des sélecteurs de classes CSS comme `.mat-mdc-button` ou `.mat-option` -- ils changent d'une version de Material à l'autre.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('Angular Material components', () => {
  test('mat-select dropdown', async ({ page }) => {
    await page.goto('/settings');

    // Angular Material select has role="combobox"
    await page.getByRole('combobox', { name: 'Theme' }).click();

    // Options appear in a CDK overlay (similar to a portal)
    await page.getByRole('option', { name: 'Dark' }).click();

    // Verify the selection
    await expect(page.getByRole('combobox', { name: 'Theme' })).toContainText('Dark');
  });

  test('mat-autocomplete with type-ahead', async ({ page }) => {
    await page.goto('/users/new');

    const roleInput = page.getByRole('combobox', { name: 'Role' });
    await roleInput.fill('adm');

    // Autocomplete suggestions appear in a CDK overlay
    await expect(page.getByRole('option', { name: 'Admin' })).toBeVisible();
    await expect(page.getByRole('option', { name: 'Administrator' })).toBeVisible();

    await page.getByRole('option', { name: 'Admin' }).click();
    await expect(roleInput).toHaveValue('Admin');
  });

  test('mat-dialog opens and closes', async ({ page }) => {
    await page.goto('/projects');

    await page.getByRole('button', { name: 'Delete project' }).first().click();

    // MatDialog renders as a CDK overlay with role="dialog"
    const dialog = page.getByRole('dialog');
    await expect(dialog).toBeVisible();
    await expect(dialog.getByText('Are you sure?')).toBeVisible();

    // Cancel
    await dialog.getByRole('button', { name: 'Cancel' }).click();
    await expect(dialog).toBeHidden();
  });

  test('mat-table sorting', async ({ page }) => {
    await page.goto('/users');

    // Click the column header to sort
    await page.getByRole('columnheader', { name: 'Name' }).click();

    // Verify sort indicator
    const header = page.getByRole('columnheader', { name: 'Name' });
    await expect(header).toHaveAttribute('aria-sort', 'ascending');

    // Verify rows are sorted
    const names = await page.getByRole('cell').filter({
      has: page.locator('[data-column="name"]'),
    }).allTextContents();
    const sortedNames = [...names].sort();
    expect(names).toEqual(sortedNames);

    // Click again for descending
    await page.getByRole('columnheader', { name: 'Name' }).click();
    await expect(header).toHaveAttribute('aria-sort', 'descending');
  });

  test('mat-paginator controls table pagination', async ({ page }) => {
    await page.goto('/users');

    await expect(page.getByText('1 - 10 of 50')).toBeVisible();

    // Navigate to next page
    await page.getByRole('button', { name: 'Next page' }).click();
    await expect(page.getByText('11 - 20 of 50')).toBeVisible();

    // Change page size
    await page.getByRole('combobox', { name: 'Items per page' }).click();
    await page.getByRole('option', { name: '25' }).click();
    await expect(page.getByText('1 - 25 of 50')).toBeVisible();
  });

  test('mat-snack-bar notification appears and dismisses', async ({ page }) => {
    await page.goto('/settings');

    await page.getByRole('button', { name: 'Save' }).click();

    // Snackbar appears at the bottom of the screen
    await expect(page.getByText('Settings saved successfully')).toBeVisible();

    // Dismiss via action button
    await page.getByRole('button', { name: 'Dismiss' }).click();
    await expect(page.getByText('Settings saved successfully')).toBeHidden();
  });

  test('mat-stepper wizard flow', async ({ page }) => {
    await page.goto('/onboarding');

    // Step 1: Personal info
    await expect(page.getByText('Step 1 of 3')).toBeVisible();
    await page.getByLabel('Full name').fill('Jane Doe');
    await page.getByRole('button', { name: 'Next' }).click();

    // Step 2: Company info
    await expect(page.getByText('Step 2 of 3')).toBeVisible();
    await page.getByLabel('Company').fill('Acme Corp');
    await page.getByRole('button', { name: 'Next' }).click();

    // Step 3: Review
    await expect(page.getByText('Step 3 of 3')).toBeVisible();
    await expect(page.getByText('Jane Doe')).toBeVisible();
    await expect(page.getByText('Acme Corp')).toBeVisible();

    // Go back to step 1
    await page.getByRole('button', { name: 'Back' }).click();
    await page.getByRole('button', { name: 'Back' }).click();
    await expect(page.getByText('Step 1 of 3')).toBeVisible();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('Angular Material components', () => {
  test('mat-select dropdown', async ({ page }) => {
    await page.goto('/settings');

    await page.getByRole('combobox', { name: 'Theme' }).click();
    await page.getByRole('option', { name: 'Dark' }).click();

    await expect(page.getByRole('combobox', { name: 'Theme' })).toContainText('Dark');
  });

  test('mat-dialog opens and closes', async ({ page }) => {
    await page.goto('/projects');

    await page.getByRole('button', { name: 'Delete project' }).first().click();

    const dialog = page.getByRole('dialog');
    await expect(dialog).toBeVisible();
    await expect(dialog.getByText('Are you sure?')).toBeVisible();

    await dialog.getByRole('button', { name: 'Cancel' }).click();
    await expect(dialog).toBeHidden();
  });

  test('mat-table sorting', async ({ page }) => {
    await page.goto('/users');

    await page.getByRole('columnheader', { name: 'Name' }).click();

    const header = page.getByRole('columnheader', { name: 'Name' });
    await expect(header).toHaveAttribute('aria-sort', 'ascending');
  });

  test('mat-snack-bar notification appears and dismisses', async ({ page }) => {
    await page.goto('/settings');

    await page.getByRole('button', { name: 'Save' }).click();
    await expect(page.getByText('Settings saved successfully')).toBeVisible();

    await page.getByRole('button', { name: 'Dismiss' }).click();
    await expect(page.getByText('Settings saved successfully')).toBeHidden();
  });
});
```

### Tester la navigation Angular Router

**À utiliser quand** : tu testes la navigation Angular Router, les routes lazy-loaded, les route guards et la gestion des paramètres d'URL.
**À éviter quand** : tu testes la configuration du router de façon isolée -- utilise Angular TestBed pour cela.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('Angular Router navigation', () => {
  test('lazy-loaded module loads on navigation', async ({ page }) => {
    await page.goto('/');

    // Navigate to a lazy-loaded route
    await page.getByRole('link', { name: 'Admin' }).click();
    await page.waitForURL('/admin');

    // The lazy module loads and renders its component
    await expect(page.getByRole('heading', { name: 'Admin Dashboard' })).toBeVisible();
  });

  test('route guard redirects unauthorized users', async ({ page }) => {
    // Visit a route protected by AuthGuard (canActivate)
    await page.goto('/admin/users');

    // Guard should redirect to login
    await expect(page).toHaveURL(/\/login/);
    await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
  });

  test('route resolver prefetches data before navigation', async ({ page }) => {
    // Intercept the API call that the resolver makes
    const resolverPromise = page.waitForResponse('**/api/products/*');

    await page.goto('/products/42');

    // The resolver fetches data before the component renders
    await resolverPromise;

    // Component renders with pre-fetched data (no loading spinner)
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Product');
  });

  test('nested router-outlet renders child components', async ({ page }) => {
    await page.goto('/settings/profile');

    // Parent layout (SettingsComponent with its own router-outlet)
    await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible();
    await expect(page.getByRole('navigation', { name: 'Settings' })).toBeVisible();

    // Child route (ProfileComponent rendered inside nested router-outlet)
    await expect(page.getByRole('heading', { name: 'Profile', level: 2 })).toBeVisible();

    // Navigate to sibling child route
    await page.getByRole('link', { name: 'Security' }).click();
    await page.waitForURL('/settings/security');

    // Parent persists, child changes
    await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Security', level: 2 })).toBeVisible();
  });

  test('route parameters update component state', async ({ page }) => {
    await page.goto('/users/1');
    await expect(page.getByRole('heading')).toContainText('User #1');

    // Navigate to a different user via the URL
    await page.goto('/users/2');
    await expect(page.getByRole('heading')).toContainText('User #2');
  });

  test('query parameters drive filter behavior', async ({ page }) => {
    await page.goto('/products?category=electronics&page=2');

    await expect(page.getByRole('heading', { name: 'Electronics' })).toBeVisible();
    await expect(page.getByText('Page 2')).toBeVisible();
  });

  test('browser back navigates through Angular history', async ({ page }) => {
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

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('Angular Router navigation', () => {
  test('lazy-loaded module loads on navigation', async ({ page }) => {
    await page.goto('/');

    await page.getByRole('link', { name: 'Admin' }).click();
    await page.waitForURL('/admin');

    await expect(page.getByRole('heading', { name: 'Admin Dashboard' })).toBeVisible();
  });

  test('route guard redirects unauthorized users', async ({ page }) => {
    await page.goto('/admin/users');

    await expect(page).toHaveURL(/\/login/);
    await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
  });

  test('nested router-outlet renders child components', async ({ page }) => {
    await page.goto('/settings/profile');

    await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Profile', level: 2 })).toBeVisible();

    await page.getByRole('link', { name: 'Security' }).click();
    await page.waitForURL('/settings/security');

    await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Security', level: 2 })).toBeVisible();
  });

  test('browser back navigates through Angular history', async ({ page }) => {
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

### Tester les modules lazy-loaded

**À utiliser quand** : tu vérifies que les modules de fonctionnalités lazy-loaded d'Angular se chargent correctement quand l'utilisateur navigue vers leurs routes. Les modules lazy-loaded introduisent des requêtes réseau pour les chunks JavaScript.
**À éviter quand** : le module est chargé de façon eager -- il n'y a pas de chunk séparé à charger.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('lazy-loaded modules', () => {
  test('lazy module loads without errors', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto('/');

    // Navigate to a lazy-loaded route
    const chunkRequest = page.waitForResponse((response) =>
      response.url().includes('.js') && response.status() === 200
    );
    await page.getByRole('link', { name: 'Reports' }).click();
    await chunkRequest;

    await page.waitForURL('/reports');
    await expect(page.getByRole('heading', { name: 'Reports' })).toBeVisible();

    // No chunk loading errors
    const chunkErrors = consoleErrors.filter(
      (e) => e.includes('ChunkLoadError') || e.includes('Loading chunk')
    );
    expect(chunkErrors).toEqual([]);
  });

  test('preloaded lazy module navigates instantly', async ({ page }) => {
    await page.goto('/dashboard');

    // If preloadingStrategy is configured, the module may already be cached
    // Navigate and verify it renders without visible delay
    const startTime = Date.now();
    await page.getByRole('link', { name: 'Reports' }).click();
    await page.waitForURL('/reports');
    await expect(page.getByRole('heading', { name: 'Reports' })).toBeVisible();
    const loadTime = Date.now() - startTime;

    // Preloaded modules should render quickly (not an exact assertion, but a sanity check)
    expect(loadTime).toBeLessThan(3000);
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('lazy-loaded modules', () => {
  test('lazy module loads without errors', async ({ page }) => {
    const consoleErrors = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto('/');

    await page.getByRole('link', { name: 'Reports' }).click();
    await page.waitForURL('/reports');
    await expect(page.getByRole('heading', { name: 'Reports' })).toBeVisible();

    const chunkErrors = consoleErrors.filter(
      (e) => e.includes('ChunkLoadError') || e.includes('Loading chunk')
    );
    expect(chunkErrors).toEqual([]);
  });
});
```

### Tester indirectement les signals et les observables

**À utiliser quand** : tu vérifies que les signals Angular (`signal()`, `computed()`, `effect()`) et les observables RxJS produisent les bonnes mises à jour de l'UI. Playwright ne peut pas s'abonner aux observables ni lire directement les signals -- teste à travers le rendu.
**À éviter quand** : tu testes la logique de transformation d'observables de façon isolée -- utilise Jasmine/Jest avec Angular TestBed pour cela.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('signals (tested through UI)', () => {
  test('signal-based counter updates the DOM', async ({ page }) => {
    await page.goto('/counter');

    // The counter uses signal() internally
    await expect(page.getByTestId('count')).toHaveText('0');

    await page.getByRole('button', { name: 'Increment' }).click();
    await expect(page.getByTestId('count')).toHaveText('1');

    await page.getByRole('button', { name: 'Increment' }).click();
    await page.getByRole('button', { name: 'Increment' }).click();
    await expect(page.getByTestId('count')).toHaveText('3');

    await page.getByRole('button', { name: 'Reset' }).click();
    await expect(page.getByTestId('count')).toHaveText('0');
  });

  test('computed signal updates derived values', async ({ page }) => {
    await page.goto('/cart');

    // Cart total is a computed() signal derived from items
    await expect(page.getByTestId('cart-total')).toHaveText('$0.00');

    // Add item (updates the items signal, which updates the computed total)
    await page.goto('/products');
    await page.getByRole('listitem')
      .filter({ hasText: '$29.99' })
      .getByRole('button', { name: 'Add to cart' })
      .click();

    await page.getByRole('link', { name: 'Cart' }).click();
    await expect(page.getByTestId('cart-total')).toHaveText('$29.99');
  });
});

test.describe('observables (tested through UI)', () => {
  test('real-time data stream updates the UI', async ({ page }) => {
    await page.goto('/dashboard');

    // The component subscribes to an observable that emits stock prices
    const priceElement = page.getByTestId('stock-price');
    await expect(priceElement).toBeVisible();

    // Get the initial value
    const initialPrice = await priceElement.textContent();

    // Wait for the observable to emit a new value
    // Use polling assertion instead of waitForTimeout
    await expect(priceElement).not.toHaveText(initialPrice!, { timeout: 10_000 });
  });

  test('search with debounceTime observable', async ({ page }) => {
    await page.goto('/search');

    const apiCalls: string[] = [];
    await page.route('**/api/search*', async (route) => {
      apiCalls.push(route.request().url());
      await route.continue();
    });

    // Type quickly -- the observable's debounceTime should batch
    await page.getByRole('textbox', { name: 'Search' }).pressSequentially('angular', {
      delay: 50,
    });

    await expect(page.getByRole('listitem')).toHaveCount(5);

    // debounceTime should prevent a request per keystroke
    expect(apiCalls.length).toBeLessThanOrEqual(2);
  });

  test('switchMap cancels previous requests on new input', async ({ page }) => {
    await page.goto('/search');

    // Type one query
    await page.getByRole('textbox', { name: 'Search' }).fill('first query');

    // Immediately type a different query before results come back
    await page.getByRole('textbox', { name: 'Search' }).fill('second query');

    // Results should match the second query, not the first
    await expect(page.getByRole('listitem').first()).toContainText(/second query/i);
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('signals (tested through UI)', () => {
  test('signal-based counter updates the DOM', async ({ page }) => {
    await page.goto('/counter');

    await expect(page.getByTestId('count')).toHaveText('0');

    await page.getByRole('button', { name: 'Increment' }).click();
    await expect(page.getByTestId('count')).toHaveText('1');

    await page.getByRole('button', { name: 'Increment' }).click();
    await page.getByRole('button', { name: 'Increment' }).click();
    await expect(page.getByTestId('count')).toHaveText('3');

    await page.getByRole('button', { name: 'Reset' }).click();
    await expect(page.getByTestId('count')).toHaveText('0');
  });
});

test.describe('observables (tested through UI)', () => {
  test('search with debounceTime observable', async ({ page }) => {
    await page.goto('/search');

    const apiCalls = [];
    await page.route('**/api/search*', async (route) => {
      apiCalls.push(route.request().url());
      await route.continue();
    });

    await page.getByRole('textbox', { name: 'Search' }).pressSequentially('angular', {
      delay: 50,
    });

    await expect(page.getByRole('listitem')).toHaveCount(5);
    expect(apiCalls.length).toBeLessThanOrEqual(2);
  });
});
```

## Conseils spécifiques au framework

### Considérations sur Zone.js

Angular utilise Zone.js pour détecter les opérations asynchrones et déclencher la détection de changements. Playwright ne dépend pas de Zone.js -- il interagit directement avec le DOM. Zone.js peut toutefois influencer le comportement des tests :

1. **Timing de la détection de changements** : après les interactions utilisateur (click, fill), Angular planifie la détection de changements via Zone.js. L'auto-waiting de Playwright s'en charge -- `expect(locator).toHaveText('new value')` réessaie jusqu'à ce que le DOM soit mis à jour.

2. **Angular zoneless** : la détection de changements zoneless est stable depuis Angular 20.2 (`provideZonelessChangeDetection()`) et devient le mode par défaut des nouvelles applications à partir d'Angular 21. Les tests fonctionnent de façon identique avec Playwright, car Playwright attend les changements du DOM, pas les ticks de Zone.js.

3. **Opérations asynchrones de longue durée** : si ton application utilise `setInterval` ou des observables de longue durée, Zone.js maintient Angular dans un état « not stable ». Cela n'affecte pas Playwright (contrairement à Protractor, qui attendait la stabilité d'Angular). Playwright interagit simplement avec ce qui est à l'écran.

### Checklist de migration de Protractor vers Playwright

| Protractor | Équivalent Playwright |
|---|---|
| `element(by.css('.btn'))` | `page.locator('.btn')` -- mais préfère `page.getByRole('button', { name: '...' })` |
| `element(by.id('login'))` | `page.getByTestId('login')` ou `page.getByRole(...)` |
| `element(by.buttonText('Submit'))` | `page.getByRole('button', { name: 'Submit' })` |
| `element(by.model('user.name'))` | `page.getByLabel('Name')` -- Playwright ne peut pas lire ng-model |
| `element(by.binding('user.name'))` | `page.getByText(expectedValue)` -- teste le rendu |
| `element(by.repeater('item in items'))` | `page.getByRole('listitem')` ou `page.getByTestId(...)` |
| `browser.waitForAngular()` | Inutile -- Playwright fait de l'auto-waiting ; supprime toutes les occurrences |
| `browser.sleep(3000)` | `await expect(locator).toBeVisible()` -- n'utilise jamais d'attentes arbitraires |
| `browser.get('/path')` | `await page.goto('/path')` |
| `protractor.ExpectedConditions` | `await expect(locator).toBeVisible/toBeHidden/toHaveText(...)` |

### Configurations de build Angular

| Scénario | Commande de build | Notes |
|---|---|---|
| Développement local | `npx ng serve` | Rebuild rapide, source maps, pas d'optimisation |
| CI (build de production) | `npx ng build && npx http-server dist/your-app/browser -p 4200 -s` | Teste le vrai bundle de production |
| CI (SSR/Universal) | `npx ng build --ssr && node dist/your-app/server/server.mjs` | Teste Angular rendu côté serveur |
| Environnement de staging | Pas de `webServer` nécessaire | Pointe `baseURL` vers l'URL de staging |

Le flag `-s` de `http-server` active le fallback SPA (renvoie `index.html` pour toutes les routes), indispensable au bon fonctionnement d'Angular Router.

### Conteneur CDK Overlay

Angular Material et Angular CDK rendent les overlays (dialogs, menus, selects, autocompletes) dans un conteneur spécial en dehors de l'arbre des composants. Playwright voit ces overlays dans le document -- aucun traitement particulier n'est nécessaire. Utilise les locators standards basés sur les rôles :

```typescript
// CDK overlays render into <div class="cdk-overlay-container"> at the body level
// Playwright sees them as regular DOM elements
const dialog = page.getByRole('dialog');
const menu = page.getByRole('menu');
const listbox = page.getByRole('listbox');
```

### Tester avec Angular SSR (Universal)

Si ton application Angular utilise le rendu côté serveur :

```typescript
// playwright.config.ts (SSR-specific)
webServer: {
  command: process.env.CI
    ? 'npx ng build --ssr && node dist/your-app/server/server.mjs'
    : 'npx ng serve --ssr',
  url: 'http://localhost:4200',
  reuseExistingServer: !process.env.CI,
  timeout: 180_000, // SSR builds are slower
},
```

Teste les problèmes d'hydratation de la même manière qu'avec les autres frameworks SSR :

```typescript
test('no hydration errors after SSR', async ({ page }) => {
  const errors: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error' && msg.text().includes('hydration')) {
      errors.push(msg.text());
    }
  });

  await page.goto('/');
  await page.getByRole('button', { name: 'Get started' }).click();

  expect(errors).toEqual([]);
});
```

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| `page.locator('[_ngcontent-abc123]')` | Les attributs de style scopé d'Angular sont aléatoires et changent à chaque build | Utilise `getByRole`, `getByLabel`, `getByText`, `getByTestId` |
| `page.locator('[ng-reflect-model="value"]')` | Les attributs `ng-reflect-*` n'existent qu'en mode dev ; ils sont supprimés en production | Teste la valeur rendue : `expect(input).toHaveValue('value')` |
| `page.locator('app-my-component')` | Les sélecteurs de composants Angular sont des détails d'implémentation | Cible le contenu rendu par le composant avec des locators sémantiques |
| `page.locator('.mat-mdc-button')` | Les noms de classes d'Angular Material changent entre les versions (migration MDC) | `page.getByRole('button', { name: 'Submit' })` |
| `page.evaluate(() => (window as any).ng)` pour accéder aux internals d'Angular | Dépend du mode debug ; indisponible dans les builds de production | Teste à travers le DOM ; n'accède jamais au runtime Angular |
| `await page.waitForTimeout(500)` après un clic sur un bouton | Le timing de la détection de changements de Zone.js varie ; les attentes arbitraires sont fragiles | `await expect(locator).toHaveText('expected value')` réessaie automatiquement |
| `browser.waitForAngular()` (pattern Protractor) | N'existe pas dans Playwright ; inutile -- Playwright fait de l'auto-waiting | Supprime-le entièrement ; utilise des assertions web-first |
| Tester des services Angular en les injectant via `page.evaluate` | Les services ne sont pas accessibles depuis la console du navigateur en production | Teste les services indirectement via l'UI qu'ils alimentent ; tests unitaires avec TestBed |
| Utiliser `ng serve` en CI | Le serveur de développement est plus lent, inclut du code de debug et peut masquer des bugs propres à la production | Utilise `ng build && http-server` en CI |
| Ne pas tester les composants CDK overlay (dialogs, selects, menus) | Ce sont les parties les plus interactives de l'application ; les bugs y sont très visibles | Teste les overlays avec des locators basés sur les rôles ; ils sont rendus dans le DOM normal |

## Voir aussi

- [core/locators.md](locators.md) -- stratégies de locators pour Angular Material et les composants CDK
- [core/assertions-and-waiting.md](assertions-and-waiting.md) -- assertions avec auto-waiting qui remplacent waitForAngular de Protractor
- [core/forms-and-validation.md](forms-and-validation.md) -- patterns de test de formulaires réactifs et template-driven
- [core/accessibility.md](accessibility.md) -- tests d'accessibilité des composants Angular Material
- [core/authentication.md](authentication.md) -- authentification avec les route guards Angular
- [migration/from-selenium.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/migration/from-selenium.md) -- patterns de migration applicables à Protractor (Protractor est construit sur Selenium)
- [core/test-architecture.md](test-architecture.md) -- quand utiliser l'E2E plutôt que des tests unitaires avec Angular TestBed
- [ci/ci-github-actions.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/ci-github-actions.md) -- configuration de la CI avec cache du build Angular
