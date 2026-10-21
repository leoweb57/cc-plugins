# Organisation des tests

> **Quand l'utiliser** : structurer les fichiers de test, nommer les tests, les grouper avec `describe`, les taguer, les filtrer, et choisir entre exécution parallèle et série.
> **Prérequis** : [core/configuration.md](configuration.md)

## Référence rapide

| Concept | Règle |
|---|---|
| Suffixe de fichier | `.spec.ts` / `.spec.js` — toujours |
| Regroupement | Par feature/domaine, pas par page ou URL |
| Noms de tests | `test('should ...')` ou `test('user can ...')` — décris le comportement |
| Imbrication | 2 niveaux max de `test.describe()` |
| Exécution par défaut | `fullyParallel: true` — les tests s'exécutent en parallèle par défaut |
| Tests série | N'utilise presque jamais `test.describe.serial()` |
| Dépendances entre tests | À éviter — chaque test prépare son propre état |
| Tags | `@smoke`, `@regression`, `@slow` — filtre avec `--grep` |

## Patterns

### Pattern 1 : Structure de fichiers par feature

**À utiliser quand** : n'importe quel projet — c'est la disposition par défaut.
**À éviter quand** : jamais. C'est toujours la bonne approche.

Groupe les tests par feature ou domaine, pas par classe de page ou par type de test.

**Petit projet (< 20 tests) :**

```
tests/
├── auth.spec.ts
├── dashboard.spec.ts
├── settings.spec.ts
└── checkout.spec.ts
playwright.config.ts
```

**Projet moyen (20–200 tests) :**

```
tests/
├── auth/
│   ├── login.spec.ts
│   ├── signup.spec.ts
│   ├── password-reset.spec.ts
│   └── mfa.spec.ts
├── dashboard/
│   ├── widgets.spec.ts
│   ├── filters.spec.ts
│   └── export.spec.ts
├── checkout/
│   ├── cart.spec.ts
│   ├── payment.spec.ts
│   └── confirmation.spec.ts
├── settings/
│   ├── profile.spec.ts
│   └── notifications.spec.ts
└── fixtures/
    ├── auth.fixture.ts
    └── test-data.ts
playwright.config.ts
```

**Grand projet (200+ tests) :**

```
tests/
├── e2e/
│   ├── auth/
│   │   ├── login.spec.ts
│   │   ├── signup.spec.ts
│   │   ├── password-reset.spec.ts
│   │   └── mfa.spec.ts
│   ├── checkout/
│   │   ├── cart.spec.ts
│   │   ├── payment.spec.ts
│   │   ├── promo-codes.spec.ts
│   │   └── confirmation.spec.ts
│   ├── admin/
│   │   ├── user-management.spec.ts
│   │   ├── reports.spec.ts
│   │   └── audit-log.spec.ts
│   └── inventory/
│       ├── product-list.spec.ts
│       ├── product-detail.spec.ts
│       └── stock-management.spec.ts
├── api/
│   ├── users.spec.ts
│   ├── orders.spec.ts
│   └── products.spec.ts
├── visual/
│   ├── homepage.spec.ts
│   └── product-page.spec.ts
├── fixtures/
│   ├── auth.fixture.ts
│   ├── db.fixture.ts
│   └── base.fixture.ts
├── page-objects/
│   ├── login.page.ts
│   ├── dashboard.page.ts
│   └── checkout.page.ts
└── helpers/
    ├── test-data.ts
    └── api-client.ts
playwright.config.ts
```

---

### Pattern 2 : Conventions de nommage

**À utiliser quand** : tu écris n'importe quel test ou fichier.
**À éviter quand** : jamais.

**TypeScript :**

```typescript
// tests/checkout/cart.spec.ts
import { test, expect } from '@playwright/test';

// Good: group by feature, describe behavior
test.describe('Shopping Cart', () => {
  test('should add item to empty cart', async ({ page }) => {
    await page.goto('/products/widget-a');
    await page.getByRole('button', { name: 'Add to cart' }).click();
    await expect(page.getByTestId('cart-count')).toHaveText('1');
  });

  test('should update quantity when same item added twice', async ({ page }) => {
    await page.goto('/products/widget-a');
    await page.getByRole('button', { name: 'Add to cart' }).click();
    await page.getByRole('button', { name: 'Add to cart' }).click();
    await expect(page.getByTestId('cart-count')).toHaveText('2');
  });

  test('user can remove item from cart', async ({ page }) => {
    await page.goto('/cart');
    // ... setup item in cart via API or fixture
    await page.getByRole('button', { name: 'Remove' }).first().click();
    await expect(page.getByText('Your cart is empty')).toBeVisible();
  });
});
```

