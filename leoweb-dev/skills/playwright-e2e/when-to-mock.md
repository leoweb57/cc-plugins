# Quand mocker et quand utiliser de vrais services

> **Quand l'utiliser** : quand tu dois décider de mocker des appels d'API, d'intercepter des requêtes réseau ou d'appeler de vrais services dans tes tests Playwright.
> **Prérequis** : [core/locators.md](locators.md), [core/assertions-and-waiting.md](assertions-and-waiting.md)

## Réponse rapide

**Mocke à la frontière, teste ta stack de bout en bout.** Mocke les services tiers que tu ne possèdes pas (Stripe, SendGrid, fournisseurs OAuth, analytics). Ne mocke jamais la communication entre ton frontend et ton backend. Tes tests doivent prouver que TON code fonctionne, pas que les API tierces sont disponibles.

## Organigramme de décision

```
Is this service part of YOUR codebase (your API, your backend)?
├── YES → Do NOT mock. Test the real integration.
│   ├── Is it slow? → Optimize the service, not the test.
│   └── Is it flaky? → Fix the service. Flaky infra is a bug.
└── NO → It's a third-party service.
    ├── Is it free, fast, and reliable? (rare)
    │   └── Consider real in CI. Mock if rate-limited.
    ├── Is it paid per call? (Stripe, Twilio, SendGrid)
    │   └── ALWAYS mock.
    ├── Is it rate-limited? (OAuth, social APIs)
    │   └── ALWAYS mock.
    ├── Is it slow or unreliable?
    │   └── ALWAYS mock.
    └── Is it a complex multi-step flow? (OAuth redirect dance)
        └── Mock with HAR recording. Update periodically.
```

## Matrice de décision

| Scénario | Mocker ? | Pourquoi | Stratégie |
|---|---|---|---|
| Ta propre API REST/GraphQL | Jamais | C'est PRÉCISÉMENT l'intégration que tu testes | Appelle la vraie API sur staging ou en dev local |
| Ta base de données (via ton API) | Jamais | Les allers-retours de données sont tout l'intérêt de l'E2E | Alimente via l'API ou des fixtures, ne mocke jamais la BDD |
| Authentification (ton système d'auth) | Plutôt non | Les bugs d'auth sont critiques ; teste le vrai flux | Utilise `storageState` pour sauter le login dans la plupart des tests, mais garde quelques vrais tests de login |
| Stripe / passerelle de paiement | Toujours | Coûte de l'argent, limité en débit, flaky en CI | `route.fulfill()` avec les réponses attendues |
| SendGrid / service d'e-mail | Toujours | Effets de bord (vrais e-mails), pas d'UI à vérifier | Mocke l'appel d'API, vérifie le payload de la requête |
| Fournisseurs OAuth (Google, GitHub) | Toujours | Beaucoup de redirections, limités en débit, CAPTCHAs | Mocke l'échange de token, teste ton handler de callback |
| Analytics (Segment, Mixpanel) | Toujours | Fire-and-forget, aucun impact sur l'UI, ralentit les tests | `route.abort()` ou `route.fulfill()` |
| API de cartes / géocodage | Toujours | Limitées en débit, payantes, lentes | Mocke avec des réponses statiques |
| Feature flags (LaunchDarkly, etc.) | Généralement | Contrôler les conditions de test de façon déterministe | Mocke pour forcer des états de flag précis |
| CDN / assets statiques | Jamais | Déjà rapides, font partie de ton infra | Laisse-les se charger normalement |
| Dépendance externe flaky | CI : mock, local : réel | Garde la CI verte, détecte les vrais problèmes en local | Mock conditionnel selon l'environnement |
| Dépendance externe lente | Dev : mock, nightly : réel | Retour rapide en dev, intégration complète en nightly | Projects de test séparés dans la config |

## Stratégies de mock

### Mock complet (route.fulfill)

**À utiliser quand** : tu veux remplacer entièrement la réponse d'une API tierce. La stratégie de mock la plus courante.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('checkout flow with mocked payment API', async ({ page }) => {
  // Mock Stripe payment intent creation
  await page.route('**/api/create-payment-intent', (route) => {
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        clientSecret: 'pi_mock_secret_123',
        amount: 9900,
        currency: 'usd',
      }),
    });
  });

  // Mock Stripe confirmation
  await page.route('**/api/confirm-payment', (route) => {
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        status: 'succeeded',
        receiptUrl: 'https://receipt.example.com/123',
      }),
    });
  });

  await page.goto('/checkout');
  await page.getByRole('button', { name: 'Pay $99.00' }).click();
  await expect(page.getByText('Payment successful')).toBeVisible();
});

