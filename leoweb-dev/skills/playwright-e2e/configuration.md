# Configuration

> **Quand l'utiliser** : mettre en place un nouveau projet Playwright, ajuster les timeouts, ajouter des navigateurs cibles, configurer le comportement en CI ou brancher des réglages propres à un environnement.

## Référence rapide

```
npm init playwright@latest             # scaffold config + first test
npx playwright test --config=custom.config.ts  # use non-default config
npx playwright test --project=chromium # run single project
npx playwright test --reporter=html    # override reporter
npx playwright show-report             # open last HTML report
DEBUG=pw:api npx playwright test       # verbose Playwright logging
```

## Config prête pour la production (à copier-coller)

### TypeScript

```ts
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';
import dotenv from 'dotenv';
import path from 'path';

// Load environment variables from .env file
dotenv.config({ path: path.resolve(__dirname, '.env') });

export default defineConfig({
  // ── Test discovery ──────────────────────────────────────────────
  testDir: './tests',
  testMatch: '**/*.spec.ts',

  // ── Execution ───────────────────────────────────────────────────
  fullyParallel: true,
  forbidOnly: !!process.env.CI,       // fail CI if test.only left in
  retries: process.env.CI ? 2 : 0,    // retry flakes in CI only
  workers: process.env.CI ? '50%' : undefined, // half CPU in CI, auto locally

  // ── Reporting ───────────────────────────────────────────────────
  reporter: process.env.CI
    ? [['html', { open: 'never' }], ['github']]
    : [['html', { open: 'on-failure' }]],

  // ── Timeouts ────────────────────────────────────────────────────
  timeout: 30_000,                     // per-test timeout
  expect: {
    timeout: 5_000,                    // per-assertion retry timeout
  },

  // ── Shared browser context options ──────────────────────────────
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    actionTimeout: 10_000,             // click, fill, etc.
    navigationTimeout: 15_000,         // goto, waitForURL, etc.

    // Artifact collection
    trace: 'on-first-retry',          // full trace on first retry only
    screenshot: 'only-on-failure',     // screenshot on failure
    video: 'retain-on-failure',        // video only kept for failures
    // 1.61+ adds video modes matching trace: 'on-all-retries',
    // 'retain-on-first-failure', 'retain-on-failure-and-retries'
    // 1.64+ adds fps to the { mode, size } object form and encodes VP9 instead of VP8

    // Sensible defaults
    locale: 'en-US',
    timezoneId: 'America/New_York',
    extraHTTPHeaders: {
      'x-test-automation': 'playwright',
    },
  },

  // ── Projects (browser targets) ─────────────────────────────────
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
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 7'] },
    },
    {
      name: 'mobile-safari',
      use: { ...devices['iPhone 14'] },
    },
  ],

  // ── Dev server ──────────────────────────────────────────────────
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,                  // 2 min for cold builds
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
```

### JavaScript

```js
// playwright.config.js
const { defineConfig, devices } = require('@playwright/test');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.resolve(__dirname, '.env') });

module.exports = defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.js',

  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? '50%' : undefined,

  reporter: process.env.CI
    ? [['html', { open: 'never' }], ['github']]
    : [['html', { open: 'on-failure' }]],

  timeout: 30_000,
  expect: {
    timeout: 5_000,
  },

  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    actionTimeout: 10_000,
    navigationTimeout: 15_000,

    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',

    locale: 'en-US',
    timezoneId: 'America/New_York',
    extraHTTPHeaders: {
      'x-test-automation': 'playwright',
    },
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
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 7'] },
    },
    {
      name: 'mobile-safari',
      use: { ...devices['iPhone 14'] },
    },
  ],

  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
```

## Patterns

### Pattern 1 : configuration par environnement

**À utiliser quand** : les tests tournent contre les environnements dev, staging et production.
**À éviter quand** : projets mono-environnement, uniquement en local.

#### TypeScript

