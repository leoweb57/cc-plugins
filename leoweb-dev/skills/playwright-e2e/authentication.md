# Tests d'authentification

> **Quand l'utiliser** : toute application avec login, gestion de session ou routes protégées. L'authentification est la source la plus courante de suites de tests lentes -- bien la gérer accélère toute ta suite.
> **Prérequis** : [core/configuration.md](configuration.md), [core/fixtures-and-hooks.md](fixtures-and-hooks.md)

## Référence rapide

```typescript
// Storage state reuse — the #1 pattern for fast auth
await page.goto('/login');
await page.getByLabel('Email').fill('user@test.com');
await page.getByLabel('Password').fill('password');
await page.getByRole('button', { name: 'Sign in' }).click();
await page.context().storageState({ path: '.auth/user.json' });

// Reuse in config — every test starts authenticated, zero login overhead
{ use: { storageState: '.auth/user.json' } }

// API login — skip the UI entirely
const context = await browser.newContext();
const response = await context.request.post('/api/auth/login', {
  data: { email: 'user@test.com', password: 'password' },
});
await context.storageState({ path: '.auth/user.json' });
```

## Patterns

### Réutilisation du storage state

**Utiliser quand** : tu as besoin de tests authentifiés et tu veux éviter de te connecter avant chaque test. C'est le pattern par défaut de presque tous les projets.
**Éviter quand** : les tests exigent des sessions totalement vierges, sans état préalable, ou tu testes le parcours de login lui-même.

Le `storageState` de Playwright sérialise les cookies et le localStorage dans un fichier JSON. Charge-le dans n'importe quel browser context pour démarrer authentifié instantanément.

**TypeScript**
```typescript
// scripts/save-auth-state.ts — run once to generate the state file
import { chromium } from '@playwright/test';

async function saveAuthState() {
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();

  await page.goto('http://localhost:3000/login');
  await page.getByLabel('Email').fill('user@test.com');
  await page.getByLabel('Password').fill('s3cure!Pass');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');

  // Save cookies + localStorage to a file
  await context.storageState({ path: '.auth/user.json' });
  await browser.close();
}

saveAuthState();
```

```typescript
// playwright.config.ts — load saved state for all tests
import { defineConfig } from '@playwright/test';

export default defineConfig({
  use: {
    baseURL: 'http://localhost:3000',
    storageState: '.auth/user.json',
  },
});
```

```typescript
// tests/dashboard.spec.ts — test starts already logged in
import { test, expect } from '@playwright/test';

test('authenticated user sees dashboard', async ({ page }) => {
  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  // No login step needed — storageState handles it
});
```

**JavaScript**
```javascript
// scripts/save-auth-state.js
const { chromium } = require('@playwright/test');

async function saveAuthState() {
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();

  await page.goto('http://localhost:3000/login');
  await page.getByLabel('Email').fill('user@test.com');
  await page.getByLabel('Password').fill('s3cure!Pass');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');

  await context.storageState({ path: '.auth/user.json' });
  await browser.close();
}

saveAuthState();
```

```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  use: {
    baseURL: 'http://localhost:3000',
    storageState: '.auth/user.json',
  },
});
```

### Rafraîchissement de l'état sur place avec `setStorageState()` (Playwright 1.59+)

**Utiliser quand** : tu as déjà un browser context ouvert et tu veux remplacer ses cookies et son local storage sans détruire le context ni en créer un nouveau.
**Éviter quand** : démarrer un nouveau context isolé est plus simple, ou quand le test valide lui-même le parcours de login depuis zéro.

Playwright 1.59 a ajouté `browserContext.setStorageState()`, qui efface les cookies, le local storage et l'état IndexedDB actuels, puis applique un nouveau snapshot de stockage sur place.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('swap to a different authenticated state without recreating the context', async ({ page, context }) => {
  await page.goto('/dashboard');

  await context.setStorageState('.auth/admin.json');
  await page.reload();

  await expect(page.getByRole('heading', { name: 'Admin dashboard' })).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('swap to a different authenticated state without recreating the context', async ({ page, context }) => {
  await page.goto('/dashboard');

  await context.setStorageState('.auth/admin.json');
  await page.reload();

  await expect(page.getByRole('heading', { name: 'Admin dashboard' })).toBeVisible();
});
```

### Sauvegarder l'état d'authentification IndexedDB et OPFS

`storageState()` sauvegarde par défaut les cookies et le local storage. Si ton application conserve ses tokens d'authentification ailleurs, active l'option à la sauvegarde : `indexedDB: true` (Firebase Authentication et équivalents, 1.51+) ou `opfs: true` pour l'origin private file system (1.63+).

```typescript
await page.context().storageState({ path: '.auth/user.json', indexedDB: true, opfs: true });
```

### HTTP Basic Auth sur plusieurs origines (Playwright 1.63+)

`httpCredentials` accepte un tableau. La première entrée dont l'`origin` correspond à la requête est utilisée ; une entrée sans `origin` correspond à n'importe quelle requête.

```typescript
use: {
  httpCredentials: [
    { username: 'app', password: process.env.APP_PASS!, origin: 'https://app.staging.example.com' },
    { username: 'api', password: process.env.API_PASS!, origin: 'https://api.staging.example.com' },
  ],
},
```

### Authentification dans le global setup

**Utiliser quand** : tu veux t'authentifier une seule fois avant l'exécution de toute la suite de tests, puis réutiliser cette session partout. C'est l'approche standard recommandée par Playwright.
**Éviter quand** : des tests différents ont besoin d'utilisateurs différents, ou tes tokens expirent plus vite que la durée de ta suite.

Le global setup s'exécute une fois par invocation de `npx playwright test`. Il se connecte, sauvegarde l'état, et chaque projet de test qui référence ce fichier d'état démarre authentifié.

**TypeScript**
```typescript
// global-setup.ts
import { chromium, type FullConfig } from '@playwright/test';