test('handle payment failure gracefully', async ({ page }) => {
  // Mock a declined card response
  await page.route('**/api/confirm-payment', (route) => {
    route.fulfill({
      status: 402,
      contentType: 'application/json',
      body: JSON.stringify({
        error: { code: 'card_declined', message: 'Your card was declined.' },
      }),
    });
  });

  await page.goto('/checkout');
  await page.getByRole('button', { name: 'Pay $99.00' }).click();
  await expect(page.getByRole('alert')).toContainText('card was declined');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('checkout flow with mocked payment API', async ({ page }) => {
  await page.route('**/api/create-payment-intent', (route) => {
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        clientSecret: 'pi_mock_secret_123',
        amount: 9900,
        currency: 'usd',
      }),
    });
  });

  await page.route('**/api/confirm-payment', (route) => {
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        status: 'succeeded',
        receiptUrl: 'https://receipt.example.com/123',
      }),
    });
  });

  await page.goto('/checkout');
  await page.getByRole('button', { name: 'Pay $99.00' }).click();
  await expect(page.getByText('Payment successful')).toBeVisible();
});

test('handle payment failure gracefully', async ({ page }) => {
  await page.route('**/api/confirm-payment', (route) => {
    route.fulfill({
      status: 402,
      contentType: 'application/json',
      body: JSON.stringify({
        error: { code: 'card_declined', message: 'Your card was declined.' },
      }),
    });
  });

  await page.goto('/checkout');
  await page.getByRole('button', { name: 'Pay $99.00' }).click();
  await expect(page.getByRole('alert')).toContainText('card was declined');
});
```

### Mock partiel (modifier les réponses)

**À utiliser quand** : tu veux que l'appel d'API réel ait lieu mais que tu dois ajuster la réponse -- injecter des états d'erreur, ajouter des données de cas limites ou surcharger un seul champ.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('show warning when inventory is low', async ({ page }) => {
  // Let the real API call go through, but override the stock count
  await page.route('**/api/products/*', async (route) => {
    const response = await route.fetch(); // forward to real server
    const body = await response.json();

    // Modify just the field we care about
    body.stockCount = 2;
    body.lowStockWarning = true;

    await route.fulfill({
      response, // preserve headers, status
      body: JSON.stringify(body),
    });
  });

  await page.goto('/products/running-shoes');
  await expect(page.getByText('Only 2 left in stock')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Add to cart' })).toBeEnabled();
});

test('inject additional items into a real API response', async ({ page }) => {
  await page.route('**/api/notifications', async (route) => {
    const response = await route.fetch();
    const body = await response.json();

    // Append a test notification to whatever real data comes back
    body.notifications.push({
      id: 'test-notif',
      message: 'Your export is ready',
      type: 'success',
      read: false,
    });

    await route.fulfill({
      response,
      body: JSON.stringify(body),
    });
  });

  await page.goto('/dashboard');
  await expect(page.getByText('Your export is ready')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('show warning when inventory is low', async ({ page }) => {
  await page.route('**/api/products/*', async (route) => {
    const response = await route.fetch();
    const body = await response.json();

    body.stockCount = 2;
    body.lowStockWarning = true;

    await route.fulfill({
      response,
      body: JSON.stringify(body),
    });
  });

  await page.goto('/products/running-shoes');
  await expect(page.getByText('Only 2 left in stock')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Add to cart' })).toBeEnabled();
});

test('inject additional items into a real API response', async ({ page }) => {
  await page.route('**/api/notifications', async (route) => {
    const response = await route.fetch();
    const body = await response.json();

    body.notifications.push({
      id: 'test-notif',
      message: 'Your export is ready',
      type: 'success',
      read: false,
    });

    await route.fulfill({
      response,
      body: JSON.stringify(body),
    });
  });

  await page.goto('/dashboard');
  await expect(page.getByText('Your export is ready')).toBeVisible();
});
```

