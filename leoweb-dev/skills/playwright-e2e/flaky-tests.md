# Tests flaky

> **Quand l'utiliser** : Un test passe parfois et échoue d'autres fois. Tu dois diagnostiquer la cause racine, la corriger et éviter que ça se reproduise.
> **Prérequis** : [core/assertions-and-waiting.md](assertions-and-waiting.md), [core/fixtures-and-hooks.md](fixtures-and-hooks.md)

## Référence rapide

```bash
# Burn-in test — run 10 times to expose flakiness
npx playwright test tests/checkout.spec.ts --repeat-each=10

# Run with retries to catch intermittent failures
npx playwright test --retries=3

# Run single test in isolation to rule out state leaks
npx playwright test tests/checkout.spec.ts --grep "adds item" --workers=1

# Best Playwright 1.59+ trace mode for flaky tests
npx playwright test --retries=3 --trace=retain-on-failure-and-retries

# Run with tracing on every attempt only when you need maximum detail
npx playwright test --retries=3 --trace=on

# Run in fully parallel mode to expose isolation issues
npx playwright test --fully-parallel --workers=4

# Run tests in a random order to expose order dependencies (1.64+)
npx playwright test --shuffle
# Reproduce a failing order with the seed printed at the start of the run
npx playwright test --shuffle 271828182

# Run all retries at the end in one worker to rule out concurrency (1.62+):
# config-only, set retryStrategy: 'isolated' in playwright.config (no CLI flag)
npx playwright test --retries=2

# List flaky tests (tests that failed then passed on retry)
npx playwright test --retries=2 --reporter=json | jq '.suites[].specs[] | select(.ok == true and (.tests[].results | length > 1))'
```

## Patterns

### Taxonomie de la flakiness

Tout test flaky tombe dans l'une de ces quatre catégories. Identifie d'abord la catégorie, puis applique la correction correspondante.

| Catégorie | Symptôme | Cause racine typique | Méthode de diagnostic |
|---|---|---|---|
| **Timing / Async** | Échoue de façon intermittente partout | Race conditions, `await` manquant, attentes arbitraires | Échoue en local avec `--repeat-each=20` |
| **Isolation des tests** | Échoue seulement quand il tourne avec d'autres tests, passe seul | État mutable partagé, collisions de données, dépendance à l'ordre des tests | Passe avec `--workers=1 --grep "this test"`, échoue dans la suite complète |
| **Environnement** | Échoue seulement en CI, passe en local | OS, viewport, polices, latence réseau différents, dépendances manquantes | Compare les screenshots/traces de la CI avec le local ; exécute en local dans Docker |
| **Infrastructure** | Échecs aléatoires sans rapport avec la logique du test | Crash du navigateur, OOM, résolution DNS, race condition sur le système de fichiers | Les échecs n'ont aucun motif ; les messages d'erreur renvoient aux internals du navigateur |

### Arbre de diagnostic

Suis cet arbre de décision pour identifier la catégorie de ton test flaky.

```
Test is flaky
|
+-- Does it fail locally with --repeat-each=20?
|   |
|   +-- YES --> TIMING / ASYNC issue
|   |           - Missing await
|   |           - Using waitForTimeout instead of assertions
|   |           - Race condition between action and assertion
|   |           - Not waiting for network response before asserting
|   |
|   +-- NO --> Does it fail only in CI?
|       |
|       +-- YES --> ENVIRONMENT issue
|       |           - Different viewport/screen size
|       |           - Missing fonts causing layout shift
|       |           - Slower CI machines hitting timeouts
|       |           - External services unavailable
|       |
|       +-- NO --> Does it fail only when run with other tests?
|           |
|           +-- YES --> ISOLATION issue
|           |           - Shared mutable state (module-level variables)
|           |           - Database/API state from previous test
|           |           - localStorage/cookies leaking between tests
|           |           - Parallel tests colliding on unique constraints
|           |
|           +-- NO --> INFRASTRUCTURE issue
|                       - Browser process crash
|                       - Out of memory
|                       - File system or network instability
|                       - Flaky third-party service
```

### Stratégie de rétention des traces dans Playwright 1.59

Pour les tests flaky sur Playwright 1.59+, privilégie `trace: 'retain-on-failure-and-retries'` plutôt que `trace: 'on'` quand tu compares des tentatives échouées avec des retries réussis. Cela conserve les exécutions utiles sans stocker toutes les traces des tests réussis de la suite.