async function globalSetup(config: FullConfig) {
  const { baseURL } = config.projects[0].use;
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();

  await page.goto(`${baseURL}/login`);
  await page.getByLabel('Email').fill(process.env.TEST_USER_EMAIL!);
  await page.getByLabel('Password').fill(process.env.TEST_USER_PASSWORD!);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('**/dashboard');

  await context.storageState({ path: '.auth/user.json' });
  await browser.close();
}

export default globalSetup;
```

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  globalSetup: require.resolve('./global-setup'),
  use: {
    baseURL: 'http://localhost:3000',
    storageState: '.auth/user.json',
  },
});
```

**JavaScript**
```javascript
// global-setup.js
const { chromium } = require('@playwright/test');

async function globalSetup(config) {
  const { baseURL } = config.projects[0].use;
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();

  await page.goto(`${baseURL}/login`);
  await page.getByLabel('Email').fill(process.env.TEST_USER_EMAIL);
  await page.getByLabel('Password').fill(process.env.TEST_USER_PASSWORD);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('**/dashboard');

  await context.storageState({ path: '.auth/user.json' });
  await browser.close();
}

module.exports = globalSetup;
```

```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  globalSetup: require.resolve('./global-setup'),
  use: {
    baseURL: 'http://localhost:3000',
    storageState: '.auth/user.json',
  },
});
```

**Important** : ajoute `.auth/` à ton `.gitignore`. Les fichiers d'état d'authentification contiennent des tokens de session et ne doivent jamais être commités.

### Authentification par worker

**Utiliser quand** : chaque worker parallèle a besoin de sa propre session authentifiée pour éviter les race conditions. Indispensable quand les tests modifient l'état de l'utilisateur (mise à jour du profil, changement de paramètres, mutations de données).
**Éviter quand** : les tests sont en lecture seule et une session partagée est sûre, ou tu n'exécutes les tests qu'en série.

Les fixtures à portée worker s'exécutent une fois par processus worker, et non une fois par test. Chaque worker parallèle obtient ainsi sa propre session isolée.

**TypeScript**
```typescript
// fixtures/auth.ts
import { test as base, type BrowserContext } from '@playwright/test';

type AuthFixtures = {
  authenticatedContext: BrowserContext;
};

export const test = base.extend<{}, AuthFixtures>({
  authenticatedContext: [async ({ browser }, use) => {
    const context = await browser.newContext();
    const page = await context.newPage();

    await page.goto('/login');
    await page.getByLabel('Email').fill(`worker-${test.info().parallelIndex}@test.com`);
    await page.getByLabel('Password').fill('password');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await page.waitForURL('/dashboard');
    await page.close();

    await use(context);
    await context.close();
  }, { scope: 'worker' }],
});

export { expect } from '@playwright/test';
```

```typescript
// tests/profile.spec.ts
import { test, expect } from '../fixtures/auth';

test('update profile name', async ({ authenticatedContext }) => {
  const page = await authenticatedContext.newPage();
  await page.goto('/settings/profile');
  await page.getByLabel('Display name').fill('Updated Name');
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page.getByText('Profile updated')).toBeVisible();
});
```

**JavaScript**
```javascript
// fixtures/auth.js
const { test: base } = require('@playwright/test');

const test = base.extend({
  authenticatedContext: [async ({ browser }, use) => {
    const context = await browser.newContext();
    const page = await context.newPage();

    await page.goto('/login');
    await page.getByLabel('Email').fill(`worker-${test.info().parallelIndex}@test.com`);
    await page.getByLabel('Password').fill('password');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await page.waitForURL('/dashboard');
    await page.close();

    await use(context);
    await context.close();
  }, { scope: 'worker' }],
});

module.exports = { test, expect: require('@playwright/test').expect };
```

### Rôles multiples

**Utiliser quand** : ton application a un contrôle d'accès basé sur les rôles et tu dois vérifier que les admins, les utilisateurs classiques et les viewers voient des choses différentes.
**Éviter quand** : ton application n'a qu'un seul rôle utilisateur.

Utilise des projets Playwright distincts avec des storage states différents, un par rôle. C'est plus propre que de changer de rôle au sein des tests.

**TypeScript**
```typescript
// global-setup.ts — authenticate all roles
import { chromium, type FullConfig } from '@playwright/test';

const users = [
  { role: 'admin', email: 'admin@test.com', password: process.env.ADMIN_PASSWORD! },
  { role: 'user', email: 'user@test.com', password: process.env.USER_PASSWORD! },
  { role: 'viewer', email: 'viewer@test.com', password: process.env.VIEWER_PASSWORD! },
];

async function globalSetup(config: FullConfig) {
  const { baseURL } = config.projects[0].use;

  for (const { role, email, password } of users) {
    const browser = await chromium.launch();
    const context = await browser.newContext();
    const page = await context.newPage();

    await page.goto(`${baseURL}/login`);
    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Password').fill(password);
    await page.getByRole('button', { name: 'Sign in' }).click();
    await page.waitForURL('**/dashboard');

    await context.storageState({ path: `.auth/${role}.json` });
    await browser.close();
  }
}

export default globalSetup;
```

```typescript
// playwright.config.ts — one project per role
import { defineConfig } from '@playwright/test';

export default defineConfig({
  globalSetup: require.resolve('./global-setup'),
  projects: [
    {
      name: 'admin',
      use: { storageState: '.auth/admin.json' },
      testMatch: '**/*.admin.spec.ts',
    },
    {
      name: 'user',
      use: { storageState: '.auth/user.json' },
      testMatch: '**/*.user.spec.ts',
    },
    {
      name: 'viewer',
      use: { storageState: '.auth/viewer.json' },
      testMatch: '**/*.viewer.spec.ts',
    },
    {
      name: 'unauthenticated',
      use: { storageState: { cookies: [], origins: [] } },
      testMatch: '**/*.anon.spec.ts',
    },
  ],
});
```

```typescript
// tests/admin-panel.admin.spec.ts
import { test, expect } from '@playwright/test';

test('admin can access user management', async ({ page }) => {
  await page.goto('/admin/users');
  await expect(page.getByRole('heading', { name: 'User Management' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Delete user' })).toBeEnabled();
});
```