### Enregistrer et rejouer (fichiers HAR)

**À utiliser quand** : séquences d'API complexes avec de nombreux endpoints (flux OAuth, wizards multi-étapes, chargement de données d'un dashboard). Enregistre une fois depuis une vraie session, rejoue de façon déterministe. Mets à jour l'enregistrement périodiquement pour que les mocks ne dérivent pas de la réalité.

**Enregistrer un fichier HAR :**

**TypeScript**
```typescript
import { test } from '@playwright/test';

// Record HAR — run this once, then commit the .har file
test('record API traffic for dashboard', async ({ page }) => {
  await page.routeFromHAR('tests/fixtures/dashboard.har', {
    url: '**/api/**',
    update: true, // record mode: forwards requests and saves responses
  });

  await page.goto('/dashboard');
  // Interact with the page to capture all relevant API calls
  await page.getByRole('tab', { name: 'Analytics' }).click();
  await page.getByRole('tab', { name: 'Users' }).click();
  await page.getByRole('button', { name: 'Load more' }).click();

  // HAR file is saved automatically when the page closes
});
```

**Rejouer un fichier HAR :**

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('dashboard loads with recorded data', async ({ page }) => {
  // Replay mode: serves responses from the HAR file
  await page.routeFromHAR('tests/fixtures/dashboard.har', {
    url: '**/api/**',
    update: false, // replay mode (default)
  });

  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { name: 'Analytics' })).toBeVisible();
  await expect(page.getByTestId('revenue-chart')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

// Record
test('record API traffic for dashboard', async ({ page }) => {
  await page.routeFromHAR('tests/fixtures/dashboard.har', {
    url: '**/api/**',
    update: true,
  });

  await page.goto('/dashboard');
  await page.getByRole('tab', { name: 'Analytics' }).click();
  await page.getByRole('tab', { name: 'Users' }).click();
  await page.getByRole('button', { name: 'Load more' }).click();
});

// Replay
test('dashboard loads with recorded data', async ({ page }) => {
  await page.routeFromHAR('tests/fixtures/dashboard.har', {
    url: '**/api/**',
    update: false,
  });

  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { name: 'Analytics' })).toBeVisible();
  await expect(page.getByTestId('revenue-chart')).toBeVisible();
});
```

**Workflow de maintenance des HAR :**
1. Enregistre les fichiers HAR sur un environnement de staging réputé sain.
2. Commite les fichiers `.har` dans le contrôle de version (c'est du JSON, diffable).
3. Ré-enregistre chaque mois ou quand les API changent. Ajoute un rappel en CI ou un événement dans le calendrier.
4. Utilise `update: true` dans un fichier de test dédié pour rafraîchir les enregistrements.
5. Limite le HAR à des patterns d'URL précis (`url: '**/api/v2/**'`) pour que les requêtes sans rapport atteignent toujours les vrais serveurs.

### Bloquer les requêtes indésirables

**À utiliser quand** : des scripts tiers (analytics, publicités, widgets de chat) ralentissent les tests sans apporter de valeur. Bloque-les purement et simplement.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.beforeEach(async ({ page }) => {
  // Block analytics and tracking — they slow tests and add no coverage
  await page.route('**/{google-analytics,segment,hotjar,intercom}.{com,io}/**', (route) => {
    route.abort();
  });

  // Block all image requests in tests that don't need them
  // await page.route('**/*.{png,jpg,jpeg,gif,svg,webp}', (route) => route.abort());
});

test('page loads fast without third-party scripts', async ({ page }) => {
  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.beforeEach(async ({ page }) => {
  await page.route('**/{google-analytics,segment,hotjar,intercom}.{com,io}/**', (route) => {
    route.abort();
  });
});

test('page loads fast without third-party scripts', async ({ page }) => {
  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

## Stratégies avec de vrais services

### Contre un environnement de staging

**À utiliser quand** : tu as un environnement de staging partagé qui reflète la production. Idéal pour la confiance dans l'intégration.

**TypeScript**
```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  use: {
    baseURL: process.env.CI
      ? 'https://staging.yourapp.com'
      : 'http://localhost:3000',
  },
  projects: [
    {
      name: 'integration',
      testMatch: '**/*.integration.spec.ts',
      use: { baseURL: 'https://staging.yourapp.com' },
    },
    {
      name: 'e2e',
      testMatch: '**/*.e2e.spec.ts',
      use: { baseURL: 'http://localhost:3000' },
    },
  ],
});
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  use: {
    baseURL: process.env.CI
      ? 'https://staging.yourapp.com'
      : 'http://localhost:3000',
  },
  projects: [
    {
      name: 'integration',
      testMatch: '**/*.integration.spec.js',
      use: { baseURL: 'https://staging.yourapp.com' },
    },
    {
      name: 'e2e',
      testMatch: '**/*.e2e.spec.js',
      use: { baseURL: 'http://localhost:3000' },
    },
  ],
});
```

### Contre un serveur de dev local

**À utiliser quand** : boucle de retour la plus rapide. Fais tourner ton backend en local et teste contre lui.

**TypeScript**
```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI, // start fresh in CI, reuse locally
    timeout: 30_000,
  },
  use: {
    baseURL: 'http://localhost:3000',
  },
});
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
  use: {
    baseURL: 'http://localhost:3000',
  },
});
```

### Contre des conteneurs de test

**À utiliser quand** : tu as besoin d'un environnement entièrement isolé avec bases de données, caches et services. Idéal pour des runs de CI reproductibles.

**TypeScript**
```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  webServer: {
    command: 'docker compose -f docker-compose.test.yml up --wait',
    url: 'http://localhost:3000/health',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000, // containers take longer to start
  },
  use: {
    baseURL: 'http://localhost:3000',
  },
  // Global teardown to stop containers
  globalTeardown: './tests/global-teardown.ts',
});
```

```typescript
// tests/global-teardown.ts
import { execSync } from 'child_process';

