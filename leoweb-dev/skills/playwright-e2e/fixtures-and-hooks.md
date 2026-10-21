# Fixtures et hooks

> **Quand l'utiliser** : Chaque fois que les tests ont besoin d'un setup partagé, d'un teardown, de ressources réutilisables ou d'un contexte configurable. Les fixtures sont la fonctionnalité phare de Playwright : préfère-les aux hooks dans toutes les situations où les deux pourraient convenir.

## Référence rapide

| Mécanisme | Portée | Nettoyage garanti ? | Sûr en parallèle ? | À utiliser pour |
|---|---|---|---|---|
| Fixture `test.extend()` | par test | Oui (via le callback `use()`) | Oui | La plupart des besoins de setup/teardown |
| Fixture à portée worker | par worker | Oui | Oui (isolée par worker) | Ressources coûteuses : connexions BDD, état d'authentification |
| Auto fixture | par test ou par worker | Oui | Oui | Effets de bord qui doivent toujours s'exécuter : blocage des analytics, logging |
| `beforeEach` / `afterEach` | par test | Non (`afterEach` ignoré en cas de crash) | Oui | Setup simple et ponctuel sans besoin de nettoyage |
| `beforeAll` / `afterAll` | par worker | Non (`afterAll` ignoré en cas de crash) | Dangereux si l'état partagé est muté | Setup unique par worker sans besoin de nettoyage |

**La règle** : Si ça nécessite un nettoyage, utilise une fixture. Si ça n'en nécessite pas et que c'est simple, un hook est acceptable. Dans le doute, utilise une fixture.

## Patterns

### 1. Fixture de test personnalisée

**À utiliser quand** : Les tests ont besoin d'une ressource avec un setup et un teardown garantis.
**À éviter quand** : Le setup tient en une seule ligne sans teardown : un `beforeEach` suffit.

Les fixtures utilisent un callback `use()`. Tout ce qui précède `use()` est du setup ; tout ce qui suit est du teardown. Le teardown s'exécute même si le test plante.

**TypeScript**
```typescript
// fixtures.ts
import { test as base, expect } from '@playwright/test';

type TodoFixtures = {
  todoPage: TodoPage;
};

class TodoPage {
  constructor(private page: import('@playwright/test').Page) {}

  async addTodo(text: string) {
    await this.page.getByPlaceholder('What needs to be done?').fill(text);
    await this.page.getByPlaceholder('What needs to be done?').press('Enter');
  }

  async todos() {
    return this.page.getByTestId('todo-item');
  }
}

export const test = base.extend<TodoFixtures>({
  todoPage: async ({ page }, use) => {
    // Setup
    await page.goto('/todos');
    const todoPage = new TodoPage(page);

    // Hand the fixture to the test
    await use(todoPage);

    // Teardown — runs even if test fails or crashes
    await page.evaluate(() => localStorage.clear());
  },
});

export { expect };
```

```typescript
// todos.spec.ts
import { test, expect } from './fixtures';

test('add a todo item', async ({ todoPage, page }) => {
  await todoPage.addTodo('Buy milk');
  await expect(await todoPage.todos()).toHaveCount(1);
});
```

**JavaScript**
```javascript
// fixtures.js
const { test: base, expect } = require('@playwright/test');

class TodoPage {
  constructor(page) {
    this.page = page;
  }

  async addTodo(text) {
    await this.page.getByPlaceholder('What needs to be done?').fill(text);
    await this.page.getByPlaceholder('What needs to be done?').press('Enter');
  }

  async todos() {
    return this.page.getByTestId('todo-item');
  }
}

const test = base.extend({
  todoPage: async ({ page }, use) => {
    await page.goto('/todos');
    const todoPage = new TodoPage(page);
    await use(todoPage);
    await page.evaluate(() => localStorage.clear());
  },
});

module.exports = { test, expect };
```

### 2. Fixtures à portée worker

**À utiliser quand** : Une ressource est coûteuse à créer et peut être partagée sans risque entre les tests d'un même worker (connexions à la base de données, tokens d'authentification, assets compilés).
**À éviter quand** : Les tests mutent la ressource : chaque test doit en recevoir sa propre copie.

Les fixtures à portée worker sont créées une fois par processus worker, et non une fois par test. Elles ne peuvent pas dépendre de fixtures à portée test (`page`, `context`, `request`).