```ts
// playwright.config.ts
import { defineConfig } from '@playwright/test';
import dotenv from 'dotenv';
import path from 'path';

// Load environment-specific .env file: .env.staging, .env.production, etc.
const ENV = process.env.TEST_ENV || 'local';
dotenv.config({ path: path.resolve(__dirname, `.env.${ENV}`) });

const envConfig: Record<string, { baseURL: string; retries: number }> = {
  local:      { baseURL: 'http://localhost:3000',       retries: 0 },
  staging:    { baseURL: 'https://staging.example.com', retries: 2 },
  production: { baseURL: 'https://www.example.com',     retries: 2 },
};

const env = envConfig[ENV];

export default defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.ts',
  retries: env.retries,
  use: {
    baseURL: env.baseURL,
  },
});
```

```bash
# Run against staging
TEST_ENV=staging npx playwright test

# Run against production (subset of smoke tests)
TEST_ENV=production npx playwright test --grep @smoke
```

#### JavaScript

```js
// playwright.config.js
const { defineConfig } = require('@playwright/test');
const dotenv = require('dotenv');
const path = require('path');

const ENV = process.env.TEST_ENV || 'local';
dotenv.config({ path: path.resolve(__dirname, `.env.${ENV}`) });

const envConfig = {
  local:      { baseURL: 'http://localhost:3000',       retries: 0 },
  staging:    { baseURL: 'https://staging.example.com', retries: 2 },
  production: { baseURL: 'https://www.example.com',     retries: 2 },
};

const env = envConfig[ENV];

module.exports = defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.js',
  retries: env.retries,
  use: {
    baseURL: env.baseURL,
  },
});
```

### Pattern 2 : multi-projets avec dépendances de setup

**À utiliser quand** : les tests ont besoin d'un état d'authentification partagé ou d'un seed de base de données avant de s'exécuter.
**À éviter quand** : les tests sont totalement indépendants, sans phase de setup partagée.

#### TypeScript

```ts
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.ts',

  projects: [
    // Setup project runs first, saves auth state
    {
      name: 'setup',
      testMatch: /global\.setup\.ts/,
    },

    // Browser projects depend on setup
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'playwright/.auth/user.json',
      },
      dependencies: ['setup'],
    },
    {
      name: 'firefox',
      use: {
        ...devices['Desktop Firefox'],
        storageState: 'playwright/.auth/user.json',
      },
      dependencies: ['setup'],
    },
  ],
});
```

```ts
// tests/global.setup.ts
import { test as setup, expect } from '@playwright/test';

const authFile = 'playwright/.auth/user.json';

setup('authenticate', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill(process.env.TEST_PASSWORD!);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  await page.context().storageState({ path: authFile });
});
```

#### JavaScript

```js
// playwright.config.js
const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.js',

  projects: [
    {
      name: 'setup',
      testMatch: /global\.setup\.js/,
    },
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'playwright/.auth/user.json',
      },
      dependencies: ['setup'],
    },
    {
      name: 'firefox',
      use: {
        ...devices['Desktop Firefox'],
        storageState: 'playwright/.auth/user.json',
      },
      dependencies: ['setup'],
    },
  ],
});
```

```js
// tests/global.setup.js
const { test: setup, expect } = require('@playwright/test');

const authFile = 'playwright/.auth/user.json';

setup('authenticate', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill(process.env.TEST_PASSWORD);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  await page.context().storageState({ path: authFile });
});
```

### Pattern 3 : `webServer` avec étape de build

**À utiliser quand** : les tests ont besoin d'un serveur applicatif en marche. Laisse Playwright gérer le cycle de vie du serveur.
**À éviter quand** : tu testes contre un environnement déjà déployé (staging/prod).

#### TypeScript

```ts
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.ts',
  use: {
    baseURL: 'http://localhost:3000',
  },
  webServer: {
    command: process.env.CI
      ? 'npm run build && npm run start'  // production build in CI
      : 'npm run dev',                    // dev server locally
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    stdout: 'pipe',
    stderr: 'pipe',
    env: {
      NODE_ENV: 'test',
      DATABASE_URL: process.env.DATABASE_URL || 'postgresql://localhost:5432/test',
    },
  },
});
```

