# Tests Electron

> **Quand l'utiliser** : quand ton application est une app de bureau Electron et que tu as besoin de tests end-to-end couvrant le processus renderer, le processus main, la communication IPC, les dialogues natifs, la system tray et les workflows multi-fenêtres.
> **Prérequis** : [core/configuration.md](configuration.md), [core/fixtures-and-hooks.md](fixtures-and-hooks.md)

## Référence rapide

```typescript
import { _electron as electron } from 'playwright';

// Launch the Electron app
const app = await electron.launch({ args: ['./main.js'] });

// Get the first window (renderer process)
const window = await app.firstWindow();

// Access the main process for evaluation
const appPath = await app.evaluate(async ({ app }) => {
  return app.getPath('userData');
});

// Close the app
await app.close();
```

## Patterns

### Mise en place basique d'une app Electron

**À utiliser quand** : tu commences à tester une app Electron avec Playwright pour la première fois.
**À éviter quand** : ton application est une web app, pas une app Electron.

**TypeScript**
```typescript
import { test, expect, _electron as electron, ElectronApplication, Page } from '@playwright/test';

let app: ElectronApplication;
let window: Page;

test.beforeAll(async () => {
  // Launch the Electron app from your project directory
  app = await electron.launch({
    args: ['./dist/main.js'],
    env: {
      ...process.env,
      NODE_ENV: 'test',
    },
  });

  // Wait for the first BrowserWindow to open
  window = await app.firstWindow();

  // Optional: wait for the app to be fully loaded
  await window.waitForLoadState('domcontentloaded');
});

test.afterAll(async () => {
  await app.close();
});

test('app window has correct title', async () => {
  const title = await window.title();
  expect(title).toBe('My Electron App');
});

test('main page renders', async () => {
  await expect(window.getByRole('heading', { name: 'Welcome' })).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect, _electron: electron } = require('@playwright/test');

let app;
let window;

test.beforeAll(async () => {
  app = await electron.launch({
    args: ['./dist/main.js'],
    env: {
      ...process.env,
      NODE_ENV: 'test',
    },
  });
  window = await app.firstWindow();
  await window.waitForLoadState('domcontentloaded');
});

test.afterAll(async () => {
  await app.close();
});

test('app window has correct title', async () => {
  const title = await window.title();
  expect(title).toBe('My Electron App');
});

test('main page renders', async () => {
  await expect(window.getByRole('heading', { name: 'Welcome' })).toBeVisible();
});
```

### Fixture d'app Electron (recommandé)

**À utiliser quand** : tu veux des instances d'app Electron isolées et réutilisables entre les fichiers de test.
**À éviter quand** : tous les tests peuvent partager une seule instance d'app (rare en pratique).

**TypeScript**
```typescript
// fixtures.ts
import { test as base, expect, _electron as electron, ElectronApplication, Page } from '@playwright/test';

type ElectronFixtures = {
  electronApp: ElectronApplication;
  window: Page;
};

export const test = base.extend<ElectronFixtures>({
  electronApp: async ({}, use) => {
    const app = await electron.launch({
      args: ['./dist/main.js'],
      env: { ...process.env, NODE_ENV: 'test' },
    });
    await use(app);
    await app.close();
  },

  window: async ({ electronApp }, use) => {
    const window = await electronApp.firstWindow();
    await window.waitForLoadState('domcontentloaded');
    await use(window);
  },
});

export { expect };
```

```typescript
// app.spec.ts
import { test, expect } from './fixtures';

test('navigate to settings', async ({ window }) => {
  await window.getByRole('link', { name: 'Settings' }).click();
  await expect(window.getByRole('heading', { name: 'Settings' })).toBeVisible();
});
```

**JavaScript**
```javascript
// fixtures.js
const { test: base, expect, _electron: electron } = require('@playwright/test');

const test = base.extend({
  electronApp: async ({}, use) => {
    const app = await electron.launch({
      args: ['./dist/main.js'],
      env: { ...process.env, NODE_ENV: 'test' },
    });
    await use(app);
    await app.close();
  },

  window: async ({ electronApp }, use) => {
    const window = await electronApp.firstWindow();
    await window.waitForLoadState('domcontentloaded');
    await use(window);
  },
});

module.exports = { test, expect };
```

### Accéder au processus main