**TypeScript**
```typescript
// fixtures.ts
import { test as base } from '@playwright/test';

type WorkerFixtures = {
  dbConnection: DatabaseClient;
  authToken: string;
};

export const test = base.extend<{}, WorkerFixtures>({
  dbConnection: [async ({}, use) => {
    const db = await DatabaseClient.connect(process.env.DB_URL!);
    await use(db);
    await db.disconnect();
  }, { scope: 'worker' }],

  authToken: [async ({}, use) => {
    const response = await fetch(`${process.env.API_URL}/auth/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: 'test-user',
        password: process.env.TEST_PASSWORD,
      }),
    });
    const { token } = await response.json();
    await use(token);
    // No teardown needed — token expires on its own
  }, { scope: 'worker' }],
});

export { expect } from '@playwright/test';
```

**JavaScript**
```javascript
// fixtures.js
const { test: base, expect } = require('@playwright/test');

const test = base.extend({
  dbConnection: [async ({}, use) => {
    const db = await DatabaseClient.connect(process.env.DB_URL);
    await use(db);
    await db.disconnect();
  }, { scope: 'worker' }],

  authToken: [async ({}, use) => {
    const response = await fetch(`${process.env.API_URL}/auth/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: 'test-user',
        password: process.env.TEST_PASSWORD,
      }),
    });
    const { token } = await response.json();
    await use(token);
  }, { scope: 'worker' }],
});

module.exports = { test, expect };
```

**Important** : Le second paramètre de type dans `base.extend<TestFixtures, WorkerFixtures>` est réservé aux fixtures à portée worker. Place toujours les fixtures worker dans le second argument générique.

### 3. Auto fixtures

**À utiliser quand** : Quelque chose doit s'exécuter pour chaque test sans être demandé explicitement : blocage des analytics, capture des erreurs console, injection de feature flags.
**À éviter quand** : Des tests doivent pouvoir s'en dispenser. Les auto fixtures s'exécutent toujours ; il n'existe pas d'échappatoire par test.

**TypeScript**
```typescript
// fixtures.ts
import { test as base, expect } from '@playwright/test';

type AutoFixtures = {
  blockAnalytics: void;
  consoleErrors: string[];
};

export const test = base.extend<AutoFixtures>({
  // Blocks all analytics/tracking requests in every test
  blockAnalytics: [async ({ page }, use) => {
    await page.route(/google-analytics|segment|hotjar|mixpanel/, (route) =>
      route.abort()
    );
    await use();
  }, { auto: true }],

  // Captures console errors — fail test if unexpected errors appear
  consoleErrors: [async ({ page }, use) => {
    const errors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });
    await use(errors);
    // Teardown: assert no unexpected console errors
    const unexpected = errors.filter(
      (e) => !e.includes('Expected warning')
    );
    if (unexpected.length > 0) {
      throw new Error(
        `Unexpected console errors:\n${unexpected.join('\n')}`
      );
    }
  }, { auto: true }],
});

export { expect };
```

**JavaScript**
```javascript
// fixtures.js
const { test: base, expect } = require('@playwright/test');

const test = base.extend({
  blockAnalytics: [async ({ page }, use) => {
    await page.route(/google-analytics|segment|hotjar|mixpanel/, (route) =>
      route.abort()
    );
    await use();
  }, { auto: true }],

  consoleErrors: [async ({ page }, use) => {
    const errors = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });
    await use(errors);
    const unexpected = errors.filter(
      (e) => !e.includes('Expected warning')
    );
    if (unexpected.length > 0) {
      throw new Error(
        `Unexpected console errors:\n${unexpected.join('\n')}`
      );
    }
  }, { auto: true }],
});

module.exports = { test, expect };
```

Les auto fixtures peuvent aussi être à portée worker avec `{ auto: true, scope: 'worker' }`, par exemple pour démarrer un serveur de dev une fois par worker.

### 4. Composition de fixtures avec `mergeTests()`

**À utiliser quand** : Tu as plusieurs fichiers de fixtures (fixtures d'authentification, d'API, d'UI) et que les tests en ont besoin de plusieurs.
**À éviter quand** : Tu n'as qu'un seul fichier de fixtures. Ne fais pas de sur-ingénierie.

`mergeTests()` combine plusieurs objets `test` étendus en un seul. Chaque fichier de fixtures définit ses propres responsabilités.

**TypeScript**
```typescript
// fixtures/auth.ts
import { test as base } from '@playwright/test';

type AuthFixtures = {
  authenticatedPage: import('@playwright/test').Page;
};

export const test = base.extend<AuthFixtures>({
  authenticatedPage: async ({ page }, use) => {
    await page.goto('/login');
    await page.getByLabel('Email').fill('user@example.com');
    await page.getByLabel('Password').fill('password123');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await page.waitForURL('/dashboard');
    await use(page);
  },
});
```

```typescript
// fixtures/api.ts
import { test as base, APIRequestContext } from '@playwright/test';

type ApiFixtures = {
  apiClient: APIRequestContext;
};

export const test = base.extend<ApiFixtures>({
  apiClient: async ({ playwright }, use) => {
    const api = await playwright.request.newContext({
      baseURL: 'https://api.example.com',
      extraHTTPHeaders: { Authorization: `Bearer ${process.env.API_TOKEN}` },
    });
    await use(api);
    await api.dispose();
  },
});
```

```typescript
// fixtures/index.ts
import { mergeTests } from '@playwright/test';
import { test as authTest } from './auth';
import { test as apiTest } from './api';

export const test = mergeTests(authTest, apiTest);
export { expect } from '@playwright/test';
```

```typescript
// dashboard.spec.ts
import { test, expect } from './fixtures';

test('dashboard loads user data', async ({ authenticatedPage, apiClient }) => {
  // Both fixtures are available
  const data = await apiClient.get('/users/me');
  await expect(authenticatedPage.getByRole('heading')).toContainText('Dashboard');
});
```

**JavaScript**
```javascript
// fixtures/auth.js
const { test: base } = require('@playwright/test');

const test = base.extend({
  authenticatedPage: async ({ page }, use) => {
    await page.goto('/login');
    await page.getByLabel('Email').fill('user@example.com');
    await page.getByLabel('Password').fill('password123');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await page.waitForURL('/dashboard');
    await use(page);
  },
});

module.exports = { test };
```

```javascript
// fixtures/api.js
const { test: base } = require('@playwright/test');

const test = base.extend({
  apiClient: async ({ playwright }, use) => {
    const api = await playwright.request.newContext({
      baseURL: 'https://api.example.com',
      extraHTTPHeaders: { Authorization: `Bearer ${process.env.API_TOKEN}` },
    });
    await use(api);
    await api.dispose();
  },
});

module.exports = { test };
```

```javascript
// fixtures/index.js
const { mergeTests } = require('@playwright/test');
const { test: authTest } = require('./auth');
const { test: apiTest } = require('./api');

const test = mergeTests(authTest, apiTest);
module.exports = { test, expect: require('@playwright/test').expect };
```

### 5. Fixtures paramétrées (option fixtures)

**À utiliser quand** : Le comportement d'une fixture doit être configurable par projet ou par bloc describe (locale, viewport, rôle utilisateur, feature flags).
**À éviter quand** : La valeur ne change jamais : mets-la simplement en dur dans la fixture.

Les option fixtures sont déclarées avec `{ option: true }` et peuvent être surchargées dans `playwright.config` sous `use` ou avec `test.use()` dans les fichiers de test.

**TypeScript**
```typescript
// fixtures.ts
import { test as base, expect } from '@playwright/test';

type OptionFixtures = {
  userRole: 'admin' | 'editor' | 'viewer';
  locale: string;
};

type DerivedFixtures = {
  authenticatedPage: import('@playwright/test').Page;
};

export const test = base.extend<OptionFixtures & DerivedFixtures>({
  // Option fixtures — configurable per project or describe block
  userRole: ['viewer', { option: true }],
  locale: ['en-US', { option: true }],

  // Derived fixture — uses the option values
  authenticatedPage: async ({ page, userRole, locale }, use) => {
    await page.goto(`/login?locale=${locale}`);
    const credentials = {
      admin: { email: 'admin@test.com', password: 'admin-pass' },
      editor: { email: 'editor@test.com', password: 'editor-pass' },
      viewer: { email: 'viewer@test.com', password: 'viewer-pass' },
    };
    const { email, password } = credentials[userRole];
    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Password').fill(password);
    await page.getByRole('button', { name: 'Sign in' }).click();
    await use(page);
  },
});

export { expect };
```

```typescript
// playwright.config.ts (override per project)
import { defineConfig } from '@playwright/test';

export default defineConfig({
  projects: [
    {
      name: 'admin-tests',
      testDir: './tests/admin',
      use: { userRole: 'admin', locale: 'en-US' },
    },
    {
      name: 'viewer-tests',
      testDir: './tests/viewer',
      use: { userRole: 'viewer', locale: 'fr-FR' },
    },
  ],
});
```

```typescript
// admin-settings.spec.ts (override per describe block)
import { test, expect } from './fixtures';

test.describe('admin settings', () => {
  test.use({ userRole: 'admin' });

  test('can access settings page', async ({ authenticatedPage }) => {
    await authenticatedPage.goto('/settings');
    await expect(authenticatedPage.getByRole('heading')).toHaveText('Admin Settings');
  });
});
```

**JavaScript**
```javascript
// fixtures.js
const { test: base, expect } = require('@playwright/test');

const test = base.extend({
  userRole: ['viewer', { option: true }],
  locale: ['en-US', { option: true }],

  authenticatedPage: async ({ page, userRole, locale }, use) => {
    await page.goto(`/login?locale=${locale}`);
    const credentials = {
      admin: { email: 'admin@test.com', password: 'admin-pass' },
      editor: { email: 'editor@test.com', password: 'editor-pass' },
      viewer: { email: 'viewer@test.com', password: 'viewer-pass' },
    };
    const { email, password } = credentials[userRole];
    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Password').fill(password);
    await page.getByRole('button', { name: 'Sign in' }).click();
    await use(page);
  },
});

module.exports = { test, expect };
```

### 6. Dépendances entre fixtures

**À utiliser quand** : Une fixture a besoin du résultat d'une autre fixture. Playwright résout automatiquement le graphe de dépendances.
**À éviter quand** : Tu es tenté d'imbriquer des fixtures sur plus de 3 niveaux : aplatis plutôt la conception.

Demande les fixtures par leur nom dans le premier argument déstructuré. Playwright gère l'ordre et le cycle de vie.

**TypeScript**
```typescript
// fixtures.ts
import { test as base, expect } from '@playwright/test';

type Fixtures = {
  apiContext: import('@playwright/test').APIRequestContext;
  testUser: { id: string; email: string };
  userPage: import('@playwright/test').Page;
};

export const test = base.extend<Fixtures>({
  apiContext: async ({ playwright }, use) => {
    const ctx = await playwright.request.newContext({
      baseURL: process.env.API_URL,
    });
    await use(ctx);
    await ctx.dispose();
  },

  // Depends on apiContext — Playwright creates apiContext first
  testUser: async ({ apiContext }, use) => {
    const response = await apiContext.post('/test/users', {
      data: { email: `user-${Date.now()}@test.com`, role: 'editor' },
    });
    const user = await response.json();
    await use(user);
    // Teardown: delete the test user
    await apiContext.delete(`/test/users/${user.id}`);
  },

  // Depends on page AND testUser — both are ready before this runs
  userPage: async ({ page, testUser }, use) => {
    await page.goto('/login');
    await page.getByLabel('Email').fill(testUser.email);
    await page.getByLabel('Password').fill('default-test-password');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await page.waitForURL('/dashboard');
    await use(page);
  },
});

export { expect };
```

**JavaScript**
```javascript
// fixtures.js
const { test: base, expect } = require('@playwright/test');

const test = base.extend({
  apiContext: async ({ playwright }, use) => {
    const ctx = await playwright.request.newContext({
      baseURL: process.env.API_URL,
    });
    await use(ctx);
    await ctx.dispose();
  },

  testUser: async ({ apiContext }, use) => {
    const response = await apiContext.post('/test/users', {
      data: { email: `user-${Date.now()}@test.com`, role: 'editor' },
    });
    const user = await response.json();
    await use(user);
    await apiContext.delete(`/test/users/${user.id}`);
  },

  userPage: async ({ page, testUser }, use) => {
    await page.goto('/login');
    await page.getByLabel('Email').fill(testUser.email);
    await page.getByLabel('Password').fill('default-test-password');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await page.waitForURL('/dashboard');
    await use(page);
  },
});

module.exports = { test, expect };
```

Le teardown s'exécute dans l'ordre inverse des dépendances : `userPage` est démantelée en premier, puis `testUser` (qui supprime l'utilisateur), puis `apiContext`.

### 7. Surcharger les fixtures intégrées

**À utiliser quand** : Chaque test a besoin de la même modification de `page`, `context` ou `browser` : en-têtes personnalisés, viewport, locale, blocage de routes.
**À éviter quand** : Seuls certains tests ont besoin de la surcharge. Utilise plutôt une nouvelle fixture nommée pour garder le `page` par défaut disponible.

**TypeScript**
```typescript
// fixtures.ts
import { test as base, expect } from '@playwright/test';

export const test = base.extend({
  // Override the built-in context fixture to add custom headers
  context: async ({ browser }, use) => {
    const context = await browser.newContext({
      extraHTTPHeaders: {
        'X-Test-ID': `test-${Date.now()}`,
        'Accept-Language': 'en-US',
      },
      permissions: ['geolocation'],
      geolocation: { latitude: 37.7749, longitude: -122.4194 },
    });
    await use(context);
    await context.close();
  },

  // Override the built-in page fixture to block third-party scripts
  page: async ({ context }, use) => {
    const page = await context.newPage();
    await page.route('**/*.{png,jpg,jpeg,gif,svg}', (route) => route.abort());
    await use(page);
    // No need to close page — context.close() handles it
  },
});

export { expect };
```

**JavaScript**
```javascript
// fixtures.js
const { test: base, expect } = require('@playwright/test');

const test = base.extend({
  context: async ({ browser }, use) => {
    const context = await browser.newContext({
      extraHTTPHeaders: {
        'X-Test-ID': `test-${Date.now()}`,
        'Accept-Language': 'en-US',
      },
      permissions: ['geolocation'],
      geolocation: { latitude: 37.7749, longitude: -122.4194 },
    });
    await use(context);
    await context.close();
  },

  page: async ({ context }, use) => {
    const page = await context.newPage();
    await page.route('**/*.{png,jpg,jpeg,gif,svg}', (route) => route.abort());
    await use(page);
  },
});

module.exports = { test, expect };
```

### 8. beforeEach / afterEach : quand les hooks sont acceptables

**À utiliser quand** : Setup simple et sans état, sans teardown nécessaire. La navigation vers une URL de départ en est l'exemple canonique.
**À éviter quand** : Le setup crée quelque chose qui doit être nettoyé. Utilise une fixture à la place.

**TypeScript**
```typescript
// acceptable-hooks.spec.ts
import { test, expect } from '@playwright/test';

// Acceptable: simple navigation, no teardown needed
test.beforeEach(async ({ page }) => {
  await page.goto('/dashboard');
});

test('shows welcome message', async ({ page }) => {
  await expect(page.getByRole('heading')).toHaveText('Welcome');
});

test('shows navigation sidebar', async ({ page }) => {
  await expect(page.getByRole('navigation')).toBeVisible();
});
```

**JavaScript**
```javascript
// acceptable-hooks.spec.js
const { test, expect } = require('@playwright/test');

test.beforeEach(async ({ page }) => {
  await page.goto('/dashboard');
});

test('shows welcome message', async ({ page }) => {
  await expect(page.getByRole('heading')).toHaveText('Welcome');
});

test('shows navigation sidebar', async ({ page }) => {
  await expect(page.getByRole('navigation')).toBeVisible();
});
```

Les hooks peuvent utiliser des fixtures dans leur liste d'arguments : `beforeEach(async ({ page, context })` fonctionne. Mais les hooks ne peuvent pas *définir* de fixtures.

### 9. beforeAll / afterAll : hooks au niveau worker

**À utiliser quand** : Setup unique partagé par tous les tests d'un fichier, sans besoin de nettoyage, comme journaliser un diagnostic ou vérifier une précondition.
**À éviter quand** : Tu crées des ressources qui nécessitent un nettoyage (utilise des fixtures à portée worker) ou tu stockes un état mutable (cela casse le parallélisme).

**TypeScript**
```typescript
// health-check.spec.ts
import { test, expect } from '@playwright/test';

// Good: read-only check, no mutable state
test.beforeAll(async ({ request }) => {
  const response = await request.get('/api/health');
  expect(response.ok()).toBeTruthy();
});

test('homepage loads', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/My App/);
});
```

**JavaScript**
```javascript
// health-check.spec.js
const { test, expect } = require('@playwright/test');

test.beforeAll(async ({ request }) => {
  const response = await request.get('/api/health');
  expect(response.ok()).toBeTruthy();
});

test('homepage loads', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/My App/);
});
```

`beforeAll` / `afterAll` ne reçoivent que les fixtures à portée worker : `request`, `browser` et les éventuelles fixtures worker personnalisées. Ils ne reçoivent **pas** `page` ni `context` (qui sont par test).

### 10. Fixtures typées en TypeScript

Définis toujours une interface pour tes fixtures. Cela te donne l'autocomplétion, détecte les fautes de frappe à la compilation et documente le contrat de la fixture.

**TypeScript**
```typescript
// fixtures.ts
import { test as base, expect, Page, APIRequestContext } from '@playwright/test';

// Define fixture types explicitly
interface TestFixtures {
  adminPage: Page;
  editorPage: Page;
  apiClient: APIRequestContext;
}

interface WorkerFixtures {
  sharedToken: string;
}

export const test = base.extend<TestFixtures, WorkerFixtures>({
  sharedToken: [async ({}, use) => {
    const res = await fetch(`${process.env.API_URL}/auth/service-token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ secret: process.env.SERVICE_SECRET }),
    });
    const { token } = await res.json();
    await use(token);
  }, { scope: 'worker' }],

  apiClient: async ({ playwright, sharedToken }, use) => {
    const ctx = await playwright.request.newContext({
      baseURL: process.env.API_URL,
      extraHTTPHeaders: { Authorization: `Bearer ${sharedToken}` },
    });
    await use(ctx);
    await ctx.dispose();
  },

  adminPage: async ({ browser }, use) => {
    const ctx = await browser.newContext({ storageState: 'auth/admin.json' });
    const page = await ctx.newPage();
    await use(page);
    await ctx.close();
  },

  editorPage: async ({ browser }, use) => {
    const ctx = await browser.newContext({ storageState: 'auth/editor.json' });
    const page = await ctx.newPage();
    await use(page);
    await ctx.close();
  },
});