#### JavaScript

```js
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.js',
  use: {
    baseURL: 'http://localhost:3000',
  },
  webServer: {
    command: process.env.CI
      ? 'npm run build && npm run start'
      : 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    stdout: 'pipe',
    stderr: 'pipe',
    env: {
      NODE_ENV: 'test',
      DATABASE_URL: process.env.DATABASE_URL || 'postgresql://localhost:5432/test',
    },
  },
});
```

### Pattern 4 : `globalSetup` / `globalTeardown`

**À utiliser quand** : travail ponctuel hors navigateur : seed d'une base de données, démarrage d'un service, définition de variables d'environnement. S'exécute une fois par invocation de `npx playwright test`.
**À éviter quand** : tu as besoin d'un contexte de navigateur (utilise un setup project) ou d'une isolation par test (utilise des fixtures).

#### TypeScript

```ts
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.ts',
  globalSetup: './tests/global-setup.ts',
  globalTeardown: './tests/global-teardown.ts',
});
```

```ts
// tests/global-setup.ts
import { FullConfig } from '@playwright/test';

async function globalSetup(config: FullConfig) {
  // Seed test database
  const { execSync } = await import('child_process');
  execSync('npx prisma db seed', { stdio: 'inherit' });

  // Store data for tests to use via environment variables
  process.env.TEST_RUN_ID = `run-${Date.now()}`;
}

export default globalSetup;
```

```ts
// tests/global-teardown.ts
import { FullConfig } from '@playwright/test';

async function globalTeardown(config: FullConfig) {
  const { execSync } = await import('child_process');
  execSync('npx prisma db push --force-reset', { stdio: 'inherit' });
}

export default globalTeardown;
```

#### JavaScript

```js
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.js',
  globalSetup: './tests/global-setup.js',
  globalTeardown: './tests/global-teardown.js',
});
```

```js
// tests/global-setup.js
const { execSync } = require('child_process');

async function globalSetup(config) {
  execSync('npx prisma db seed', { stdio: 'inherit' });
  process.env.TEST_RUN_ID = `run-${Date.now()}`;
}

module.exports = globalSetup;
```

```js
// tests/global-teardown.js
const { execSync } = require('child_process');

async function globalTeardown(config) {
  execSync('npx prisma db push --force-reset', { stdio: 'inherit' });
}

module.exports = globalTeardown;
```

### Pattern 5 : mise en place du fichier `.env`

**À utiliser quand** : tu gères des secrets, des URLs ou des feature flags sans les coder en dur.
**À éviter quand** : ne commite jamais de fichiers `.env` contenant de vrais secrets. Fournis un `.env.example` à la place.

```bash
# .env.example (commit this)
BASE_URL=http://localhost:3000
TEST_PASSWORD=
API_KEY=

# .env.local (gitignored)
BASE_URL=http://localhost:3000
TEST_PASSWORD=s3cret
API_KEY=test-key-abc123

# .env.staging (gitignored)
BASE_URL=https://staging.example.com
TEST_PASSWORD=staging-password
API_KEY=staging-key-xyz789
```

```bash
# .gitignore
.env
.env.local
.env.staging
.env.production
playwright/.auth/
```

Installe dotenv :

```bash
npm install -D dotenv
```

### Pattern 6 : réglages de trace, screenshot et vidéo

**À utiliser quand** : tu choisis la stratégie de collecte d'artefacts entre développement local et CI.

| Réglage | Local | CI | Pourquoi |
|---|---|---|---|
| `trace` | `'off'` ou `'on-first-retry'` | `'on-first-retry'` | Les traces sont volumineuses ; ne les collecter qu'en cas d'échec |
| `screenshot` | `'off'` | `'only-on-failure'` | Utile uniquement pour déboguer en CI |
| `video` | `'off'` | `'retain-on-failure'` | L'enregistrement vidéo est lent ; ne garder que les échecs |

#### TypeScript