```typescript
import { defineConfig } from '@playwright/test';

export default defineConfig({
  retries: process.env.CI ? 2 : 0,
  use: {
    trace: process.env.CI
      ? 'retain-on-failure-and-retries'
      : 'on-first-retry',
  },
});
```

C'est particulièrement efficace quand un test échoue une fois, passe au retry, et que tu dois comparer ces tentatives dans le Trace Viewer.

### Capturer `errorContext` pour les échecs d'assertion intermittents (Playwright 1.60+)

Quand un test flaky n'échoue que parfois sur un matcher `expect()`, le message d'erreur brut explique rarement *pourquoi*. Playwright 1.60 attache `errorContext` à chaque erreur de `testInfo`, y compris l'aria snapshot de l'élément au moment où le matcher a échoué. Journalise-le depuis `afterEach` pour que chaque échec flaky laisse une trace, même sur les exécutions que tu ne peux pas reproduire en local.

```typescript
import { test } from '@playwright/test';

test.afterEach(async ({}, testInfo) => {
  if (testInfo.status !== testInfo.expectedStatus) {
    for (const err of testInfo.errors) {
      if (err.errorContext) {
        await testInfo.attach('failure-context', {
          body: err.errorContext,
          contentType: 'text/plain',
        });
      }
    }
  }
});
```

Associe-le à `trace: 'retain-on-failure-and-retries'` : la trace montre la chronologie, et `errorContext` capture l'état d'accessibilité du récepteur au point exact de l'échec.

### Utiliser les filtres du mode UI et du Trace Viewer

Quand tu débogues une trace bruyante ou une longue exécution en mode UI, utilise les nouvelles options de filtrage pour te concentrer sur le test en échec, les actions pertinentes ou une séquence d'assertions précise, plutôt que de parcourir manuellement tout le flux d'événements.

### Correction : problèmes de timing et d'async

**À utiliser quand** : Le test échoue en local avec `--repeat-each=20`, ou tu vois des `waitForTimeout`, des `await` manquants ou des race conditions.

C'est la source de flakiness la plus courante. La correction est toujours la même : remplace les attentes arbitraires et les vérifications manuelles par les mécanismes d'auto-retry de Playwright.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// ---- FIX 1: Replace waitForTimeout with assertions ----

// BAD — arbitrary delay, fails on slow machines, wastes time on fast ones
test('bad: uses arbitrary wait', async ({ page }) => {
  await page.goto('/dashboard');
  await page.getByRole('button', { name: 'Refresh' }).click();
  await page.waitForTimeout(3000); // hoping data loads in 3s
  await expect(page.getByTestId('data-table')).toBeVisible();
});

// GOOD — auto-retrying assertion waits exactly as long as needed
test('good: uses auto-retrying assertion', async ({ page }) => {
  await page.goto('/dashboard');
  await page.getByRole('button', { name: 'Refresh' }).click();
  await expect(page.getByTestId('data-table')).toBeVisible();
});

// ---- FIX 2: Wait for network responses before asserting ----

// BAD — clicks button and immediately asserts, but data comes from API
test('bad: does not wait for API response', async ({ page }) => {
  await page.goto('/users');
  await page.getByRole('button', { name: 'Load More' }).click();
  // Flaky: API response may not have arrived yet
  await expect(page.getByRole('listitem')).toHaveCount(20);
});

// GOOD — waits for the specific API response that populates the data
test('good: waits for API response', async ({ page }) => {
  await page.goto('/users');

  const responsePromise = page.waitForResponse(
    (resp) => resp.url().includes('/api/users') && resp.status() === 200
  );
  await page.getByRole('button', { name: 'Load More' }).click();
  await responsePromise;

  await expect(page.getByRole('listitem')).toHaveCount(20);
});

// ---- FIX 3: Handle animations and transitions ----

// BAD — element exists but is mid-animation, click lands on wrong target
test('bad: clicks during animation', async ({ page }) => {
  await page.goto('/modal-demo');
  await page.getByRole('button', { name: 'Open' }).click();
  // Modal is animating in — click may miss the button inside it
  await page.getByRole('button', { name: 'Confirm' }).click();
});

// GOOD — wait for the modal to be fully stable before interacting
test('good: waits for stable state', async ({ page }) => {
  await page.goto('/modal-demo');
  await page.getByRole('button', { name: 'Open' }).click();
  // toBeVisible auto-waits for stability (no animation in progress)
  await expect(page.getByRole('dialog')).toBeVisible();
  await page.getByRole('button', { name: 'Confirm' }).click();
});

// ---- FIX 4: Use toPass() for multi-step assertions that must succeed together ----

