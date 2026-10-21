# Pièges courants

> **Quand l'utiliser** : Pour apprendre Playwright, relire des tests à la recherche d'erreurs courantes, ou intégrer de nouveaux membres de l'équipe à ta suite de tests.

Les 20 erreurs Playwright les plus courantes, classées selon leur fréquence dans les codebases réelles. Chaque piège comprend le symptôme, la cause racine et un correctif complet.

---

## Piège 1 : Utiliser `page.waitForTimeout()` au lieu d'assertions

**Symptôme** : Les tests sont lents et flaky. Ils passent sur les machines rapides mais échouent sur les runners CI lents.

**Pourquoi ça arrive** : Les développeurs importent leurs habitudes de Selenium ou Cypress, où les attentes explicites étaient nécessaires. Dans Playwright, les assertions avec retry automatique gèrent le timing toutes seules.

**Correctif** : Remplace chaque `waitForTimeout` par une assertion web-first ou par une attente explicite d'une condition précise.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// BAD
test('bad: arbitrary wait', async ({ page }) => {
  await page.goto('/dashboard');
  await page.getByRole('button', { name: 'Load' }).click();
  await page.waitForTimeout(3000);
  await expect(page.getByTestId('chart')).toBeVisible();
});

// GOOD
test('good: auto-retrying assertion', async ({ page }) => {
  await page.goto('/dashboard');
  await page.getByRole('button', { name: 'Load' }).click();
  await expect(page.getByTestId('chart')).toBeVisible();
});