export default function globalTeardown() {
  if (process.env.CI) {
    execSync('docker compose -f docker-compose.test.yml down -v');
  }
}
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  webServer: {
    command: 'docker compose -f docker-compose.test.yml up --wait',
    url: 'http://localhost:3000/health',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
  use: {
    baseURL: 'http://localhost:3000',
  },
  globalTeardown: './tests/global-teardown.js',
});
```

```javascript
// tests/global-teardown.js
const { execSync } = require('child_process');

module.exports = function globalTeardown() {
  if (process.env.CI) {
    execSync('docker compose -f docker-compose.test.yml down -v');
  }
};
```

## Approche hybride

Les suites de tests les plus solides combinent services réels et mockés. Le principe : **mocke ce que tu ne possèdes pas, exécute ce que tu possèdes.**

### Contrôle des mocks via fixtures

Crée une fixture qui permet à chaque test de choisir de mocker certains services tout en gardant tout le reste réel.

**TypeScript**
```typescript
// tests/fixtures/mock-fixtures.ts
import { test as base } from '@playwright/test';

type MockOptions = {
  mockPayments: boolean;
  mockEmail: boolean;
  mockAnalytics: boolean;
};

export const test = base.extend<MockOptions>({
  mockPayments: [true, { option: true }],  // default: mock payments
  mockEmail: [true, { option: true }],     // default: mock email
  mockAnalytics: [true, { option: true }], // default: mock analytics

  page: async ({ page, mockPayments, mockEmail, mockAnalytics }, use) => {
    if (mockPayments) {
      await page.route('**/api/payments/**', (route) => {
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ status: 'succeeded', id: 'pay_mock_123' }),
        });
      });
    }

    if (mockEmail) {
      await page.route('**/api/send-email', (route) => {
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ messageId: 'msg_mock_456' }),
        });
      });
    }

    if (mockAnalytics) {
      await page.route('**/{segment,google-analytics,mixpanel}.**/**', (route) => {
        route.abort();
      });
    }

    await use(page);
  },
});