export { expect };
```

### 11. Interrompre un test depuis une fixture ou une route (`test.abort()`, Playwright 1.60+)

**À utiliser quand** : Une fixture, un hook ou un handler de route détecte une précondition irrécupérable (un backend requis est down, une étape de seed a échoué, une route a reçu une requête inattendue) et continuer ne produirait qu'un échec en aval déroutant.
**À éviter quand** : Le corps du test peut lui-même asserter la condition. Utilise un `expect()` classique à cet endroit. `test.abort()` est destiné au code qui s'exécute *en dehors* du corps du test, là où tu ne peux pas utiliser `expect`.

Playwright 1.60 ajoute `test.abort(message?)`, qui arrête immédiatement le test en cours d'exécution. Contrairement à `test.skip()`, il marque le test comme échoué/interrompu avec ton message, et contrairement à un `throw`, il fonctionne proprement depuis les fixtures et les handlers de route.

**TypeScript**
```typescript
import { test as base, expect } from '@playwright/test';

export const test = base.extend({
  // Abort early if the environment isn't ready, instead of letting every
  // assertion fail with a cryptic message.
  seededDb: async ({}, use) => {
    const res = await fetch(`${process.env.API_URL}/health/db`);
    if (!res.ok) {
      base.abort(`Database not reachable (${res.status}) — aborting test`);
    }
    await use(true);
  },
});