test('good: retry entire assertion block', async ({ page }) => {
  await page.goto('/search');

  await expect(async () => {
    await page.getByLabel('Search').fill('playwright');
    await page.getByRole('button', { name: 'Search' }).click();
    await expect(page.getByTestId('result-count')).toHaveText('10 results');
  }).toPass({
    timeout: 15_000,
    intervals: [1_000, 2_000, 5_000],
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

// FIX 1: Replace waitForTimeout with assertions
test('good: uses auto-retrying assertion', async ({ page }) => {
  await page.goto('/dashboard');
  await page.getByRole('button', { name: 'Refresh' }).click();
  await expect(page.getByTestId('data-table')).toBeVisible();
});

// FIX 2: Wait for network responses before asserting
test('good: waits for API response', async ({ page }) => {
  await page.goto('/users');

  const responsePromise = page.waitForResponse(
    (resp) => resp.url().includes('/api/users') && resp.status() === 200
  );
  await page.getByRole('button', { name: 'Load More' }).click();
  await responsePromise;

  await expect(page.getByRole('listitem')).toHaveCount(20);
});

// FIX 3: Handle animations and transitions
test('good: waits for stable state', async ({ page }) => {
  await page.goto('/modal-demo');
  await page.getByRole('button', { name: 'Open' }).click();
  await expect(page.getByRole('dialog')).toBeVisible();
  await page.getByRole('button', { name: 'Confirm' }).click();
});

// FIX 4: Use toPass() for multi-step assertions
test('good: retry entire assertion block', async ({ page }) => {
  await page.goto('/search');

  await expect(async () => {
    await page.getByLabel('Search').fill('playwright');
    await page.getByRole('button', { name: 'Search' }).click();
    await expect(page.getByTestId('result-count')).toHaveText('10 results');
  }).toPass({
    timeout: 15_000,
    intervals: [1_000, 2_000, 5_000],
  });
});
```

### Correction : problèmes d'isolation des tests

**À utiliser quand** : Le test passe quand il est exécuté seul (`--grep "test name"`) mais échoue avec d'autres tests, ou échoue uniquement en mode parallèle.

Les problèmes d'isolation viennent d'un état partagé : variables au niveau du module, lignes en base, localStorage, cookies ou artefacts du système de fichiers.

Quand l'état partagé ne peut pas être rendu propre à chaque test (un compte externe unique, un réglage global), déclare un `lock` de test (1.63+) pour que seuls les tests en concurrence sur cette ressource soient sérialisés. Voir [Serializing Tests on a Shared Resource](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/parallel-and-sharding.md#pattern-6-serializing-tests-on-a-shared-resource-lock-playwright-163).

**TypeScript**
```typescript
import { test as base, expect } from '@playwright/test';

// ---- FIX 1: Unique test data per test ----

// BAD — all parallel tests use the same email, causing unique constraint violations
test('bad: hardcoded data', async ({ page }) => {
  await page.goto('/register');
  await page.getByLabel('Email').fill('test@example.com');
  await page.getByRole('button', { name: 'Register' }).click();
  await expect(page.getByText('Welcome')).toBeVisible();
});

// GOOD — unique email per test run
test('good: unique data per test', async ({ page }) => {
  const email = `test-${Date.now()}-${Math.random().toString(36).slice(2)}@example.com`;

  await page.goto('/register');
  await page.getByLabel('Email').fill(email);
  await page.getByRole('button', { name: 'Register' }).click();
  await expect(page.getByText('Welcome')).toBeVisible();
});

// ---- FIX 2: Worker-scoped fixtures for shared expensive resources ----

type WorkerFixtures = {
  workerAccount: { email: string; id: string };
};

export const test = base.extend<{}, WorkerFixtures>({
  workerAccount: [async ({ request }, use) => {
    const email = `worker-${Date.now()}-${Math.random().toString(36).slice(2)}@example.com`;
    const response = await request.post('/api/users', {
      data: { email, password: 'TestP@ss123!' },
    });
    const account = await response.json();

    await use({ email, id: account.id });

    // Cleanup after all tests in this worker are done
    await request.delete(`/api/users/${account.id}`);
  }, { scope: 'worker' }],
});

// ---- FIX 3: Clean up state in fixture teardown ----

export const testWithCleanup = base.extend({
  cleanPage: async ({ page }, use) => {
    await use(page);

    // Teardown: clear all client-side state
    await page.evaluate(() => {
      localStorage.clear();
      sessionStorage.clear();
    });
    await page.context().clearCookies();
  },
});

// ---- FIX 4: Isolate tests that cannot run in parallel ----

import { test } from '@playwright/test';

// Use serial mode ONLY for tests that genuinely depend on shared state
// (e.g., a multi-step wizard where each test is one step)
test.describe.serial('checkout wizard', () => {
  test('step 1: add items', async ({ page }) => {
    await page.goto('/shop');
    await page.getByRole('button', { name: 'Add Widget' }).click();
    await expect(page.getByTestId('cart-count')).toHaveText('1');
  });

  test('step 2: enter shipping', async ({ page }) => {
    await page.goto('/checkout/shipping');
    await page.getByLabel('Address').fill('123 Test St');
    await page.getByRole('button', { name: 'Continue' }).click();
  });
});
```

**JavaScript**
```javascript
const { test: base, expect } = require('@playwright/test');

// FIX 1: Unique test data per test
test('good: unique data per test', async ({ page }) => {
  const email = `test-${Date.now()}-${Math.random().toString(36).slice(2)}@example.com`;

  await page.goto('/register');
  await page.getByLabel('Email').fill(email);
  await page.getByRole('button', { name: 'Register' }).click();
  await expect(page.getByText('Welcome')).toBeVisible();
});

// FIX 2: Worker-scoped fixtures for shared expensive resources
const test = base.extend({
  workerAccount: [async ({ request }, use) => {
    const email = `worker-${Date.now()}-${Math.random().toString(36).slice(2)}@example.com`;
    const response = await request.post('/api/users', {
      data: { email, password: 'TestP@ss123!' },
    });
    const account = await response.json();

    await use({ email, id: account.id });

    await request.delete(`/api/users/${account.id}`);
  }, { scope: 'worker' }],
});

module.exports = { test, expect };
```

#### Révéler les dépendances d'ordre cachées avec `--shuffle` (Playwright 1.64+)

**Avant la 1.64**, les dépendances d'ordre se cachaient derrière l'ordonnancement fixe : le test B ne passait que parce que le test A s'exécutait toujours avant lui dans le même worker et laissait derrière lui une ligne, un cookie ou une variable au niveau du module. Tu ne le découvrais que lorsque quelqu'un ajoutait un test, que le sharding changeait ou qu'un fichier était renommé.

**La 1.64** ajoute `--shuffle`, qui planifie les tests dans un ordre aléatoire et affiche la seed :

```bash
npx playwright test --shuffle
# Running 42 tests using 4 workers, shuffle seed 271828182

# Same seed, same order: reproduce the failure deterministically
npx playwright test --shuffle 271828182
```

**Usage pratique** : lance un job CI nocturne avec `--shuffle` et conserve la seed dans le log du job. Un test qui échoue en mode shuffle mais passe dans l'ordre par défaut a un bug d'isolation ; corrige-le avec les patterns ci-dessus plutôt que de figer l'ordre. Ne mets pas `--shuffle` dans la pipeline des PR tant que la suite n'est pas propre, sinon chaque PR hérite d'échecs aléatoires sans rapport.

### Correction : problèmes d'environnement

**À utiliser quand** : Le test passe en local mais échoue en CI, ou échoue sur certains systèmes d'exploitation, viewports ou machines.

La flakiness d'environnement vient des différences de rendu, de timing, de ressources disponibles ou de disponibilité des services externes entre ta machine locale et la CI.

**TypeScript**
```typescript
// playwright.config.ts — environment-consistent configuration
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  // ---- FIX 1: Disable animations for deterministic behavior ----
  use: {
    // Disable CSS animations and transitions
    contextOptions: {
      reducedMotion: 'reduce',
    },
  },

  // ---- FIX 2: Consistent viewport across environments ----
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        // Explicit viewport prevents layout differences between local and CI
        viewport: { width: 1280, height: 720 },
      },
    },
  ],

  // ---- FIX 3: Use webServer to start app in CI ----
  webServer: {
    command: 'npm run start',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },

  // ---- FIX 4: Higher timeouts for slower CI machines ----
  timeout: process.env.CI ? 60_000 : 30_000,
  expect: {
    timeout: process.env.CI ? 10_000 : 5_000,
  },
});
```

```typescript
// tests/fixtures/stub-externals.ts — stub external services
import { test as base, expect } from '@playwright/test';