export { expect } from '@playwright/test';
```

```typescript
// tests/checkout.spec.ts
import { test, expect } from './fixtures/mock-fixtures';

// Uses defaults: payments mocked, email mocked, analytics blocked
test('checkout sends confirmation email', async ({ page }) => {
  await page.goto('/checkout');
  await page.getByRole('button', { name: 'Pay $99.00' }).click();
  await expect(page.getByText('Confirmation email sent')).toBeVisible();
});

// Override: test with real payment API (nightly integration test)
test.describe('nightly integration', () => {
  test.use({ mockPayments: false });

  test('real payment flow against Stripe test mode', async ({ page }) => {
    await page.goto('/checkout');
    // This hits the real Stripe test API
    await page.getByRole('button', { name: 'Pay $99.00' }).click();
    await expect(page.getByText('Payment successful')).toBeVisible();
  });
});
```

**JavaScript**
```javascript
// tests/fixtures/mock-fixtures.js
const { test: base } = require('@playwright/test');

const test = base.extend({
  mockPayments: [true, { option: true }],
  mockEmail: [true, { option: true }],
  mockAnalytics: [true, { option: true }],

  page: async ({ page, mockPayments, mockEmail, mockAnalytics }, use) => {
    if (mockPayments) {
      await page.route('**/api/payments/**', (route) => {
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ status: 'succeeded', id: 'pay_mock_123' }),
        });
      });
    }

    if (mockEmail) {
      await page.route('**/api/send-email', (route) => {
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ messageId: 'msg_mock_456' }),
        });
      });
    }

    if (mockAnalytics) {
      await page.route('**/{segment,google-analytics,mixpanel}.**/**', (route) => {
        route.abort();
      });
    }

    await use(page);
  },
});

module.exports = { test, expect: require('@playwright/test').expect };
```

```javascript
// tests/checkout.spec.js
const { test, expect } = require('./fixtures/mock-fixtures');

test('checkout sends confirmation email', async ({ page }) => {
  await page.goto('/checkout');
  await page.getByRole('button', { name: 'Pay $99.00' }).click();
  await expect(page.getByText('Confirmation email sent')).toBeVisible();
});

