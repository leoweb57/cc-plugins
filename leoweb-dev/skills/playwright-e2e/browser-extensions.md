# Extensions de navigateur

> **Quand l'utiliser** : tester des extensions Chrome — popups, content scripts, service workers en arrière-plan ou UI injectée par l'extension. Nécessite Chromium et un contexte de navigateur persistant.
> **Prérequis** : [core/configuration.md](configuration.md), [core/fixtures-and-hooks.md](fixtures-and-hooks.md)

## Référence rapide

```typescript
// Load an unpacked extension with a persistent context (Chromium only)
const context = await chromium.launchPersistentContext(userDataDir, {
  channel: 'chromium', // bundled Chromium: extensions work headless too
  args: [
    `--disable-extensions-except=${pathToExtension}`,
    `--load-extension=${pathToExtension}`,
  ],
});
```

**Contraintes strictes** : les extensions ne fonctionnent que dans Chromium. Elles nécessitent `launchPersistentContext` (et non `browser.newContext`). Utilise le Chromium embarqué (`channel: 'chromium'`), qui exécute aussi les extensions en mode headless, ou lance en mode headed. Google Chrome et Microsoft Edge ont supprimé les flags de ligne de commande nécessaires au side-loading d'extensions : les channels de marque (`chrome`, `msedge`) ne peuvent donc pas les charger.

## Patterns

### Charger une extension

**À utiliser quand** : tu as besoin de tester n'importe quelle fonctionnalité d'une extension Chrome.
**À éviter quand** : tu n'as besoin de tester que l'application web avec laquelle une extension interagit — mocke plutôt les effets de l'extension.

**TypeScript**
```typescript
import { test as base, expect, chromium, type BrowserContext } from '@playwright/test';
import path from 'path';

// Create a fixture that provides a context with the extension loaded
type ExtensionFixtures = {
  context: BrowserContext;
  extensionId: string;
};

export const test = base.extend<ExtensionFixtures>({
  // Override the default context to load the extension
  context: async ({}, use) => {
    const extensionPath = path.resolve(__dirname, '../my-extension');
    const context = await chromium.launchPersistentContext('', {
      channel: 'chromium',
      args: [
        `--disable-extensions-except=${extensionPath}`,
        `--load-extension=${extensionPath}`,
      ],
    });
    await use(context);
    await context.close();
  },

  // Extract the extension ID from the service worker URL
  extensionId: async ({ context }, use) => {
    let [background] = context.serviceWorkers();
    if (!background) {
      background = await context.waitForEvent('serviceworker');
    }
    const extensionId = background.url().split('/')[2];
    await use(extensionId);
  },
});

export { expect };
```

**JavaScript**
```javascript
const { test: base, expect, chromium } = require('@playwright/test');
const path = require('path');

const test = base.extend({
  context: async ({}, use) => {
    const extensionPath = path.resolve(__dirname, '../my-extension');
    const context = await chromium.launchPersistentContext('', {
      channel: 'chromium',
      args: [
        `--disable-extensions-except=${extensionPath}`,
        `--load-extension=${extensionPath}`,
      ],
    });
    await use(context);
    await context.close();
  },

  extensionId: async ({ context }, use) => {
    let [background] = context.serviceWorkers();
    if (!background) {
      background = await context.waitForEvent('serviceworker');
    }
    const extensionId = background.url().split('/')[2];
    await use(extensionId);
  },
});

module.exports = { test, expect };
```

### Tester les popups d'extension

**À utiliser quand** : ton extension a un popup de browser action (l'UI qui apparaît au clic sur l'icône de l'extension).
**À éviter quand** : le popup est trivial — teste plutôt le content script ou la logique en arrière-plan.

**TypeScript**
```typescript
import { test, expect } from './extension-fixture';

test('extension popup displays saved bookmarks', async ({ page, extensionId }) => {
  // Navigate directly to the popup HTML
  await page.goto(`chrome-extension://${extensionId}/popup.html`);

  // Interact with popup UI using standard locators
  await expect(page.getByRole('heading', { name: 'My Bookmarks' })).toBeVisible();
  await page.getByRole('button', { name: 'Add current page' }).click();
  await expect(page.getByRole('listitem')).toHaveCount(1);
});