// GOOD — when you need to wait for a specific network event
test('good: wait for response', async ({ page }) => {
  await page.goto('/dashboard');
  const responsePromise = page.waitForResponse('**/api/chart-data');
  await page.getByRole('button', { name: 'Load' }).click();
  await responsePromise;
  await expect(page.getByTestId('chart')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

// BAD
test('bad: arbitrary wait', async ({ page }) => {
  await page.goto('/dashboard');
  await page.getByRole('button', { name: 'Load' }).click();
  await page.waitForTimeout(3000);
  await expect(page.getByTestId('chart')).toBeVisible();
});

// GOOD
test('good: auto-retrying assertion', async ({ page }) => {
  await page.goto('/dashboard');
  await page.getByRole('button', { name: 'Load' }).click();
  await expect(page.getByTestId('chart')).toBeVisible();
});
```

**Le seul usage acceptable de `waitForTimeout`** : Déboguer quand `page.pause()` n'est pas disponible, ou simuler un « temps de réflexion » réaliste de l'utilisateur dans des tests de performance. Jamais dans le code de test en production.

---

## Piège 2 : Ne pas `await` les opérations asynchrones

**Symptôme** : Les tests passent de façon imprévisible. Les assertions s'exécutent avant la fin des actions. Les messages d'erreur mentionnent des frames détachées ou des pages fermées.

**Pourquoi ça arrive** : Chaque appel à l'API Playwright est asynchrone. Un seul `await` oublié fait s'exécuter la ligne suivante avant la fin de l'action précédente.

**Correctif** : Mets toujours un `await` devant chaque appel Playwright. Active la règle ESLint `@typescript-eslint/no-floating-promises`.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// BAD — missing await on click, assertion runs before navigation
test('bad: missing await', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@test.com');
  await page.getByLabel('Password').fill('password');
  page.getByRole('button', { name: 'Sign in' }).click(); // MISSING AWAIT
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});

// GOOD
test('good: all actions awaited', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@test.com');
  await page.getByLabel('Password').fill('password');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

// BAD
test('bad: missing await', async ({ page }) => {
  await page.goto('/login');
  page.getByRole('button', { name: 'Submit' }).click(); // MISSING AWAIT
  await expect(page.getByText('Success')).toBeVisible();
});

// GOOD
test('good: all actions awaited', async ({ page }) => {
  await page.goto('/login');
  await page.getByRole('button', { name: 'Submit' }).click();
  await expect(page.getByText('Success')).toBeVisible();
});
```

**Prévention** : Ajoute cette config ESLint pour détecter les promesses flottantes dès la compilation :
```json
{
  "rules": {
    "@typescript-eslint/no-floating-promises": "error"
  }
}
```

---

## Piège 3 : Utiliser des sélecteurs CSS au lieu de locators basés sur les rôles

**Symptôme** : Les tests cassent dès qu'un nom de classe CSS, la structure du DOM ou la bibliothèque de composants change. Les tests sont difficiles à lire, car les sélecteurs ressemblent à `.btn-primary > span:nth-child(2)`.

**Pourquoi ça arrive** : Les développeurs utilisent ce qu'ils connaissent de jQuery ou des DevTools. Les sélecteurs CSS sont des détails d'implémentation qui changent fréquemment.

**Correctif** : Utilise les locators intégrés de Playwright, qui ciblent les rôles accessibles, les labels, le texte et les test IDs.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// BAD — brittle CSS selectors
test('bad: CSS selectors', async ({ page }) => {
  await page.goto('/settings');
  await page.locator('.form-group:nth-child(3) input.form-control').fill('new value');
  await page.locator('button.btn.btn-primary.submit-btn').click();
  await expect(page.locator('.alert.alert-success')).toBeVisible();
});

// GOOD — role-based locators
test('good: accessible locators', async ({ page }) => {
  await page.goto('/settings');
  await page.getByLabel('Display name').fill('new value');
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page.getByRole('alert')).toHaveText('Settings saved');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

// BAD
test('bad: CSS selectors', async ({ page }) => {
  await page.locator('.form-group:nth-child(3) input').fill('new value');
  await page.locator('button.btn-primary').click();
});

// GOOD
test('good: accessible locators', async ({ page }) => {
  await page.getByLabel('Display name').fill('new value');
  await page.getByRole('button', { name: 'Save' }).click();
});
```

**Priorité des locators** (du plus résilient au moins résilient) :
1. `getByRole()` -- rôle accessible + nom
2. `getByLabel()` -- champs de formulaire par le texte de leur label
3. `getByPlaceholder()` -- inputs par leur placeholder
4. `getByText()` -- contenu textuel visible
5. `getByTestId()` -- attribut `data-testid` stable
6. Sélecteurs CSS/XPath -- en dernier recours uniquement

---

## Piège 4 : Asserter sur la valeur retournée par `isVisible()` au lieu de `expect().toBeVisible()`

**Symptôme** : Le test passe alors que l'élément n'est pas visible. L'assertion est silencieusement fausse. Flaky quand le timing est serré.

**Pourquoi ça arrive** : `isVisible()` retourne un booléen à un instant donné -- sans retry. Si l'élément n'est pas encore apparu, il retourne `false` et `expect(false).toBe(true)` échoue immédiatement sans attendre.

**Correctif** : Utilise toujours `expect(locator).toBeVisible()`, qui réessaie automatiquement jusqu'à ce que l'élément apparaisse ou que le timeout expire.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// BAD — resolves once, no retry
test('bad: isVisible check', async ({ page }) => {
  await page.goto('/dashboard');
  const visible = await page.getByTestId('widget').isVisible();
  expect(visible).toBe(true); // Fails immediately if widget hasn't rendered yet
});

// GOOD — auto-retries for up to 5 seconds
test('good: toBeVisible assertion', async ({ page }) => {
  await page.goto('/dashboard');
  await expect(page.getByTestId('widget')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

// BAD
test('bad: isVisible check', async ({ page }) => {
  const visible = await page.getByTestId('widget').isVisible();
  expect(visible).toBe(true);
});

// GOOD
test('good: toBeVisible assertion', async ({ page }) => {
  await expect(page.getByTestId('widget')).toBeVisible();
});
```

Cela vaut pour toutes les méthodes qui « résolvent une seule fois » : `isVisible()`, `isEnabled()`, `isChecked()`, `textContent()`, `getAttribute()`, `inputValue()`. Utilise toujours l'équivalent en assertion web-first `expect(locator)`.

---

## Piège 5 : Partager un état mutable entre des tests parallèles

**Symptôme** : Les tests passent seuls mais échouent dans la suite complète. Échecs dépendants de l'ordre. Erreurs « Duplicate key ».

**Pourquoi ça arrive** : Des variables de niveau module, des lignes de base de données partagées ou un état créé dans `beforeAll` sont modifiés par un test et vus par un autre qui tourne en parallèle.

**Correctif** : Utilise des fixtures à portée de test avec des données uniques. Ne stocke jamais d'état mutable dans des variables de niveau module.

**TypeScript**
```typescript
import { test as base, expect } from '@playwright/test';

// BAD — module-level mutable state shared across parallel tests
let userId: string;

test.beforeAll(async ({ request }) => {
  const res = await request.post('/api/users', {
    data: { email: 'shared@test.com' },
  });
  userId = (await res.json()).id; // Every parallel worker overwrites this
});

test('bad: uses shared state', async ({ page }) => {
  await page.goto(`/users/${userId}`); // userId may be from another worker
});

// GOOD — test-scoped fixture with unique data per test
export const test = base.extend<{ testUser: { id: string; email: string } }>({
  testUser: async ({ request }, use) => {
    const email = `user-${Date.now()}-${Math.random().toString(36).slice(2)}@test.com`;
    const res = await request.post('/api/users', { data: { email } });
    const user = await res.json();

    await use({ id: user.id, email });

    await request.delete(`/api/users/${user.id}`);
  },
});

test('good: isolated data per test', async ({ page, testUser }) => {
  await page.goto(`/users/${testUser.id}`);
  await expect(page.getByText(testUser.email)).toBeVisible();
});
```

**JavaScript**
```javascript
const { test: base, expect } = require('@playwright/test');

// GOOD
const test = base.extend({
  testUser: async ({ request }, use) => {
    const email = `user-${Date.now()}-${Math.random().toString(36).slice(2)}@test.com`;
    const res = await request.post('/api/users', { data: { email } });
    const user = await res.json();

    await use({ id: user.id, email });

    await request.delete(`/api/users/${user.id}`);
  },
});

test('good: isolated data per test', async ({ page, testUser }) => {
  await page.goto(`/users/${testUser.id}`);
  await expect(page.getByText(testUser.email)).toBeVisible();
});

module.exports = { test };
```

---

## Piège 6 : Ne pas utiliser `baseURL` (URLs complètes codées en dur)

**Symptôme** : Les tests cassent quand on change d'environnement (local, staging, production). Les chaînes d'URL sont dupliquées partout.

**Pourquoi ça arrive** : Les développeurs commencent avec `page.goto('http://localhost:3000/login')` et ne refactorent jamais.

**Correctif** : Définis `baseURL` dans `playwright.config` et utilise des chemins relatifs dans tous les tests.

**TypeScript**
```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
  },
});
```

```typescript
import { test, expect } from '@playwright/test';

// BAD
test('bad: hardcoded URL', async ({ page }) => {
  await page.goto('http://localhost:3000/login');
});

// GOOD
test('good: relative URL', async ({ page }) => {
  await page.goto('/login');
});
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
  },
});
```

```javascript
const { test, expect } = require('@playwright/test');

// BAD
test('bad: hardcoded URL', async ({ page }) => {
  await page.goto('http://localhost:3000/login');
});

// GOOD
test('good: relative URL', async ({ page }) => {
  await page.goto('/login');
});
```

Lance les tests sur un autre environnement en définissant la variable : `BASE_URL=https://staging.example.com npx playwright test`

---

## Piège 7 : Utiliser `page.$()` au lieu de `page.locator()`

**Symptôme** : Le handle d'élément vaut `null`. Erreurs d'élément obsolète (stale). Pas d'auto-waiting.

**Pourquoi ça arrive** : `page.$()` et `page.$$()` sont des API ElementHandle héritées de Puppeteer. Elles résolvent une seule fois et retournent un handle qui peut devenir obsolète. Les locators sont le remplacement de Playwright -- ils sont lazy et se ré-évaluent à chaque action.

**Correctif** : Utilise toujours `page.locator()`, `page.getByRole()` ou les autres méthodes de locator.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// BAD — ElementHandle API, resolves once, can go stale
test('bad: page.$ usage', async ({ page }) => {
  await page.goto('/products');
  const button = await page.$('.add-to-cart'); // null if not found, stale if DOM changes
  if (button) {
    await button.click();
  }
  const count = await page.$$('.cart-item');
  expect(count.length).toBe(1); // No auto-retry
});

// GOOD — locator API, lazy evaluation, auto-waiting
test('good: locator usage', async ({ page }) => {
  await page.goto('/products');
  await page.getByRole('button', { name: 'Add to cart' }).first().click();
  await expect(page.getByTestId('cart-item')).toHaveCount(1); // Auto-retries
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

// BAD
test('bad: page.$ usage', async ({ page }) => {
  const button = await page.$('.add-to-cart');
  if (button) await button.click();
});

// GOOD
test('good: locator usage', async ({ page }) => {
  await page.getByRole('button', { name: 'Add to cart' }).first().click();
});
```

---

## Piège 8 : Ne pas gérer la navigation après l'envoi d'un formulaire

**Symptôme** : Le test échoue avec « Target page, context or browser has been closed », ou les assertions échouent parce que la page a navigué avant leur exécution.

**Pourquoi ça arrive** : Cliquer sur un bouton d'envoi déclenche une navigation complète. L'assertion s'exécute sur l'ancienne page, en cours de déchargement.

**Correctif** : Attends la fin de la navigation avant d'asserter sur la nouvelle page.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// BAD — assertion runs before navigation completes
test('bad: no navigation handling', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@test.com');
  await page.getByLabel('Password').fill('password');
  await page.getByRole('button', { name: 'Sign in' }).click();
  // Page is navigating — this may fail with "Execution context was destroyed"
  await expect(page.getByRole('heading')).toHaveText('Dashboard');
});

// GOOD — wait for URL to change, then assert
test('good: waitForURL after navigation', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@test.com');
  await page.getByLabel('Password').fill('password');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');
  await expect(page.getByRole('heading')).toHaveText('Dashboard');
});

// GOOD — alternative: use expect().toHaveURL() which auto-retries
test('good: toHaveURL assertion', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@test.com');
  await page.getByLabel('Password').fill('password');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page).toHaveURL(/.*dashboard/);
  await expect(page.getByRole('heading')).toHaveText('Dashboard');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

// GOOD
test('good: waitForURL after navigation', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@test.com');
  await page.getByLabel('Password').fill('password');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');
  await expect(page.getByRole('heading')).toHaveText('Dashboard');
});
```

---

## Piège 9 : Tester contre `localhost` en CI sans config `webServer`

**Symptôme** : Les tests échouent en CI avec `ECONNREFUSED` sur `localhost:3000`. Ça marche en local parce que le serveur de dev tourne déjà.

**Pourquoi ça arrive** : Les runners CI démarrent avec un environnement vierge. Aucun serveur de dev ne tourne, sauf si tu en démarres un explicitement.

**Correctif** : Utilise l'option de config `webServer` pour démarrer ton application automatiquement.

**TypeScript**
```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  use: {
    baseURL: 'http://localhost:3000',
  },

  webServer: {
    command: 'npm run start',
    url: 'http://localhost:3000',
    // Reuse existing server locally (faster), start fresh in CI
    reuseExistingServer: !process.env.CI,
    // Give the server time to start
    timeout: 120_000,
    // Capture server output for debugging startup failures
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  use: {
    baseURL: 'http://localhost:3000',
  },
  webServer: {
    command: 'npm run start',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
```

Pour plusieurs serveurs (frontend + backend), passe un tableau :
```typescript
webServer: [
  { command: 'npm run start:api', url: 'http://localhost:4000/health', reuseExistingServer: !process.env.CI },
  { command: 'npm run start:web', url: 'http://localhost:3000', reuseExistingServer: !process.env.CI },
],
```

---

## Piège 10 : Utiliser `innerHTML` pour des assertions de texte au lieu de `toHaveText()`

**Symptôme** : Les tests cassent quand la structure HTML change. Les assertions sont fragiles et difficiles à lire.

**Pourquoi ça arrive** : Les développeurs utilisent `innerHTML()` ou `textContent()` pour récupérer le texte, puis asserent sur la chaîne résolue. Cela résout une seule fois, sans retry.

**Correctif** : Utilise `expect(locator).toHaveText()` ou `expect(locator).toContainText()` pour des assertions de texte avec retry automatique.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// BAD — resolves once, includes HTML tags, no retry
test('bad: innerHTML assertion', async ({ page }) => {
  await page.goto('/product/123');
  const html = await page.getByTestId('price').innerHTML();
  expect(html).toContain('$49.99'); // Brittle: depends on HTML structure
});

// BAD — textContent resolves once, no retry
test('bad: textContent assertion', async ({ page }) => {
  await page.goto('/product/123');
  const text = await page.getByTestId('price').textContent();
  expect(text).toBe('$49.99'); // No retry if text hasn't loaded yet
});

// GOOD — auto-retrying, no HTML dependency
test('good: toHaveText assertion', async ({ page }) => {
  await page.goto('/product/123');
  await expect(page.getByTestId('price')).toHaveText('$49.99');
});

// GOOD — partial match for flexible assertions
test('good: toContainText assertion', async ({ page }) => {
  await page.goto('/product/123');
  await expect(page.getByTestId('price')).toContainText('$49');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

// BAD
test('bad: textContent assertion', async ({ page }) => {
  const text = await page.getByTestId('price').textContent();
  expect(text).toBe('$49.99');
});

// GOOD
test('good: toHaveText assertion', async ({ page }) => {
  await expect(page.getByTestId('price')).toHaveText('$49.99');
});
```

---

## Piège 11 : Trop de mocks (mocker sa propre API)

**Symptôme** : Tous les tests passent mais l'application est cassée en production. Les réponses mockées divergent de la vraie API. Fausse confiance.

**Pourquoi ça arrive** : Les développeurs mockent chaque appel d'API pour la vitesse et la stabilité, y compris leur propre backend. Les mocks deviennent obsolètes à mesure que la vraie API évolue.

**Correctif** : Ne mocke que les services tiers externes. Teste ta propre API pour de vrai. Utilise `webServer` pour lancer ton backend pendant les tests.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// BAD — mocking your own API removes confidence
test('bad: mocks own API', async ({ page }) => {
  await page.route('**/api/users/me', (route) =>
    route.fulfill({
      status: 200,
      body: JSON.stringify({ name: 'Test User', role: 'admin' }),
    })
  );
  await page.goto('/dashboard');
  await expect(page.getByText('Test User')).toBeVisible(); // Passes even if API is broken
});

// GOOD — mock only external services, test your own API for real
test('good: real API, mocked externals', async ({ page }) => {
  // Block third-party analytics and ads
  await page.route(/google-analytics|intercom|segment/, (route) => route.abort());

  // Stub a flaky external payment provider
  await page.route('**/api.stripe.com/**', (route) =>
    route.fulfill({
      status: 200,
      body: JSON.stringify({ status: 'succeeded' }),
    })
  );

  // Test against the real app API
  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

// GOOD — mock only external services
test('good: real API, mocked externals', async ({ page }) => {
  await page.route(/google-analytics|intercom|segment/, (route) => route.abort());

  await page.route('**/api.stripe.com/**', (route) =>
    route.fulfill({
      status: 200,
      body: JSON.stringify({ status: 'succeeded' }),
    })
  );

  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

**Quand mocker sa propre API est acceptable** : Tester des états d'erreur précis (500, 503, timeout réseau) ou des cas limites difficiles à reproduire avec un vrai backend.

---

## Piège 12 : Ne pas utiliser `test.describe` pour grouper

**Symptôme** : Les fichiers de test sont des listes plates de tests sans rapport. La configuration partagée (`test.use()`, `test.beforeEach()`) ne peut pas être scopée. Les rapports HTML sont difficiles à parcourir.

**Pourquoi ça arrive** : Les développeurs écrivent les tests en liste plate, sans jamais regrouper les tests liés.

**Correctif** : Groupe les tests liés avec `test.describe`. Utilise-le pour scoper le setup partagé, les surcharges de configuration et l'organisation logique.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// BAD — flat list, no grouping, no shared context
test('admin can view users', async ({ page }) => { /* ... */ });
test('admin can delete user', async ({ page }) => { /* ... */ });
test('viewer cannot delete user', async ({ page }) => { /* ... */ });
test('viewer can view users', async ({ page }) => { /* ... */ });

// GOOD — grouped by role, scoped configuration
test.describe('admin users', () => {
  test.use({ storageState: '.auth/admin.json' });

  test.beforeEach(async ({ page }) => {
    await page.goto('/admin/users');
  });

  test('can view user list', async ({ page }) => {
    await expect(page.getByRole('table')).toBeVisible();
  });

  test('can delete a user', async ({ page }) => {
    await page.getByRole('row').first().getByRole('button', { name: 'Delete' }).click();
    await expect(page.getByRole('dialog')).toBeVisible();
  });
});

test.describe('viewer users', () => {
  test.use({ storageState: '.auth/viewer.json' });

  test('can view user list', async ({ page }) => {
    await page.goto('/admin/users');
    await expect(page.getByRole('table')).toBeVisible();
  });

  test('cannot see delete button', async ({ page }) => {
    await page.goto('/admin/users');
    await expect(page.getByRole('button', { name: 'Delete' })).not.toBeVisible();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('admin users', () => {
  test.use({ storageState: '.auth/admin.json' });

  test.beforeEach(async ({ page }) => {
    await page.goto('/admin/users');
  });

  test('can view user list', async ({ page }) => {
    await expect(page.getByRole('table')).toBeVisible();
  });

  test('can delete a user', async ({ page }) => {
    await page.getByRole('row').first().getByRole('button', { name: 'Delete' }).click();
    await expect(page.getByRole('dialog')).toBeVisible();
  });
});
```

---

## Piège 13 : Utiliser `beforeAll` pour le setup propre à chaque test

**Symptôme** : Des tests qui devraient être indépendants partagent l'état issu de `beforeAll`. Un test modifie l'état et les tests suivants échouent.

**Pourquoi ça arrive** : Les développeurs pensent que `beforeAll` est « plus efficace » parce qu'il ne s'exécute qu'une fois. Mais `beforeAll` crée un état à portée de worker que tous les tests du fichier partagent.

**Correctif** : Utilise `beforeEach` pour le setup propre à chaque test, ou des fixtures à portée de test pour le setup qui nécessite un teardown.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// BAD — beforeAll creates one user for all tests; tests mutate shared state
test.beforeAll(async ({ request }) => {
  // This user is shared across all tests in this file
  await request.post('/api/users', { data: { email: 'shared@test.com', name: 'Original' } });
});

test('updates user name', async ({ page }) => {
  await page.goto('/users/shared@test.com');
  await page.getByLabel('Name').fill('Updated');
  await page.getByRole('button', { name: 'Save' }).click();
  // Now the shared user has name "Updated" — other tests see this
});

test('checks user name is Original', async ({ page }) => {
  await page.goto('/users/shared@test.com');
  // FAILS — previous test changed the name
  await expect(page.getByLabel('Name')).toHaveValue('Original');
});

// GOOD — each test creates its own user
test.describe('user profile', () => {
  test('updates user name', async ({ page, request }) => {
    const email = `user-${Date.now()}@test.com`;
    await request.post('/api/users', { data: { email, name: 'Original' } });

    await page.goto(`/users/${email}`);
    await page.getByLabel('Name').fill('Updated');
    await page.getByRole('button', { name: 'Save' }).click();
    await expect(page.getByLabel('Name')).toHaveValue('Updated');
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

// GOOD — per-test data creation
test('updates user name', async ({ page, request }) => {
  const email = `user-${Date.now()}@test.com`;
  await request.post('/api/users', { data: { email, name: 'Original' } });

  await page.goto(`/users/${email}`);
  await page.getByLabel('Name').fill('Updated');
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page.getByLabel('Name')).toHaveValue('Updated');
});
```

---

## Piège 14 : Stocker des données de test dans des variables partagées entre tests

**Symptôme** : Le test B dépend de données créées dans le test A. Réordonner les tests ou les lancer en parallèle casse la suite.

**Pourquoi ça arrive** : Les développeurs déclarent des variables `let` au niveau module et les assignent dans un test, en s'attendant à ce qu'un autre test les lise.

**Correctif** : Chaque test doit créer ses propres données. Utilise des fixtures pour la logique de setup partagée.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// BAD — test B depends on test A creating the product
let productId: string;

test('test A: creates product', async ({ request }) => {
  const res = await request.post('/api/products', { data: { name: 'Widget' } });
  productId = (await res.json()).id;
});

test('test B: edits product', async ({ page }) => {
  await page.goto(`/products/${productId}/edit`); // undefined if test A didn't run first
});

// GOOD — each test is self-contained
test('creates and edits product', async ({ page, request }) => {
  const res = await request.post('/api/products', { data: { name: `Widget-${Date.now()}` } });
  const { id } = await res.json();

  await page.goto(`/products/${id}/edit`);
  await page.getByLabel('Name').fill('Updated Widget');
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page.getByText('Updated Widget')).toBeVisible();

  // Cleanup
  await request.delete(`/api/products/${id}`);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

// GOOD — self-contained test
test('creates and edits product', async ({ page, request }) => {
  const res = await request.post('/api/products', { data: { name: `Widget-${Date.now()}` } });
  const { id } = await res.json();

  await page.goto(`/products/${id}/edit`);
  await page.getByLabel('Name').fill('Updated Widget');
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page.getByText('Updated Widget')).toBeVisible();

  await request.delete(`/api/products/${id}`);
});
```

---

## Piège 15 : Imbriquer profondément les blocs `test.describe`

**Symptôme** : La structure des tests fait 3 niveaux ou plus. Difficile à lire. Les hooks `beforeEach` des blocs externes sont invisibles au niveau du test. Les rapports HTML sont encombrés.

**Pourquoi ça arrive** : Les développeurs organisent les tests comme ils organisent le code -- en hiérarchies profondément imbriquées. Mais les tests doivent rester plats et faciles à parcourir.

**Correctif** : Limite l'imbrication à 2 niveaux maximum. Utilise des fichiers séparés plutôt qu'une imbrication profonde.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// BAD — 4 levels deep, impossible to follow
test.describe('admin', () => {
  test.describe('settings', () => {
    test.describe('security', () => {
      test.describe('two-factor auth', () => {
        test('enables TOTP', async ({ page }) => {
          // Which beforeEach hooks ran before this? Good luck figuring out.
        });
      });
    });
  });
});

// GOOD — max 2 levels, clear and flat
test.describe('admin security settings', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/admin/settings/security');
  });

  test('enables two-factor auth via TOTP', async ({ page }) => {
    await page.getByRole('button', { name: 'Enable 2FA' }).click();
    await expect(page.getByText('Scan QR code')).toBeVisible();
  });

  test('disables two-factor auth', async ({ page }) => {
    await page.getByRole('button', { name: 'Disable 2FA' }).click();
    await expect(page.getByRole('dialog')).toBeVisible();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

// GOOD — flat structure, max 2 levels
test.describe('admin security settings', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/admin/settings/security');
  });

  test('enables two-factor auth via TOTP', async ({ page }) => {
    await page.getByRole('button', { name: 'Enable 2FA' }).click();
    await expect(page.getByText('Scan QR code')).toBeVisible();
  });
});
```

Si tu dois organiser beaucoup de tests, découpe-les en fichiers séparés : `security-2fa.spec.ts`, `security-passwords.spec.ts`, `security-sessions.spec.ts`.

---

## Piège 16 : Ne pas configurer les retries différemment en local et en CI

**Symptôme** : Les développeurs utilisent des retries en local (ce qui masque les bugs pendant le développement) ou n'en ont pas en CI (échecs sur des problèmes intermittents qui ne sont pas de leur faute).

**Pourquoi ça arrive** : Une seule valeur de `retries` est définie sans tenir compte de l'environnement.

**Correctif** : Zéro retry en local (échouer vite), 1 à 2 retries en CI (absorber les accrocs d'infrastructure).

**TypeScript**
```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  // GOOD — different retry strategy per environment
  retries: process.env.CI ? 2 : 0,

  use: {
    // Only capture traces on retry — saves CI time and storage
    trace: 'on-first-retry',
  },
});
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  retries: process.env.CI ? 2 : 0,
  use: {
    trace: 'on-first-retry',
  },
});
```

**Important** : Un test qui a systématiquement besoin de retries pour passer ne « passe » pas -- il est flaky. Suis le nombre de retries et corrige la cause racine.

---

## Piège 17 : Lancer tous les navigateurs à chaque run CI

**Symptôme** : La CI prend 3 fois plus de temps que nécessaire. La plupart des bugs sont détectés par un seul moteur de navigateur.

**Pourquoi ça arrive** : Les développeurs activent Chromium + Firefox + WebKit dans la config et ne remettent jamais cela en question.

**Correctif** : Lance Chromium sur chaque PR. Lance tous les navigateurs dans un job nightly ou de pré-release.

**TypeScript**
```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

const allBrowsers = [
  { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
  { name: 'webkit', use: { ...devices['Desktop Safari'] } },
];

const chromeOnly = [
  { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
];

export default defineConfig({
  // PR runs: Chromium only. Nightly: all browsers.
  projects: process.env.ALL_BROWSERS ? allBrowsers : chromeOnly,
});
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig, devices } = require('@playwright/test');

const allBrowsers = [
  { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
  { name: 'webkit', use: { ...devices['Desktop Safari'] } },
];

const chromeOnly = [
  { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
];

module.exports = defineConfig({
  projects: process.env.ALL_BROWSERS ? allBrowsers : chromeOnly,
});
```

```yaml
# .github/workflows/tests.yml
jobs:
  pr-tests:
    # Fast: Chromium only
    runs-on: ubuntu-latest
    steps:
      - run: npx playwright test

  nightly-full:
    # Comprehensive: all browsers
    schedule:
      - cron: '0 3 * * *'
    steps:
      - run: ALL_BROWSERS=1 npx playwright test
```

---

## Piège 18 : Utiliser `page.evaluate()` pour ce que les locators savent faire

**Symptôme** : Les tests sont verbeux et fragiles. La manipulation directe du DOM contourne l'auto-waiting et les vérifications d'actionnabilité de Playwright.

**Pourquoi ça arrive** : Les développeurs venant du JS vanilla ou de Puppeteer utilisent `evaluate()` pour tout parce que c'est familier.

**Correctif** : Utilise les méthodes de locator pour toutes les interactions avec le DOM. Réserve `page.evaluate()` à ce que les locators ne peuvent vraiment pas faire (lire des styles calculés, appeler des API JS propres à l'application, mettre en place des hooks de test).

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// BAD — using evaluate for things locators handle better
test('bad: evaluate for DOM interaction', async ({ page }) => {
  await page.goto('/settings');

  // Getting text
  const text = await page.evaluate(() =>
    document.querySelector('[data-testid="username"]')?.textContent
  );
  expect(text).toBe('John');

  // Clicking
  await page.evaluate(() => {
    (document.querySelector('button.save-btn') as HTMLButtonElement)?.click();
  });

  // Checking visibility
  const visible = await page.evaluate(() => {
    const el = document.querySelector('.success-message');
    return el ? window.getComputedStyle(el).display !== 'none' : false;
  });
  expect(visible).toBe(true);
});

// GOOD — locators with auto-waiting and retry
test('good: locator methods', async ({ page }) => {
  await page.goto('/settings');

  await expect(page.getByTestId('username')).toHaveText('John');
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page.getByText('Settings saved')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

// BAD
test('bad: evaluate for DOM interaction', async ({ page }) => {
  const text = await page.evaluate(() =>
    document.querySelector('[data-testid="username"]')?.textContent
  );
  expect(text).toBe('John');
});

// GOOD
test('good: locator methods', async ({ page }) => {
  await expect(page.getByTestId('username')).toHaveText('John');
});
```

**Quand `evaluate()` est approprié** : Lire `window.__APP_STATE__`, appeler des fonctions de setup propres aux tests exposées par l'application, manipuler `localStorage`/`sessionStorage`, ou lire des styles calculés sans équivalent en locator.

---

## Piège 19 : Ne pas utiliser `test.step()` pour les parcours complexes

**Symptôme** : Les tests longs sont difficiles à déboguer. Quand ils échouent, la trace montre plus de 50 actions sans regroupement logique. Le rapport HTML n'offre aucune structure.

**Pourquoi ça arrive** : Les développeurs écrivent les tests comme une suite linéaire d'actions, sans nommer les phases.

**Correctif** : Enveloppe les phases logiques dans `test.step()`. Les steps apparaissent dans les traces, les rapports et les messages d'erreur.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// BAD — 30 lines of actions with no structure
test('bad: flat checkout flow', async ({ page }) => {
  await page.goto('/products');
  await page.getByRole('button', { name: 'Add Widget' }).click();
  await page.getByRole('link', { name: 'Cart' }).click();
  await page.getByRole('button', { name: 'Checkout' }).click();
  await page.getByLabel('Email').fill('user@test.com');
  await page.getByLabel('Address').fill('123 Test St');
  await page.getByRole('button', { name: 'Continue' }).click();
  await page.getByLabel('Card number').fill('4242424242424242');
  await page.getByRole('button', { name: 'Pay' }).click();
  await expect(page.getByText('Order confirmed')).toBeVisible();
});

// GOOD — logical steps, clear in traces and reports
test('good: structured checkout flow', async ({ page }) => {
  await test.step('add item to cart', async () => {
    await page.goto('/products');
    await page.getByRole('button', { name: 'Add Widget' }).click();
    await expect(page.getByTestId('cart-count')).toHaveText('1');
  });

  await test.step('proceed to checkout', async () => {
    await page.getByRole('link', { name: 'Cart' }).click();
    await page.getByRole('button', { name: 'Checkout' }).click();
    await expect(page).toHaveURL(/.*checkout/);
  });

  await test.step('fill shipping details', async () => {
    await page.getByLabel('Email').fill('user@test.com');
    await page.getByLabel('Address').fill('123 Test St');
    await page.getByRole('button', { name: 'Continue' }).click();
  });

  await test.step('complete payment', async () => {
    await page.getByLabel('Card number').fill('4242424242424242');
    await page.getByRole('button', { name: 'Pay' }).click();
    await expect(page.getByText('Order confirmed')).toBeVisible();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('good: structured checkout flow', async ({ page }) => {
  await test.step('add item to cart', async () => {
    await page.goto('/products');
    await page.getByRole('button', { name: 'Add Widget' }).click();
    await expect(page.getByTestId('cart-count')).toHaveText('1');
  });

  await test.step('proceed to checkout', async () => {
    await page.getByRole('link', { name: 'Cart' }).click();
    await page.getByRole('button', { name: 'Checkout' }).click();
  });

  await test.step('fill shipping details', async () => {
    await page.getByLabel('Email').fill('user@test.com');
    await page.getByLabel('Address').fill('123 Test St');
    await page.getByRole('button', { name: 'Continue' }).click();
  });

  await test.step('complete payment', async () => {
    await page.getByLabel('Card number').fill('4242424242424242');
    await page.getByRole('button', { name: 'Pay' }).click();
    await expect(page.getByText('Order confirmed')).toBeVisible();
  });
});
```

Quand un step échoue, le message d'erreur inclut le nom du step : `Error in step "complete payment": ...`. C'est nettement plus utile que les seuls numéros de ligne.

---

## Piège 20 : Capturer les erreurs d'assertion (try/catch autour de expect)

**Symptôme** : Les tests passent alors qu'ils devraient échouer. Les erreurs d'assertion sont avalées en silence. De vrais bugs passent inaperçus.

**Pourquoi ça arrive** : Les développeurs enveloppent les assertions dans un try/catch pour gérer des éléments « optionnels » ou implémenter une logique conditionnelle. Cela annule l'intérêt des assertions.

**Correctif** : Utilise `expect.soft()` pour les vérifications non critiques, des assertions `.not` pour les éléments absents, ou restructure le test pour éviter la logique conditionnelle.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// BAD — swallows real failures
test('bad: try/catch around assertion', async ({ page }) => {
  await page.goto('/dashboard');

  try {
    await expect(page.getByRole('alert')).toBeVisible({ timeout: 2_000 });
    // Dismiss the alert if it exists
    await page.getByRole('button', { name: 'Dismiss' }).click();
  } catch {
    // Alert didn't appear — that's fine
  }

  await expect(page.getByRole('heading')).toHaveText('Dashboard');
});

// GOOD — check count to determine if element exists, no try/catch needed
test('good: conditional without try/catch', async ({ page }) => {
  await page.goto('/dashboard');

  // If an alert banner is present, dismiss it
  const alertCount = await page.getByRole('alert').count();
  if (alertCount > 0) {
    await page.getByRole('button', { name: 'Dismiss' }).click();
    await expect(page.getByRole('alert')).not.toBeVisible();
  }

  await expect(page.getByRole('heading')).toHaveText('Dashboard');
});

// GOOD — use soft assertions for non-critical checks
test('good: soft assertions for nice-to-have checks', async ({ page }) => {
  await page.goto('/dashboard');

  // These are informational — test continues even if they fail
  await expect.soft(page.getByTestId('revenue')).toContainText('$');
  await expect.soft(page.getByTestId('users')).toContainText('active');

  // This is the actual assertion — test fails if this fails
  await expect(page.getByRole('heading')).toHaveText('Dashboard');
});

// GOOD — assert element is NOT present (no try/catch needed)
test('good: assert absence directly', async ({ page }) => {
  await page.goto('/dashboard');

  // This auto-retries until the error disappears (or times out)
  await expect(page.getByRole('alert')).not.toBeVisible();

  await expect(page.getByRole('heading')).toHaveText('Dashboard');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

// GOOD — conditional without try/catch
test('good: conditional without try/catch', async ({ page }) => {
  await page.goto('/dashboard');

  const alertCount = await page.getByRole('alert').count();
  if (alertCount > 0) {
    await page.getByRole('button', { name: 'Dismiss' }).click();
    await expect(page.getByRole('alert')).not.toBeVisible();
  }

  await expect(page.getByRole('heading')).toHaveText('Dashboard');
});

// GOOD — soft assertions for non-critical checks
test('good: soft assertions for nice-to-have checks', async ({ page }) => {
  await page.goto('/dashboard');

  await expect.soft(page.getByTestId('revenue')).toContainText('$');
  await expect.soft(page.getByTestId('users')).toContainText('active');

  await expect(page.getByRole('heading')).toHaveText('Dashboard');
});
```

**Règle** : Si tu te retrouves à écrire un `try/catch` autour d'un `expect()`, la conception du test est mauvaise. Repense l'assertion.

---

## Table de référence rapide

| # | Piège | Correctif en une ligne |
|---|---|---|
| 1 | `waitForTimeout()` | Remplacer par `expect(locator).toBeVisible()` |
| 2 | `await` manquant | Ajouter `await` + activer la règle ESLint `no-floating-promises` |
| 3 | Sélecteurs CSS | Utiliser `getByRole()`, `getByLabel()`, `getByTestId()` |
| 4 | Vérification avec `isVisible()` | Utiliser `expect(locator).toBeVisible()` |
| 5 | État mutable partagé | Utiliser des fixtures à portée de test avec des données uniques |
| 6 | URLs codées en dur | Définir `baseURL` dans la config, utiliser des chemins relatifs |
| 7 | `page.$()` / `page.$$()` | Utiliser `page.locator()` ou `page.getByRole()` |
| 8 | Navigation non gérée | Ajouter `page.waitForURL()` après l'envoi d'un formulaire |
| 9 | Pas de `webServer` en CI | Ajouter la config `webServer` avec `reuseExistingServer: !process.env.CI` |
| 10 | `innerHTML` / `textContent` | Utiliser `expect(locator).toHaveText()` |
| 11 | Trop de mocks sur sa propre API | Ne mocker que les services externes |
| 12 | Pas de `test.describe` | Grouper les tests liés, scoper `beforeEach` et `test.use()` |
| 13 | `beforeAll` pour le setup par test | Utiliser `beforeEach` ou des fixtures à portée de test |
| 14 | Variables de données de test au niveau module | Créer les données dans chaque test ou via des fixtures |
| 15 | `describe` trop imbriqués (3+) | 2 niveaux max ; découper en fichiers séparés |
| 16 | Mêmes retries partout | `retries: process.env.CI ? 2 : 0` |
| 17 | Tous les navigateurs à chaque PR | Chromium sur les PR, matrice complète en nightly |
| 18 | Abus de `page.evaluate()` | Utiliser les méthodes de locator ; réserver `evaluate` aux API JS |
| 19 | Pas de `test.step()` | Envelopper les phases logiques dans des steps nommés |
| 20 | `try/catch` autour de `expect` | Utiliser `expect.soft()`, `.not` ou `locator.count()` |

## Voir aussi

- [core/locators.md](locators.md) -- hiérarchie des stratégies de locators (Pièges 3, 7, 18)
- [core/assertions-and-waiting.md](assertions-and-waiting.md) -- assertions web-first (Pièges 1, 4, 10, 20)
- [core/fixtures-and-hooks.md](fixtures-and-hooks.md) -- fixtures vs hooks (Pièges 5, 13, 14)
- [core/configuration.md](configuration.md) -- baseURL, webServer, retries (Pièges 6, 9, 16, 17)
- [core/test-organization.md](test-organization.md) -- blocs describe, imbrication, tags (Pièges 12, 15)
- [core/flaky-tests.md](flaky-tests.md) -- diagnostiquer et corriger les tests flaky (Pièges 1, 2, 5)
- [core/debugging.md](debugging.md) -- traces, mode UI, page.pause()