test.describe('nightly integration', () => {
  test.use({ mockPayments: false });

  test('real payment flow against Stripe test mode', async ({ page }) => {
    await page.goto('/checkout');
    await page.getByRole('button', { name: 'Pay $99.00' }).click();
    await expect(page.getByText('Payment successful')).toBeVisible();
  });
});
```

### Mocking selon l'environnement

Sépare les projects de test par environnement pour exécuter les tests mockés à chaque push en CI et les tests d'intégration complète chaque nuit.

**TypeScript**
```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  projects: [
    {
      name: 'fast-ci',
      testMatch: '**/*.spec.ts',
      use: {
        baseURL: 'http://localhost:3000',
        // All external services mocked via fixtures
      },
    },
    {
      name: 'nightly-integration',
      testMatch: '**/*.integration.spec.ts',
      use: {
        baseURL: 'https://staging.yourapp.com',
        // Real services, longer timeouts
      },
      timeout: 120_000,
    },
  ],
});
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  projects: [
    {
      name: 'fast-ci',
      testMatch: '**/*.spec.js',
      use: {
        baseURL: 'http://localhost:3000',
      },
    },
    {
      name: 'nightly-integration',
      testMatch: '**/*.integration.spec.js',
      use: {
        baseURL: 'https://staging.yourapp.com',
      },
      timeout: 120_000,
    },
  ],
});
```

### Vérifier la fidélité des mocks

Les réponses mockées dérivent des vraies API avec le temps. Protège-toi contre cela.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// Run this weekly or when APIs change — validates that mocks match reality
test.describe('mock contract validation', () => {
  test('payment mock matches real Stripe test API shape', async ({ request }) => {
    // Hit the real API
    const realResponse = await request.post('/api/create-payment-intent', {
      data: { amount: 9900, currency: 'usd' },
    });
    const realBody = await realResponse.json();

    // Verify mock has the same shape
    const mockBody = {
      clientSecret: 'pi_mock_secret_123',
      amount: 9900,
      currency: 'usd',
    };

    // Same keys exist in both
    expect(Object.keys(mockBody).sort()).toEqual(Object.keys(realBody).sort());

    // Same types for each key
    for (const key of Object.keys(mockBody)) {
      expect(typeof mockBody[key]).toBe(typeof realBody[key]);
    }
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('mock contract validation', () => {
  test('payment mock matches real Stripe test API shape', async ({ request }) => {
    const realResponse = await request.post('/api/create-payment-intent', {
      data: { amount: 9900, currency: 'usd' },
    });
    const realBody = await realResponse.json();

    const mockBody = {
      clientSecret: 'pi_mock_secret_123',
      amount: 9900,
      currency: 'usd',
    };

    expect(Object.keys(mockBody).sort()).toEqual(Object.keys(realBody).sort());

    for (const key of Object.keys(mockBody)) {
      expect(typeof mockBody[key]).toBe(typeof realBody[key]);
    }
  });
});
```

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| Mocker ta propre API (`page.route('**/api/users', ...)` alors que tu possèdes l'endpoint `/api/users`) | Tu testes une fiction. Ton frontend et ton backend peuvent être totalement incompatibles. | Appelle ta vraie API. Ne mocke que les services tiers derrière ton API. |
| Tout mocker pour la vitesse | Les tests passent, l'app casse. Tu n'as aucune couverture d'intégration. | Ne mocke que les frontières externes. Optimise tes propres services pour la vitesse des tests. |
| Ne jamais rien mocker | Les tests sont lents, flaky et échouent quand Stripe a une panne. Tu testes la disponibilité de tiers, pas ton code. | Mocke les services tiers. Ta CI ne doit pas dépendre de l'infrastructure de quelqu'un d'autre. |
| Utiliser des mocks périmés qui ne correspondent pas à la vraie API | Le mock renvoie `{ status: "ok" }` mais la vraie API renvoie `{ status: "success", data: {...} }`. Les tests passent, la production casse. | Exécute périodiquement des tests de validation de contrat. Ré-enregistre les fichiers HAR chaque mois. |
| Mocker à la mauvaise couche (intercepter ton propre client HTTP frontend) | Contourne la sérialisation des requêtes/réponses, les headers, la gestion des erreurs. | Mocke au niveau réseau avec `page.route()`. Cela teste tout ton code de client HTTP. |
| Copier-coller les réponses mockées dans des dizaines de fichiers de test | Un changement d'API oblige à mettre à jour 40 fichiers. Les mocks divergent. | Centralise les mocks dans des fixtures ou des fichiers helpers. Une seule source de vérité. |
| Mocker avec `page.evaluate()` pour stubber `fetch`/`XMLHttpRequest` | Fragile, ne survit pas à la navigation, ignore les service workers. | Utilise `page.route()`, qui intercepte au niveau réseau. |
| Bloquer toutes les requêtes réseau et utiliser une whitelist | Extrêmement fragile. Chaque nouvel endpoint d'API nécessite une mise à jour de la whitelist. Les tests cassent à chaque changement de backend. | Autorise tout le trafic par défaut. Ne mocke sélectivement que les services tiers nécessaires. |

## Voir aussi

- [core/network-mocking.md](network-mocking.md) -- patterns détaillés d'interception réseau et API
- [core/api-testing.md](api-testing.md) -- tester ton API directement avec le contexte `request`
- [core/authentication.md](authentication.md) -- quand mocker l'auth vs tester de vrais flux de login
- [core/fixtures-and-hooks.md](fixtures-and-hooks.md) -- construire des fixtures de mock réutilisables
- [core/configuration.md](configuration.md) -- `webServer`, `baseURL` et configuration des projects
- [ci/ci-github-actions.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/ci-github-actions.md) -- configuration de la CI pour différents niveaux de tests