**JavaScript :**

```javascript
// tests/checkout/cart.spec.js
const { test, expect } = require('@playwright/test');

test.describe('Shopping Cart', () => {
  test('should add item to empty cart', async ({ page }) => {
    await page.goto('/products/widget-a');
    await page.getByRole('button', { name: 'Add to cart' }).click();
    await expect(page.getByTestId('cart-count')).toHaveText('1');
  });

  test('should update quantity when same item added twice', async ({ page }) => {
    await page.goto('/products/widget-a');
    await page.getByRole('button', { name: 'Add to cart' }).click();
    await page.getByRole('button', { name: 'Add to cart' }).click();
    await expect(page.getByTestId('cart-count')).toHaveText('2');
  });

  test('user can remove item from cart', async ({ page }) => {
    await page.goto('/cart');
    await page.getByRole('button', { name: 'Remove' }).first().click();
    await expect(page.getByText('Your cart is empty')).toBeVisible();
  });
});
```

**Règles de nommage :**

| Élément | Convention | Exemple |
|---|---|---|
| Nom de fichier | `kebab-case.spec.ts` | `password-reset.spec.ts` |
| `test.describe()` | Title Case, nom de la feature | `'Password Reset'` |
| `test()` | Phrase commençant par `should` ou `user can` | `'should send reset email'` |
| Page objects | `PascalCase.page.ts` | `login.page.ts` / `LoginPage` |
| Fixtures | `kebab-case.fixture.ts` | `auth.fixture.ts` |

---

### Pattern 3 : Regroupement avec `test.describe()`

**À utiliser quand** : un fichier contient plusieurs tests liés qui partagent un contexte ou un setup.
**À éviter quand** : un fichier ne contient que 1 à 3 tests sans setup partagé — saute l'enveloppe `describe`.

**TypeScript :**

```typescript
// tests/auth/login.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Login', () => {
  // Shared setup for all tests in this describe block
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
  });

  test('should login with valid credentials', async ({ page }) => {
    await page.getByLabel('Email').fill('user@example.com');
    await page.getByLabel('Password').fill('securepass123');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await expect(page).toHaveURL('/dashboard');
  });

  test('should show error for invalid password', async ({ page }) => {
    await page.getByLabel('Email').fill('user@example.com');
    await page.getByLabel('Password').fill('wrongpassword');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await expect(page.getByRole('alert')).toHaveText('Invalid credentials');
  });

  // One level of nesting — acceptable
  test.describe('Rate Limiting', () => {
    test('should lock account after 5 failed attempts', async ({ page }) => {
      for (let i = 0; i < 5; i++) {
        await page.getByLabel('Email').fill('user@example.com');
        await page.getByLabel('Password').fill('wrong');
        await page.getByRole('button', { name: 'Sign in' }).click();
      }
      await expect(page.getByRole('alert')).toContainText('Account locked');
    });
  });
});
```

**JavaScript :**

```javascript
// tests/auth/login.spec.js
const { test, expect } = require('@playwright/test');

test.describe('Login', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
  });

  test('should login with valid credentials', async ({ page }) => {
    await page.getByLabel('Email').fill('user@example.com');
    await page.getByLabel('Password').fill('securepass123');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await expect(page).toHaveURL('/dashboard');
  });

  test('should show error for invalid password', async ({ page }) => {
    await page.getByLabel('Email').fill('user@example.com');
    await page.getByLabel('Password').fill('wrongpassword');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await expect(page.getByRole('alert')).toHaveText('Invalid credentials');
  });

  test.describe('Rate Limiting', () => {
    test('should lock account after 5 failed attempts', async ({ page }) => {
      for (let i = 0; i < 5; i++) {
        await page.getByLabel('Email').fill('user@example.com');
        await page.getByLabel('Password').fill('wrong');
        await page.getByRole('button', { name: 'Sign in' }).click();
      }
      await expect(page.getByRole('alert')).toContainText('Account locked');
    });
  });
});
```

**Limite d'imbrication : 2 niveaux max.** Si tu as besoin d'un troisième niveau, découpe dans un fichier séparé.