```typescript
// tests/admin-panel.viewer.spec.ts
import { test, expect } from '@playwright/test';

test('viewer cannot access admin panel', async ({ page }) => {
  await page.goto('/admin/users');
  // Should redirect to forbidden or dashboard
  await expect(page.getByText('Access denied')).toBeVisible();
});
```

**JavaScript**
```javascript
// global-setup.js
const { chromium } = require('@playwright/test');

const users = [
  { role: 'admin', email: 'admin@test.com', password: process.env.ADMIN_PASSWORD },
  { role: 'user', email: 'user@test.com', password: process.env.USER_PASSWORD },
  { role: 'viewer', email: 'viewer@test.com', password: process.env.VIEWER_PASSWORD },
];

async function globalSetup(config) {
  const { baseURL } = config.projects[0].use;

  for (const { role, email, password } of users) {
    const browser = await chromium.launch();
    const context = await browser.newContext();
    const page = await context.newPage();

    await page.goto(`${baseURL}/login`);
    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Password').fill(password);
    await page.getByRole('button', { name: 'Sign in' }).click();
    await page.waitForURL('**/dashboard');

    await context.storageState({ path: `.auth/${role}.json` });
    await browser.close();
  }
}

module.exports = globalSetup;
```

```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  globalSetup: require.resolve('./global-setup'),
  projects: [
    {
      name: 'admin',
      use: { storageState: '.auth/admin.json' },
      testMatch: '**/*.admin.spec.js',
    },
    {
      name: 'user',
      use: { storageState: '.auth/user.json' },
      testMatch: '**/*.user.spec.js',
    },
    {
      name: 'viewer',
      use: { storageState: '.auth/viewer.json' },
      testMatch: '**/*.viewer.spec.js',
    },
    {
      name: 'unauthenticated',
      use: { storageState: { cookies: [], origins: [] } },
      testMatch: '**/*.anon.spec.js',
    },
  ],
});
```

**Alternative** : utilise une fixture qui accepte un paramètre de rôle quand tu as besoin de changer de rôle au sein d'un même fichier spec.

```typescript
// fixtures/auth.ts — role-based fixture
import { test as base, type Page } from '@playwright/test';
import fs from 'fs';

type RoleFixtures = {
  loginAs: (role: 'admin' | 'user' | 'viewer') => Promise<Page>;
};

export const test = base.extend<RoleFixtures>({
  loginAs: async ({ browser }, use) => {
    const pages: Page[] = [];

    await use(async (role) => {
      const statePath = `.auth/${role}.json`;
      if (!fs.existsSync(statePath)) {
        throw new Error(`Auth state for role "${role}" not found at ${statePath}. Run global setup first.`);
      }
      const context = await browser.newContext({ storageState: statePath });
      const page = await context.newPage();
      pages.push(page);
      return page;
    });

    for (const page of pages) {
      await page.context().close();
    }
  },
});

export { expect } from '@playwright/test';
```

```typescript
// tests/role-comparison.spec.ts
import { test, expect } from '../fixtures/auth';

test('admin sees delete button, viewer does not', async ({ loginAs }) => {
  const adminPage = await loginAs('admin');
  await adminPage.goto('/admin/users');
  await expect(adminPage.getByRole('button', { name: 'Delete user' })).toBeVisible();

  const viewerPage = await loginAs('viewer');
  await viewerPage.goto('/admin/users');
  await expect(viewerPage.getByText('Access denied')).toBeVisible();
});
```

### Mock d'OAuth/SSO

**Utiliser quand** : ton application s'authentifie via un provider OAuth tiers (Google, GitHub, Okta, Auth0) et tu ne peux pas, ou ne dois pas, solliciter le vrai provider dans les tests.
**Éviter quand** : tu disposes d'un tenant de test dédié chez le provider OAuth et tu veux une vraie couverture end-to-end du flow OAuth.

La stratégie : intercepter la route de callback OAuth et injecter directement une session valide, en contournant complètement le provider.

**TypeScript**
```typescript
// fixtures/oauth-mock.ts
import { test as base } from '@playwright/test';

export const test = base.extend({
  // Mock OAuth by intercepting the callback and injecting session cookies
  page: async ({ page }, use) => {
    // Intercept the OAuth redirect to the provider
    await page.route('**/auth/callback**', async (route) => {
      // Instead of going to Google/GitHub, call your own backend
      // with a test token that your backend recognizes in test mode
      const url = new URL(route.request().url());
      url.searchParams.set('code', 'test-oauth-code');
      url.searchParams.set('state', url.searchParams.get('state') || '');

      await route.continue({ url: url.toString() });
    });

    await use(page);
  },
});

export { expect } from '@playwright/test';
```

```typescript
// tests/oauth-login.spec.ts — approach 1: mock the callback route
import { test, expect } from '@playwright/test';

test('login via mocked OAuth flow', async ({ page }) => {
  // Intercept the redirect to the OAuth provider
  await page.route('https://accounts.google.com/**', async (route) => {
    // Redirect back to your app's callback with a fake auth code
    const callbackUrl = new URL('http://localhost:3000/auth/callback');
    callbackUrl.searchParams.set('code', 'mock-auth-code-12345');
    callbackUrl.searchParams.set('state', 'expected-state-value');
    await route.fulfill({
      status: 302,
      headers: { location: callbackUrl.toString() },
    });
  });

  await page.goto('/login');
  await page.getByRole('button', { name: 'Sign in with Google' }).click();

  // Your backend must accept "mock-auth-code-12345" in test mode
  // and exchange it for a real session
  await page.waitForURL('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

```typescript
// tests/oauth-login.spec.ts — approach 2: API-based session injection
import { test, expect } from '@playwright/test';