export const test = base.extend({
  // Auto fixture: block all external services in every test
  stubExternals: [async ({ page }, use) => {
    // Block third-party scripts that vary between environments
    await page.route(/google-analytics|segment|hotjar|intercom/, (route) =>
      route.abort()
    );

    // Stub flaky external API with consistent response
    await page.route('**/api.external-service.com/**', (route) =>
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ status: 'ok', data: [] }),
      })
    );

    await use();
  }, { auto: true }],
});

export { expect };
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  use: {
    contextOptions: {
      reducedMotion: 'reduce',
    },
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1280, height: 720 },
      },
    },
  ],
  webServer: {
    command: 'npm run start',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
  timeout: process.env.CI ? 60_000 : 30_000,
  expect: {
    timeout: process.env.CI ? 10_000 : 5_000,
  },
});
```

```javascript
// tests/fixtures/stub-externals.js
const { test: base, expect } = require('@playwright/test');

const test = base.extend({
  stubExternals: [async ({ page }, use) => {
    await page.route(/google-analytics|segment|hotjar|intercom/, (route) =>
      route.abort()
    );

    await page.route('**/api.external-service.com/**', (route) =>
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ status: 'ok', data: [] }),
      })
    );

    await use();
  }, { auto: true }],
});

module.exports = { test, expect };
```

### Stratégies de détection

**À utiliser quand** : Tu soupçonnes de la flakiness mais le test n'échoue pas de façon constante, ou tu veux valider qu'une correction a bien éliminé la flakiness.

**TypeScript**
```typescript
// ---- Strategy 1: Burn-in testing with --repeat-each ----
// Run a test 20 times. If it fails even once, it has a flakiness bug.
// npx playwright test tests/checkout.spec.ts --repeat-each=20