**À utiliser quand** : tu dois lire l'état de l'app Electron, vérifier des chemins, obtenir la version de l'app ou vérifier le comportement du processus main.
**À éviter quand** : tout ce dont tu as besoin se trouve dans le renderer (UI). Privilégie le test via l'UI.

`app.evaluate()` exécute du code dans le processus main avec accès à toutes les API Electron.

**TypeScript**
```typescript
import { test, expect } from './fixtures';

test('verify app version and paths', async ({ electronApp }) => {
  // Evaluate in the main process — receives the Electron module
  const appInfo = await electronApp.evaluate(async ({ app }) => {
    return {
      version: app.getVersion(),
      name: app.getName(),
      userData: app.getPath('userData'),
      locale: app.getLocale(),
      isPackaged: app.isPackaged,
    };
  });

  expect(appInfo.version).toMatch(/^\d+\.\d+\.\d+$/);
  expect(appInfo.name).toBe('my-electron-app');
  expect(appInfo.userData).toBeTruthy();
  expect(appInfo.isPackaged).toBe(false); // false during development
});

test('main process environment variables are set', async ({ electronApp }) => {
  const nodeEnv = await electronApp.evaluate(async () => {
    return process.env.NODE_ENV;
  });

  expect(nodeEnv).toBe('test');
});
```

**JavaScript**
```javascript
const { test, expect } = require('./fixtures');

test('verify app version and paths', async ({ electronApp }) => {
  const appInfo = await electronApp.evaluate(async ({ app }) => {
    return {
      version: app.getVersion(),
      name: app.getName(),
      userData: app.getPath('userData'),
      isPackaged: app.isPackaged,
    };
  });

  expect(appInfo.version).toMatch(/^\d+\.\d+\.\d+$/);
  expect(appInfo.name).toBe('my-electron-app');
});
```

### Tester la communication IPC

**À utiliser quand** : ton app utilise `ipcMain` / `ipcRenderer` pour la communication entre les processus main et renderer.
**À éviter quand** : l'IPC est un détail d'implémentation et le comportement est entièrement testable via l'UI.

**TypeScript**
```typescript
import { test, expect } from './fixtures';

test('renderer sends IPC message and gets response', async ({ electronApp, window }) => {
  // Trigger an IPC call from the renderer
  const result = await window.evaluate(async () => {
    // Assumes your preload script exposes ipcRenderer via contextBridge
    return await (window as any).electronAPI.getSystemInfo();
  });

  expect(result).toHaveProperty('platform');
  expect(result).toHaveProperty('arch');
  expect(result.platform).toBeTruthy();
});

test('main process handles IPC file-read request', async ({ electronApp, window }) => {
  // Set up a listener in the main process first
  await electronApp.evaluate(async ({ ipcMain }) => {
    ipcMain.handle('test-ping', async () => {
      return { pong: true, timestamp: Date.now() };
    });
  });

  // Send from renderer
  const response = await window.evaluate(async () => {
    return await (window as any).electronAPI.invoke('test-ping');
  });

  expect(response.pong).toBe(true);
  expect(response.timestamp).toBeGreaterThan(0);
});

test('IPC event triggers UI update', async ({ window }) => {
  // Simulate the main process sending an event to the renderer
  await window.evaluate(() => {
    // Trigger a custom event that the app listens for
    window.dispatchEvent(new CustomEvent('app:notification', {
      detail: { message: 'Update available', version: '2.0.0' },
    }));
  });

  await expect(window.getByText('Update available')).toBeVisible();
  await expect(window.getByText('Version 2.0.0')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('./fixtures');

test('renderer sends IPC message and gets response', async ({ electronApp, window }) => {
  const result = await window.evaluate(async () => {
    return await window.electronAPI.getSystemInfo();
  });

  expect(result).toHaveProperty('platform');
  expect(result).toHaveProperty('arch');
});

test('IPC event triggers UI update', async ({ window }) => {
  await window.evaluate(() => {
    window.dispatchEvent(new CustomEvent('app:notification', {
      detail: { message: 'Update available', version: '2.0.0' },
    }));
  });

  await expect(window.getByText('Update available')).toBeVisible();
});
```

### Dialogues du système de fichiers

**À utiliser quand** : ton app utilise `dialog.showOpenDialog`, `dialog.showSaveDialog` d'Electron ou des dialogues de fichiers natifs similaires.
**À éviter quand** : la sélection de fichier est gérée par un input web (`<input type="file">`). Utilise pour cela le file chooser standard de Playwright.

