# Tests de régression visuelle

> **Quand l'utiliser** : détecter les changements visuels involontaires -- décalages de layout, régressions de style, designs responsives cassés, thèmes corrompus -- que les assertions fonctionnelles ne voient pas. Les tests visuels répondent à la question « est-ce que ça a toujours la bonne allure ? » après des changements de code.
> **Prérequis** : [core/configuration.md](configuration.md) pour la configuration du projet, [core/assertions-and-waiting.md](assertions-and-waiting.md) pour les bases des assertions.

## Référence rapide

```typescript
// Page screenshot -- compare entire viewport
await expect(page).toHaveScreenshot();

// Element screenshot -- compare a specific component
await expect(page.getByTestId('pricing-card')).toHaveScreenshot();

// Named snapshot -- explicit file name
await expect(page).toHaveScreenshot('homepage-hero.png');

// With threshold -- allow minor pixel differences
await expect(page).toHaveScreenshot({ maxDiffPixelRatio: 0.01 });

// Mask dynamic content -- hide timestamps, avatars, ads
await expect(page).toHaveScreenshot({
  mask: [page.getByTestId('timestamp'), page.getByRole('img', { name: 'Avatar' })],
});

// Disable animations -- prevent flaky diffs from CSS transitions
await expect(page).toHaveScreenshot({ animations: 'disabled' });

// Update baselines (CLI)
npx playwright test --update-snapshots
```

## Patterns

### 1. Bases de la comparaison de screenshots

**À utiliser quand** : tu vérifies qu'une page ou un composant s'affiche correctement après des changements de code. Idéal pour les pages au layout stable -- landing pages, dashboards, panneaux de réglages.
**À éviter quand** : la page est très dynamique, avec des données temps réel, des flux live ou un contenu qui change à chaque chargement. Utilise plutôt des assertions fonctionnelles.

Playwright compare un screenshot pris pendant le test à une image de référence (golden) stockée. Au premier lancement, la baseline est créée. Aux lancements suivants, les différences font échouer le test avec un rapport de diff visuel.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('homepage renders correctly', async ({ page }) => {
  await page.goto('/');

  // Full page screenshot comparison
  await expect(page).toHaveScreenshot('homepage.png');
});

test('pricing card matches design', async ({ page }) => {
  await page.goto('/pricing');

  // Element-level screenshot -- scoped to a single component
  const card = page.getByTestId('pro-plan-card');
  await expect(card).toHaveScreenshot('pro-plan-card.png');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('homepage renders correctly', async ({ page }) => {
  await page.goto('/');

  await expect(page).toHaveScreenshot('homepage.png');
});

test('pricing card matches design', async ({ page }) => {
  await page.goto('/pricing');

  const card = page.getByTestId('pro-plan-card');
  await expect(card).toHaveScreenshot('pro-plan-card.png');
});
```

Par défaut, les snapshots sont stockés à côté des tests, dans un dossier nommé `<test-file-name>-snapshots/`. La structure du dossier inclut le nom du projet et la plateforme :

```
tests/
  homepage.spec.ts
  homepage.spec.ts-snapshots/
    homepage-chromium-linux.png
    homepage-chromium-darwin.png
```

### 2. Configurer les seuils

**À utiliser quand** : ton UI présente de légères différences de rendu d'un lancement à l'autre -- anti-aliasing, font hinting, rendu sub-pixel. Les seuils évitent les faux échecs dus au bruit au niveau du pixel.
**À éviter quand** : tu veux des comparaisons au pixel près (bibliothèques de composants de design system, rendu d'icônes). Garde alors les seuils à zéro.

Trois réglages contrôlent la sensibilité de la comparaison :

| Option | Ce qu'elle contrôle | Bonne valeur par défaut |
|---|---|---|
| `maxDiffPixels` | Nombre absolu de pixels pouvant différer | `100` pour les pages complètes, `10` pour les composants |
| `maxDiffPixelRatio` | Fraction du total de pixels pouvant différer (0-1) | `0.01` (1 %) pour les pages complètes |
| `threshold` | Tolérance de différence de couleur par pixel (0-1) | `0.2` pour la plupart des UI, `0.1` pour les design systems |

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('dashboard allows minor rendering variance', async ({ page }) => {
  await page.goto('/dashboard');

  // Allow up to 1% of pixels to differ
  await expect(page).toHaveScreenshot('dashboard.png', {
    maxDiffPixelRatio: 0.01,
  });
});

test('icon renders pixel-perfect', async ({ page }) => {
  await page.goto('/icons');

  // Strict: zero tolerance
  await expect(page.getByTestId('logo')).toHaveScreenshot('logo.png', {
    maxDiffPixels: 0,
    threshold: 0,
  });
});

test('chart allows anti-aliasing differences', async ({ page }) => {
  await page.goto('/analytics');

  // Per-pixel color threshold + absolute pixel count cap
  await expect(page.getByTestId('revenue-chart')).toHaveScreenshot('revenue-chart.png', {
    threshold: 0.3,
    maxDiffPixels: 200,
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('dashboard allows minor rendering variance', async ({ page }) => {
  await page.goto('/dashboard');

  await expect(page).toHaveScreenshot('dashboard.png', {
    maxDiffPixelRatio: 0.01,
  });
});

test('icon renders pixel-perfect', async ({ page }) => {
  await page.goto('/icons');

  await expect(page.getByTestId('logo')).toHaveScreenshot('logo.png', {
    maxDiffPixels: 0,
    threshold: 0,
  });
});

test('chart allows anti-aliasing differences', async ({ page }) => {
  await page.goto('/analytics');

  await expect(page.getByTestId('revenue-chart')).toHaveScreenshot('revenue-chart.png', {
    threshold: 0.3,
    maxDiffPixels: 200,
  });
});
```

**Seuils globaux** dans `playwright.config.ts` :

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  expect: {
    toHaveScreenshot: {
      maxDiffPixelRatio: 0.01,
      threshold: 0.2,
      animations: 'disabled',
    },
  },
});
```

### 3. Page complète vs screenshots d'éléments

**À utiliser quand** : tu choisis la portée. La page complète détecte les décalages de layout et les régressions d'espacement. Les screenshots d'éléments isolent les composants et sont plus stables.
**À éviter quand** : aucun des deux cas -- utilise les deux de façon stratégique.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('full page screenshot catches layout shifts', async ({ page }) => {
  await page.goto('/');

  // Captures the visible viewport
  await expect(page).toHaveScreenshot('homepage-viewport.png');

  // Captures the entire scrollable page
  await expect(page).toHaveScreenshot('homepage-full.png', {
    fullPage: true,
  });
});

test('element screenshot isolates component changes', async ({ page }) => {
  await page.goto('/pricing');

  // Only the pricing table -- immune to header/footer changes
  await expect(page.getByRole('table')).toHaveScreenshot('pricing-table.png');

  // A specific card within the page
  await expect(page.getByTestId('enterprise-card')).toHaveScreenshot('enterprise-card.png');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('full page screenshot catches layout shifts', async ({ page }) => {
  await page.goto('/');

  await expect(page).toHaveScreenshot('homepage-viewport.png');

  await expect(page).toHaveScreenshot('homepage-full.png', {
    fullPage: true,
  });
});

test('element screenshot isolates component changes', async ({ page }) => {
  await page.goto('/pricing');

  await expect(page.getByRole('table')).toHaveScreenshot('pricing-table.png');
  await expect(page.getByTestId('enterprise-card')).toHaveScreenshot('enterprise-card.png');
});
```