---

### Pattern 4 : Tags et annotations

**À utiliser quand** : tu dois catégoriser les tests pour des exécutions sélectives (suites smoke, pipelines CI, mise de côté de problèmes connus).
**À éviter quand** : tous les tests s'exécutent toujours ensemble et tu as moins de 20 tests.

**TypeScript :**

```typescript
// tests/checkout/payment.spec.ts
import { test, expect } from '@playwright/test';

// Tag in the test title — simplest approach
test('should process credit card payment @smoke', async ({ page }) => {
  await page.goto('/checkout');
  await page.getByLabel('Card number').fill('4242424242424242');
  await page.getByLabel('Expiry').fill('12/28');
  await page.getByLabel('CVC').fill('123');
  await page.getByRole('button', { name: 'Pay now' }).click();
  await expect(page.getByText('Payment successful')).toBeVisible();
});

test('should handle declined card @regression', async ({ page }) => {
  await page.goto('/checkout');
  await page.getByLabel('Card number').fill('4000000000000002');
  await page.getByLabel('Expiry').fill('12/28');
  await page.getByLabel('CVC').fill('123');
  await page.getByRole('button', { name: 'Pay now' }).click();
  await expect(page.getByRole('alert')).toContainText('Card declined');
});

// Tag via test.describe for group-level tagging
test.describe('Payment Edge Cases @regression', () => {
  test('should handle network timeout during payment', async ({ page }) => {
    await page.goto('/checkout');
    // ... test implementation
    await expect(page.getByText('Please try again')).toBeVisible();
  });
});

// Annotations for test lifecycle control
test('should render 3D Secure iframe @slow', async ({ page }) => {
  test.slow(); // Triples the default timeout
  await page.goto('/checkout/3ds');
  // ... long-running 3D Secure flow
  await expect(page.getByText('Verified')).toBeVisible();
});

test('should apply loyalty points discount', async ({ page }) => {
  test.skip(process.env.CI !== 'true', 'Only run in CI — needs loyalty service');
  await page.goto('/checkout');
  // ...
});

test('should handle Apple Pay on Safari', async ({ page, browserName }) => {
  test.skip(browserName !== 'webkit', 'Apple Pay only works in Safari');
  await page.goto('/checkout');
  // ...
});

test('should display PayPal button', async ({ page }) => {
  test.fixme(); // Known broken — tracked in JIRA-1234
  await page.goto('/checkout');
  await expect(page.getByRole('button', { name: 'PayPal' })).toBeVisible();
});

test('should fail when submitting empty card form', async ({ page }) => {
  test.fail(); // This test is expected to fail — documents known bug
  await page.goto('/checkout');
  await page.getByRole('button', { name: 'Pay now' }).click();
  // Bug: currently no validation shown — this assertion will fail
  await expect(page.getByRole('alert')).toBeVisible();
});
```

**JavaScript :**

```javascript
// tests/checkout/payment.spec.js
const { test, expect } = require('@playwright/test');

test('should process credit card payment @smoke', async ({ page }) => {
  await page.goto('/checkout');
  await page.getByLabel('Card number').fill('4242424242424242');
  await page.getByLabel('Expiry').fill('12/28');
  await page.getByLabel('CVC').fill('123');
  await page.getByRole('button', { name: 'Pay now' }).click();
  await expect(page.getByText('Payment successful')).toBeVisible();
});

test('should handle declined card @regression', async ({ page }) => {
  await page.goto('/checkout');
  await page.getByLabel('Card number').fill('4000000000000002');
  await page.getByLabel('Expiry').fill('12/28');
  await page.getByLabel('CVC').fill('123');
  await page.getByRole('button', { name: 'Pay now' }).click();
  await expect(page.getByRole('alert')).toContainText('Card declined');
});

test.describe('Payment Edge Cases @regression', () => {
  test('should handle network timeout during payment', async ({ page }) => {
    await page.goto('/checkout');
    await expect(page.getByText('Please try again')).toBeVisible();
  });
});

test('should render 3D Secure iframe @slow', async ({ page }) => {
  test.slow();
  await page.goto('/checkout/3ds');
  await expect(page.getByText('Verified')).toBeVisible();
});

test('should apply loyalty points discount', async ({ page }) => {
  test.skip(process.env.CI !== 'true', 'Only run in CI — needs loyalty service');
  await page.goto('/checkout');
});

test('should handle Apple Pay on Safari', async ({ page, browserName }) => {
  test.skip(browserName !== 'webkit', 'Apple Pay only works in Safari');
  await page.goto('/checkout');
});

test('should display PayPal button', async ({ page }) => {
  test.fixme(); // Known broken — tracked in JIRA-1234
  await page.goto('/checkout');
  await expect(page.getByRole('button', { name: 'PayPal' })).toBeVisible();
});

test('should fail when submitting empty card form', async ({ page }) => {
  test.fail();
  await page.goto('/checkout');
  await page.getByRole('button', { name: 'Pay now' }).click();
  await expect(page.getByRole('alert')).toBeVisible();
});
```

