# Assertions et attentes

> **Quand l'utiliser** : à chaque fois que tu écris un appel `expect()`, que tu attends une condition, ou que tu te demandes pourquoi un test est flaky à cause du timing.
> **Prérequis** : [core/locators.md](locators.md) pour les stratégies de locators utilisées dans les exemples.

## Référence rapide

```typescript
// Web-first (auto-retry) — ALWAYS prefer these
await expect(page.getByRole('button', { name: 'Submit' })).toBeVisible();
await expect(page.getByRole('heading')).toHaveText('Dashboard');
await expect(page.getByRole('listitem')).toHaveCount(5);

// Negative — auto-retries until condition is met
await expect(page.getByRole('dialog')).not.toBeVisible();

// Soft — collect failures, don't stop test
await expect.soft(page.getByRole('heading')).toHaveText('Title');

// Polling — non-DOM async conditions
await expect.poll(() => getUserCount()).toBe(10);

// Retry a block — multiple assertions that must pass together
await expect(async () => { /* assertions */ }).toPass();
```

## Patterns

### Assertions web-first (auto-retry)

**À utiliser quand** : tu fais une assertion sur un locator — visibilité, texte, attributs, CSS, nombre, valeurs.
**À éviter quand** : tu fais une assertion sur une valeur JavaScript déjà résolue (utilise plutôt des assertions sans retry).

Les assertions web-first réessaient automatiquement jusqu'à ce que la condition soit remplie ou que le timeout expire. Elles sont la colonne vertébrale de tests Playwright fiables.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('web-first assertions demo', async ({ page }) => {
  await page.goto('/products');

  // Visibility
  await expect(page.getByRole('heading', { name: 'Products' })).toBeVisible();

  // Text — exact match
  await expect(page.getByTestId('total')).toHaveText('Total: $99.00');

  // Text — partial match (substring or regex)
  await expect(page.getByTestId('total')).toContainText('$99');
  await expect(page.getByTestId('total')).toHaveText(/Total: \$\d+\.\d{2}/);

  // Element count
  await expect(page.getByRole('listitem')).toHaveCount(5);

  // Attribute
  await expect(page.getByRole('link', { name: 'Docs' })).toHaveAttribute('href', '/docs');

  // CSS property
  await expect(page.getByTestId('alert')).toHaveCSS('background-color', 'rgb(255, 0, 0)');

  // Input value
  await expect(page.getByLabel('Email')).toHaveValue('user@example.com');

  // Class (use toHaveClass for full match, regex for partial)
  await expect(page.getByTestId('card')).toHaveClass(/active/);

  // Enabled / disabled / checked
  await expect(page.getByRole('button', { name: 'Submit' })).toBeEnabled();
  await expect(page.getByRole('checkbox')).toBeChecked();

  // Editable / focused / attached
  await expect(page.getByLabel('Name')).toBeEditable();
  await expect(page.getByLabel('Name')).toBeFocused();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('web-first assertions demo', async ({ page }) => {
  await page.goto('/products');

  await expect(page.getByRole('heading', { name: 'Products' })).toBeVisible();
  await expect(page.getByTestId('total')).toHaveText('Total: $99.00');
  await expect(page.getByTestId('total')).toContainText('$99');
  await expect(page.getByTestId('total')).toHaveText(/Total: \$\d+\.\d{2}/);
  await expect(page.getByRole('listitem')).toHaveCount(5);
  await expect(page.getByRole('link', { name: 'Docs' })).toHaveAttribute('href', '/docs');
  await expect(page.getByTestId('alert')).toHaveCSS('background-color', 'rgb(255, 0, 0)');
  await expect(page.getByLabel('Email')).toHaveValue('user@example.com');
  await expect(page.getByTestId('card')).toHaveClass(/active/);
  await expect(page.getByRole('button', { name: 'Submit' })).toBeEnabled();
  await expect(page.getByRole('checkbox')).toBeChecked();
  await expect(page.getByLabel('Name')).toBeEditable();
  await expect(page.getByLabel('Name')).toBeFocused();
});
```

#### Asserter les styles de pseudo-éléments (`toHaveCSS({ pseudo })`, Playwright 1.60+)

**À utiliser quand** : le style qui t'intéresse se trouve sur un pseudo-élément `::before` ou `::after` — glyphes d'icônes (`content`), barres décoratives, astérisques de champs obligatoires, tooltips.
**À éviter quand** : le style est sur l'élément lui-même ; ne passe pas l'option `pseudo`.

Playwright 1.60 ajoute une option `pseudo` à `toHaveCSS()`, ce qui te permet d'asserter directement les styles calculés des pseudo-éléments au lieu de passer par `getComputedStyle` via `evaluate`.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('required field shows a red asterisk via ::after', async ({ page }) => {
  await page.goto('/register');

  const label = page.getByText('Email', { exact: true });

  // Verify the ::after content and color of the "required" marker
  await expect(label).toHaveCSS('content', '"*"', { pseudo: 'after' });
  await expect(label).toHaveCSS('color', 'rgb(220, 38, 38)', { pseudo: 'after' });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('required field shows a red asterisk via ::after', async ({ page }) => {
  await page.goto('/register');

  const label = page.getByText('Email', { exact: true });
  await expect(label).toHaveCSS('content', '"*"', { pseudo: 'after' });
});
```