Les dialogues natifs ne peuvent pas être manipulés directement. Mocke-les dans le processus main.

**TypeScript**
```typescript
import { test, expect } from './fixtures';

test('open file dialog and load a document', async ({ electronApp, window }) => {
  // Mock the dialog to return a specific file path
  await electronApp.evaluate(async ({ dialog }) => {
    dialog.showOpenDialog = async () => ({
      canceled: false,
      filePaths: ['/tmp/test-document.txt'],
    });
  });

  // Click the "Open File" button in the renderer
  await window.getByRole('button', { name: 'Open File' }).click();

  // Verify the app loaded the file
  await expect(window.getByTestId('file-name')).toHaveText('test-document.txt');
});

test('save file dialog returns selected path', async ({ electronApp, window }) => {
  await electronApp.evaluate(async ({ dialog }) => {
    dialog.showSaveDialog = async () => ({
      canceled: false,
      filePath: '/tmp/exported-report.pdf',
    });
  });

  await window.getByRole('button', { name: 'Export PDF' }).click();
  await expect(window.getByText('Saved to /tmp/exported-report.pdf')).toBeVisible();
});

test('handle canceled file dialog', async ({ electronApp, window }) => {
  await electronApp.evaluate(async ({ dialog }) => {
    dialog.showOpenDialog = async () => ({
      canceled: true,
      filePaths: [],
    });
  });

  await window.getByRole('button', { name: 'Open File' }).click();

  // App should not crash or change state
  await expect(window.getByTestId('file-name')).toHaveText('No file selected');
});
```

**JavaScript**
```javascript
const { test, expect } = require('./fixtures');

test('open file dialog and load a document', async ({ electronApp, window }) => {
  await electronApp.evaluate(async ({ dialog }) => {
    dialog.showOpenDialog = async () => ({
      canceled: false,
      filePaths: ['/tmp/test-document.txt'],
    });
  });

  await window.getByRole('button', { name: 'Open File' }).click();
  await expect(window.getByTestId('file-name')).toHaveText('test-document.txt');
});

test('handle canceled file dialog', async ({ electronApp, window }) => {
  await electronApp.evaluate(async ({ dialog }) => {
    dialog.showOpenDialog = async () => ({
      canceled: true,
      filePaths: [],
    });
  });

  await window.getByRole('button', { name: 'Open File' }).click();
  await expect(window.getByTestId('file-name')).toHaveText('No file selected');
});
```

### Tester la system tray

**À utiliser quand** : ton app a une icône dans la system tray avec des menus contextuels ou des indicateurs d'état.
**À éviter quand** : ton app n'a aucune fonctionnalité de tray.

Playwright ne peut pas cliquer directement sur les icônes de la system tray. Teste la logique de la tray en évaluant du code dans le processus main.

**TypeScript**
```typescript
import { test, expect } from './fixtures';

test('tray icon is created on app launch', async ({ electronApp }) => {
  const hasTray = await electronApp.evaluate(async ({ BrowserWindow }) => {
    // Access the tray via a reference your app stores
    const { tray } = require('./tray-manager');
    return tray !== null && !tray.isDestroyed();
  });

  expect(hasTray).toBe(true);
});

test('tray tooltip shows unread count', async ({ electronApp }) => {
  const tooltip = await electronApp.evaluate(async () => {
    const { tray } = require('./tray-manager');
    return tray.getToolTip();
  });

  expect(tooltip).toMatch(/\d+ unread messages?/);
});

test('clicking tray "Show" menu item opens the window', async ({ electronApp }) => {
  // Simulate clicking a tray menu item by invoking its callback
  await electronApp.evaluate(async ({ BrowserWindow }) => {
    const { trayMenu } = require('./tray-manager');
    // Find the "Show" menu item and invoke its click handler
    const showItem = trayMenu.items.find((item: any) => item.label === 'Show');
    if (showItem && showItem.click) {
      showItem.click();
    }
  });

  // The main window should now be visible
  const window = await electronApp.firstWindow();
  const isVisible = await window.evaluate(() => {
    return document.visibilityState === 'visible';
  });
  expect(isVisible).toBe(true);
});
```

**JavaScript**
```javascript
const { test, expect } = require('./fixtures');

test('tray icon is created on app launch', async ({ electronApp }) => {
  const hasTray = await electronApp.evaluate(async () => {
    const { tray } = require('./tray-manager');
    return tray !== null && !tray.isDestroyed();
  });

  expect(hasTray).toBe(true);
});
```