// ---- Strategy 2: Retry configuration to catch intermittent failures ----
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  // Retries in CI surface flaky tests in the report
  retries: process.env.CI ? 2 : 0,

  // Reporter shows which tests needed retries
  reporter: process.env.CI
    ? [['html', { open: 'never' }], ['json', { outputFile: 'results.json' }]]
    : [['html', { open: 'on-failure' }]],
});

// ---- Strategy 3: Custom reporter to track flaky test metrics ----
// flaky-reporter.ts
import type { Reporter, TestCase, TestResult } from '@playwright/test/reporter';

class FlakyReporter implements Reporter {
  private flakyTests: { name: string; file: string; retries: number }[] = [];

  onTestEnd(test: TestCase, result: TestResult) {
    if (result.retry > 0 && result.status === 'passed') {
      this.flakyTests.push({
        name: test.title,
        file: test.location.file,
        retries: result.retry,
      });
    }
  }

  onEnd() {
    if (this.flakyTests.length > 0) {
      console.log('\n--- FLAKY TESTS ---');
      for (const t of this.flakyTests) {
        console.log(`  ${t.file} > "${t.name}" (needed ${t.retries} retries)`);
      }
      console.log(`Total flaky: ${this.flakyTests.length}`);
    }
  }
}

export default FlakyReporter;
```

```typescript
// playwright.config.ts — register custom flaky reporter
import { defineConfig } from '@playwright/test';

export default defineConfig({
  retries: process.env.CI ? 2 : 0,
  reporter: [
    ['html'],
    ['./flaky-reporter.ts'],
  ],
});
```

**JavaScript**
```javascript
// flaky-reporter.js
class FlakyReporter {
  constructor() {
    this.flakyTests = [];
  }

  onTestEnd(test, result) {
    if (result.retry > 0 && result.status === 'passed') {
      this.flakyTests.push({
        name: test.title,
        file: test.location.file,
        retries: result.retry,
      });
    }
  }

  onEnd() {
    if (this.flakyTests.length > 0) {
      console.log('\n--- FLAKY TESTS ---');
      for (const t of this.flakyTests) {
        console.log(`  ${t.file} > "${t.name}" (needed ${t.retries} retries)`);
      }
      console.log(`Total flaky: ${this.flakyTests.length}`);
    }
  }
}

