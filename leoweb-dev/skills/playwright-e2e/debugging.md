# Débugger les tests Playwright

> **Quand l'utiliser** : un test échoue et tu dois comprendre pourquoi — mauvais sélecteurs, problèmes de timing, échecs réseau ou état inattendu de l'application.

## Référence rapide

| Outil | Commande | Idéal pour |
|---|---|---|
| UI Mode | `npx playwright test --ui` | Exploration interactive, timeline visuelle, relance de tests |
| Playwright Inspector | `PWDEBUG=1 npx playwright test` | Débogage pas à pas, playground de sélecteurs |
| Trace Viewer | `npx playwright show-trace trace.zip` | Analyse post-mortem d'un échec en CI |
| Débogueur CLI | `npx playwright test --debug=cli` | Workflows d'agents, sessions SSH, débogage orienté terminal |
| Mode headed | `npx playwright test --headed` | Regarder le navigateur pendant l'exécution du test |
| Ralenti | `--headed` + `launchOptions: { slowMo: 500 }` dans la config (pas de flag CLI) | Suivre visuellement des interactions rapides |
| `page.pause()` | À insérer dans le code du test | Mettre en pause à un point précis pour inspecter l'état |
| Logs d'API verbeux | `DEBUG=pw:api npx playwright test` | Voir chaque appel d'API Playwright avec son timing |
| Extension VS Code | Playwright Test for VS Code | Points d'arrêt, pas à pas, sélection de locator |
| Relancer uniquement les échecs | `npx playwright test --last-failed` | Boucle corriger-relancer après un run complet |
| Lancer uniquement les tests modifiés | `npx playwright test --only-changed[=origin/main]` | Fichiers de test modifiés par rapport à `HEAD` (non commités) ou à une ref |
| S'arrêter au premier échec | `npx playwright test -x` | Retour rapide ; `--max-failures=N` pour N |

## Workflow de débogage systématique

Suis cet ordre. Ne saute pas directement à l'étape 5 — la plupart des problèmes se résolvent dès l'étape 2.

```
1. Read the full error message
   └─ Check error-index.md for known patterns
2. Run with --ui to see what happened visually
   └─ Timeline shows every action, screenshot at failure point
3. Enable tracing if not already on
   └─ use: { trace: 'on' } temporarily in config
4. Check the network tab in trace for API failures
   └─ Missing responses, 4xx/5xx, CORS errors
5. Insert page.pause() at the failure point
   └─ Inspect live DOM, try selectors in console
6. Check browser console for JavaScript errors
   └─ page.on('console') or console tab in trace
```

## Patterns

### Pattern 1 : UI Mode pour le débogage interactif

**À utiliser quand** : tu développes de nouveaux tests, tu investigues des échecs en local, tu explores le comportement de l'application.
**À éviter quand** : en environnement CI (utilise plutôt les traces).

UI Mode fournit une timeline visuelle, des snapshots du DOM à chaque étape, une cascade réseau et la possibilité de relancer des tests individuels.

**TypeScript**
```typescript
// Launch UI Mode from terminal:
// npx playwright test --ui

// Run a specific test file in UI Mode:
// npx playwright test tests/checkout.spec.ts --ui

// playwright.config.ts — configure for UI Mode convenience
import { defineConfig } from '@playwright/test';

export default defineConfig({
  use: {
    // Traces are always available in UI Mode regardless of this setting,
    // but this ensures traces are captured for CI failures too
    trace: 'on-first-retry',
  },
});
```

Pour les tests flaky sur Playwright 1.59+, envisage `trace: 'retain-on-failure-and-retries'` afin de pouvoir comparer la tentative en échec avec les retries réussis, au lieu de ne conserver qu'un seul artefact de trace.

**JavaScript**
```javascript
// Launch UI Mode from terminal:
// npx playwright test --ui

// Run a specific test file in UI Mode:
// npx playwright test tests/checkout.spec.js --ui

// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  use: {
    trace: 'on-first-retry',
  },
});
```

### Pattern 2 : Playwright Inspector avec PWDEBUG

**À utiliser quand** : tu dois avancer action par action, tester des sélecteurs de façon interactive ou voir l'état exact avant et après chaque action.
**À éviter quand** : l'échec est visible rien qu'avec le message d'erreur ou la trace.