### Fenêtres multiples

**À utiliser quand** : ton app Electron ouvre plusieurs fenêtres (préférences, à propos, panneaux détachés).
**À éviter quand** : ton app utilise une seule fenêtre.

**TypeScript**
```typescript
import { test, expect } from './fixtures';

test('open and interact with preferences window', async ({ electronApp, window }) => {
  // Click the menu item or button that opens the preferences window
  await window.getByRole('menuitem', { name: 'Preferences' }).click();

  // Wait for the new window to appear
  const prefsWindow = await electronApp.waitForEvent('window');
  await prefsWindow.waitForLoadState('domcontentloaded');

  // Interact with the preferences window
  await prefsWindow.getByLabel('Theme').selectOption('dark');
  await prefsWindow.getByRole('button', { name: 'Save' }).click();

  // Verify the main window reflects the change
  await expect(window.locator('html')).toHaveAttribute('data-theme', 'dark');

  // Close the preferences window
  await prefsWindow.close();
});

test('get all open windows', async ({ electronApp, window }) => {
  // Open a second window
  await window.getByRole('button', { name: 'New Window' }).click();

  // Get all windows
  const allWindows = electronApp.windows();
  expect(allWindows.length).toBe(2);

  // Find the new window (not the main one)
  const newWindow = allWindows.find((w) => w !== window)!;
  await expect(newWindow.getByRole('heading')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('./fixtures');

test('open and interact with preferences window', async ({ electronApp, window }) => {
  await window.getByRole('menuitem', { name: 'Preferences' }).click();

  const prefsWindow = await electronApp.waitForEvent('window');
  await prefsWindow.waitForLoadState('domcontentloaded');

  await prefsWindow.getByLabel('Theme').selectOption('dark');
  await prefsWindow.getByRole('button', { name: 'Save' }).click();

  await expect(window.locator('html')).toHaveAttribute('data-theme', 'dark');
  await prefsWindow.close();
});
```

### Tester les apps packagées/buildées

**À utiliser quand** : tu veux tester le build de production de ton app Electron (après `electron-builder`, `electron-forge`, etc.).
**À éviter quand** : les tests en mode développement suffisent pour ton pipeline de CI.

**TypeScript**
```typescript
import { test, expect, _electron as electron } from '@playwright/test';
import path from 'path';

test('packaged app launches and works', async () => {
  // Path to the packaged app executable
  const appPath = process.platform === 'darwin'
    ? path.join(__dirname, '../dist/mac/MyApp.app/Contents/MacOS/MyApp')
    : process.platform === 'win32'
      ? path.join(__dirname, '../dist/win-unpacked/MyApp.exe')
      : path.join(__dirname, '../dist/linux-unpacked/my-app');

  const app = await electron.launch({
    executablePath: appPath,
  });

  const window = await app.firstWindow();
  await window.waitForLoadState('domcontentloaded');

  // Verify the packaged app works correctly
  const title = await window.title();
  expect(title).toBe('My Electron App');

  await expect(window.getByRole('heading', { name: 'Welcome' })).toBeVisible();

  // Verify it reports as packaged
  const isPackaged = await app.evaluate(async ({ app }) => app.isPackaged);
  expect(isPackaged).toBe(true);

  await app.close();
});
```

**JavaScript**
```javascript
const { test, expect, _electron: electron } = require('@playwright/test');
const path = require('path');

test('packaged app launches and works', async () => {
  const appPath = process.platform === 'darwin'
    ? path.join(__dirname, '../dist/mac/MyApp.app/Contents/MacOS/MyApp')
    : process.platform === 'win32'
      ? path.join(__dirname, '../dist/win-unpacked/MyApp.exe')
      : path.join(__dirname, '../dist/linux-unpacked/my-app');

  const app = await electron.launch({
    executablePath: appPath,
  });

  const window = await app.firstWindow();
  await window.waitForLoadState('domcontentloaded');

  const title = await window.title();
  expect(title).toBe('My Electron App');

  await expect(window.getByRole('heading', { name: 'Welcome' })).toBeVisible();
  await app.close();
});
```

## Guide de décision