module.exports = FlakyReporter;
```

### Stratégie de quarantaine

**À utiliser quand** : Un test est connu comme flaky et tu ne peux pas le corriger immédiatement. Mets-le en quarantaine pour qu'il ne bloque pas la CI, mais suis-le pour qu'il ne pourrisse pas.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// ---- Option 1: test.fixme() — skips the test with a reason ----
test.fixme('checkout with promo code applies discount', async ({ page }) => {
  // TODO(JIRA-1234): Flaky due to race condition in promo service
  // Fails ~10% of runs. Root cause: /api/promo responds after rendering
  await page.goto('/checkout');
  await page.getByLabel('Promo code').fill('SAVE20');
  await page.getByRole('button', { name: 'Apply' }).click();
  await expect(page.getByTestId('discount')).toHaveText('-$20.00');
});

// ---- Option 2: test.fail() — inverts: test passes only if it fails ----
// Use this when you KNOW the test fails and want CI to alert you when it starts passing
test.fail('known broken: export to PDF', async ({ page }) => {
  // When this test starts passing, the .fail() annotation will make it fail,
  // reminding you to remove the annotation
  await page.goto('/reports');
  await page.getByRole('button', { name: 'Export PDF' }).click();
  await expect(page.getByText('PDF ready')).toBeVisible({ timeout: 10_000 });
});

// ---- Option 3: Skip by tag — quarantine with a grep filter ----
test('@flaky checkout race condition', async ({ page }) => {
  // In CI, exclude flaky-tagged tests: npx playwright test --grep-invert @flaky
  // Run ONLY flaky tests nightly: npx playwright test --grep @flaky --retries=5
  await page.goto('/checkout');
  await page.getByRole('button', { name: 'Place Order' }).click();
  await expect(page.getByText('Order confirmed')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

// Option 1: test.fixme() — skips the test with a reason
test.fixme('checkout with promo code applies discount', async ({ page }) => {
  // TODO(JIRA-1234): Flaky due to race condition in promo service
  await page.goto('/checkout');
  await page.getByLabel('Promo code').fill('SAVE20');
  await page.getByRole('button', { name: 'Apply' }).click();
  await expect(page.getByTestId('discount')).toHaveText('-$20.00');
});

// Option 2: test.fail() — inverts: test passes only if it fails
test.fail('known broken: export to PDF', async ({ page }) => {
  await page.goto('/reports');
  await page.getByRole('button', { name: 'Export PDF' }).click();
  await expect(page.getByText('PDF ready')).toBeVisible({ timeout: 10_000 });
});

// Option 3: Skip by tag
test('@flaky checkout race condition', async ({ page }) => {
  await page.goto('/checkout');
  await page.getByRole('button', { name: 'Place Order' }).click();
  await expect(page.getByText('Order confirmed')).toBeVisible();
});
```

**Configuration CI pour la quarantaine :**

```yaml
# .github/workflows/tests.yml
jobs:
  e2e-tests:
    steps:
      - name: Run stable tests
        run: npx playwright test --grep-invert @flaky

  flaky-monitoring:
    # Runs nightly, not on every PR
    schedule:
      - cron: '0 3 * * *'
    steps:
      - name: Run flaky tests with retries
        run: npx playwright test --grep @flaky --retries=5 --reporter=json
      - name: Report flaky test results
        run: node scripts/report-flaky-metrics.js
```

#### Option 4 : mettre en quarantaine depuis un reporter (`reporter.preprocess()`, Playwright 1.62+)

Les options 1 à 3 imposent toutes de modifier le fichier de spec, ce qui signifie que la liste de quarantaine vit dans le contrôle de version et se met à jour à la main. Playwright 1.62 ajoute `reporter.preprocess()`, un hook qui s'exécute après la collecte et avant l'exécution, de sorte que la liste peut provenir de l'historique des exécutions.

```js
class QuarantineReporter {
  async preprocess({ config, suite, testRun }) {
    for (const test of suite.allTests()) {
      if (shouldSkip(test))
        testRun.skip(test);
    }
  }
}
```

`testRun` marque un test comme `skip`, `exclude`, `fixed` ou `failing`. Préfère `failing` à `skip` pour la quarantaine : le test s'exécute quand même, le rouge est attendu, et l'exécution échoue s'il passe de manière inattendue, si bien qu'un test rétabli se retire lui-même de la liste au lieu d'y rester indéfiniment.

Le pilotage depuis une API externe de flakiness, la correspondance sur les chemins de titre complets, et la garde d'exemption qui empêche la quarantaine automatique de réduire au silence ton test le plus critique sont traités dans [core/dynamic-test-selection.md](dynamic-test-selection.md).

#### Retries isolés (`retryStrategy: 'isolated'`, Playwright 1.62+)

La stratégie par défaut `'immediate'` relance dès qu'un worker est libre, alors que le reste de la suite tourne encore et peut interférer à nouveau. `'isolated'` reporte tous les retries à la fin de l'exécution et les exécute dans un seul worker.

```typescript
// playwright.config.ts
export default defineConfig({
  retries: 2,
  retryStrategy: 'isolated',
});
```