**Aide-mémoire des annotations :**

| Annotation | Effet | Quand l'utiliser |
|---|---|---|
| `test.skip()` | Ignore complètement le test | Feature indisponible dans cet environnement/navigateur |
| `test.skip(condition, reason)` | Skip conditionnel | Tests propres à un navigateur ou à un environnement |
| `test.fixme()` | Ignore et marque comme « à corriger » | Bug connu, pas encore corrigé |
| `test.slow()` | Triple le timeout | Tests dont le workflow est intrinsèquement lent |
| `test.fail()` | Attend que le test échoue ; échoue s'il passe | Documenter un bug connu avec un garde-fou de régression |
| `test.info().annotations` | Ajoute des annotations personnalisées | Métadonnées personnalisées pour les rapports |

---

### Pattern 5 : Filtrage des tests

**À utiliser quand** : tu exécutes un sous-ensemble de tests depuis la CLI ou la CI.
**À éviter quand** : jamais — connais ces commandes.

```bash
# By tag (in test title)
npx playwright test --grep @smoke
npx playwright test --grep @regression
npx playwright test --grep-invert @slow     # everything except @slow
npx playwright test -G @slow                # same — -G is the 1.61+ shorthand

# By file
npx playwright test tests/auth/
npx playwright test tests/checkout/payment.spec.ts

# By test name
npx playwright test --grep "should login"

# By project (from playwright.config)
npx playwright test --project=chromium
npx playwright test --project=mobile-safari

# Combine filters
npx playwright test --grep @smoke --project=chromium
npx playwright test tests/checkout/ --grep @smoke

# By line number — run a single test
npx playwright test tests/auth/login.spec.ts:15
```

**Utiliser les tags avec `test.describe.configure()` :**

**TypeScript :**

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  projects: [
    {
      name: 'smoke',
      testMatch: '**/*.spec.ts',
      grep: /@smoke/,
    },
    {
      name: 'regression',
      testMatch: '**/*.spec.ts',
      grep: /@regression/,
    },
    {
      name: 'all',
      testMatch: '**/*.spec.ts',
      grepInvert: /@slow/,
    },
  ],
});
```

**JavaScript :**

```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  projects: [
    {
      name: 'smoke',
      testMatch: '**/*.spec.js',
      grep: /@smoke/,
    },
    {
      name: 'regression',
      testMatch: '**/*.spec.js',
      grep: /@regression/,
    },
    {
      name: 'all',
      testMatch: '**/*.spec.js',
      grepInvert: /@slow/,
    },
  ],
});
```

---

### Pattern 6 : Exécution parallèle vs série

**À utiliser quand** : tu décides comment les tests s'exécutent les uns par rapport aux autres.
**À éviter quand** : tu as moins de 5 tests (le parallélisme n'a pas d'importance).

**Par défaut : toujours en parallèle.** Définis `fullyParallel: true` dans la config.

**TypeScript :**

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  fullyParallel: true, // All tests run in parallel by default
  workers: process.env.CI ? 1 : undefined, // Use all cores locally, 1 in CI (or adjust)
});
```

**JavaScript :**

```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  fullyParallel: true,
  workers: process.env.CI ? 1 : undefined,
});
```

**Exécution série — à n'utiliser que lorsque les tests partagent un état externe que tu ne peux pas isoler :**

**TypeScript :**