**Règle empirique** : utilise des screenshots d'éléments pour les composants qui évoluent indépendamment. Utilise des screenshots de page complète pour les landing pages clés et les layouts où l'espacement entre les sections compte.

### 4. Masquer le contenu dynamique

**À utiliser quand** : la page contient du contenu qui change d'un lancement de test à l'autre -- timestamps, avatars d'utilisateurs, emplacements publicitaires, dates relatives (« il y a 3 minutes »), images hero aléatoires, variantes d'A/B test.
**À éviter quand** : tout le contenu est déterministe. Le masquage ajoute de la maintenance.

L'option `mask` superpose un cadre de couleur unie sur les locators indiqués avant de prendre le screenshot. La zone masquée est exclue de la comparaison.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('dashboard with masked dynamic content', async ({ page }) => {
  await page.goto('/dashboard');

  await expect(page).toHaveScreenshot('dashboard.png', {
    mask: [
      page.getByTestId('current-time'),
      page.getByTestId('user-avatar'),
      page.getByTestId('live-visitor-count'),
      page.locator('.ad-banner'),
    ],
    maskColor: '#FF00FF', // visible magenta -- makes it obvious what's masked in reviews
  });
});

test('feed page with relative timestamps', async ({ page }) => {
  await page.goto('/feed');

  // Mask all relative time elements at once
  await expect(page).toHaveScreenshot('feed.png', {
    mask: [page.locator('time[datetime]')],
  });
});