C'est un outil de diagnostic, pas une correction. Un test qui échoue dans l'exécution parallèle et passe au retry isolé te dit que l'échec est lié à la concurrence plutôt qu'inhérent au test, ce qui renvoie à [Correction : problèmes d'isolation des tests](#correction--problèmes-disolation-des-tests) ci-dessus. Note que la phase de retry est sérielle : une suite avec beaucoup de tests relancés paie donc un vrai temps d'horloge pour obtenir ce signal.

### Checklist de prévention

Applique ces règles dès le départ pour empêcher la flakiness d'entrer dans ta suite de tests.

**TypeScript**
```typescript
// playwright.config.ts — flake-resistant configuration
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  // RULE 1: Run tests fully parallel to expose isolation issues early
  fullyParallel: true,

  // RULE 2: Fail CI if test.only() is left in code
  forbidOnly: !!process.env.CI,

  // RULE 3: Use retries in CI to surface (not hide) flaky tests
  retries: process.env.CI ? 2 : 0,

  // RULE 4: Reasonable timeouts — not too high, not too low
  timeout: 30_000,
  expect: { timeout: 5_000 },

  use: {
    // RULE 5: Always capture traces on retry for debugging
    trace: 'on-first-retry',

    // RULE 6: Use baseURL — never hardcode full URLs in tests
    baseURL: process.env.BASE_URL || 'http://localhost:3000',

    // RULE 7: Disable animations for deterministic behavior
    contextOptions: {
      reducedMotion: 'reduce',
    },

    // RULE 8: Explicit viewport — same locally and in CI
    viewport: { width: 1280, height: 720 },
  },

  // RULE 9: Start the app automatically in CI
  webServer: {
    command: 'npm run start',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
});
```

```typescript
// tests/example-stable-test.spec.ts — applying all rules in a test
import { test, expect } from '@playwright/test';

test.describe('user profile', () => {
  test('updates display name', async ({ page }) => {
    // RULE 10: Unique data per test
    const newName = `User-${Date.now()}`;

    // RULE 11: Use baseURL — relative paths only
    await page.goto('/profile');

    // RULE 12: Role-based locators — resilient to implementation changes
    await page.getByRole('textbox', { name: 'Display name' }).fill(newName);
    await page.getByRole('button', { name: 'Save' }).click();

    // RULE 13: Auto-retrying assertions — never manual waits
    await expect(page.getByRole('alert')).toHaveText('Profile updated');

    // RULE 14: Assert on the result, not intermediate states
    await expect(page.getByRole('textbox', { name: 'Display name' })).toHaveValue(newName);
  });
});
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  timeout: 30_000,
  expect: { timeout: 5_000 },
  use: {
    trace: 'on-first-retry',
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    contextOptions: {
      reducedMotion: 'reduce',
    },
    viewport: { width: 1280, height: 720 },
  },
  webServer: {
    command: 'npm run start',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
});
```

```javascript
// tests/example-stable-test.spec.js
const { test, expect } = require('@playwright/test');

test.describe('user profile', () => {
  test('updates display name', async ({ page }) => {
    const newName = `User-${Date.now()}`;

    await page.goto('/profile');
    await page.getByRole('textbox', { name: 'Display name' }).fill(newName);
    await page.getByRole('button', { name: 'Save' }).click();

    await expect(page.getByRole('alert')).toHaveText('Profile updated');
    await expect(page.getByRole('textbox', { name: 'Display name' })).toHaveValue(newName);
  });
});
```

## Guide de décision

```
My test is flaky. What do I do?
|
+-- Step 1: Reproduce locally
|   |
|   +-- npx playwright test <file> --repeat-each=20
|   +-- Fails? --> TIMING issue. Fix with auto-retrying assertions.
|   +-- Does not fail? --> Continue to Step 2.
|
+-- Step 2: Isolate from other tests
|   |
|   +-- npx playwright test --grep "exact test name" --workers=1
|   +-- Passes alone? --> ISOLATION issue. Fix with unique data + fixtures.
|   +-- Fails alone? --> Continue to Step 3.
|
+-- Step 3: Compare environments
|   |
|   +-- Download CI trace, compare with local trace
|   +-- Different? --> ENVIRONMENT issue. Fix with explicit viewport,
|   |                  reducedMotion, webServer config, stub externals.
|   +-- Same? --> Continue to Step 4.
|
+-- Step 4: Check infrastructure
|   |
|   +-- Error mentions browser crash, OOM, DNS, ECONNREFUSED?
|   +-- YES --> INFRASTRUCTURE issue. Fix with Docker, retry config,
|   |           health checks before test run.
|   +-- NO --> Re-examine. Enable trace: 'on' and retries to collect
|              more data. Compare passing and failing traces side by side.
```

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| Augmenter le timeout à 120 s pour « corriger » la flakiness | Masque le vrai problème. Les tests deviennent insupportablement lents quand ils échouent. Ralentit toute la pipeline CI. | Diagnostiquer la cause racine. Corriger la race condition, pas le timeout. |
| Utiliser `page.waitForTimeout(N)` | Les délais arbitraires sont trop lents sur les machines rapides et trop courts sur les lentes. Cause n°1 de flakiness. | Utiliser `expect(locator).toBeVisible()`, `page.waitForResponse()` ou `expect.poll()`. |
| Ignorer les tests flaky (« ça marche si on relance ») | Les tests flaky érodent la confiance dans toute la suite. Les gens arrêtent de lire les échecs. De vrais bugs passent à travers. | Diagnostiquer immédiatement. Si tu ne peux pas corriger tout de suite, mettre en quarantaine avec `test.fixme()` et un ticket de suivi. |
| Ajouter `--retries=3` et considérer que c'est corrigé | Les retries ne corrigent pas la flakiness, ils la cachent. Un test qui a besoin de retries est un test avec un bug. | Utiliser les retries pour **détecter** la flakiness (vérifier le nombre de retries dans les rapports), pas pour la masquer. |
| Utiliser `test.describe.serial()` pour réparer des tests dépendants de l'ordre | Le mode serial force tous les tests du bloc à s'exécuter séquentiellement. Il cache les bugs d'isolation et ralentit la suite. | Corriger le problème d'isolation. Chaque test doit passer quel que soit l'ordre d'exécution. |
| Tout mocker pour éviter les différences d'environnement | Le sur-mocking enlève la confiance que le vrai système fonctionne. Les tests passent mais l'application est cassée. | Ne mocker que les services externes/tiers. Tester sa propre API pour de vrai. |
| Lancer `--repeat-each=100` en CI à chaque commit | Multiplie le temps de CI par 100. Gaspille des ressources. | Lancer le burn-in en local ou dans un job nocturne, pas à chaque PR. |

## Dépannage

| Symptôme | Catégorie | Correction |
|---|---|---|
| Le test échoue par intermittence avec « Timeout 5000ms » | Timing | Augmenter `expect.timeout` à 10 s, ou ajouter `page.waitForResponse()` avant l'assertion |
| Le test passe seul, échoue dans l'exécution de la suite complète | Isolation | Chercher des variables `let` au niveau du module, des lignes de base partagées ou des fuites de localStorage |
| Le test passe en local, échoue en CI | Environnement | Comparer les traces. Vérifier le viewport, les polices, `reducedMotion` et la disponibilité des services externes |
| Le test échoue avec « Target closed » ou « Browser closed » | Infrastructure | Vérifier les limites mémoire de la CI. Ajouter `--workers=50%` pour réduire la charge parallèle. Ajouter un healthcheck dans `beforeAll` |
| Le test échoue différemment à chaque fois | Timing + Isolation | Activer `trace: 'on'` et comparer plusieurs traces en échec. L'incohérence elle-même est un indice |
| Un test flaky passe 99 fois sur 100 | Timing (race rare) | Utiliser `--repeat-each=200` en local. Ajouter `page.waitForResponse()` ou `expect.poll()` pour la race précise |
| Un test de comparaison visuelle est flaky | Environnement | Utiliser le seuil `maxDiffPixelRatio`. Définir des polices explicites avec `@font-face`. Utiliser Docker pour un rendu cohérent |
| Les tests ne sont flaky que sur WebKit | Environnement | WebKit a un comportement de timing différent. Ajouter des assertions spécifiques à WebKit ou augmenter les timeouts par projet |

## Voir aussi

- [core/assertions-and-waiting.md](assertions-and-waiting.md) -- assertions auto-retry et attentes explicites
- [core/fixtures-and-hooks.md](fixtures-and-hooks.md) -- teardown de fixture pour l'isolation des tests
- [core/test-data-management.md](test-data-management.md) -- données uniques par test, factory functions
- [core/configuration.md](configuration.md) -- configuration des retries, timeouts et traces
- [core/debugging.md](debugging.md) -- Trace Viewer, mode UI et Inspector pour diagnostiquer les échecs
- [core/common-pitfalls.md](common-pitfalls.md) -- erreurs courantes qui causent de la flakiness