```typescript
// tests/onboarding/wizard.spec.ts
import { test, expect } from '@playwright/test';

// ONLY use serial when steps truly depend on prior state that cannot be set up independently
test.describe.serial('Onboarding Wizard', () => {
  test('step 1: user enters company name', async ({ page }) => {
    await page.goto('/onboarding');
    await page.getByLabel('Company name').fill('Acme Corp');
    await page.getByRole('button', { name: 'Next' }).click();
    await expect(page).toHaveURL('/onboarding/step-2');
  });

  test('step 2: user selects plan', async ({ page }) => {
    await page.goto('/onboarding/step-2');
    await page.getByRole('radio', { name: 'Pro plan' }).check();
    await page.getByRole('button', { name: 'Next' }).click();
    await expect(page).toHaveURL('/onboarding/step-3');
  });

  test('step 3: user confirms and completes', async ({ page }) => {
    await page.goto('/onboarding/step-3');
    await page.getByRole('button', { name: 'Complete setup' }).click();
    await expect(page.getByText('Welcome to Acme Corp')).toBeVisible();
  });
});
```

**JavaScript :**

```javascript
// tests/onboarding/wizard.spec.js
const { test, expect } = require('@playwright/test');

test.describe.serial('Onboarding Wizard', () => {
  test('step 1: user enters company name', async ({ page }) => {
    await page.goto('/onboarding');
    await page.getByLabel('Company name').fill('Acme Corp');
    await page.getByRole('button', { name: 'Next' }).click();
    await expect(page).toHaveURL('/onboarding/step-2');
  });

  test('step 2: user selects plan', async ({ page }) => {
    await page.goto('/onboarding/step-2');
    await page.getByRole('radio', { name: 'Pro plan' }).check();
    await page.getByRole('button', { name: 'Next' }).click();
    await expect(page).toHaveURL('/onboarding/step-3');
  });

  test('step 3: user confirms and completes', async ({ page }) => {
    await page.goto('/onboarding/step-3');
    await page.getByRole('button', { name: 'Complete setup' }).click();
    await expect(page.getByText('Welcome to Acme Corp')).toBeVisible();
  });
});
```

**Meilleure alternative : tester le flux complet dans un seul test avec `test.step()` :**

**TypeScript :**

```typescript
// tests/onboarding/wizard.spec.ts
import { test, expect } from '@playwright/test';

test('user completes full onboarding wizard', async ({ page }) => {
  await test.step('enter company name', async () => {
    await page.goto('/onboarding');
    await page.getByLabel('Company name').fill('Acme Corp');
    await page.getByRole('button', { name: 'Next' }).click();
    await expect(page).toHaveURL('/onboarding/step-2');
  });

  await test.step('select plan', async () => {
    await page.getByRole('radio', { name: 'Pro plan' }).check();
    await page.getByRole('button', { name: 'Next' }).click();
    await expect(page).toHaveURL('/onboarding/step-3');
  });

  await test.step('confirm and complete', async () => {
    await page.getByRole('button', { name: 'Complete setup' }).click();
    await expect(page.getByText('Welcome to Acme Corp')).toBeVisible();
  });
});
```

**JavaScript :**

```javascript
// tests/onboarding/wizard.spec.js
const { test, expect } = require('@playwright/test');

test('user completes full onboarding wizard', async ({ page }) => {
  await test.step('enter company name', async () => {
    await page.goto('/onboarding');
    await page.getByLabel('Company name').fill('Acme Corp');
    await page.getByRole('button', { name: 'Next' }).click();
    await expect(page).toHaveURL('/onboarding/step-2');
  });

  await test.step('select plan', async () => {
    await page.getByRole('radio', { name: 'Pro plan' }).check();
    await page.getByRole('button', { name: 'Next' }).click();
    await expect(page).toHaveURL('/onboarding/step-3');
  });

  await test.step('confirm and complete', async () => {
    await page.getByRole('button', { name: 'Complete setup' }).click();
    await expect(page.getByText('Welcome to Acme Corp')).toBeVisible();
  });
});
```

**Options de step** : `test.step(title, body, { box, timeout, subtitle, params })`. `box: true` signale les échecs à l'endroit où le step est appelé plutôt qu'à l'intérieur d'un helper ; `timeout` plafonne la durée d'un step. Depuis la 1.63, `subtitle` et `params` attachent des données structurées que le rapport HTML et le trace viewer affichent à côté du titre du step :

```javascript
await test.step('select plan', async () => {
  await page.getByRole('radio', { name: 'Pro plan' }).check();
}, { subtitle: 'Pro', params: { plan: 'pro', seats: 5 } });
```

---