**TypeScript**
```typescript
// Launch Inspector from terminal:
// PWDEBUG=1 npx playwright test tests/login.spec.ts

// On Windows PowerShell:
// $env:PWDEBUG=1; npx playwright test tests/login.spec.ts

// On Windows CMD:
// set PWDEBUG=1 && npx playwright test tests/login.spec.ts

// Inspector opens automatically. Use these controls:
// - "Step over" button: execute one action at a time
// - "Pick locator" button: hover elements to see the best locator
// - "Resume" button: run to the next page.pause() or end

import { test, expect } from '@playwright/test';

test('debug login flow', async ({ page }) => {
  await page.goto('/login');

  // Inspector pauses before each action when PWDEBUG=1
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

**JavaScript**
```javascript
// Launch Inspector from terminal:
// PWDEBUG=1 npx playwright test tests/login.spec.js

const { test, expect } = require('@playwright/test');

test('debug login flow', async ({ page }) => {
  await page.goto('/login');

  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

### Pattern 3 : Trace Viewer pour analyser un échec en CI

**À utiliser quand** : un test échoue en CI et tu dois comprendre ce qui s'est passé sans le relancer en local.
**À éviter quand** : tu peux reproduire l'échec en local (utilise plutôt UI Mode ou l'Inspector).

**TypeScript**
```typescript
// playwright.config.ts — trace configuration
import { defineConfig } from '@playwright/test';

export default defineConfig({
  retries: process.env.CI ? 2 : 0,
  use: {
    // 'on-first-retry' — captures trace on first retry only (recommended for CI)
    // 'on' — captures every run (use temporarily for stubborn failures)
    // 'retain-on-failure' — captures every run, keeps only failures
    trace: 'on-first-retry',
  },
});

// After CI failure, download the trace artifact and open it:
// npx playwright show-trace test-results/tests-login-Login-test-chromium/trace.zip

// Or open from URL:
// npx playwright show-trace https://ci.example.com/artifacts/trace.zip

// Or use trace.playwright.dev to view traces in the browser — drag and drop the zip file
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

// After CI failure, download the trace artifact and open it:
// npx playwright show-trace test-results/tests-login-Login-test-chromium/trace.zip
```

**Lire une trace — quoi vérifier, dans l'ordre :**

1. **Onglet Actions** — chaque action Playwright avec ses captures d'écran avant/après
2. **Onglet Console** — sortie console du navigateur (erreurs, warnings, logs)
3. **Onglet Network** — chaque requête HTTP avec statut, timing, corps de requête/réponse
4. **Onglet Source** — code source du test avec la ligne en échec surlignée
5. **Onglet Call** — arguments exacts et valeurs de retour de chaque appel Playwright

### Pattern 3b : Débogueur CLI pour les workflows d'agents

**À utiliser quand** : tu débogues depuis un terminal, une machine distante ou un workflow d'agent de code où ouvrir l'inspector complet est peu pratique.
**À éviter quand** : tu veux l'interface interactive la plus riche en local ; utilise UI Mode ou l'Inspector pour cela.

```bash
# Start a paused debugging session
npx playwright test --debug=cli

# Attach from another terminal using the session id printed by Playwright
playwright-cli attach tw-87b59e
playwright-cli --session=tw-87b59e snapshot
playwright-cli --session=tw-87b59e step-over
playwright-cli --session=tw-87b59e console error
```

Ce flux est idéal quand un agent ou un collègue doit inspecter l'état du navigateur en direct sans quitter la ligne de commande.

### Pattern 3c : Analyse de trace dans le terminal

**À utiliser quand** : tu as une archive de trace mais tu as besoin de réponses rapides depuis un shell, un worker de CI ou une machine distante.
**À éviter quand** : tu as besoin de la timeline visuelle complète ; utilise le Trace Viewer pour cela.

```bash
npx playwright trace open test-results/checkout-chromium/trace.zip
npx playwright trace actions --grep="expect"
npx playwright trace action 9
npx playwright trace snapshot 9 --phase after
npx playwright trace close
```

C'est particulièrement utile pour les boucles de réparation pilotées par des agents et le triage de tests flaky, où ouvrir un trace viewer graphique ajoute de la friction.

### Pattern 4 : Mode headed avec ralenti

**À utiliser quand** : tu veux regarder le navigateur pendant l'exécution sans la lourdeur de l'Inspector complet.
**À éviter quand** : le test va trop vite pour être suivi même avec le ralenti (utilise plutôt l'Inspector).

**TypeScript**
```typescript
// From terminal — quick visual debugging:
// npx playwright test tests/checkout.spec.ts --headed
// (there is no --slow-mo flag; set launchOptions.slowMo in config, below)

// playwright.config.ts — configure headed mode for local development
import { defineConfig } from '@playwright/test';

export default defineConfig({
  use: {
    // Do NOT commit these — use CLI flags or environment checks instead
    headless: !process.env.HEADED,
    launchOptions: {
      slowMo: process.env.SLOW_MO ? parseInt(process.env.SLOW_MO) : 0,
    },
  },
});

// Then run:
// HEADED=1 SLOW_MO=500 npx playwright test tests/checkout.spec.ts
```

**JavaScript**
```javascript
// From terminal:
// npx playwright test tests/checkout.spec.js --headed
// (there is no --slow-mo flag; set launchOptions.slowMo in config, below)

// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  use: {
    headless: !process.env.HEADED,
    launchOptions: {
      slowMo: process.env.SLOW_MO ? parseInt(process.env.SLOW_MO) : 0,
    },
  },
});
```

### Pattern 5 : Intégration VS Code

**À utiliser quand** : tu préfères déboguer dans l'IDE, avec points d'arrêt, inspection de variables et exécution de tests intégrée.
**À éviter quand** : tu débogues des échecs propres à la CI qui ne se reproduisent pas en local.

Installe l'extension **Playwright Test for VS Code** (`ms-playwright.playwright`).

**Fonctionnalités clés :**
- **Lancer/déboguer des tests individuels** — clique sur le bouton play vert dans la gouttière à côté de n'importe quel `test()`
- **Poser des points d'arrêt** — clique dans la gouttière ; les tests se mettent en pause dessus automatiquement
- **Pick locator** — utilise la commande « Pick locator » pour survoler les éléments et obtenir le meilleur sélecteur
- **Show browser** — coche « Show Browser » dans la barre latérale de tests pour voir le navigateur pendant l'exécution
- **Watch mode** — active-le pour relancer les tests à chaque sauvegarde de fichier

**TypeScript**
```typescript
// When debugging in VS Code, use test.only() to focus on one test
// instead of running the entire suite through the debugger
import { test, expect } from '@playwright/test';

test.only('debug this specific test', async ({ page }) => {
  await page.goto('/products');

  // Set a VS Code breakpoint on this line, then inspect `page` in the debug panel
  const productCard = page.getByRole('listitem').filter({ hasText: 'Widget' });
  await expect(productCard).toBeVisible();

  await productCard.getByRole('button', { name: 'Add to cart' }).click();
  await expect(page.getByTestId('cart-count')).toHaveText('1');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.only('debug this specific test', async ({ page }) => {
  await page.goto('/products');

  const productCard = page.getByRole('listitem').filter({ hasText: 'Widget' });
  await expect(productCard).toBeVisible();

  await productCard.getByRole('button', { name: 'Add to cart' }).click();
  await expect(page.getByTestId('cart-count')).toHaveText('1');
});
```

### Pattern 6 : Capturer les logs de la console du navigateur

**À utiliser quand** : tu soupçonnes des erreurs JavaScript, des appels d'API côté client en échec ou des logs applicatifs qui expliquent l'échec.
**À éviter quand** : le problème est clairement un souci de sélecteur ou de timing visible dans la trace.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('capture console output', async ({ page }) => {
  // Collect all console messages
  const consoleLogs: string[] = [];
  page.on('console', (msg) => {
    consoleLogs.push(`[${msg.type()}] ${msg.text()}`);
  });

  // Capture uncaught exceptions
  page.on('pageerror', (error) => {
    console.error('Page error:', error.message);
  });

  await page.goto('/dashboard');
  await page.getByRole('button', { name: 'Load data' }).click();
  await expect(page.getByRole('table')).toBeVisible();

  // Print collected logs on failure for debugging context
  console.log('Browser console output:', consoleLogs);
});

// Reusable fixture for console logging across all tests
import { test as base } from '@playwright/test';

type ConsoleFixtures = {
  consoleMessages: string[];
};

export const test = base.extend<ConsoleFixtures>({
  consoleMessages: async ({ page }, use) => {
    const messages: string[] = [];
    page.on('console', (msg) => messages.push(`[${msg.type()}] ${msg.text()}`));
    page.on('pageerror', (err) => messages.push(`[pageerror] ${err.message}`));
    await use(messages);
  },
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('capture console output', async ({ page }) => {
  const consoleLogs = [];
  page.on('console', (msg) => {
    consoleLogs.push(`[${msg.type()}] ${msg.text()}`);
  });

  page.on('pageerror', (error) => {
    console.error('Page error:', error.message);
  });

  await page.goto('/dashboard');
  await page.getByRole('button', { name: 'Load data' }).click();
  await expect(page.getByRole('table')).toBeVisible();

  console.log('Browser console output:', consoleLogs);
});

// Reusable fixture for console logging
const { test: base } = require('@playwright/test');

const test = base.extend({
  consoleMessages: async ({ page }, use) => {
    const messages = [];
    page.on('console', (msg) => messages.push(`[${msg.type()}] ${msg.text()}`));
    page.on('pageerror', (err) => messages.push(`[pageerror] ${err.message}`));
    await use(messages);
  },
});

module.exports = { test };
```

#### Localiser les erreurs non interceptées avec `webError.location()` (Playwright 1.60+)

`page.on('pageerror')` te donne l'erreur, mais pas *d'où* elle vient. Playwright 1.60 ajoute `webError.location()` (sur l'événement `weberror` au niveau du `context`), en miroir de `consoleMessage.location()` — tu obtiens ainsi l'URL, la ligne et la colonne d'une exception non interceptée.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('capture uncaught errors with their source location', async ({ context, page }) => {
  context.on('weberror', (webError) => {
    const loc = webError.location(); // { url, line, column } — 0-based
    console.error(
      `Uncaught: ${webError.error().message} @ ${loc.url}:${loc.line}:${loc.column}`
    );
  });

  await page.goto('/dashboard');
  await page.getByRole('button', { name: 'Load data' }).click();
  await expect(page.getByRole('table')).toBeVisible();
});
```

La localisation permet de remonter beaucoup plus vite d'une exception côté navigateur au fichier source et à la ligne exacts, surtout avec les source maps activées.

### Pattern 7 : Captures d'écran en cas d'échec

**À utiliser quand** : tu as besoin d'un instantané visuel au moment exact de l'échec.
**À éviter quand** : les traces sont activées (elles incluent déjà des captures d'écran à chaque étape).

**TypeScript**
```typescript
// playwright.config.ts — automatic screenshots on failure
import { defineConfig } from '@playwright/test';

export default defineConfig({
  use: {
    // 'off' — no screenshots (default)
    // 'on' — screenshot after every test
    // 'only-on-failure' — screenshot only when test fails (recommended)
    screenshot: 'only-on-failure',
  },
});
```

```typescript
// Manual screenshot at a specific point
import { test, expect } from '@playwright/test';

test('debug visual state', async ({ page }) => {
  await page.goto('/checkout');
  await page.getByLabel('Promo code').fill('SAVE20');
  await page.getByRole('button', { name: 'Apply' }).click();

  // Capture screenshot before assertion for debugging
  await page.screenshot({ path: 'test-results/before-discount.png', fullPage: true });

  await expect(page.getByTestId('discount-amount')).toHaveText('-$20.00');
});
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  use: {
    screenshot: 'only-on-failure',
  },
});
```

```javascript
// Manual screenshot
const { test, expect } = require('@playwright/test');

test('debug visual state', async ({ page }) => {
  await page.goto('/checkout');
  await page.getByLabel('Promo code').fill('SAVE20');
  await page.getByRole('button', { name: 'Apply' }).click();

  await page.screenshot({ path: 'test-results/before-discount.png', fullPage: true });

  await expect(page.getByTestId('discount-amount')).toHaveText('-$20.00');
});
```

### Pattern 8 : Débogage réseau

**À utiliser quand** : tu soupçonnes des échecs d'API, de mauvais payloads de requête, des headers d'auth manquants ou des réponses lentes provoquant des timeouts.
**À éviter quand** : l'onglet réseau de la trace montre déjà le problème.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('debug network requests', async ({ page }) => {
  // Log all requests
  page.on('request', (request) => {
    console.log(`>> ${request.method()} ${request.url()}`);
  });

  // Log all responses with status
  page.on('response', (response) => {
    console.log(`<< ${response.status()} ${response.url()}`);
  });

  // Log failed requests (network errors, not HTTP errors)
  page.on('requestfailed', (request) => {
    console.log(`FAILED: ${request.url()} ${request.failure()?.errorText}`);
  });

  await page.goto('/dashboard');
  await page.getByRole('button', { name: 'Refresh' }).click();
  await expect(page.getByRole('table')).toBeVisible();
});

// Wait for a specific API response and inspect it
test('inspect API response', async ({ page }) => {
  await page.goto('/products');

  const responsePromise = page.waitForResponse(
    (resp) => resp.url().includes('/api/products') && resp.status() === 200
  );

  await page.getByRole('button', { name: 'Load products' }).click();

  const response = await responsePromise;
  const body = await response.json();
  console.log('API response:', JSON.stringify(body, null, 2));

  await expect(page.getByRole('listitem')).toHaveCount(body.products.length);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('debug network requests', async ({ page }) => {
  page.on('request', (request) => {
    console.log(`>> ${request.method()} ${request.url()}`);
  });

  page.on('response', (response) => {
    console.log(`<< ${response.status()} ${response.url()}`);
  });

  page.on('requestfailed', (request) => {
    console.log(`FAILED: ${request.url()} ${request.failure()?.errorText}`);
  });

  await page.goto('/dashboard');
  await page.getByRole('button', { name: 'Refresh' }).click();
  await expect(page.getByRole('table')).toBeVisible();
});

test('inspect API response', async ({ page }) => {
  await page.goto('/products');

  const responsePromise = page.waitForResponse(
    (resp) => resp.url().includes('/api/products') && resp.status() === 200
  );

  await page.getByRole('button', { name: 'Load products' }).click();

  const response = await responsePromise;
  const body = await response.json();
  console.log('API response:', JSON.stringify(body, null, 2));

  await expect(page.getByRole('listitem')).toHaveCount(body.products.length);
});
```

### Pattern 9 : Logs d'API verbeux

**À utiliser quand** : tu as besoin de voir chaque appel d'API Playwright avec son timing pour identifier où le test passe son temps ou se bloque.
**À éviter quand** : tu sais déjà quelle action échoue (utilise plutôt l'Inspector ou `page.pause()`).

```bash
# See all Playwright API calls with timestamps
DEBUG=pw:api npx playwright test tests/slow-test.spec.ts

# See browser protocol messages (very verbose — use sparingly)
DEBUG=pw:protocol npx playwright test tests/slow-test.spec.ts

# Combine multiple debug channels
DEBUG=pw:api,pw:browser npx playwright test tests/slow-test.spec.ts

# Windows PowerShell
$env:DEBUG="pw:api"; npx playwright test tests/slow-test.spec.ts

# Windows CMD
set DEBUG=pw:api && npx playwright test tests/slow-test.spec.ts
```

### Pattern 10 : `page.pause()` — points d'arrêt inline

**À utiliser quand** : tu dois mettre l'exécution en pause à un point précis pour inspecter le DOM en direct, essayer des locators ou vérifier l'état de l'application.
**À éviter quand** : tu peux utiliser `PWDEBUG=1`, qui met en pause à chaque étape automatiquement.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('debug with pause', async ({ page }) => {
  await page.goto('/checkout');
  await page.getByLabel('Email').fill('user@example.com');

  // Execution pauses here — Inspector opens with:
  // - Live DOM inspection
  // - Selector playground (try locators in the console)
  // - Step through remaining actions
  await page.pause();

  // These actions wait until you click "Resume" in the Inspector
  await page.getByRole('button', { name: 'Continue' }).click();
  await expect(page.getByText('Order confirmed')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('debug with pause', async ({ page }) => {
  await page.goto('/checkout');
  await page.getByLabel('Email').fill('user@example.com');

  // Execution pauses here — Inspector opens
  await page.pause();

  await page.getByRole('button', { name: 'Continue' }).click();
  await expect(page.getByText('Order confirmed')).toBeVisible();
});
```

**Important** : retire `page.pause()` avant de commiter. Il se bloquera indéfiniment en CI. Utilise cette règle de lint ou ce contrôle en CI :

```bash
# Add to your pre-commit hook or CI pipeline
grep -r "page.pause()" tests/ && echo "ERROR: Remove page.pause() before committing" && exit 1
```

### Pattern 11 : Surlignages stylés et `errorContext` (Playwright 1.60+)

**À utiliser quand** : tu débogues visuellement vers quel élément un locator se résout (surtout en mode headed ou pendant l'enregistrement d'une vidéo), ou tu veux des diagnostics plus riches attachés aux échecs d'assertion.
**À éviter quand** : une trace répond déjà à la question — elle montre l'élément résolu à chaque étape.

Playwright 1.60 ajoute une option `style` à `locator.highlight()` (CSS inline personnalisé sur la boîte de surlignage), ainsi que `page.hideHighlight()` pour l'effacer. Il expose aussi `testInfoError.errorContext`, qui contient des diagnostics supplémentaires — comme le snapshot aria de l'élément quand un matcher `expect()` a échoué.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('highlight an element while debugging headed', async ({ page }) => {
  await page.goto('/dashboard');

  const cta = page.getByRole('button', { name: 'Upgrade' });
  await cta.highlight({ style: 'outline: 3px solid magenta; background: rgba(255,0,255,.15)' });

  // ... inspect visually / take a screenshot ...
  await page.hideHighlight();
});

test.afterEach(async ({}, testInfo) => {
  // On failure, surface the diagnostic context Playwright captured
  for (const err of testInfo.errors) {
    if (err.errorContext) {
      console.log('Failure context:\n', err.errorContext);
    }
  }
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('highlight an element while debugging headed', async ({ page }) => {
  await page.goto('/dashboard');

  const cta = page.getByRole('button', { name: 'Upgrade' });
  await cta.highlight({ style: 'outline: 3px solid magenta' });

  await page.hideHighlight();
});
```

`errorContext` est surtout utile dans les reporters personnalisés et les hooks `afterEach`, où tu veux logger *pourquoi* un matcher a échoué au-delà du simple message.

## Guide de décision

Utilise ce tableau pour choisir le bon outil selon le type d'échec.

| Type d'échec | Premier outil | Pourquoi |
|---|---|---|
| **Élément introuvable** (mauvais sélecteur) | UI Mode (`--ui`) | Voir le DOM au moment de l'échec, essayer des sélecteurs dans Pick Locator |
| **Élément introuvable** (problème de timing) | Trace Viewer — onglet Actions | Comparer les captures avant/après pour voir si l'élément est apparu après le timeout |
| **Mauvais texte / valeur** | Trace Viewer — onglet Actions | Inspecter le contenu réel du DOM à chaque étape |
| **Le test se bloque / timeout** | `DEBUG=pw:api` | Voir quel appel d'API attend sans jamais se résoudre |
| **Échec réseau / API** | Trace Viewer — onglet Network | Voir les codes de statut, payloads et timings des requêtes/réponses |
| **Problèmes d'auth / de session** | Débogage réseau (`page.on('response')`) | Vérifier les réponses 401/403, les cookies/tokens manquants |
| **Rendu visuel incorrect** | `--headed` + `launchOptions.slowMo` | Observer le rendu réel dans le navigateur |
| **Erreur JavaScript dans l'app** | Logs de la console (`page.on('console')`) | Capturer les exceptions non interceptées et les logs d'erreur |
| **Échec uniquement en CI** | Trace Viewer (depuis l'artefact de CI) | Reproduire l'état exact de la CI sans relancer en local |
| **Flaky / intermittent** | Trace à chaque run (`trace: 'on'`) + retries | Comparer côte à côte les traces réussies et en échec |
| **Pollution d'état** | Lancer un seul test avec `test.only()` | L'isoler des autres tests ; s'il passe seul, l'état fuit depuis un autre test |

## Anti-patterns

### Ajouter `waitForTimeout` pour corriger des problèmes de timing

```typescript
// WRONG — arbitrary delays mask the real problem and make tests slow and flaky
await page.getByRole('button', { name: 'Submit' }).click();
await page.waitForTimeout(3000); // "It works with this delay"
await expect(page.getByText('Success')).toBeVisible();

// RIGHT — wait for the actual condition
await page.getByRole('button', { name: 'Submit' }).click();
await expect(page.getByText('Success')).toBeVisible(); // Auto-retries for up to 5s
```

Si le timeout par défaut est insuffisant, cherche *pourquoi* l'opération est lente, puis soit :
- Corrige la performance de l'application
- Augmente le timeout de l'assertion concernée : `await expect(locator).toBeVisible({ timeout: 15000 })`
- Attends un prérequis : `await page.waitForResponse('**/api/submit')`

### Commenter des tests pour isoler un échec

```typescript
// WRONG — commenting out tests to find which one causes the failure
// test('test A', ...);
// test('test B', ...);
test('test C — this one fails', async ({ page }) => { /* ... */ });

// RIGHT — use .only to run a single test
test.only('test C — this one fails', async ({ page }) => { /* ... */ });

// RIGHT — use grep to run tests matching a pattern
// npx playwright test --grep "test C"
```

### Ne pas lire le message d'erreur en entier

Les messages d'erreur Playwright incluent :
- La valeur **attendue** vs la valeur **réelle**
- Le **locator** utilisé
- Un **call log** montrant ce que Playwright a essayé avant le timeout
- Le **numéro de ligne** dans ton test

Lis tout. Le call log seul montre souvent exactement ce qui s'est mal passé (par ex. « waiting for selector to be visible » alors que l'élément existe mais est masqué).

### Déboguer en CI sans traces

```typescript
// WRONG — no traces in CI, no way to debug failures
export default defineConfig({
  use: {
    trace: 'off',
  },
});

// RIGHT — always capture traces on failure in CI
export default defineConfig({
  retries: process.env.CI ? 2 : 0,
  use: {
    trace: 'on-first-retry',
  },
});
```

### Utiliser `console.log` au lieu de vrais outils de débogage

```typescript
// WRONG — sprinkling console.log everywhere
test('debug with logs', async ({ page }) => {
  await page.goto('/dashboard');
  console.log('page loaded');
  const el = page.getByRole('button', { name: 'Save' });
  console.log('button found:', await el.isVisible());
  console.log('button text:', await el.textContent());
  // ...20 more console.log calls

  // RIGHT — use page.pause() at the point of interest
  await page.goto('/dashboard');
  await page.pause(); // Inspect everything interactively
});
```

### Laisser `page.pause()` ou `test.only()` dans du code commité

```typescript
// WRONG — these should never reach CI
test.only('focused test', async ({ page }) => {  // Skips all other tests
  await page.goto('/');
  await page.pause();  // Hangs forever in CI
});

// Add a CI guard if needed during development
if (!process.env.CI) {
  await page.pause();
}
```

## Dépannage

| Symptôme | Cause probable | Correctif |
|---|---|---|
| L'Inspector ne s'ouvre pas avec `PWDEBUG=1` | Exécution en headless ou workers > 1 | Lance avec `--headed` et `--workers=1` |
| La trace est vide ou absente | `trace: 'off'` dans la config, ou le test n'a pas été retenté | Mets temporairement `trace: 'on'`, ou `trace: 'retain-on-failure'` |
| UI Mode affiche des résultats de test périmés | Le file watcher n'a pas détecté les changements | Arrête UI Mode, vide `test-results/`, relance |
| `page.pause()` ne fait rien | `PWDEBUG` n'est pas défini et exécution en headless | Lance avec `--headed` ou définis `PWDEBUG=1` |
| Les captures d'écran sont vides ou de mauvaise taille | Viewport non défini ou test exécuté sur le mauvais project | Définis `viewport` dans la config ; vérifie quel project de navigateur a tourné |
| Les logs verbeux sont écrasants | Utilisation de `DEBUG=pw:protocol` | Utilise `DEBUG=pw:api` pour un niveau de détail gérable |
| Le fichier de trace est trop gros | `trace: 'on'` pour tous les tests, y compris ceux qui passent | Passe à `trace: 'on-first-retry'` ou `trace: 'retain-on-failure'` |
| VS Code ne détecte pas les tests | `testDir` ou `testMatch` mal configuré | Vérifie que les chemins de la config correspondent et que les réglages de l'extension pointent vers ton `playwright.config` |
| Les événements réseau ne se déclenchent pas | La requête a été faite avant l'attachement du listener | Attache `page.on('request')` et `page.on('response')` avant `page.goto()` |

## Voir aussi

- [core/error-index.md](error-index.md) — rechercher des messages d'erreur précis
- [core/flaky-tests.md](flaky-tests.md) — patterns d'échecs intermittents et correctifs
- [core/common-pitfalls.md](common-pitfalls.md) — erreurs courantes de débutant
- [core/assertions-and-waiting.md](assertions-and-waiting.md) — assertions web-first et auto-waiting
- [core/configuration.md](configuration.md) — configuration des traces, captures d'écran et retries
- [ci/reporting-and-artifacts.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/reporting-and-artifacts.md) — collecte des artefacts de CI pour les traces et captures d'écran