test('checkout works on a healthy backend', async ({ page, seededDb }) => {
  await page.goto('/checkout');
  await expect(page.getByRole('heading', { name: 'Checkout' })).toBeVisible();
});

test('abort from a route handler on an unexpected request', async ({ page }) => {
  await page.route('**/api/**', (route) => {
    if (route.request().url().includes('/api/forbidden')) {
      test.abort('Unexpected call to forbidden endpoint');
    }
    return route.continue();
  });

  await page.goto('/dashboard');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('abort from a route handler on an unexpected request', async ({ page }) => {
  await page.route('**/api/**', (route) => {
    if (route.request().url().includes('/api/forbidden')) {
      test.abort('Unexpected call to forbidden endpoint');
    }
    return route.continue();
  });

  await page.goto('/dashboard');
});
```

> `test.abort()` termine le test immédiatement : le code qui suit dans le même handler ne s'exécutera pas. Utilise-le pour les conditions *irrécupérables* ; pour « ce test ne s'applique pas ici », préfère `test.skip()`.

## Guide de décision

```
I need to set up something before tests run.
│
├── Does it create a resource that MUST be cleaned up?
│   │
│   ├── YES → Use a fixture (setup before `use()`, teardown after)
│   │   │
│   │   ├── Is the resource expensive and safe to share across tests?
│   │   │   ├── YES → Worker-scoped fixture: { scope: 'worker' }
│   │   │   └── NO  → Test-scoped fixture (default)
│   │   │
│   │   ├── Should every test get this automatically?
│   │   │   ├── YES → Auto fixture: { auto: true }
│   │   │   └── NO  → Regular fixture (test declares it in args)
│   │   │
│   │   └── Should the value be configurable per project?
│   │       ├── YES → Option fixture: { option: true }
│   │       └── NO  → Regular fixture with hardcoded setup
│   │
│   └── NO → Hook is acceptable
│       │
│       ├── Per-test setup?
│       │   └── beforeEach
│       │
│       └── One-time per worker?
│           └── beforeAll (but only for read-only / diagnostic checks)
│
└── Am I combining fixtures from multiple domains?
    └── YES → mergeTests() from separate fixture files
```

## Anti-patterns

### 1. État mutable global dans `beforeAll`

```typescript
// BAD: Mutable state shared across parallel tests
let testUser: { id: string; email: string };

test.beforeAll(async ({ request }) => {
  const res = await request.post('/api/users', { data: { email: 'shared@test.com' } });
  testUser = await res.json(); // Shared mutable state!
});

test.afterAll(async ({ request }) => {
  await request.delete(`/api/users/${testUser.id}`); // Cleanup may not run
});

test('test 1', async ({ page }) => {
  // Uses testUser — but what if another worker also has a testUser?
});
```

```typescript
// GOOD: Worker-scoped fixture — isolated per worker, guaranteed cleanup
import { test as base } from '@playwright/test';

export const test = base.extend<{ testUser: { id: string; email: string } }>({
  testUser: async ({ request }, use) => {
    const res = await request.post('/api/users', {
      data: { email: `user-${Date.now()}@test.com` },
    });
    const user = await res.json();
    await use(user);
    await request.delete(`/api/users/${user.id}`);
  },
});
```

### 2. Nettoyage dans `afterEach` au lieu du teardown de fixture

```typescript
// BAD: afterEach is not guaranteed to run on crash
test.beforeEach(async ({ page }) => {
  await page.evaluate(() => localStorage.setItem('debug', 'true'));
});

test.afterEach(async ({ page }) => {
  // This might NOT run if the test crashes or times out
  await page.evaluate(() => localStorage.clear());
});
```

```typescript
// GOOD: Fixture teardown always runs
export const test = base.extend<{ debugMode: void }>({
  debugMode: async ({ page }, use) => {
    await page.evaluate(() => localStorage.setItem('debug', 'true'));
    await use();
    await page.evaluate(() => localStorage.clear()); // Guaranteed
  },
});
```

### 3. Des fixtures qui font trop de choses

```typescript
// BAD: One fixture doing setup for unrelated concerns
export const test = base.extend({
  everything: async ({ page }, use) => {
    // Logs in
    await page.goto('/login');
    await page.getByLabel('Email').fill('user@test.com');
    await page.getByLabel('Password').fill('password');
    await page.getByRole('button', { name: 'Sign in' }).click();
    // Creates test data
    await page.request.post('/api/products', { data: { name: 'Widget' } });
    // Blocks analytics
    await page.route(/analytics/, (r) => r.abort());
    // Sets locale
    await page.evaluate(() => localStorage.setItem('locale', 'en'));
    await use(page);
  },
});
```

```typescript
// GOOD: Separate fixtures, each with one responsibility
export const test = base.extend({
  authenticatedPage: async ({ page }, use) => {
    await page.goto('/login');
    await page.getByLabel('Email').fill('user@test.com');
    await page.getByLabel('Password').fill('password');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await use(page);
  },

  testProduct: async ({ request }, use) => {
    const res = await request.post('/api/products', { data: { name: 'Widget' } });
    const product = await res.json();
    await use(product);
    await request.delete(`/api/products/${product.id}`);
  },

  blockAnalytics: [async ({ page }, use) => {
    await page.route(/analytics/, (r) => r.abort());
    await use();
  }, { auto: true }],
});
```

### 4. Sur-abstraction des fixtures

```typescript
// BAD: Fixture factory with layers of indirection nobody can follow
const createFixture = (role, permissions, options) =>
  base.extend({
    [`${role}Page`]: async ({ page }, use) => {
      await setupRole(page, role, permissions, options);
      await use(page);
    },
  });

const adminTest = createFixture('admin', ['read', 'write', 'delete'], { mfa: true });
const editorTest = createFixture('editor', ['read', 'write'], { mfa: false });
// Good luck debugging which fixture ran
```

```typescript
// GOOD: Explicit fixtures — boring but readable
export const test = base.extend({
  adminPage: async ({ browser }, use) => {
    const ctx = await browser.newContext({ storageState: 'auth/admin.json' });
    const page = await ctx.newPage();
    await use(page);
    await ctx.close();
  },

  editorPage: async ({ browser }, use) => {
    const ctx = await browser.newContext({ storageState: 'auth/editor.json' });
    const page = await ctx.newPage();
    await use(page);
    await ctx.close();
  },
});
```

### 5. Ne pas typer les fixtures en TypeScript

```typescript
// BAD: No type parameter — no autocomplete, no compile-time errors
export const test = base.extend({
  myFixture: async ({ page }, use) => {
    await use({ count: 42 });
  },
});
// test('example', async ({ myFixture }) => {
//   myFixture.cont // No autocomplete, no type safety
// });
```

```typescript
// GOOD: Explicit type interface
interface MyFixtures {
  myFixture: { count: number };
}

export const test = base.extend<MyFixtures>({
  myFixture: async ({ page }, use) => {
    await use({ count: 42 });
  },
});
// test('example', async ({ myFixture }) => {
//   myFixture.count // Autocomplete works, typos caught at compile time
// });
```

## Dépannage

| Symptôme | Cause | Correction |
|---|---|---|
| `Cannot use a test-scoped fixture in a worker-scoped fixture` | Une fixture worker dépend de `page`, `context` ou d'une fixture personnalisée à portée test | Les fixtures worker ne peuvent dépendre que d'autres fixtures worker ou de fixtures worker intégrées (`browser`, `playwright`) |
| `Fixture "X" has already been registered` | Deux fichiers de fixtures définissent le même nom de fixture et sont tous deux étendus | Utilise `mergeTests()` au lieu d'enchaîner des appels `.extend()`, ou renomme l'une des fixtures |
| Le teardown de la fixture ne s'exécute pas | Tu as utilisé `afterEach` au lieu du pattern de callback `use()` | Déplace le code de nettoyage après l'appel `await use()` dans la fixture |
| `beforeAll` ne peut pas accéder à `page` | `page` est à portée test ; `beforeAll` ne reçoit que les fixtures à portée worker | Utilise une fixture à portée worker, ou déplace la logique dans `beforeEach` |
| Le test se bloque dans la fixture | `await use()` n'a jamais été appelé : Playwright attend indéfiniment que la fixture cède la main | Assure-toi que chaque chemin de code de la fixture appelle `await use(value)` exactement une fois |
| La fixture s'exécute mais le test ne voit pas la valeur | La fixture n'est pas déclarée dans les arguments déstructurés du test | Ajoute le nom de la fixture à la signature de la fonction de test : `test('name', async ({ myFixture }) => { ... })` |
| La valeur de l'option fixture est ignorée | `test.use()` appelé dans `test()` au lieu de `test.describe()` | `test.use()` doit se trouver au niveau racine d'un bloc `describe` ou d'un fichier, pas à l'intérieur d'un test |
| L'auto fixture ne s'exécute pas | Le fichier de fixtures n'est pas importé : le `test` personnalisé n'est pas utilisé | Importe et utilise le `test` de ton fichier de fixtures, pas celui de `@playwright/test` |

## Voir aussi

- [pom/page-object-model.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/pom/page-object-model.md) — Les page objects sont généralement consommés via des fixtures
- [core/test-organization.md](test-organization.md) — Où placer les fichiers de fixtures dans l'arborescence du projet
- [core/configuration.md](configuration.md) — Les option fixtures se configurent dans `playwright.config`
- [core/authentication.md](authentication.md) — L'état d'authentification est la fixture à portée worker la plus courante
- [ci/global-setup-teardown.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/global-setup-teardown.md) — Pour un setup vraiment global (tous les workers), pas par worker
- [pom/pom-vs-fixtures-vs-helpers.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/pom/pom-vs-fixtures-vs-helpers.md) — Quand utiliser chaque abstraction