### Assertions sans retry

**À utiliser quand** : la valeur est déjà résolue — une variable JavaScript, un corps de réponse d'API, un titre de page issu de `page.title()`, ou une URL issue de `page.url()`.
**À éviter quand** : tu asserts sur quelque chose qui peut changer de façon asynchrone dans le DOM. Utilise plutôt des assertions web-first.

Les assertions sans retry s'exécutent une seule fois. Si elles échouent, elles échouent immédiatement.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('non-retrying assertions for resolved values', async ({ page }) => {
  await page.goto('/api/health');

  // Already-resolved values — no retry needed
  const title = await page.title();
  expect(title).toBe('Health Check');

  const url = page.url();
  expect(url).toContain('/api/health');

  // API response body
  const response = await page.request.get('/api/users');
  const body = await response.json();
  expect(body.users).toHaveLength(3);
  expect(response.status()).toBe(200);

  // Snapshot (value comparison, not retrying)
  expect(body).toMatchObject({ status: 'healthy', users: expect.any(Array) });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('non-retrying assertions for resolved values', async ({ page }) => {
  await page.goto('/api/health');

  const title = await page.title();
  expect(title).toBe('Health Check');

  const url = page.url();
  expect(url).toContain('/api/health');

  const response = await page.request.get('/api/users');
  const body = await response.json();
  expect(body.users).toHaveLength(3);
  expect(response.status()).toBe(200);

  expect(body).toMatchObject({ status: 'healthy', users: expect.any(Array) });
});
```

### Assertions négatives

**À utiliser quand** : tu vérifies que quelque chose a disparu, a été supprimé ou n'est pas présent.
**À éviter quand** : jamais.

Les assertions négatives web-first réessaient automatiquement jusqu'à ce que la condition soit remplie. C'est crucial : `expect(locator).not.toBeVisible()` attend correctement que l'élément disparaisse. Elle ne vérifie pas juste une fois.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('verify element disappears after action', async ({ page }) => {
  await page.goto('/notifications');

  // Dismiss a notification
  await page.getByRole('button', { name: 'Dismiss' }).click();

  // Auto-retries until the notification is gone — correct
  await expect(page.getByRole('alert')).not.toBeVisible();

  // Verify text is not present
  await expect(page.getByText('Error occurred')).not.toBeVisible();

  // Verify element is detached from DOM entirely
  await expect(page.getByTestId('modal')).not.toBeAttached();

  // Verify count dropped to zero
  await expect(page.getByRole('alert')).toHaveCount(0);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('verify element disappears after action', async ({ page }) => {
  await page.goto('/notifications');

  await page.getByRole('button', { name: 'Dismiss' }).click();

  await expect(page.getByRole('alert')).not.toBeVisible();
  await expect(page.getByText('Error occurred')).not.toBeVisible();
  await expect(page.getByTestId('modal')).not.toBeAttached();
  await expect(page.getByRole('alert')).toHaveCount(0);
});
```

**Piège** : `not.toBeVisible()` passe pour les éléments qui existent mais sont masqués ET pour les éléments absents du DOM. Si tu dois spécifiquement asserter que l'élément est entièrement retiré du DOM (et pas seulement masqué), utilise `not.toBeAttached()`.