test('extension popup settings toggle works', async ({ page, extensionId }) => {
  await page.goto(`chrome-extension://${extensionId}/popup.html`);

  await page.getByRole('checkbox', { name: 'Enable notifications' }).check();
  await expect(page.getByText('Notifications enabled')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('./extension-fixture');

test('extension popup displays saved bookmarks', async ({ page, extensionId }) => {
  await page.goto(`chrome-extension://${extensionId}/popup.html`);

  await expect(page.getByRole('heading', { name: 'My Bookmarks' })).toBeVisible();
  await page.getByRole('button', { name: 'Add current page' }).click();
  await expect(page.getByRole('listitem')).toHaveCount(1);
});
```

### Tester les content scripts

**À utiliser quand** : ton extension injecte des scripts ou de l'UI dans des pages web.
**À éviter quand** : le content script ne fait que modifier des données sans effet visible — teste via le worker en arrière-plan ou le storage.

**TypeScript**
```typescript
import { test, expect } from './extension-fixture';

test('content script injects price comparison widget', async ({ context }) => {
  const page = await context.newPage();
  await page.goto('https://example-shop.com/product/123');

  // Wait for the content script to inject its UI
  // The extension adds a shadow DOM element — Playwright pierces it automatically
  await expect(page.getByTestId('price-compare-widget')).toBeVisible({ timeout: 10000 });
  await expect(page.getByText('Best price: $29.99')).toBeVisible();
});

test('content script highlights search terms', async ({ context }) => {
  const page = await context.newPage();
  await page.goto('https://example.com/article');

  // Verify the content script added highlight spans
  const highlights = page.locator('.ext-highlight');
  await expect(highlights).toHaveCount(5);
  await expect(highlights.first()).toHaveCSS('background-color', 'rgb(255, 255, 0)');
});
```

**JavaScript**
```javascript
const { test, expect } = require('./extension-fixture');

test('content script injects price comparison widget', async ({ context }) => {
  const page = await context.newPage();
  await page.goto('https://example-shop.com/product/123');

  await expect(page.getByTestId('price-compare-widget')).toBeVisible({ timeout: 10000 });
  await expect(page.getByText('Best price: $29.99')).toBeVisible();
});
```

### Tester les service workers en arrière-plan

**À utiliser quand** : ton extension utilise des service workers Manifest V3 pour le traitement en arrière-plan, les alarmes ou l'échange de messages.
**À éviter quand** : la logique en arrière-plan est simple et déjà couverte par les tests du popup ou du content script.

**TypeScript**
```typescript
import { test, expect } from './extension-fixture';

test('background worker processes messages correctly', async ({ context, extensionId }) => {
  const page = await context.newPage();
  await page.goto(`chrome-extension://${extensionId}/popup.html`);

  // Trigger an action that sends a message to the background worker
  await page.getByRole('button', { name: 'Sync data' }).click();

  // Verify the response from the background worker updates the popup
  await expect(page.getByText('Last synced: just now')).toBeVisible();
});

test('service worker handles extension storage', async ({ context, extensionId }) => {
  const page = await context.newPage();
  await page.goto(`chrome-extension://${extensionId}/popup.html`);

  // Set a value through the popup
  await page.getByLabel('API Key').fill('test-key-123');
  await page.getByRole('button', { name: 'Save' }).click();

  // Reload popup and verify persistence through the service worker
  await page.reload();
  await expect(page.getByLabel('API Key')).toHaveValue('test-key-123');
});
```

**JavaScript**
```javascript
const { test, expect } = require('./extension-fixture');

test('background worker processes messages correctly', async ({ context, extensionId }) => {
  const page = await context.newPage();
  await page.goto(`chrome-extension://${extensionId}/popup.html`);

  await page.getByRole('button', { name: 'Sync data' }).click();
  await expect(page.getByText('Last synced: just now')).toBeVisible();
});
```

### Tester la page d'options de l'extension

**À utiliser quand** : ton extension a une page d'options/paramètres dédiée.
**À éviter quand** : les paramètres sont entièrement couverts par les tests du popup.

**TypeScript**
```typescript
import { test, expect } from './extension-fixture';

test('options page saves preferences', async ({ page, extensionId }) => {
  await page.goto(`chrome-extension://${extensionId}/options.html`);

  await page.getByRole('combobox', { name: 'Theme' }).selectOption('dark');
  await page.getByRole('checkbox', { name: 'Auto-update' }).check();
  await page.getByRole('button', { name: 'Save' }).click();

  await expect(page.getByText('Settings saved')).toBeVisible();

  // Verify persistence after reload
  await page.reload();
  await expect(page.getByRole('combobox', { name: 'Theme' })).toHaveValue('dark');
  await expect(page.getByRole('checkbox', { name: 'Auto-update' })).toBeChecked();
});
```

**JavaScript**
```javascript
const { test, expect } = require('./extension-fixture');

test('options page saves preferences', async ({ page, extensionId }) => {
  await page.goto(`chrome-extension://${extensionId}/options.html`);

  await page.getByRole('combobox', { name: 'Theme' }).selectOption('dark');
  await page.getByRole('checkbox', { name: 'Auto-update' }).check();
  await page.getByRole('button', { name: 'Save' }).click();

  await expect(page.getByText('Settings saved')).toBeVisible();

  await page.reload();
  await expect(page.getByRole('combobox', { name: 'Theme' })).toHaveValue('dark');
  await expect(page.getByRole('checkbox', { name: 'Auto-update' })).toBeChecked();
});
```

## Guide de décision

| Scénario | Approche | Pourquoi |
|---|---|---|
| Tester l'UI du popup | Naviguer vers `chrome-extension://<id>/popup.html` | Accès direct sans avoir à cliquer sur l'icône de l'extension |
| Tester les effets d'un content script | Charger une page réelle ou de test, asserter les éléments injectés | Les content scripts s'exécutent automatiquement sur les URLs correspondantes |
| Tester la logique en arrière-plan | La déclencher via le popup/content script, vérifier les effets de bord | Impossible d'appeler directement les fonctions du service worker depuis Playwright |
| Tester le storage de l'extension | Utiliser le popup pour définir des valeurs, recharger, vérifier la persistance | `chrome.storage` n'est accessible que depuis les pages de l'extension |
| Tester la page d'options | Naviguer vers `chrome-extension://<id>/options.html` | Même approche que pour le test du popup |
| Tester un comportement multi-pages | Ouvrir plusieurs pages dans le même contexte | Le contexte persistant partage l'état de l'extension entre les onglets |
| Exécuter en CI (headless) | `channel: 'chromium'` | Le mode headless du Chromium embarqué supporte les extensions |
| Tester avec plusieurs extensions | Ajouter plusieurs chemins à `--load-extension` | Séparer les chemins par des virgules dans la valeur du flag |

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| `browser.newContext()` pour des extensions | Les extensions nécessitent un contexte persistant | `chromium.launchPersistentContext()` |
| Headless par défaut sans `channel: 'chromium'` | Le headless shell par défaut ne charge pas les extensions | Définir `channel: 'chromium'` ou `headless: false` |
| Tester sur Firefox ou WebKit | Les extensions ne fonctionnent que dans Chromium | Ignorer les tests d'extension pour les projets non-Chromium |
| Cliquer sur l'icône de l'extension via des coordonnées | Fragile, la disposition de la barre d'outils varie | Naviguer directement vers `chrome-extension://<id>/popup.html` |
| Coder en dur l'ID de l'extension | Les IDs changent entre les builds et les machines | L'extraire dynamiquement de l'URL du service worker |
| Tester directement des fichiers `.crx` packagés | Plus difficile à déboguer, nécessite de les décompresser d'abord | Tester le répertoire source de l'extension non packagée |
| Partager le répertoire de données utilisateur du contexte persistant | L'état fuit entre les exécutions de tests | Utiliser une chaîne vide `''` pour un répertoire temporaire |
| Pas de timeout sur les assertions de content script | Les content scripts peuvent se charger après le chargement de la page | Utiliser `{ timeout: 10000 }` sur les assertions d'éléments de content script |

## Dépannage

| Symptôme | Cause probable | Correction |
|---|---|---|
| L'extension ne se charge pas | Mauvais chemin dans `--load-extension` | Utiliser `path.resolve()` pour obtenir le chemin absolu du répertoire de l'extension |
| `context.serviceWorkers()` renvoie un tableau vide | Le service worker n'est pas encore enregistré | Utiliser `context.waitForEvent('serviceworker')` avant d'extraire l'ID |
| La page du popup est vide | Le chemin du HTML du popup est incorrect | Vérifier `manifest.json` pour le bon chemin `default_popup` |
| Le content script ne s'injecte pas | L'URL de la page ne correspond pas à `matches` dans le manifest | Vérifier le motif d'URL dans `content_scripts[].matches` |
| L'extension fonctionne en local mais pas en CI | La CI exécute le headless shell ou un channel de marque | Utiliser `channel: 'chromium'` en CI |
| Les appels à `chrome.storage` échouent | Accès au storage depuis un contexte hors extension | Accéder au storage uniquement via les pages de l'extension (popup, options, background) |
| Conflit entre plusieurs extensions | Les deux extensions modifient les mêmes éléments de la page | Tester chaque extension dans son propre contexte persistant |
| Les tests sont lents à démarrer | Surcoût d'initialisation du contexte persistant | Réutiliser le contexte entre les tests d'un même fichier avec `test.describe` |

## Voir aussi

- [core/fixtures-and-hooks.md](fixtures-and-hooks.md) -- construire des fixtures personnalisées pour les contextes d'extension
- [core/service-workers-and-pwa.md](service-workers-and-pwa.md) -- patterns de test de service workers (hors extension)
- [core/iframes-and-shadow-dom.md](iframes-and-shadow-dom.md) -- les content scripts injectent souvent des éléments Shadow DOM
- [core/configuration.md](configuration.md) -- configuration de projet pour des suites de tests Chromium uniquement
- [ci/ci-github-actions.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/ci-github-actions.md) -- configuration de la CI pour les tests headed/d'extension