| Scénario | Approche | Pourquoi |
|---|---|---|
| Lancer l'app Electron pour les tests | `_electron.launch({ args: ['./main.js'] })` | Support Electron intégré à Playwright |
| Obtenir la fenêtre principale | `app.firstWindow()` | Retourne la première `BrowserWindow` sous forme de `Page` Playwright |
| Lire l'état du processus main | `app.evaluate(({ app }) => ...)` | Exécute du code dans le processus main avec les API Electron |
| Tester les allers-retours IPC | `window.evaluate` (renderer) + `app.evaluate` (main) | Couvre les deux côtés du pont IPC |
| Mocker les dialogues de fichiers natifs | Surcharger `dialog.showOpenDialog` via `app.evaluate` | Les dialogues natifs ne peuvent pas être automatisés directement |
| Tester la system tray | `app.evaluate` pour invoquer les callbacks de la tray | Les icônes de tray sont natives à l'OS ; non cliquables via Playwright |
| Fenêtres multiples | `app.waitForEvent('window')` | Capture les nouvelles instances de `BrowserWindow` à leur ouverture |
| Tester les builds packagés | `electron.launch({ executablePath })` | Pointe vers le binaire buildé plutôt que vers les sources |

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| `const { app } = require('electron')` dans les fichiers de test | Les API Electron ne sont pas disponibles dans le processus Node de Playwright | Utilise `electronApp.evaluate(({ app }) => ...)` |
| Importer directement du code renderer dans les tests | Contourne le vrai cycle de vie de l'app et l'IPC | Teste via l'UI avec l'objet `window` (Page) |
| Sauter `waitForLoadState` après `firstWindow()` | La fenêtre peut ne pas être complètement rendue | Fais toujours `await window.waitForLoadState('domcontentloaded')` |
| Tester la tray en cliquant sur l'UI système | Playwright ne peut pas interagir avec le chrome natif de l'OS | Mocke les callbacks du menu de la tray via `app.evaluate` |
| Partager une seule `ElectronApplication` entre tous les tests sans nettoyage | L'état fuit d'un test à l'autre | Utilise des fixtures avec `app.close()` au teardown |
| Oublier de fermer l'app dans `afterAll` | Laisse des processus Electron actifs, qui consomment les ressources de la CI | Fais toujours `await app.close()` au teardown |

## Dépannage

| Symptôme | Cause | Correctif |
|---|---|---|
| `electron.launch()` lève « cannot find module » | Le chemin dans `args` ne pointe pas vers ton fichier d'entrée main | Vérifie le chemin : `args: ['./dist/main.js']` relatif au répertoire de travail |
| `firstWindow()` expire (timeout) | L'app n'ouvre pas de `BrowserWindow` à temps | Vérifie que l'app crée une fenêtre au démarrage ; augmente le timeout |
| `app.evaluate` ne peut pas accéder aux modules Electron | Mauvais paramètre déstructuré | Déstructure correctement : `evaluate(async ({ app, dialog, BrowserWindow }) => ...)` |
| Le mock du dialogue n'a aucun effet | Le mock a été appliqué après l'appel du dialogue | Mets les mocks en place avant de déclencher l'action UI qui ouvre le dialogue |
| La seconde fenêtre n'est pas capturée | `waitForEvent('window')` enregistré après l'ouverture de la fenêtre | Enregistre le listener d'événement avant de déclencher l'action qui ouvre la fenêtre |
| Les tests se bloquent après `app.close()` | Des processus enfants lancés par l'app tournent encore | Assure-toi que ton app Electron nettoie ses processus enfants à la fermeture |
| Le test de l'app packagée échoue avec une erreur de chemin | Le chemin de l'exécutable varie selon l'OS et l'outil de build | Utilise `process.platform` pour calculer le bon chemin |
| `window.evaluate` lève « context destroyed » | La fenêtre a été fermée ou a navigué pendant l'évaluation | Assure-toi que la fenêtre est stable avant d'évaluer |

## Voir aussi

- [core/fixtures-and-hooks.md](fixtures-and-hooks.md) -- encapsuler le lancement de l'app Electron dans des fixtures
- [core/assertions-and-waiting.md](assertions-and-waiting.md) -- toutes les assertions standard fonctionnent sur les fenêtres Electron
- [core/iframes-and-shadow-dom.md](iframes-and-shadow-dom.md) -- les apps Electron embarquent souvent des web components ou des iframes
- [core/browser-apis.md](browser-apis.md) -- localStorage, IndexedDB et les autres API fonctionnent de la même façon dans Electron