```ts
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.ts',
  use: {
    // CI: capture everything on failure; Local: minimal overhead
    trace: process.env.CI ? 'on-first-retry' : 'off',
    screenshot: process.env.CI ? 'only-on-failure' : 'off',
    video: process.env.CI ? 'retain-on-failure' : 'off',
  },
});
```

#### JavaScript

```js
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.js',
  use: {
    trace: process.env.CI ? 'on-first-retry' : 'off',
    screenshot: process.env.CI ? 'only-on-failure' : 'off',
    video: process.env.CI ? 'retain-on-failure' : 'off',
  },
});
```

## Guide de décision

### Quel timeout ajuster

| Symptôme | Timeout à modifier | Défaut | Plage recommandée |
|---|---|---|---|
| Le test est trop long globalement | `timeout` | 30s | 30-60s (jamais au-dessus de 120s) |
| L'assertion `expect()` réessaie trop longtemps ou pas assez | `expect.timeout` | 5s | 5-10s |
| `page.goto()` ou `waitForURL()` expire | `navigationTimeout` | 0 (sans limite) | 10-30s |
| `click()`, `fill()`, `check()` expirent | `actionTimeout` | 0 (sans limite) | 10-15s |
| Le serveur de dev démarre lentement | `webServer.timeout` | 60s | 60-180s |

### Gestion du serveur

| Scénario | Approche | Pourquoi |
|---|---|---|
| Dev local + CI, app dans le même dépôt | `webServer` avec `reuseExistingServer: !process.env.CI` | Playwright gère le serveur ; réutilise le tien en local |
| Dépôts frontend/backend séparés | Démarrage manuel ou Docker Compose | `webServer` ne peut lancer qu'une commande |
| Test d'un staging/production déployé | Pas de `webServer` ; définir `baseURL` via une variable d'environnement | Le serveur tourne déjà à distance |
| Plusieurs services nécessaires (API + frontend) | Tableau d'entrées `webServer` | Chacune a sa propre commande et son propre healthcheck d'URL |

### Config mono-projet vs multi-projets

| Scénario | Approche | Pourquoi |
|---|---|---|
| Début de projet, développement précoce | Un seul projet (chromium uniquement) | Retour plus rapide, config plus simple |
| Validation cross-browser avant release | Multi-projets : chromium + firefox + webkit | Détecter les différences de rendu/API |
| App responsive mobile | Ajouter des projets mobile à côté du desktop | Les différences de viewport et de tactile comptent |
| Tests authentifiés + non authentifiés | Setup project + projets dépendants | Partager l'état d'auth sans re-login à chaque test |
| Pipeline CI avec budget de temps serré | Chromium dans les checks de PR ; tous les navigateurs au merge sur main | Équilibrer vitesse et couverture |

### globalSetup vs setup projects vs fixtures