### Assertions soft

**À utiliser quand** : tu veux collecter plusieurs échecs dans un même test sans t'arrêter au premier. Courant pour les vérifications de validation de formulaire, les audits du contenu d'un dashboard ou les checklists visuelles.
**À éviter quand** : les assertions suivantes dépendent du résultat des précédentes (si la première échoue, les suivantes peuvent n'avoir aucun sens).

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('dashboard shows all expected widgets', async ({ page }) => {
  await page.goto('/dashboard');

  // All checks run even if earlier ones fail
  await expect.soft(page.getByTestId('revenue-widget')).toBeVisible();
  await expect.soft(page.getByTestId('users-widget')).toBeVisible();
  await expect.soft(page.getByTestId('orders-widget')).toBeVisible();
  await expect.soft(page.getByTestId('revenue-widget')).toContainText('$');
  await expect.soft(page.getByTestId('users-widget')).toContainText('active');

  // Test still fails if any soft assertion failed, but you see ALL failures in the report
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('dashboard shows all expected widgets', async ({ page }) => {
  await page.goto('/dashboard');

  await expect.soft(page.getByTestId('revenue-widget')).toBeVisible();
  await expect.soft(page.getByTestId('users-widget')).toBeVisible();
  await expect.soft(page.getByTestId('orders-widget')).toBeVisible();
  await expect.soft(page.getByTestId('revenue-widget')).toContainText('$');
  await expect.soft(page.getByTestId('users-widget')).toContainText('active');
});
```

**Astuce** : protège les actions suivantes contre les échecs d'assertions soft quand ces actions lèveraient des erreurs déroutantes.

```typescript
await expect.soft(page.getByRole('button', { name: 'Next' })).toBeVisible();
if (test.info().errors.length > 0) return; // bail out — no point continuing
await page.getByRole('button', { name: 'Next' }).click();
```

**Polling soft (Playwright 1.61+)** : `expect.soft.poll()` combine les deux — il interroge une condition asynchrone et enregistre un échec sans arrêter le test :

```typescript
// Audit several async conditions; see every failure in one run
await expect.soft.poll(() => getQueueDepth()).toBe(0);
await expect.soft.poll(() => getFailedJobCount()).toBe(0);
```

### Assertions par polling

**À utiliser quand** : tu attends une condition asynchrone qui n'est ni du DOM ni un locator : disponibilité d'une API, état d'une base de données, existence d'un fichier, interrogation d'un service.
**À éviter quand** : la condition porte sur un élément du DOM. Utilise des assertions web-first sur les locators.

`expect.poll()` appelle une fonction de façon répétée jusqu'à ce que l'assertion passe.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('wait for background job to complete', async ({ page }) => {
  await page.goto('/jobs');
  await page.getByRole('button', { name: 'Start Export' }).click();

  // Poll an API endpoint until the job finishes
  await expect.poll(async () => {
    const response = await page.request.get('/api/jobs/latest');
    const job = await response.json();
    return job.status;
  }, {
    message: 'Expected export job to complete',
    timeout: 30_000,
    intervals: [1_000, 2_000, 5_000], // backoff: 1s, 2s, then every 5s
  }).toBe('completed');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('wait for background job to complete', async ({ page }) => {
  await page.goto('/jobs');
  await page.getByRole('button', { name: 'Start Export' }).click();

  await expect.poll(async () => {
    const response = await page.request.get('/api/jobs/latest');
    const job = await response.json();
    return job.status;
  }, {
    message: 'Expected export job to complete',
    timeout: 30_000,
    intervals: [1_000, 2_000, 5_000],
  }).toBe('completed');
});
```

### Blocs d'assertions avec retry via `toPass()`

**À utiliser quand** : plusieurs assertions ou actions doivent passer ensemble en groupe, et tout le bloc doit être réessayé si une partie échoue. Courant pour les race conditions où les données apparaissent progressivement.
**À éviter quand** : une seule assertion web-first suffit.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('search results update correctly', async ({ page }) => {
  await page.goto('/search');

  await expect(async () => {
    await page.getByLabel('Search').fill('playwright');
    await page.getByRole('button', { name: 'Search' }).click();

    // Both must pass together — retries the whole block
    await expect(page.getByRole('listitem')).toHaveCount(10);
    await expect(page.getByRole('listitem').first()).toContainText('Playwright');
  }).toPass({
    timeout: 15_000,
    intervals: [1_000, 2_000, 5_000],
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('search results update correctly', async ({ page }) => {
  await page.goto('/search');

  await expect(async () => {
    await page.getByLabel('Search').fill('playwright');
    await page.getByRole('button', { name: 'Search' }).click();

    await expect(page.getByRole('listitem')).toHaveCount(10);
    await expect(page.getByRole('listitem').first()).toContainText('Playwright');
  }).toPass({
    timeout: 15_000,
    intervals: [1_000, 2_000, 5_000],
  });
});
```

### Matchers personnalisés

**À utiliser quand** : des assertions propres à ton domaine que tu répètes dans de nombreux tests — format de prix valide, plage de dates, formulaire accessible, etc.
**À éviter quand** : l'assertion n'est utilisée que dans un seul test. Écris-la inline.

**TypeScript**
```typescript
// fixtures/custom-matchers.ts
import { expect, type Locator } from '@playwright/test';

expect.extend({
  async toHaveValidPrice(locator: Locator) {
    const assertionName = 'toHaveValidPrice';
    let pass: boolean;
    let matcherResult: any;

    try {
      await expect(locator).toHaveText(/^\$\d{1,3}(,\d{3})*\.\d{2}$/);
      pass = true;
    } catch (e: any) {
      matcherResult = e.matcherResult;
      pass = false;
    }

    const message = pass
      ? () => `${this.utils.matcherHint(assertionName, undefined, undefined, { isNot: this.isNot })}\n\nLocator: ${locator}\nExpected: not a valid price format\nReceived: ${matcherResult?.actual || 'valid price'}`
      : () => `${this.utils.matcherHint(assertionName, undefined, undefined, { isNot: this.isNot })}\n\nLocator: ${locator}\nExpected: valid price format ($X,XXX.XX)\nReceived: ${matcherResult?.actual || 'no text'}`;

    return { message, pass, name: assertionName, expected: 'valid price format', actual: matcherResult?.actual };
  },
});

// Declare types for TypeScript
export {};
declare global {
  namespace PlaywrightTest {
    interface Matchers<R, T> {
      toHaveValidPrice(): R;
    }
  }
}
```

```typescript
// tests/products.spec.ts
import { test, expect } from '@playwright/test';
import '../fixtures/custom-matchers';

test('product prices are valid', async ({ page }) => {
  await page.goto('/products');
  await expect(page.getByTestId('price-tag').first()).toHaveValidPrice();
});
```

**JavaScript**
```javascript
// fixtures/custom-matchers.js
const { expect } = require('@playwright/test');

expect.extend({
  async toHaveValidPrice(locator) {
    const assertionName = 'toHaveValidPrice';
    let pass;
    let matcherResult;

    try {
      await expect(locator).toHaveText(/^\$\d{1,3}(,\d{3})*\.\d{2}$/);
      pass = true;
    } catch (e) {
      matcherResult = e.matcherResult;
      pass = false;
    }

    const message = pass
      ? () => `Expected locator not to have valid price format`
      : () => `Expected locator to have valid price format ($X,XXX.XX), received: ${matcherResult?.actual || 'no text'}`;

    return { message, pass, name: assertionName };
  },
});
```

```javascript
// tests/products.spec.js
const { test, expect } = require('@playwright/test');
require('../fixtures/custom-matchers');

test('product prices are valid', async ({ page }) => {
  await page.goto('/products');
  await expect(page.getByTestId('price-tag').first()).toHaveValidPrice();
});
```

### Auto-waiting (actionability)

**À utiliser quand** : tu n'as pas besoin de l'« utiliser » — comprends-le. Chaque action Playwright (`click`, `fill`, `check`, `selectOption`, etc.) attend automatiquement que l'élément cible soit actionnable avant de continuer.

Playwright vérifie avant d'agir :
| Action | Attend que |
|---|---|
| `click()` | Attaché, visible, stable (sans animation), activé, non masqué par un autre élément |
| `fill()` | Attaché, visible, activé, éditable |
| `check()` | Attaché, visible, stable, activé |
| `selectOption()` | Attaché, visible, activé |
| `hover()` | Attaché, visible, stable |
| `pressSequentially()` | Attaché uniquement (pas de vérifications d'actionability) |

Cela signifie que tu n'as presque jamais besoin d'attentes explicites avant les actions. N'écris PAS `await expect(button).toBeVisible()` avant `await button.click()` — le click attend déjà la visibilité.

Les actions font aussi défiler la cible dans la vue, y compris dans des conteneurs scrollables imbriqués. Depuis la 1.62, passe `scroll: 'none'` (par exemple `click({ scroll: 'none' })`) pour éviter cela ; l'action échoue alors si l'élément n'est pas déjà dans le viewport, ce qui revient à asserter qu'il est atteignable sans défilement.

### Attentes explicites

**À utiliser quand** : tu attends une navigation, des réponses réseau ou des états de chargement de page qui ne sont pas liés à un locator précis.
**À éviter quand** : une assertion web-first sur un locator suffit.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('explicit waits for non-locator conditions', async ({ page }) => {
  await page.goto('/login');

  // Wait for navigation after form submit
  await page.getByLabel('Email').fill('user@test.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign In' }).click();
  await page.waitForURL('/dashboard');
  // can also use glob: await page.waitForURL('**/dashboard');
  // or regex: await page.waitForURL(/.*dashboard/);

  // Wait for a specific API response
  const responsePromise = page.waitForResponse(
    (resp) => resp.url().includes('/api/user') && resp.status() === 200
  );
  await page.getByRole('button', { name: 'Refresh' }).click();
  const response = await responsePromise;
  const data = await response.json();
  expect(data.name).toBe('Test User');

  // Wait for a network request to be sent
  const requestPromise = page.waitForRequest('**/api/analytics');
  await page.getByRole('button', { name: 'Track' }).click();
  const request = await requestPromise;
  expect(request.method()).toBe('POST');

  // Wait for load state
  await page.waitForLoadState('networkidle'); // use sparingly — only for legacy apps
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('explicit waits for non-locator conditions', async ({ page }) => {
  await page.goto('/login');

  await page.getByLabel('Email').fill('user@test.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign In' }).click();
  await page.waitForURL('/dashboard');

  const responsePromise = page.waitForResponse(
    (resp) => resp.url().includes('/api/user') && resp.status() === 200
  );
  await page.getByRole('button', { name: 'Refresh' }).click();
  const response = await responsePromise;
  const data = await response.json();
  expect(data.name).toBe('Test User');

  const requestPromise = page.waitForRequest('**/api/analytics');
  await page.getByRole('button', { name: 'Track' }).click();
  const request = await requestPromise;
  expect(request.method()).toBe('POST');

  await page.waitForLoadState('networkidle');
});
```

**Pattern critique** : mets toujours en place `waitForResponse` / `waitForRequest` AVANT l'action qui le déclenche. Sinon tu as une race condition.

```typescript
// CORRECT — promise registered before the click
const responsePromise = page.waitForResponse('**/api/data');
await page.getByRole('button', { name: 'Load' }).click();
const response = await responsePromise;

// WRONG — response may already have arrived before waitForResponse is registered
await page.getByRole('button', { name: 'Load' }).click();
const response = await page.waitForResponse('**/api/data'); // race condition!
```

### Annuler des actions et des assertions (`signal`, Playwright 1.62+)

Playwright 1.62 accepte un `AbortSignal` standard sur les actions et les assertions, de sorte qu'une opération peut être annulée depuis l'extérieur de son propre timeout.

```javascript
const controller = new AbortController();
setTimeout(() => controller.abort(), 1000);
await page.getByRole('button', { name: 'Submit' }).click({ signal: controller.signal });
await expect(page.getByText('Done')).toBeVisible({ signal: controller.signal });
```

**Ce n'est pas un remplacement des timeouts.** Un timeout exprime « ça aurait déjà dû arriver » et relève de la config. Un signal exprime « ce résultat ne nous intéresse plus » — une course entre 2 flux possibles, un nettoyage quand une fixture est démontée plus tôt, ou l'abandon d'un polling une fois qu'une opération voisine a déjà répondu à la question. Utilise `signal` quand c'est *autre chose* qui décide que l'attente est inutile ; utilise `timeout` quand l'attente elle-même est trop longue.

### Attendre une condition à l'intérieur d'un élément (`locator.waitForFunction()`, Playwright 1.62+)

```javascript
await locator.waitForFunction((element) => element.innerText === 'Ready');
```

Le prédicat reçoit l'élément résolu et se réexécute jusqu'à ce qu'il retourne une valeur truthy. Cela comble un vrai manque : `expect.poll()` interroge une valeur que tu calcules, et les assertions web-first couvrent les matchers intégrés, mais aucun des deux ne lit un état DOM arbitraire sur un élément précis sans passer par `evaluate()`.

**Préfère une assertion web-first quand il en existe une.** `expect(locator).toHaveText('Ready')` est plus clair, produit un meilleur message d'échec et n'envoie pas de fonction dans la page. Utilise `waitForFunction()` pour les conditions qu'aucun matcher ne couvre — un style calculé franchissant un seuil, un canvas atteignant un état, un widget tiers définissant une propriété.

### Timeouts des assertions

**À utiliser quand** : une assertion précise nécessite plus ou moins de temps que la valeur par défaut globale.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// Per-assertion timeout
test('slow element appears eventually', async ({ page }) => {
  await page.goto('/slow-dashboard');

  await expect(page.getByTestId('heavy-chart')).toBeVisible({
    timeout: 30_000, // override for this one assertion
  });
});

// Per-test timeout
test('long-running flow', async ({ page }) => {
  test.setTimeout(120_000);
  await page.goto('/import');
  await page.getByRole('button', { name: 'Import CSV' }).click();
  await expect(page.getByText('Import complete')).toBeVisible({ timeout: 60_000 });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('slow element appears eventually', async ({ page }) => {
  await page.goto('/slow-dashboard');

  await expect(page.getByTestId('heavy-chart')).toBeVisible({
    timeout: 30_000,
  });
});

test('long-running flow', async ({ page }) => {
  test.setTimeout(120_000);
  await page.goto('/import');
  await page.getByRole('button', { name: 'Import CSV' }).click();
  await expect(page.getByText('Import complete')).toBeVisible({ timeout: 60_000 });
});
```

**Timeout global** dans `playwright.config.ts` :
```typescript
export default defineConfig({
  expect: {
    timeout: 10_000, // default is 5_000 — increase for slow apps
  },
  timeout: 30_000,   // per-test timeout (default 30_000)
});
```

## Guide de décision

| Scénario | Approche recommandée | Pourquoi |
|---|---|---|
| Élément visible / masqué | `expect(locator).toBeVisible()` / `.not.toBeVisible()` | Auto-retry, gère le timing |
| Vérification du contenu textuel | `expect(locator).toHaveText()` ou `.toContainText()` | Auto-retry ; utilise `toContainText` pour une sous-chaîne |
| Nombre d'éléments | `expect(locator).toHaveCount(n)` | Réessaie jusqu'à ce que le nombre corresponde |
| Valeur d'un input | `expect(locator).toHaveValue('x')` | Auto-retry sur le locator |
| Attribut d'un élément | `expect(locator).toHaveAttribute('href', '/x')` | Auto-retry |
| Propriété CSS | `expect(locator).toHaveCSS('color', 'rgb(0,0,0)')` | Auto-retry ; utilise les valeurs RGB calculées. Ajoute `{ pseudo: 'after' }` (1.60+) pour les styles de pseudo-éléments |
| Élément retiré du DOM | `expect(locator).not.toBeAttached()` | Distingue masqué et supprimé |
| URL modifiée | `page.waitForURL('/path')` ou `expect(page).toHaveURL('/path')` | `toHaveURL` réessaie ; `waitForURL` bloque |
| Titre de la page | `expect(page).toHaveTitle('Title')` | Auto-retry |
| Statut d'une réponse d'API | `expect(response.status()).toBe(200)` | Déjà résolu — sans retry |
| Job en arrière-plan / polling | `expect.poll(() => fetchStatus())` | Réessaie une fonction, pas un locator |
| Plusieurs assertions en une | `expect(async () => { ... }).toPass()` | Réessaie tout le bloc |
| Plusieurs vérifications indépendantes | `expect.soft(locator)` | Collecte tous les échecs |
| Valeur JS résolue | `expect(value).toBe(x)` | Pas de retry nécessaire |

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| `await page.waitForTimeout(2000)` | Délai arbitraire. Trop lent quand c'est rapide, trop court quand c'est lent. Flaky. | Utilise une assertion web-first : `await expect(locator).toBeVisible()` |
| `const visible = await el.isVisible(); expect(visible).toBe(true)` | `isVisible()` se résout une seule fois — pas de retry. Race condition. | `await expect(el).toBeVisible()` |
| `try { await expect(el).toBeVisible() } catch { /* ignore */ }` | Avale les vrais échecs. Masque les bugs. | Utilise `expect.soft()` ou restructure le test |
| `expect(locator).toBeVisible().then(...)` | `await` manquant. L'assertion s'exécute détachée, le test passe avant qu'elle ne se résolve. | Toujours `await expect(locator).toBeVisible()` |
| `await expect(btn).toBeVisible(); await btn.click()` | Redondant. `click()` attend déjà la visibilité. | Juste `await btn.click()` |
| `await page.waitForLoadState('networkidle')` avant chaque action | `networkidle` est fragile (long-poll, analytics, websockets le cassent). Ralentit les tests. | Attends plutôt un élément ou une URL précis |
| `expect(await el.textContent()).toBe('X')` | Résout le texte une seule fois — pas de retry. | `await expect(el).toHaveText('X')` |
| `expect(await page.locator('.item').count()).toBe(5)` | Résout le nombre une seule fois — pas de retry. | `await expect(page.locator('.item')).toHaveCount(5)` |
| Utiliser `toPass()` pour une seule assertion | Complexité inutile. | Utilise directement l'assertion web-first |
| Timeout énorme par assertion (>60s) | Masque de vrais problèmes de performance. Les tests deviennent insupportablement lents en cas d'échec. | Corrige l'app ou découpe le test. 10-30s max. |

## Dépannage

### « Timed out 5000ms waiting for expect(...).toBeVisible() »

**Cause** : l'élément n'est jamais apparu dans le timeout de l'assertion. Raisons courantes :
1. Mauvais locator — l'élément existe mais le locator ne correspond pas.
2. L'élément est derrière un spinner de chargement ou dans une section repliée.
3. La requête réseau qui alimente l'élément est lente.

**Correctif** :
- Lance avec `--ui` ou `--debug` pour inspecter visuellement l'état de la page au moment de l'échec.
- Vérifie que le locator correspond dans la console du navigateur : `playwright.$(selector)`.
- Augmente le timeout pour les opérations réellement lentes : `{ timeout: 15_000 }`.
- Vérifie que le locator cible le bon élément : `await expect(locator).toHaveCount(1)` d'abord.

### « expect.soft: Test finished with X failed assertions »

**Cause** : les assertions soft ont collecté des échecs mais tu n'as pas de visibilité immédiate sur lesquels.

**Correctif** : consulte le rapport HTML (`npx playwright show-report`). Chaque échec soft y est listé avec son locator, sa valeur attendue et sa valeur réelle. Regroupe les assertions soft liées sous `test.step()` pour une meilleure lisibilité.

### « Expected '  Dashboard  ' to have text 'Dashboard' »

**Cause** : `toHaveText()` effectue une correspondance complète du texte, normalisation comprise, mais les écarts d'espaces piègent encore les gens quand les éléments ont un rendu inhabituel.

**Correctif** :
- Utilise `toContainText('Dashboard')` pour une correspondance de sous-chaîne plus résistante aux espaces.
- Utilise une regex : `toHaveText(/Dashboard/)`.
- Cherche les espaces de largeur nulle ou les caractères Unicode spéciaux avec `--debug`.

## Voir aussi

- [core/locators.md](locators.md) — stratégies de locators utilisées comme cibles d'assertions
- [core/fixtures-and-hooks.md](fixtures-and-hooks.md) — fixtures personnalisées pour un setup d'assertions réutilisable
- [core/debugging.md](debugging.md) — déboguer les échecs d'assertions avec UI mode et les traces
- [core/flaky-tests.md](flaky-tests.md) — corriger la flakiness liée au timing
- [core/error-index.md](error-index.md) — messages d'erreur précis et correctifs