test('bypass OAuth entirely via API session injection', async ({ page, request }) => {
  // Call a test-only endpoint that creates a session without OAuth
  // Your backend exposes this only when NODE_ENV=test
  const response = await request.post('/api/test/create-session', {
    data: {
      email: 'oauth-user@test.com',
      provider: 'google',
      role: 'user',
    },
  });
  expect(response.ok()).toBeTruthy();

  // The response sets session cookies; storageState captures them
  await page.context().storageState({ path: '.auth/oauth-user.json' });

  // Now navigate — already authenticated
  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('login via mocked OAuth flow', async ({ page }) => {
  await page.route('https://accounts.google.com/**', async (route) => {
    const callbackUrl = new URL('http://localhost:3000/auth/callback');
    callbackUrl.searchParams.set('code', 'mock-auth-code-12345');
    callbackUrl.searchParams.set('state', 'expected-state-value');
    await route.fulfill({
      status: 302,
      headers: { location: callbackUrl.toString() },
    });
  });

  await page.goto('/login');
  await page.getByRole('button', { name: 'Sign in with Google' }).click();

  await page.waitForURL('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

```javascript
test('bypass OAuth entirely via API session injection', async ({ page, request }) => {
  const response = await request.post('/api/test/create-session', {
    data: {
      email: 'oauth-user@test.com',
      provider: 'google',
      role: 'user',
    },
  });
  expect(response.ok()).toBeTruthy();

  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

**Exigence côté backend** : ton backend doit exposer un endpoint de création de session réservé aux tests (protégé par `NODE_ENV=test`) ou accepter un code OAuth de test connu. Ne déploie jamais d'endpoints d'authentification de test en production.

### Gestion de la MFA

**Utiliser quand** : ton application exige une authentification à deux facteurs (TOTP, SMS, codes par email) et tu dois la gérer dans les tests.
**Éviter quand** : la MFA est optionnelle et tu peux la désactiver pour les comptes de test.

**Stratégie 1** : génère de vrais codes TOTP à partir d'un secret partagé. C'est l'approche la plus fiable.

**TypeScript**
```typescript
// helpers/totp.ts
import * as OTPAuth from 'otpauth';

export function generateTOTP(secret: string): string {
  const totp = new OTPAuth.TOTP({
    secret: OTPAuth.Secret.fromBase32(secret),
    digits: 6,
    period: 30,
    algorithm: 'SHA1',
  });
  return totp.generate();
}
```

```typescript
// tests/mfa-login.spec.ts
import { test, expect } from '@playwright/test';
import { generateTOTP } from '../helpers/totp';

test('login with TOTP two-factor auth', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('mfa-user@test.com');
  await page.getByLabel('Password').fill('password');
  await page.getByRole('button', { name: 'Sign in' }).click();

  // MFA challenge screen
  await expect(page.getByText('Enter your authentication code')).toBeVisible();

  // Generate a valid TOTP from the test account's secret
  const code = generateTOTP(process.env.MFA_TOTP_SECRET!);
  await page.getByLabel('Authentication code').fill(code);
  await page.getByRole('button', { name: 'Verify' }).click();

  await page.waitForURL('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

**JavaScript**
```javascript
// helpers/totp.js
const OTPAuth = require('otpauth');

function generateTOTP(secret) {
  const totp = new OTPAuth.TOTP({
    secret: OTPAuth.Secret.fromBase32(secret),
    digits: 6,
    period: 30,
    algorithm: 'SHA1',
  });
  return totp.generate();
}

module.exports = { generateTOTP };
```

```javascript
// tests/mfa-login.spec.js
const { test, expect } = require('@playwright/test');
const { generateTOTP } = require('../helpers/totp');

test('login with TOTP two-factor auth', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('mfa-user@test.com');
  await page.getByLabel('Password').fill('password');
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page.getByText('Enter your authentication code')).toBeVisible();

  const code = generateTOTP(process.env.MFA_TOTP_SECRET);
  await page.getByLabel('Authentication code').fill(code);
  await page.getByRole('button', { name: 'Verify' }).click();

  await page.waitForURL('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

**Stratégie 2** : mocke la MFA au niveau du backend. Fais en sorte que ton backend accepte un code de contournement connu (par ex. `000000`) quand `NODE_ENV=test`.

```typescript
// Simpler but less realistic — backend accepts bypass code in test mode
test('login with MFA bypass code', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('mfa-user@test.com');
  await page.getByLabel('Password').fill('password');
  await page.getByRole('button', { name: 'Sign in' }).click();

  // Backend accepts "000000" as a valid MFA code in test environment
  await page.getByLabel('Authentication code').fill('000000');
  await page.getByRole('button', { name: 'Verify' }).click();

  await page.waitForURL('/dashboard');
});
```

**Stratégie 3** : désactive la MFA pour les comptes de test au niveau de l'infrastructure. Configure des utilisateurs de test dédiés avec la MFA désactivée. C'est l'approche la plus simple quand elle est possible.

### Rafraîchissement de session

**Utiliser quand** : tes tokens expirent pendant les longues exécutions de tests ou ton application utilise des JWT de courte durée qu'il faut rafraîchir.
**Éviter quand** : ta suite de tests s'exécute en quelques minutes et les tokens survivent à toute l'exécution.

**TypeScript**
```typescript
// fixtures/auth-with-refresh.ts
import { test as base, type BrowserContext } from '@playwright/test';
import fs from 'fs';

type AuthFixtures = {
  authenticatedPage: import('@playwright/test').Page;
};

export const test = base.extend<AuthFixtures>({
  authenticatedPage: async ({ browser }, use) => {
    const statePath = '.auth/user.json';

    // Check if the stored session is still valid
    let context: BrowserContext;
    if (fs.existsSync(statePath)) {
      context = await browser.newContext({ storageState: statePath });
      const page = await context.newPage();

      // Quick health check — does the session still work?
      const response = await page.request.get('/api/auth/me');
      if (response.ok()) {
        await use(page);
        await context.close();
        return;
      }
      // Session expired — close and re-authenticate
      await context.close();
    }

    // Re-authenticate
    context = await browser.newContext();
    const page = await context.newPage();
    await page.goto('/login');
    await page.getByLabel('Email').fill(process.env.TEST_USER_EMAIL!);
    await page.getByLabel('Password').fill(process.env.TEST_USER_PASSWORD!);
    await page.getByRole('button', { name: 'Sign in' }).click();
    await page.waitForURL('/dashboard');

    // Save refreshed state for subsequent tests
    await context.storageState({ path: statePath });

    await use(page);
    await context.close();
  },
});

export { expect } from '@playwright/test';
```

```typescript
// Alternative: intercept token refresh requests to ensure they work
import { test, expect } from '@playwright/test';

test('app refreshes expired token automatically', async ({ page }) => {
  await page.goto('/dashboard');

  // Simulate token expiration by clearing the access token cookie
  await page.context().clearCookies({ name: 'access_token' });

  // Next API call should trigger a token refresh via refresh_token cookie
  const refreshPromise = page.waitForResponse('**/api/auth/refresh');
  await page.getByRole('button', { name: 'Load data' }).click();
  const refreshResponse = await refreshPromise;

  expect(refreshResponse.status()).toBe(200);
  await expect(page.getByTestId('data-table')).toBeVisible();
});
```

**JavaScript**
```javascript
// fixtures/auth-with-refresh.js
const { test: base } = require('@playwright/test');
const fs = require('fs');

const test = base.extend({
  authenticatedPage: async ({ browser }, use) => {
    const statePath = '.auth/user.json';

    if (fs.existsSync(statePath)) {
      const context = await browser.newContext({ storageState: statePath });
      const page = await context.newPage();
      const response = await page.request.get('/api/auth/me');

      if (response.ok()) {
        await use(page);
        await context.close();
        return;
      }
      await context.close();
    }

    const context = await browser.newContext();
    const page = await context.newPage();
    await page.goto('/login');
    await page.getByLabel('Email').fill(process.env.TEST_USER_EMAIL);
    await page.getByLabel('Password').fill(process.env.TEST_USER_PASSWORD);
    await page.getByRole('button', { name: 'Sign in' }).click();
    await page.waitForURL('/dashboard');
    await context.storageState({ path: statePath });

    await use(page);
    await context.close();
  },
});

module.exports = { test, expect: require('@playwright/test').expect };
```

### Page Object de login

**Utiliser quand** : plusieurs fichiers de test doivent se connecter et tu veux une logique de login cohérente et maintenable, avec une gestion d'erreurs correcte.
**Éviter quand** : tu utilises `storageState` partout et ne passes jamais par l'UI de login dans les tests (reste utile pour tester la page de login elle-même).

**TypeScript**
```typescript
// page-objects/LoginPage.ts
import { type Page, type Locator, expect } from '@playwright/test';

export class LoginPage {
  readonly page: Page;
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly signInButton: Locator;
  readonly errorMessage: Locator;
  readonly forgotPasswordLink: Locator;

  constructor(page: Page) {
    this.page = page;
    this.emailInput = page.getByLabel('Email');
    this.passwordInput = page.getByLabel('Password');
    this.signInButton = page.getByRole('button', { name: 'Sign in' });
    this.errorMessage = page.getByRole('alert');
    this.forgotPasswordLink = page.getByRole('link', { name: 'Forgot password' });
  }

  async goto() {
    await this.page.goto('/login');
    await expect(this.signInButton).toBeVisible();
  }

  async login(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.signInButton.click();
  }

  async loginAndWaitForDashboard(email: string, password: string) {
    await this.login(email, password);
    await this.page.waitForURL('/dashboard');
  }

  async expectError(message: string | RegExp) {
    await expect(this.errorMessage).toContainText(message);
  }

  async expectFieldError(field: 'email' | 'password', message: string) {
    const input = field === 'email' ? this.emailInput : this.passwordInput;
    await expect(input).toHaveAttribute('aria-invalid', 'true');
    // Error message associated with the field
    const errorId = await input.getAttribute('aria-describedby');
    if (errorId) {
      await expect(this.page.locator(`#${errorId}`)).toContainText(message);
    }
  }
}
```

```typescript
// tests/login.spec.ts
import { test, expect } from '@playwright/test';
import { LoginPage } from '../page-objects/LoginPage';

// These tests run WITHOUT storageState (unauthenticated)
test.use({ storageState: { cookies: [], origins: [] } });

test.describe('login page', () => {
  let loginPage: LoginPage;

  test.beforeEach(async ({ page }) => {
    loginPage = new LoginPage(page);
    await loginPage.goto();
  });

  test('successful login redirects to dashboard', async ({ page }) => {
    await loginPage.loginAndWaitForDashboard('user@test.com', 'password');
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });

  test('wrong password shows error', async () => {
    await loginPage.login('user@test.com', 'wrong-password');
    await loginPage.expectError('Invalid email or password');
  });

  test('empty fields show validation errors', async () => {
    await loginPage.signInButton.click();
    await loginPage.expectFieldError('email', 'Email is required');
  });

  test('forgot password link navigates correctly', async ({ page }) => {
    await loginPage.forgotPasswordLink.click();
    await page.waitForURL('/forgot-password');
    await expect(page.getByRole('heading', { name: 'Reset password' })).toBeVisible();
  });
});
```

**JavaScript**
```javascript
// page-objects/LoginPage.js
const { expect } = require('@playwright/test');

class LoginPage {
  constructor(page) {
    this.page = page;
    this.emailInput = page.getByLabel('Email');
    this.passwordInput = page.getByLabel('Password');
    this.signInButton = page.getByRole('button', { name: 'Sign in' });
    this.errorMessage = page.getByRole('alert');
    this.forgotPasswordLink = page.getByRole('link', { name: 'Forgot password' });
  }

  async goto() {
    await this.page.goto('/login');
    await expect(this.signInButton).toBeVisible();
  }

  async login(email, password) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.signInButton.click();
  }

  async loginAndWaitForDashboard(email, password) {
    await this.login(email, password);
    await this.page.waitForURL('/dashboard');
  }

  async expectError(message) {
    await expect(this.errorMessage).toContainText(message);
  }

  async expectFieldError(field, message) {
    const input = field === 'email' ? this.emailInput : this.passwordInput;
    await expect(input).toHaveAttribute('aria-invalid', 'true');
    const errorId = await input.getAttribute('aria-describedby');
    if (errorId) {
      await expect(this.page.locator(`#${errorId}`)).toContainText(message);
    }
  }
}

module.exports = { LoginPage };
```

```javascript
// tests/login.spec.js
const { test, expect } = require('@playwright/test');
const { LoginPage } = require('../page-objects/LoginPage');

test.use({ storageState: { cookies: [], origins: [] } });

test.describe('login page', () => {
  let loginPage;

  test.beforeEach(async ({ page }) => {
    loginPage = new LoginPage(page);
    await loginPage.goto();
  });

  test('successful login redirects to dashboard', async ({ page }) => {
    await loginPage.loginAndWaitForDashboard('user@test.com', 'password');
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });

  test('wrong password shows error', async () => {
    await loginPage.login('user@test.com', 'wrong-password');
    await loginPage.expectError('Invalid email or password');
  });

  test('empty fields show validation errors', async () => {
    await loginPage.signInButton.click();
    await loginPage.expectFieldError('email', 'Email is required');
  });
});
```

### Login via l'API

**Utiliser quand** : tu veux l'authentification la plus rapide possible, sans aucune interaction avec le navigateur. Idéal pour générer des fichiers `storageState` dans le global setup ou les fixtures.
**Éviter quand** : tu testes spécifiquement l'UI de login. Utilise plutôt le pattern Login Page Object.

Le login via l'API est généralement 5 à 10 fois plus rapide que le login via l'UI. Utilise `request.post()` pour appeler directement ton endpoint d'authentification, puis récupère les cookies obtenus.

**TypeScript**
```typescript
// global-setup.ts — API-based login (fastest)
import { request, type FullConfig } from '@playwright/test';

async function globalSetup(config: FullConfig) {
  const { baseURL } = config.projects[0].use;

  const requestContext = await request.newContext({ baseURL });

  // Login via API — no browser needed
  const response = await requestContext.post('/api/auth/login', {
    data: {
      email: process.env.TEST_USER_EMAIL!,
      password: process.env.TEST_USER_PASSWORD!,
    },
  });

  if (!response.ok()) {
    throw new Error(`API login failed: ${response.status()} ${await response.text()}`);
  }

  // Save the session cookies from the API response
  await requestContext.storageState({ path: '.auth/user.json' });
  await requestContext.dispose();
}

export default globalSetup;
```

```typescript
// fixtures/api-auth.ts — fixture version for per-test authentication
import { test as base } from '@playwright/test';

export const test = base.extend({
  authenticatedPage: async ({ browser, playwright }, use) => {
    // Create API context and login
    const apiContext = await playwright.request.newContext({
      baseURL: 'http://localhost:3000',
    });

    await apiContext.post('/api/auth/login', {
      data: {
        email: 'user@test.com',
        password: 'password',
      },
    });

    // Transfer API session to browser context
    const state = await apiContext.storageState();
    const context = await browser.newContext({ storageState: state });
    const page = await context.newPage();

    await use(page);

    await context.close();
    await apiContext.dispose();
  },
});

export { expect } from '@playwright/test';
```

**JavaScript**
```javascript
// global-setup.js — API-based login
const { request } = require('@playwright/test');

async function globalSetup(config) {
  const { baseURL } = config.projects[0].use;
  const requestContext = await request.newContext({ baseURL });

  const response = await requestContext.post('/api/auth/login', {
    data: {
      email: process.env.TEST_USER_EMAIL,
      password: process.env.TEST_USER_PASSWORD,
    },
  });

  if (!response.ok()) {
    throw new Error(`API login failed: ${response.status()} ${await response.text()}`);
  }

  await requestContext.storageState({ path: '.auth/user.json' });
  await requestContext.dispose();
}

module.exports = globalSetup;
```

```javascript
// fixtures/api-auth.js
const { test: base } = require('@playwright/test');

const test = base.extend({
  authenticatedPage: async ({ browser, playwright }, use) => {
    const apiContext = await playwright.request.newContext({
      baseURL: 'http://localhost:3000',
    });

    await apiContext.post('/api/auth/login', {
      data: { email: 'user@test.com', password: 'password' },
    });

    const state = await apiContext.storageState();
    const context = await browser.newContext({ storageState: state });
    const page = await context.newPage();

    await use(page);

    await context.close();
    await apiContext.dispose();
  },
});

module.exports = { test, expect: require('@playwright/test').expect };
```

### Tests non authentifiés

**Utiliser quand** : tu testes la page de login, le parcours d'inscription, la réinitialisation du mot de passe, les pages publiques, la gestion des erreurs d'authentification ou le comportement de redirection pour les utilisateurs non authentifiés.
**Éviter quand** : le test nécessite un utilisateur connecté.

Quand ta configuration définit un `storageState` par défaut, tu dois l'effacer explicitement pour les tests non authentifiés.

**TypeScript**
```typescript
// tests/public-pages.spec.ts
import { test, expect } from '@playwright/test';

// Override storageState to empty — no cookies, no session
test.use({ storageState: { cookies: [], origins: [] } });

test.describe('unauthenticated access', () => {
  test('homepage is accessible without login', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('heading', { name: 'Welcome' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Sign in' })).toBeVisible();
  });

  test('protected route redirects to login', async ({ page }) => {
    await page.goto('/dashboard');
    await page.waitForURL('**/login**');
    // Verify redirect preserves the intended destination
    expect(page.url()).toContain('redirect=%2Fdashboard');
  });

  test('expired session shows re-login prompt', async ({ page, context }) => {
    // Start with a valid session, then invalidate it
    await page.goto('/dashboard');

    // Clear all cookies to simulate session expiration
    await context.clearCookies();

    // Next navigation should detect the invalid session
    await page.goto('/settings');
    await page.waitForURL('**/login**');
    await expect(page.getByText('Your session has expired')).toBeVisible();
  });

  test('login page shows social auth options', async ({ page }) => {
    await page.goto('/login');
    await expect(page.getByRole('button', { name: 'Sign in with Google' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Sign in with GitHub' })).toBeVisible();
  });

  test('signup flow creates account', async ({ page }) => {
    await page.goto('/signup');
    await page.getByLabel('Name').fill('New User');
    await page.getByLabel('Email').fill(`test-${Date.now()}@test.com`);
    await page.getByLabel('Password', { exact: true }).fill('s3cure!Pass');
    await page.getByLabel('Confirm password').fill('s3cure!Pass');
    await page.getByRole('button', { name: 'Create account' }).click();

    await page.waitForURL('/onboarding');
    await expect(page.getByText('Welcome, New User')).toBeVisible();
  });
});
```

**JavaScript**
```javascript
// tests/public-pages.spec.js
const { test, expect } = require('@playwright/test');

test.use({ storageState: { cookies: [], origins: [] } });

test.describe('unauthenticated access', () => {
  test('homepage is accessible without login', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('heading', { name: 'Welcome' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Sign in' })).toBeVisible();
  });

  test('protected route redirects to login', async ({ page }) => {
    await page.goto('/dashboard');
    await page.waitForURL('**/login**');
    expect(page.url()).toContain('redirect=%2Fdashboard');
  });

  test('signup flow creates account', async ({ page }) => {
    await page.goto('/signup');
    await page.getByLabel('Name').fill('New User');
    await page.getByLabel('Email').fill(`test-${Date.now()}@test.com`);
    await page.getByLabel('Password', { exact: true }).fill('s3cure!Pass');
    await page.getByLabel('Confirm password').fill('s3cure!Pass');
    await page.getByRole('button', { name: 'Create account' }).click();

    await page.waitForURL('/onboarding');
    await expect(page.getByText('Welcome, New User')).toBeVisible();
  });
});
```

## Guide de décision

| Scénario | Approche | Vitesse | Isolation | Quand la choisir |
|---|---|---|---|---|
| La plupart des tests nécessitent une auth | Global setup + `storageState` | La plus rapide | Session partagée | Choix par défaut de presque tous les projets. Le login a lieu une seule fois, tous les tests réutilisent le fichier de session. |
| Les tests modifient l'état de l'utilisateur | Fixture par worker | Rapide | Par worker | Les tests mettent à jour le profil, changent des paramètres ou modifient des données susceptibles d'entrer en conflit entre workers parallèles. |
| Plusieurs rôles utilisateur | `storageState` par projet | La plus rapide | Par rôle | L'application a des rôles admin/user/viewer. Chaque projet obtient son propre fichier d'état produit par le global setup. |
| Test de la page de login | Pas de `storageState` | N/A | Totale | Utilise `test.use({ storageState: { cookies: [], origins: [] } })` pour surcharger les valeurs par défaut. |
| Provider OAuth/SSO | Mocker le callback | Rapide | Par test | Ne sollicite jamais de vrais providers OAuth en CI. Mocke la redirection ou utilise l'injection de session via l'API. |
| La MFA est obligatoire | Génération TOTP ou contournement | Moyenne | Par test | Génère de vrais codes TOTP à partir d'un secret partagé, ou utilise un code de contournement en mode test. |
| Le token expire en cours de suite | Fixture de rafraîchissement de session | Rapide | Par vérification | La fixture valide la session avant usage et se ré-authentifie si elle a expiré. |
| Un seul test a besoin d'un autre utilisateur | Fixture `loginAs(role)` | Moyenne | Par appel | Cas rare : préfère les rôles par projet. À utiliser quand un test doit comparer deux rôles côte à côte. |
| Application API-first (pas d'UI de login) | Login via l'API avec `request.post()` | La plus rapide | Par test | Aucun navigateur nécessaire pour l'auth. Appelle directement l'API et récupère les cookies. |
| CI avec des suites longues | Login via l'API + vérification de session | La plus rapide | Par worker | Combine la rapidité du login via l'API avec le rafraîchissement de session pour la fiabilité sur les longues exécutions. |

### Login via l'UI vs login via l'API vs storage state

```
Need to test the login page itself?
├── Yes → UI login with LoginPage POM, no storageState
└── No → Do you have a login API endpoint?
    ├── Yes → API login in global setup, save storageState (fastest)
    └── No → UI login in global setup, save storageState
              └── Tokens expire quickly?
                  ├── Yes → Add session refresh fixture
                  └── No → Standard storageState reuse is fine
```

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| Se connecter via l'UI avant chaque test | Ajoute 2 à 5 secondes par test. Une suite de 200 tests perd 7 à 17 minutes rien qu'à se connecter. | Utilise `storageState` pour éviter complètement le login. Connecte-toi une seule fois dans le global setup. |
| Partager un seul fichier d'état d'auth entre des workers parallèles qui modifient l'état | Race conditions : le worker A change le mot de passe pendant que le worker B est en plein test. | Utilise des fixtures par worker avec `{ scope: 'worker' }` ou des comptes de test par worker. |
| Écrire les identifiants en dur dans les fichiers de test | Risque de sécurité. Les identifiants fuitent dans le contrôle de version et les logs de CI. | Utilise des variables d'environnement (`process.env.TEST_USER_PASSWORD`) et des fichiers `.env`. |
| Ignorer l'expiration des tokens | Les tests échouent par intermittence avec des erreurs 401 après un certain temps d'exécution. | Ajoute une vérification de validité de la session dans ta fixture d'auth et ré-authentifie-toi à l'expiration. |
| Solliciter de vrais providers OAuth en CI | Flaky : rate limits du provider, CAPTCHA, problèmes réseau. Lent. Peut violer les CGU. | Mocke le callback OAuth ou utilise l'injection de session via l'API avec un endpoint réservé aux tests. |
| Utiliser `page.waitForTimeout(2000)` après le login | Délai arbitraire. Trop lent dans les environnements rapides, trop court dans les lents. | `await page.waitForURL('/dashboard')` ou `await expect(heading).toBeVisible()`. |
| Stocker les fichiers `.auth/*.json` dans git | Des tokens et des cookies dans le contrôle de version. Un incident de sécurité en puissance. | Ajoute `.auth/` au `.gitignore`. Génère l'état d'auth en CI dans le cadre de l'exécution des tests. |
| Créer un seul compte de test « dieu » avec toutes les permissions | Impossible de tester le contrôle d'accès basé sur les rôles. Les bugs dans les vérifications de permissions passent inaperçus. | Crée des comptes distincts par rôle (admin, user, viewer) avec les permissions adaptées. |
| Utiliser `browser.newContext()` sans `storageState` pour des tests authentifiés | Chaque context démarre non authentifié. Tu finis par te reconnecter en permanence. | Passe `storageState` à la création du context : `browser.newContext({ storageState: '.auth/user.json' })`. |
| Tester la MFA en la désactivant partout | Tu ne testes jamais le flow MFA. Les vrais utilisateurs tombent sur des bugs MFA que tu ne détectes jamais. | Utilise la génération TOTP à partir d'un secret partagé pour au moins un test. Contourne la MFA pour le reste. |

## Dépannage

### Le global setup échoue avec "Target page, context or browser has been closed"

**Cause** : la page de login a redirigé de façon inattendue, ou le navigateur s'est fermé avant l'appel à `storageState()`. Fréquent quand l'URL de login exige HTTPS alors que ton serveur de test utilise HTTP.

**Solution** :
- Ajoute `await page.waitForURL()` après l'action de login pour t'assurer que la navigation est terminée.
- Vérifie que `baseURL` dans ta configuration correspond à l'URL et au protocole réels du serveur.
- Ajoute une gestion d'erreurs au global setup avec un message d'erreur explicite :

```typescript
const response = await page.waitForResponse('**/api/auth/**');
if (!response.ok()) {
  throw new Error(`Login failed in global setup: ${response.status()} ${await response.text()}`);
}
```

### Les tests échouent avec 401 Unauthorized après un certain temps d'exécution

**Cause** : le token de session sauvegardé dans `storageState` a expiré. Les JWT de courte durée (expiration à 15 minutes) ne survivront pas à une longue suite de tests.

**Solution** :
- Utilise le pattern de fixture de rafraîchissement de session (voir la section Rafraîchissement de session).
- Augmente la durée de validité des tokens dans la configuration de l'environnement de test.
- Passe au login via l'API dans une fixture à portée worker qui se ré-authentifie à chaque worker.

### Le fichier `storageState` est vide ou ne contient aucun cookie

**Cause** : `storageState()` a été appelé avant que la réponse de login ne pose les cookies. Le login peut être asynchrone (le POST retourne, puis une redirection pose le cookie).

**Solution** :
- Attends le chargement de la page post-login : `await page.waitForURL('/dashboard')`.
- Attends un cookie précis : utilise `await context.cookies()` dans une vérification en polling.
- Vérifie que les cookies existent avant de sauvegarder :

```typescript
const cookies = await context.cookies();
if (cookies.length === 0) {
  throw new Error('No cookies found after login. Check that the login flow sets cookies.');
}
await context.storageState({ path: '.auth/user.json' });
```

### Des navigateurs différents obtiennent des cookies différents (problèmes d'auth cross-browser)

**Cause** : certains flows d'authentification posent des cookies avec `SameSite=Strict` ou reposent sur un comportement des cookies propre à chaque navigateur. Chromium et Firefox gèrent différemment les cookies tiers.

**Solution** :
- Génère des fichiers d'état d'auth distincts par projet navigateur.
- Vérifie si ton auth utilise des cookies `SameSite=None; Secure` qui exigent HTTPS.
- Dans `playwright.config`, définis des chemins `storageState` distincts par projet :

```typescript
projects: [
  {
    name: 'chromium',
    use: { ...devices['Desktop Chrome'], storageState: '.auth/chromium-user.json' },
  },
  {
    name: 'firefox',
    use: { ...devices['Desktop Firefox'], storageState: '.auth/firefox-user.json' },
  },
],
```

### Les tests parallèles interfèrent avec les sessions des autres

**Cause** : plusieurs workers partagent le même compte de test et les actions d'un worker (déconnexion, changement de mot de passe, invalidation de session) affectent les autres.

**Solution** :
- Utilise des comptes de test par worker : `worker-${test.info().parallelIndex}@test.com`.
- Utilise le pattern de fixture d'authentification par worker (voir la section Authentification par worker).
- Rends les tests idempotents : chaque test doit fonctionner quoi que les autres tests aient fait.

### Le mock OAuth ne fonctionne pas : la redirection part toujours vers le vrai provider

**Cause** : `page.route()` a été enregistré après la navigation qui déclenche la redirection OAuth, ou le pattern de route ne correspond pas à l'URL de redirection réelle.

**Solution** :
- Enregistre les route handlers avant toute navigation : appelle `page.route()` avant `page.goto()`.
- Logue l'URL de redirection réelle pour vérifier le pattern :

```typescript
page.on('request', (req) => {
  if (req.url().includes('oauth') || req.url().includes('accounts.google')) {
    console.log('OAuth request:', req.url());
  }
});
```

- Commence par un pattern large (`**accounts.google.com**`), puis affine-le.

## Voir aussi

- [core/fixtures-and-hooks.md](fixtures-and-hooks.md) -- fixtures personnalisées pour le setup et le teardown de l'auth
- [core/configuration.md](configuration.md) -- configuration de `storageState`, des projects et du global setup
- [ci/global-setup-teardown.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/global-setup-teardown.md) -- patterns de global setup et dépendances entre projects
- [core/network-mocking.md](network-mocking.md) -- patterns d'interception de routes utilisés pour le mock OAuth
- [core/api-testing.md](api-testing.md) -- API request context utilisé pour le login via l'API
- [core/flaky-tests.md](flaky-tests.md) -- diagnostiquer les flaky tests liés à l'auth
- [core/auth-flows.md](auth-flows.md) -- recettes complètes pour des providers d'auth spécifiques (Auth0, Okta, Firebase)