| Besoin | Utiliser | Pourquoi |
|---|---|---|
| Seed ponctuel de la BDD ou préparation d'un service externe | `globalSetup` | S'exécute une fois, pas de navigateur nécessaire |
| Auth navigateur partagée (login une fois, réutiliser les cookies) | Setup project avec `dependencies` | Il faut un contexte de navigateur ; `globalSetup` n'en a pas |
| État isolé par test (utilisateur unique, données fraîches) | Fixture custom via `test.extend()` | Chaque test reçoit sa propre instance avec teardown |
| Nettoyage après tous les tests | `globalTeardown` | S'exécute une fois à la fin, que ça passe ou non |

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| `timeout: 300_000` globalement | Masque les tests flaky ; les runs CI deviennent interminables | Corriger la cause racine ; garder le timeout à 30s ; n'augmenter `navigationTimeout` que si c'est justifié |
| URLs en dur dans les tests : `page.goto('http://localhost:3000/login')` | Casse dans tous les environnements non locaux | Utiliser `baseURL` dans la config, puis `page.goto('/login')` |
| Lancer chromium + firefox + webkit sur chaque PR | Temps de CI x3 pour un bénéfice marginal sur la plupart des PR | Chromium sur les PR ; tous les navigateurs aux merges sur main |
| `trace: 'on'` en permanence en CI | Artefacts énormes, uploads lents, disque plein | `trace: 'on-first-retry'` -- ne capture que lorsqu'un test échoue et est rejoué |
| `video: 'on'` en permanence en CI | Stockage CI massif ; l'enregistrement ralentit les tests | `video: 'retain-on-failure'` -- enregistre tout mais ne garde que les échecs |
| Valeurs de config inline dans les fichiers de test : `test.use({ viewport: { width: 1280, height: 720 } })` dans chaque fichier | Dispersé, difficile à maintenir, incohérent | Définir une fois dans la config du projet ; ne surcharger par fichier que si c'est vraiment nécessaire |
| `retries: 3` en local | Masque le flaky pendant le développement | `retries: 0` en local, `retries: 2` en CI |
| Pas de `forbidOnly` en CI | Un `test.only` commité par erreur lance un seul test, tout le reste est ignoré en silence | `forbidOnly: !!process.env.CI` |
| `globalSetup` pour l'auth navigateur | Pas de contexte de navigateur disponible ; contournements complexes | Utiliser un setup project avec `dependencies` |
| Commiter des fichiers `.env` avec de vrais identifiants | Risque de sécurité | Ne commiter que `.env.example` ; mettre les vrais `.env` dans le gitignore |

## Dépannage

### "baseURL" ne fonctionne pas -- les tests naviguent vers l'URL complète

**Cause** : utilisation de `page.goto('http://localhost:3000/path')` au lieu de `page.goto('/path')`. Quand `goto` reçoit une URL absolue, il ignore `baseURL`.

**Correctif** : passe toujours des chemins relatifs à `page.goto()` :

```ts
// Wrong -- ignores baseURL
await page.goto('http://localhost:3000/dashboard');

// Correct -- uses baseURL from config
await page.goto('/dashboard');
```

### webServer démarre mais les tests échouent quand même avec connection refused

**Cause** : l'`url` du `webServer` ne correspond pas à ce que le serveur sert réellement, ou l'endpoint de healthcheck renvoie autre chose que 200.

**Correctif** : assure-toi que `webServer.url` correspond à l'adresse réelle du serveur. Ajoute une route de healthcheck si besoin :

```ts
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.ts',
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000/api/health',  // use a real endpoint
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
```

### Les tests passent en local mais expirent en CI

**Cause** : les machines de CI sont plus lentes. Les timeouts par défaut sont trop serrés pour le matériel de CI.

**Correctif** : augmente `navigationTimeout` pour la CI, réduis `workers` pour éviter la contention de ressources :

```ts
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.ts',
  workers: process.env.CI ? '50%' : undefined,
  use: {
    navigationTimeout: process.env.CI ? 30_000 : 15_000,
    actionTimeout: process.env.CI ? 15_000 : 10_000,
  },
});
```

### "Error: page.goto: Target page, context or browser has been closed"

**Cause** : le test a dépassé son `timeout` et Playwright a fermé le navigateur alors qu'une action était encore en cours.

**Correctif** : n'augmente pas le timeout global. Trouve plutôt l'étape lente avec `--trace on` et corrige-la. Causes courantes : attente d'une API lente, requête réseau non résolue, ou `await` manquant.

```bash
# Record a trace for debugging
npx playwright test --trace on
npx playwright show-report
```

## Voir aussi

- [core/fixtures-and-hooks.md](fixtures-and-hooks.md) -- fixtures custom qui remplacent `globalSetup` pour l'état par test
- [core/test-organization.md](test-organization.md) -- structure des fichiers, conventions de nommage, regroupement des tests
- [core/authentication.md](authentication.md) -- setup projects pour l'état d'auth partagé
- [ci/ci-github-actions.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/ci-github-actions.md) -- config spécifique à la CI et cache
- [ci/projects-and-dependencies.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/projects-and-dependencies.md) -- patterns multi-projets avancés