### Pattern 7 : Tests en monorepo

**À utiliser quand** : un même dépôt contient plusieurs apps ou packages qui ont chacun besoin de tests E2E.
**À éviter quand** : dépôt à application unique.

**TypeScript :**

```typescript
// playwright.config.ts (root of monorepo)
import { defineConfig } from '@playwright/test';

export default defineConfig({
  projects: [
    {
      name: 'web-app',
      testDir: './apps/web/tests',
      use: {
        baseURL: 'http://localhost:3000',
      },
    },
    {
      name: 'admin-panel',
      testDir: './apps/admin/tests',
      use: {
        baseURL: 'http://localhost:3001',
      },
    },
    {
      name: 'marketing-site',
      testDir: './apps/marketing/tests',
      use: {
        baseURL: 'http://localhost:4000',
      },
    },
  ],
});
```

**JavaScript :**

```javascript
// playwright.config.js (root of monorepo)
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  projects: [
    {
      name: 'web-app',
      testDir: './apps/web/tests',
      use: {
        baseURL: 'http://localhost:3000',
      },
    },
    {
      name: 'admin-panel',
      testDir: './apps/admin/tests',
      use: {
        baseURL: 'http://localhost:3001',
      },
    },
    {
      name: 'marketing-site',
      testDir: './apps/marketing/tests',
      use: {
        baseURL: 'http://localhost:4000',
      },
    },
  ],
});
```

**Arborescence d'un monorepo :**

```
monorepo/
├── apps/
│   ├── web/
│   │   ├── src/
│   │   └── tests/
│   │       ├── auth/
│   │       │   └── login.spec.ts
│   │       └── dashboard/
│   │           └── widgets.spec.ts
│   ├── admin/
│   │   ├── src/
│   │   └── tests/
│   │       └── user-management.spec.ts
│   └── marketing/
│       ├── src/
│       └── tests/
│           └── landing-page.spec.ts
├── packages/
│   └── shared-fixtures/
│       ├── auth.fixture.ts
│       └── index.ts
└── playwright.config.ts
```

Pour n'exécuter que les tests d'une seule app :

```bash
npx playwright test --project=web-app
npx playwright test --project=admin-panel
```

## Guide de décision

```
How many tests do you have?
│
├── < 20 tests (small)
│   ├── Flat structure: all .spec.ts files in tests/
│   ├── No subdirectories needed
│   ├── Tags optional — just run everything
│   └── fullyParallel: true, single config project
│
├── 20–200 tests (medium)
│   ├── Feature subdirectories: tests/auth/, tests/checkout/
│   ├── Use @smoke tag for critical-path subset (< 15 min)
│   ├── Shared fixtures in tests/fixtures/
│   ├── Page objects in tests/page-objects/ (if you use them)
│   └── Consider separate projects for different browsers
│
└── 200+ tests (large)
    ├── Top-level split: tests/e2e/, tests/api/, tests/visual/
    ├── Feature subdirectories under each
    ├── @smoke, @regression, @slow tags — multiple CI pipelines
    ├── Sharding in CI for faster runs
    ├── Project-based filtering: smoke project, full project
    └── Shared fixtures as a package in monorepo
```

```
Should I use test.describe.serial()?
│
├── Can each test set up its own state via API/fixture?
│   └── YES → Do NOT use serial. Use independent parallel tests.
│
├── Is this a multi-step wizard where each step changes server state
│   that cannot be reset between tests?
│   └── Write it as ONE test with test.step() instead.
│
└── Is this genuinely stateful (e.g., database migration sequence)?
    └── Use serial as last resort. Add a comment explaining why.
```

## Anti-patterns

### Un seul fichier de test géant

```typescript
// BAD: tests/all-tests.spec.ts with 80 tests and 2000+ lines
test.describe('Everything', () => {
  test('login works', async ({ page }) => { /* ... */ });
  test('signup works', async ({ page }) => { /* ... */ });
  test('cart works', async ({ page }) => { /* ... */ });
  // ... 77 more tests
});
```

**Correctif :** découpe par feature — un fichier par domaine fonctionnel, 5 à 15 tests par fichier.

---

### Noms de tests sans signification

```typescript
// BAD
test('test1', async ({ page }) => { /* ... */ });
test('test2', async ({ page }) => { /* ... */ });
test('payment test', async ({ page }) => { /* ... */ });
test('it works', async ({ page }) => { /* ... */ });
```