test('profile page with user-generated content', async ({ page }) => {
  await page.goto('/profile/test-user');

  await expect(page).toHaveScreenshot('profile.png', {
    mask: [
      page.getByRole('img', { name: 'Profile photo' }),
      page.getByTestId('last-login'),
      page.getByTestId('member-since'),
    ],
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('dashboard with masked dynamic content', async ({ page }) => {
  await page.goto('/dashboard');

  await expect(page).toHaveScreenshot('dashboard.png', {
    mask: [
      page.getByTestId('current-time'),
      page.getByTestId('user-avatar'),
      page.getByTestId('live-visitor-count'),
      page.locator('.ad-banner'),
    ],
    maskColor: '#FF00FF',
  });
});

test('feed page with relative timestamps', async ({ page }) => {
  await page.goto('/feed');

  await expect(page).toHaveScreenshot('feed.png', {
    mask: [page.locator('time[datetime]')],
  });
});

test('profile page with user-generated content', async ({ page }) => {
  await page.goto('/profile/test-user');

  await expect(page).toHaveScreenshot('profile.png', {
    mask: [
      page.getByRole('img', { name: 'Profile photo' }),
      page.getByTestId('last-login'),
      page.getByTestId('member-since'),
    ],
  });
});
```

**Alternative : figer le contenu dynamique avec JavaScript**

Quand le masquage ne suffit pas (par exemple parce que le contenu influence le layout), injecte du JavaScript pour figer le contenu :

```typescript
test('freeze clock before screenshot', async ({ page }) => {
  await page.goto('/dashboard');

  // Replace all dynamic timestamps with a fixed value
  await page.evaluate(() => {
    document.querySelectorAll('[data-testid="timestamp"]').forEach((el) => {
      el.textContent = 'Jan 1, 2025 12:00 PM';
    });
  });

  await expect(page).toHaveScreenshot('dashboard-frozen.png');
});
```

### 5. Gérer les animations

**À utiliser quand** : toujours. Les animations et transitions CSS sont la cause numéro un des diffs visuels flaky. Un screenshot capturé en pleine animation ne correspondra jamais à la baseline.
**À éviter quand** : tu testes explicitement l'animation elle-même (rare).

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('page renders without animation interference', async ({ page }) => {
  await page.goto('/');

  // Disables CSS animations and transitions before screenshotting
  await expect(page).toHaveScreenshot('homepage.png', {
    animations: 'disabled',
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('page renders without animation interference', async ({ page }) => {
  await page.goto('/');

  await expect(page).toHaveScreenshot('homepage.png', {
    animations: 'disabled',
  });
});
```

**À définir globalement** -- ce devrait être la valeur par défaut de tout projet :

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  expect: {
    toHaveScreenshot: {
      animations: 'disabled',
    },
  },
});
```

Quand `animations: 'disabled'` est activé, Playwright :
1. Injecte une feuille de style qui définit `* { animation-duration: 0s !important; transition-duration: 0s !important; }`.
2. Attend la fin des animations en cours (les force à leur état final).
3. Prend le screenshot.

Pour les animations pilotées par JavaScript (requestAnimationFrame, GSAP, Framer Motion), tu peux aussi avoir besoin d'attendre la stabilité :

```typescript
test('page with JS animations', async ({ page }) => {
  await page.goto('/animated-landing');

  // Wait for the hero animation to settle
  await page.getByTestId('hero-section').waitFor({ state: 'visible' });
  // No fixed sleep: toHaveScreenshot retries until two consecutive captures match.
  // Libraries that honor prefers-reduced-motion skip animations under test.use({ reducedMotion: 'reduce' }).

  await expect(page).toHaveScreenshot('landing.png', {
    animations: 'disabled',
  });
});
```

### 6. Mettre à jour les snapshots

**À utiliser quand** : tu as volontairement modifié l'UI et tu dois mettre à jour les baselines. Refonte du design, rebranding, nouvelle fonctionnalité ou changement de layout.
**À éviter quand** : le diff est inattendu -- cherche la cause avant de mettre à jour aveuglément.

```bash
# Update all snapshots
npx playwright test --update-snapshots

# Update snapshots for a specific test file
npx playwright test tests/homepage.spec.ts --update-snapshots

# Update snapshots for a specific project (browser)
npx playwright test --project=chromium --update-snapshots
```

**Workflow pour relire les changements de snapshots :**

1. Lance les tests et observe les échecs dans le rapport HTML :
   ```bash
   npx playwright test
   npx playwright show-report
   ```
   Le rapport affiche côte à côte l'image attendue, l'image obtenue et une image de diff.

2. Si les changements sont voulus, mets à jour les snapshots :
   ```bash
   npx playwright test --update-snapshots
   ```

3. Relis les snapshots mis à jour dans ton outil de diff avant de commiter :
   ```bash
   git diff --name-only  # see which snapshot files changed
   ```

4. Commite les snapshots mis à jour avec un message clair expliquant pourquoi ils ont changé.

**`--update-snapshots=missing` passe désormais (breaking change de Playwright 1.64).** Avant la 1.64, un test qui écrivait une baseline manquante échouait quand même, si bien que la CI ne pouvait pas créer de nouvelles baselines et vérifier les existantes dans le même run. Dans la 1.64, le mode `'missing'` écrit les snapshots manquants **et passe**, tandis que les snapshots existants restent comparés. Le mode utilisé quand tu ne passes aucune option s'appelle désormais `'default'` et garde l'ancien comportement : les snapshots manquants sont écrits et le test échoue.

```bash
# CI: create baselines for new tests, verify everything else, stay green
npx playwright test --update-snapshots=missing
```

Utilise-le pour le premier lancement de nouveaux tests visuels dans un conteneur dont le rendu correspond à celui de la CI. Relis et commite quand même les fichiers générés ; une baseline que personne n'a regardée est une régression qui attend d'être approuvée.

**Astuce** : ne lance jamais `--update-snapshots` en CI. Mets toujours à jour en local, relis les diffs et commite les nouvelles baselines.

**TypeScript -- helper pour des mises à jour contrôlées**
```typescript
import { test, expect } from '@playwright/test';

// Tag visual tests so you can update them selectively
test('homepage visual @visual', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveScreenshot('homepage.png', {
    animations: 'disabled',
  });
});

test('pricing visual @visual', async ({ page }) => {
  await page.goto('/pricing');
  await expect(page).toHaveScreenshot('pricing.png', {
    animations: 'disabled',
  });
});
```

```bash
# Update only visual tests
npx playwright test --grep @visual --update-snapshots
```

### 7. Tests visuels cross-browser

**À utiliser quand** : tes utilisateurs se répartissent entre Chrome, Firefox et Safari et tu dois vérifier la cohérence du rendu par navigateur.
**À éviter quand** : projets en phase initiale ciblant un seul navigateur -- des tests visuels sur trois navigateurs triplent la charge de maintenance.

Playwright sépare automatiquement les snapshots par nom de projet. Chaque navigateur a son propre fichier de baseline. C'est le comportement attendu -- les navigateurs rendent les polices, les ombres et l'anti-aliasing différemment.

**TypeScript**
```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  expect: {
    toHaveScreenshot: {
      animations: 'disabled',
      maxDiffPixelRatio: 0.01,
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
  ],
});
```

```typescript
// tests/homepage.spec.ts
import { test, expect } from '@playwright/test';