**Correctif :** décris le comportement. Quand un test échoue, son nom doit t'indiquer ce qui est cassé.

```typescript
// GOOD
test('should reject expired credit card', async ({ page }) => { /* ... */ });
test('user can update shipping address during checkout', async ({ page }) => { /* ... */ });
```

---

### Imbrication profonde de `describe`

```typescript
// BAD: 3+ levels deep — hard to read, hard to find tests in reports
test.describe('Auth', () => {
  test.describe('Login', () => {
    test.describe('With MFA', () => {
      test.describe('SMS', () => {
        test('should send code', async ({ page }) => { /* ... */ });
      });
    });
  });
});
```

**Correctif :** 2 niveaux max. Découpe les imbrications plus profondes dans des fichiers séparés.

```typescript
// GOOD: tests/auth/login-mfa-sms.spec.ts
test.describe('Login with SMS MFA', () => {
  test('should send verification code', async ({ page }) => { /* ... */ });
  test('should reject invalid code', async ({ page }) => { /* ... */ });
});
```

---

### Utiliser `test.describe.serial()` par défaut

```typescript
// BAD: serial for no reason — kills parallelism, creates hidden dependencies
test.describe.serial('User Profile', () => {
  test('should display profile page', async ({ page }) => { /* ... */ });
  test('should update display name', async ({ page }) => { /* ... */ });
  test('should upload avatar', async ({ page }) => { /* ... */ });
});
```

**Correctif :** chaque test doit être indépendant. Utilise `beforeEach` ou des fixtures pour préparer l'état.

```typescript
// GOOD
test.describe('User Profile', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/profile');
  });

  test('should display profile page', async ({ page }) => { /* ... */ });
  test('should update display name', async ({ page }) => { /* ... */ });
  test('should upload avatar', async ({ page }) => { /* ... */ });
});
```

---

### Dépendre de l'ordre d'exécution des tests

```typescript
// BAD: test 2 depends on test 1 creating data
test('should create a product', async ({ page }) => {
  // creates "Widget X" in the database
});

test('should edit the product', async ({ page }) => {
  // assumes "Widget X" exists — breaks if run alone or in parallel
});
```

**Correctif :** chaque test crée ses propres données via des appels d'API ou des fixtures.

```typescript
// GOOD
test('should edit a product', async ({ page, request }) => {
  // Set up test data independently
  const response = await request.post('/api/products', {
    data: { name: 'Widget X', price: 9.99 },
  });
  const product = await response.json();

  await page.goto(`/products/${product.id}/edit`);
  await page.getByLabel('Name').fill('Widget X Updated');
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page.getByText('Widget X Updated')).toBeVisible();
});
```

## Dépannage

| Problème | Cause | Correctif |
|---|---|---|
| Les tests passent seuls mais échouent ensemble | État partagé entre les tests (cookies, lignes en base, variables globales) | Isole chaque test — utilise des fixtures pour le setup/teardown |
| `--grep @smoke` ne correspond à rien | Le tag n'est pas dans la chaîne du titre du test | Vérifie que le tag apparaît littéralement dans `test('... @smoke', ...)` |
| Les tests série échouent en cascade | Un test échoue, tous les suivants sont ignorés | Réécris en tests indépendants ou utilise `test.step()` dans un seul test |
| Les tests sont plus lents que prévu | `fullyParallel` non défini | Ajoute `fullyParallel: true` dans `playwright.config` |
| Mauvais tests exécutés en CI | `testMatch` ou `testDir` mal configuré | Vérifie `playwright.config` — affiche la config résolue avec `npx playwright test --list` |
| Les tests du monorepo récupèrent les mauvais fichiers | Le `testDir` par défaut est `.` | Définis un `testDir` explicite par project |

## Voir aussi

- [core/configuration.md](configuration.md) — `testMatch`, `testDir`, `fullyParallel`, `workers`
- [core/fixtures-and-hooks.md](fixtures-and-hooks.md) — setup partagé via des fixtures plutôt que `beforeAll`
- [core/test-architecture.md](test-architecture.md) — quand écrire des tests E2E, API ou de composants
- [ci/parallel-and-sharding.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/parallel-and-sharding.md) — sharding en CI pour les grandes suites
- [ci/projects-and-dependencies.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/projects-and-dependencies.md) — configuration multi-project