test('homepage renders correctly per browser', async ({ page }) => {
  await page.goto('/');

  // Playwright creates separate baselines per project:
  //   homepage.spec.ts-snapshots/homepage-chromium-linux.png
  //   homepage.spec.ts-snapshots/homepage-firefox-linux.png
  //   homepage.spec.ts-snapshots/homepage-webkit-linux.png
  await expect(page).toHaveScreenshot('homepage.png', {
    animations: 'disabled',
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('homepage renders correctly per browser', async ({ page }) => {
  await page.goto('/');

  await expect(page).toHaveScreenshot('homepage.png', {
    animations: 'disabled',
  });
});
```

**Stratégie pour gérer les snapshots cross-browser** : lance les tests visuels dans un seul navigateur (Chromium sous Linux en CI) pour minimiser le nombre de snapshots, et n'ajoute d'autres navigateurs que si tu rencontres de vrais bugs de rendu cross-browser. Tu peux limiter les tests visuels à un seul projet :

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  projects: [
    {
      name: 'visual',
      testMatch: '**/*.visual.spec.ts',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'chromium',
      testIgnore: '**/*.visual.spec.ts',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      testIgnore: '**/*.visual.spec.ts',
      use: { ...devices['Desktop Firefox'] },
    },
  ],
});
```

### 8. Tests visuels responsives

**À utiliser quand** : ton application a des breakpoints responsives et tu dois vérifier les layouts à différentes tailles de viewport.
**À éviter quand** : la page a un layout unique à largeur fixe.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

const viewports = [
  { name: 'mobile', width: 375, height: 812 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'desktop', width: 1440, height: 900 },
];

for (const viewport of viewports) {
  test(`homepage at ${viewport.name} (${viewport.width}x${viewport.height})`, async ({ page }) => {
    await page.setViewportSize({ width: viewport.width, height: viewport.height });
    await page.goto('/');

    await expect(page).toHaveScreenshot(`homepage-${viewport.name}.png`, {
      animations: 'disabled',
      fullPage: true,
    });
  });
}
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

const viewports = [
  { name: 'mobile', width: 375, height: 812 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'desktop', width: 1440, height: 900 },
];

for (const viewport of viewports) {
  test(`homepage at ${viewport.name} (${viewport.width}x${viewport.height})`, async ({ page }) => {
    await page.setViewportSize({ width: viewport.width, height: viewport.height });
    await page.goto('/');

    await expect(page).toHaveScreenshot(`homepage-${viewport.name}.png`, {
      animations: 'disabled',
      fullPage: true,
    });
  });
}
```

**Alternative : utiliser les projects Playwright pour les tests responsives.**

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  projects: [
    {
      name: 'desktop',
      testMatch: '**/*.visual.spec.ts',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1440, height: 900 },
      },
    },
    {
      name: 'tablet',
      testMatch: '**/*.visual.spec.ts',
      use: {
        ...devices['iPad (gen 7)'],
      },
    },
    {
      name: 'mobile',
      testMatch: '**/*.visual.spec.ts',
      use: {
        ...devices['iPhone 14'],
      },
    },
  ],
});
```

Cette approche te donne des dossiers de snapshots séparés par appareil et les exécute en parallèle.

### 9. Configurer la CI pour les tests visuels

**À utiliser quand** : tu exécutes des tests de régression visuelle en CI. L'exigence critique est un rendu cohérent -- le même test doit produire le même screenshot à chaque fois.
**À éviter quand** : ne saute jamais cette étape. Des tests visuels sans cohérence en CI ne valent rien.

**Le problème** : le rendu des polices, l'anti-aliasing et le rendu sub-pixel diffèrent selon les systèmes d'exploitation. Un snapshot pris sous macOS ne correspondra pas à un snapshot pris sous Linux. C'est la source de douleur la plus courante des tests visuels.

**La solution** : exécute les tests visuels dans Docker avec le conteneur Playwright officiel. Génère et mets à jour les snapshots depuis le même conteneur.

**GitHub Actions avec Docker**

```yaml
# .github/workflows/visual-tests.yml
name: Visual Regression Tests
on: [push, pull_request]

jobs:
  visual-tests:
    runs-on: ubuntu-latest
    container:
      image: mcr.microsoft.com/playwright:v1.64.0-noble
    steps:
      - uses: actions/checkout@v7

      - uses: actions/setup-node@v7
        with:
          node-version: lts/*
          cache: npm

      - run: npm ci

      - name: Run visual tests
        run: npx playwright test --project=visual
        env:
          HOME: /root  # required for Playwright in Docker

      - uses: actions/upload-artifact@v7
        if: failure()
        with:
          name: visual-test-report
          path: playwright-report/
          retention-days: 14
```

**Mettre à jour les snapshots en local avec Docker** -- pour que tes baselines locales correspondent à la CI :

```bash
# Generate/update snapshots using the same container as CI
docker run --rm --init --ipc=host -v $(pwd):/work -w /work \
  mcr.microsoft.com/playwright:v1.64.0-noble \
  npx playwright test --update-snapshots --project=visual
```

**Ajoute un script à `package.json`** pour plus de confort :

```json
{
  "scripts": {
    "test:visual": "npx playwright test --project=visual",
    "test:visual:update": "docker run --rm --init --ipc=host -v $(pwd):/work -w /work mcr.microsoft.com/playwright:v1.64.0-noble npx playwright test --update-snapshots --project=visual"
  }
}
```

**Configure les snapshots pour Linux uniquement** dans ta config :

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  snapshotPathTemplate: '{testDir}/{testFileDir}/{testFileName}-snapshots/{arg}{-projectName}{ext}',
  // Omits {-snapshotSuffix} which includes the platform name (linux, darwin, win32).
  // This means snapshots are platform-agnostic -- you MUST generate them in Docker.
  projects: [
    {
      name: 'visual',
      testMatch: '**/*.visual.spec.ts',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
```

### 10. Tests visuels de composants

**À utiliser quand** : tu testes des composants d'UI individuels en isolation -- boutons, cards, formulaires, modales. Plus rapide que les screenshots de page complète, plus stable et plus facile à maintenir.
**À éviter quand** : tu dois vérifier les interactions entre plusieurs composants ou le layout au niveau de la page.

**TypeScript -- avec le component testing de Playwright**
```typescript
// tests/components/button.visual.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Button component visual states', () => {
  test('primary button', async ({ page }) => {
    await page.goto('/storybook/iframe.html?id=button--primary');
    const button = page.getByRole('button');
    await expect(button).toHaveScreenshot('button-primary.png', {
      animations: 'disabled',
    });
  });

  test('primary button hover', async ({ page }) => {
    await page.goto('/storybook/iframe.html?id=button--primary');
    const button = page.getByRole('button');
    await button.hover();
    await expect(button).toHaveScreenshot('button-primary-hover.png', {
      animations: 'disabled',
    });
  });

  test('primary button disabled', async ({ page }) => {
    await page.goto('/storybook/iframe.html?id=button--primary-disabled');
    const button = page.getByRole('button');
    await expect(button).toHaveScreenshot('button-primary-disabled.png', {
      animations: 'disabled',
    });
  });

  test('button sizes', async ({ page }) => {
    for (const size of ['small', 'medium', 'large']) {
      await page.goto(`/storybook/iframe.html?id=button--${size}`);
      const button = page.getByRole('button');
      await expect(button).toHaveScreenshot(`button-${size}.png`, {
        animations: 'disabled',
      });
    }
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('Button component visual states', () => {
  test('primary button', async ({ page }) => {
    await page.goto('/storybook/iframe.html?id=button--primary');
    const button = page.getByRole('button');
    await expect(button).toHaveScreenshot('button-primary.png', {
      animations: 'disabled',
    });
  });

  test('primary button hover', async ({ page }) => {
    await page.goto('/storybook/iframe.html?id=button--primary');
    const button = page.getByRole('button');
    await button.hover();
    await expect(button).toHaveScreenshot('button-primary-hover.png', {
      animations: 'disabled',
    });
  });

  test('primary button disabled', async ({ page }) => {
    await page.goto('/storybook/iframe.html?id=button--primary-disabled');
    const button = page.getByRole('button');
    await expect(button).toHaveScreenshot('button-primary-disabled.png', {
      animations: 'disabled',
    });
  });

  test('button sizes', async ({ page }) => {
    for (const size of ['small', 'medium', 'large']) {
      await page.goto(`/storybook/iframe.html?id=button--${size}`);
      const button = page.getByRole('button');
      await expect(button).toHaveScreenshot(`button-${size}.png`, {
        animations: 'disabled',
      });
    }
  });
});
```

**Avec une page de test visuel dédiée** plutôt que Storybook :

```typescript
// tests/components/card.visual.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Card component', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to a page that renders the component in isolation
    await page.goto('/test-harness/card');
  });

  test('default state', async ({ page }) => {
    await expect(page.getByTestId('card')).toHaveScreenshot('card-default.png', {
      animations: 'disabled',
    });
  });

  test('with long content truncates correctly', async ({ page }) => {
    await page.goto('/test-harness/card?content=long');
    await expect(page.getByTestId('card')).toHaveScreenshot('card-long-content.png', {
      animations: 'disabled',
    });
  });

  test('error state', async ({ page }) => {
    await page.goto('/test-harness/card?state=error');
    await expect(page.getByTestId('card')).toHaveScreenshot('card-error.png', {
      animations: 'disabled',
    });
  });
});
```

### 11. Snapshots WebP (Playwright 1.62+)

Playwright 1.62 supporte WebP pour les assertions de snapshots comme pour les screenshots ponctuels.

```javascript
await expect(page).toHaveScreenshot('homepage.webp');
await page.screenshot({ path: 'homepage.webp', type: 'webp', quality: 50 });
```

`quality` va de 0 à 100, où **100 correspond à du lossless**. Tout ce qui est en dessous est lossy, et cette distinction détermine comment tu l'utilises.

**Pour les baselines de régression visuelle, reste en lossless.** Une baseline lossy incorpore des artefacts de compression dans l'image de référence, et ton seuil de pixels doit alors absorber à la fois les vraies différences de rendu et le bruit du codec. Le WebP lossless est typiquement 20 à 30 % plus léger que le PNG pour des screenshots d'UI, à pixels identiques : il réduit donc la taille du dépôt sans effet sur la comparaison.

**Pour les artefacts d'échec, le lossy est le bon compromis.** Les screenshots d'échec sont faits pour être regardés par un humain, pas diffés, et `quality: 50` à `80` les allège énormément tout en restant lisibles. L'option `use.screenshot` n'accepte que `mode`, `fullPage` et `omitBackground` (pas de `type`/`quality`), donc capture toi-même les artefacts lossy :

```typescript
test.afterEach(async ({ page }, testInfo) => {
  if (testInfo.status !== testInfo.expectedStatus) {
    await testInfo.attach('failure', {
      body: await page.screenshot({ type: 'webp', quality: 70 }),
      contentType: 'image/webp',
    });
  }
});
```

**Faire du WebP le format par défaut des snapshots sans nom (1.64+)** : `expect(page).toHaveScreenshot()` sans nom produisait auparavant toujours un `.png`. Définis `type` une fois dans la config et chaque baseline sans nom est stockée en WebP :

```typescript
export default defineConfig({
  expect: {
    toHaveScreenshot: { type: 'webp' },
  },
});
```

**Ne mélange pas les formats dans un même jeu de baselines.** Convertir des baselines PNG existantes en WebP régénère toutes les images de référence : fais-le en un seul commit délibéré plutôt que de laisser les 2 formats dériver dans la suite de tests.

### 12. Asserter les styles de pseudo-éléments au lieu d'un screenshot (Playwright 1.60+)

**À utiliser quand** : seuls un ou deux styles calculés d'un pseudo-élément `::before` / `::after` t'intéressent (un glyphe d'icône, un astérisque de champ obligatoire, la couleur d'une pastille de statut). Une assertion CSS ciblée est plus rapide et bien moins fragile qu'un diff de pixels.
**À éviter quand** : ce que tu vérifies est réellement visuel (layout, dégradés, ombres). Continue d'utiliser `toHaveScreenshot()` dans ce cas.

L'option `pseudo` de `toHaveCSS()`, apparue dans Playwright 1.60, te permet de vérifier les styles d'un pseudo-élément sans baseline de screenshot à maintenir :

```typescript
import { test, expect } from '@playwright/test';

test('status badge renders a green dot via ::before', async ({ page }) => {
  await page.goto('/orders');

  const badge = page.getByTestId('status-online');
  // No snapshot file to update — assert the computed style directly
  await expect(badge).toHaveCSS('background-color', 'rgb(22, 163, 74)', { pseudo: 'before' });
});
```

Cela complète les snapshots visuels : utilise-le pour verrouiller un style de pseudo-élément précis qui forcerait sinon un screenshot complet. Voir [core/assertions-and-waiting.md](assertions-and-waiting.md#asserter-les-styles-de-pseudo-éléments-tohavecss-pseudo--playwright-160).

## Guide de décision

| Scénario | Approche recommandée | Pourquoi |
|---|---|---|
| Landing pages clés, site marketing | Screenshot de page complète, `fullPage: true` | Détecte les décalages de layout, l'espacement et l'harmonie visuelle d'ensemble |
| Composants d'UI individuels (boutons, cards, modales) | Screenshot d'élément sur le composant | Isolé, rapide, stable -- insensible aux changements sans rapport sur la page |
| Page avec contenu dynamique (timestamps, données live) | Page complète + `mask` sur les éléments dynamiques | Couvre le layout tout en ignorant le contenu volatil |
| Bibliothèque de composants de design system | Screenshot d'élément par variante, seuil à zéro | Exigence pixel-perfect pour les composants partagés |
| Vérification du layout responsive | Screenshot par viewport (boucle ou projects) | Détecte les bugs de breakpoint en mobile/tablette/desktop |
| Cohérence du rendu cross-browser | Snapshots séparés par projet de navigateur | Les navigateurs rendent les polices et les ombres différemment |
| Pipeline de CI | Conteneur Docker (image Playwright), snapshots Linux uniquement | Rendu cohérent, aucun diff dépendant de l'OS |
| Seuil de pixels : design system | `threshold: 0`, `maxDiffPixels: 0` | Tolérance zéro pour la bibliothèque de composants |
| Seuil de pixels : pages de contenu | `maxDiffPixelRatio: 0.01`, `threshold: 0.2` | Tolère une légère variance d'anti-aliasing |
| Seuil de pixels : charts et graphiques | `maxDiffPixels: 200`, `threshold: 0.3` | L'anti-aliasing sur les courbes varie d'un run à l'autre |
| Les tests visuels apportent de la valeur | Pages stables, design systems, vérification après refactoring | Baseline claire, contenu prévisible |
| Les tests visuels ne sont que du bruit | Pages très dynamiques, dashboards temps réel, pages d'A/B test | Le contenu change à chaque chargement, les diffs n'ont aucun sens |

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| Tester visuellement chaque page de l'application | Maintenance massive des snapshots, faux échecs constants, l'équipe ignore les résultats | Choisis 5 à 10 pages clés et les composants critiques. La qualité plutôt que la quantité. |
| Ne pas masquer le contenu dynamique (timestamps, avatars, compteurs) | Les screenshots diffèrent à chaque exécution. Les tests sont flaky en permanence. | Utilise l'option `mask` pour tous les éléments dynamiques. Audite la volatilité des pages avant d'ajouter des tests visuels. |
| Lancer les tests visuels sur macOS, Linux et Windows | Le rendu des polices diffère selon l'OS. Les snapshots ne correspondent jamais d'une plateforme à l'autre. | Standardise sur Linux via Docker. Génère et exécute les snapshots dans le même conteneur Docker Playwright. |
| Ne pas utiliser Docker en CI pour les tests visuels | Les mises à jour de l'OS du runner CI, les changements de polices ou les montées de version de librairies décalent silencieusement le rendu. | Épingle une version précise de l'image Docker Playwright. Mets à jour volontairement. |
| Mettre à jour aveuglément les snapshots avec `--update-snapshots` | Accepte des régressions involontaires. La baseline devient fausse. | Relis toujours d'abord le diff dans le rapport HTML. Comprends pourquoi le snapshot a changé. |
| Omettre `animations: 'disabled'` | Les transitions CSS et animations keyframe créent des diffs aléatoires. Une des premières causes de tests visuels flaky. | Définis `animations: 'disabled'` globalement dans la config. |
| Utiliser des tests visuels à la place des assertions fonctionnelles | Les diffs de screenshots ne disent pas *ce qui* est cassé -- seulement que *quelque chose* a changé d'aspect. Lent à débugger. | Utilise des assertions fonctionnelles (`toHaveText`, `toBeVisible`) pour le comportement. Les tests visuels complètent, ne remplacent jamais. |
| Commiter des snapshots générés sur des plateformes différentes | Le dépôt contient des snapshots macOS du dev A et des snapshots Linux du dev B. Les tests échouent pour tout le monde. | Tous les membres de l'équipe génèrent les snapshots avec le même conteneur Docker. Ajoute un script `test:visual:update`. |
| Fixer un seuil trop haut (par ex. `maxDiffPixelRatio: 0.1`) | 10 % des pixels peuvent changer et le test passe quand même. Ça annule l'intérêt du test. | Commence à `0.01` (1 %) et ajuste test par test si besoin. |
| Screenshots de page complète sur des pages avec scroll infini ou lazy loading | La hauteur de la page est non déterministe. Les screenshots varient selon le timing de chargement. | Utilise des screenshots d'éléments sur le contenu above-the-fold, ou scrolle d'abord vers un état déterministe. |

## Dépannage

### « Screenshot comparison failed » au premier run en CI après du développement en local

**Cause** : les snapshots ont été générés en local sous macOS (ou Windows). La CI tourne sous Linux. Le rendu des polices diffère entre systèmes d'exploitation, donc chaque comparaison de pixels échoue.

**Correctif** : génère les snapshots avec Docker en local pour qu'ils correspondent à la CI :

```bash
docker run --rm --init --ipc=host -v $(pwd):/work -w /work \
  mcr.microsoft.com/playwright:v1.64.0-noble \
  npx playwright test --update-snapshots --project=visual
```

Commite les snapshots générés sous Linux. Ne commite jamais de snapshots générés sous macOS si ta CI tourne sous Linux.

### « Expected screenshot to match but X pixels differ »

**Cause** : de légères différences de rendu dues à l'anti-aliasing, au font hinting ou au rendu sub-pixel. Fréquent sur les pages riches en texte et les formes courbes (charts, coins arrondis).

**Correctif** : ajoute une petite tolérance :

```typescript
await expect(page).toHaveScreenshot('page.png', {
  maxDiffPixelRatio: 0.01,  // allow 1% variance
  threshold: 0.2,           // per-pixel color tolerance
});
```

Si le diff est plus important, consulte le rapport HTML. Regarde l'image de diff pour déterminer s'il s'agit d'une vraie régression ou de bruit de rendu.

### Les tests visuels passent en local mais échouent en CI (même avec Docker)

**Cause** : versions de Playwright différentes entre le local et la CI. L'image Docker épingle une version précise de Playwright. Si ton `@playwright/test` local est plus récent, le moteur de rendu peut différer.

**Correctif** : assure-toi que la version de Playwright dans `package.json` correspond au tag de l'image Docker :

```json
{
  "devDependencies": {
    "@playwright/test": "1.64.0"
  }
}
```

```yaml
# CI config
container:
  image: mcr.microsoft.com/playwright:v1.64.0-noble  # must match
```

### Les animations provoquent des échecs de diff aléatoires

**Cause** : des animations ou transitions CSS capturées en plein milieu d'une frame. Le screenshot est pris à un point non déterministe de la timeline de l'animation.

**Correctif** : définis `animations: 'disabled'` globalement :

```typescript
// playwright.config.ts
export default defineConfig({
  expect: {
    toHaveScreenshot: {
      animations: 'disabled',
    },
  },
});
```

Pour les animations pilotées par JavaScript, attends un état stable avant de prendre le screenshot : vérifie l'état final de l'élément avec une assertion, définis `reducedMotion: 'reduce'` si la librairie d'animation respecte `prefers-reduced-motion`, et appuie-toi sur le retry de `toHaveScreenshot` jusqu'à ce que deux captures consécutives correspondent. Évite `page.waitForTimeout()`.

### Conflits de noms de fichiers de snapshots entre les tests

**Cause** : deux tests dans des fichiers différents utilisent le même nom de screenshot (`'homepage.png'`) sans chemins de fichier uniques.

**Correctif** : Playwright inclut par défaut le nom du fichier de test dans le chemin du snapshot. Si tu as encore des conflits, utilise des noms explicites et uniques :

```typescript
await expect(page).toHaveScreenshot('auth-homepage.png');   // in auth.spec.ts
await expect(page).toHaveScreenshot('public-homepage.png'); // in public.spec.ts
```

Ou personnalise le template de chemin des snapshots dans la config :

```typescript
export default defineConfig({
  snapshotPathTemplate: '{testDir}/{testFileDir}/{testFileName}-snapshots/{arg}{-projectName}{ext}',
});
```

### Trop de fichiers de snapshots à maintenir

**Cause** : des tests visuels pour chaque page, chaque navigateur, chaque viewport. Le nombre de snapshots explose.

**Correctif** : sois sélectif. Ne teste visuellement que les pages où les régressions visuelles sont à haut risque :
- Landing pages et pages marketing
- Composants de design system
- Layouts complexes (dashboards, tableaux de données)
- Pages après un gros refactoring

Saute les pages où les assertions fonctionnelles couvrent déjà les éléments clés. Un `toHaveText` et un `toBeVisible` suffisent souvent.

## Voir aussi

- [core/assertions-and-waiting.md](assertions-and-waiting.md) -- `toHaveScreenshot()` est une assertion web-first et suit la même sémantique de retry
- [core/configuration.md](configuration.md) -- config globale des screenshots, configuration des projects, `snapshotPathTemplate`
- [core/mobile-and-responsive.md](mobile-and-responsive.md) -- patterns de tests de viewport responsive
- [ci/docker-and-containers.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/docker-and-containers.md) -- configuration Docker pour un rendu cohérent
- [ci/ci-github-actions.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/ci-github-actions.md) -- configuration du pipeline de CI pour les tests visuels
