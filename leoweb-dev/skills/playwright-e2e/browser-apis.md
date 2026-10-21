# API du navigateur

> **Quand l'utiliser** : Pour tester des fonctionnalités qui dépendent d'API natives du navigateur -- géolocalisation, permissions, presse-papiers, notifications, caméra/microphone, localStorage, sessionStorage, IndexedDB.
> **Prérequis** : [core/configuration.md](configuration.md), [core/fixtures-and-hooks.md](fixtures-and-hooks.md)

## Référence rapide

```typescript
// Geolocation — set via context options
const context = await browser.newContext({
  geolocation: { latitude: 40.7128, longitude: -74.0060 },
  permissions: ['geolocation'],
});

// Permissions — grant at context level
const context = await browser.newContext({
  permissions: ['clipboard-read', 'clipboard-write', 'notifications'],
});

// localStorage / sessionStorage — access via page.evaluate
await page.evaluate(() => localStorage.setItem('theme', 'dark'));
const value = await page.evaluate(() => localStorage.getItem('theme'));

// Clipboard — read/write in page context
await page.evaluate(() => navigator.clipboard.writeText('copied text'));
```

## Patterns

### Géolocalisation

**Quand l'utiliser** : Ton application utilise `navigator.geolocation` pour des cartes, des localisateurs de magasins, du suivi de livraison ou des fonctionnalités basées sur la position.
**À éviter quand** : Ton application ne lit jamais la position de l'utilisateur.

La géolocalisation se définit au niveau du contexte. Tu peux aussi la modifier en cours de test avec `context.setGeolocation()`.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('shows nearest store based on geolocation', async ({ browser }) => {
  const context = await browser.newContext({
    geolocation: { latitude: 40.7128, longitude: -74.0060 }, // New York
    permissions: ['geolocation'],
  });
  const page = await context.newPage();

  await page.goto('/store-locator');
  await page.getByRole('button', { name: 'Find nearby stores' }).click();

  await expect(page.getByText('Manhattan Store')).toBeVisible();
  await context.close();
});

test('update location mid-test for moving user', async ({ browser }) => {
  const context = await browser.newContext({
    geolocation: { latitude: 37.7749, longitude: -122.4194 }, // San Francisco
    permissions: ['geolocation'],
  });
  const page = await context.newPage();

  await page.goto('/delivery-tracker');
  await expect(page.getByTestId('current-city')).toHaveText('San Francisco');

  // Simulate user moving to a new location
  await context.setGeolocation({ latitude: 34.0522, longitude: -118.2437 }); // Los Angeles

  // Trigger location refresh
  await page.getByRole('button', { name: 'Update location' }).click();
  await expect(page.getByTestId('current-city')).toHaveText('Los Angeles');

  await context.close();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('shows nearest store based on geolocation', async ({ browser }) => {
  const context = await browser.newContext({
    geolocation: { latitude: 40.7128, longitude: -74.0060 },
    permissions: ['geolocation'],
  });
  const page = await context.newPage();

  await page.goto('/store-locator');
  await page.getByRole('button', { name: 'Find nearby stores' }).click();

  await expect(page.getByText('Manhattan Store')).toBeVisible();
  await context.close();
});

test('update location mid-test', async ({ browser }) => {
  const context = await browser.newContext({
    geolocation: { latitude: 37.7749, longitude: -122.4194 },
    permissions: ['geolocation'],
  });
  const page = await context.newPage();

  await page.goto('/delivery-tracker');
  await expect(page.getByTestId('current-city')).toHaveText('San Francisco');

  await context.setGeolocation({ latitude: 34.0522, longitude: -118.2437 });
  await page.getByRole('button', { name: 'Update location' }).click();
  await expect(page.getByTestId('current-city')).toHaveText('Los Angeles');

  await context.close();
});
```

Tu peux aussi définir la géolocalisation globalement dans `playwright.config` :

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  use: {
    geolocation: { latitude: 51.5074, longitude: -0.1278 }, // London
    permissions: ['geolocation'],
  },
});
```

### Permissions

**Quand l'utiliser** : Ton application demande des permissions au navigateur -- notifications, caméra, microphone, géolocalisation, presse-papiers.
**À éviter quand** : Ton application n'utilise pas l'API Permissions.

Accorde les permissions à la création du contexte. Playwright n'affiche pas de boîtes de dialogue de permission ; tu les accordes ou les refuses à l'avance.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('notification permission granted shows notification UI', async ({ browser }) => {
  const context = await browser.newContext({
    permissions: ['notifications'],
  });
  const page = await context.newPage();

  await page.goto('/settings/notifications');

  // App checks Notification.permission and shows the toggle
  await expect(page.getByRole('switch', { name: 'Enable notifications' })).toBeEnabled();

  await context.close();
});

test('notification permission denied shows upgrade prompt', async ({ browser }) => {
  // No 'notifications' in permissions = denied
  const context = await browser.newContext({
    permissions: [],
  });
  const page = await context.newPage();

  await page.goto('/settings/notifications');

  await expect(page.getByText('Notifications are blocked')).toBeVisible();
  await context.close();
});

test('grant permissions mid-test', async ({ browser }) => {
  const context = await browser.newContext();
  const page = await context.newPage();
  await page.goto('/camera-app');

  // Initially no camera permission
  await expect(page.getByText('Camera access needed')).toBeVisible();

  // Grant permission dynamically
  await context.grantPermissions(['camera'], { origin: 'https://localhost:3000' });

  await page.getByRole('button', { name: 'Enable camera' }).click();
  await expect(page.getByTestId('camera-preview')).toBeVisible();

  // Revoke all permissions
  await context.clearPermissions();
  await context.close();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('notification permission granted shows notification UI', async ({ browser }) => {
  const context = await browser.newContext({
    permissions: ['notifications'],
  });
  const page = await context.newPage();

  await page.goto('/settings/notifications');
  await expect(page.getByRole('switch', { name: 'Enable notifications' })).toBeEnabled();
  await context.close();
});

test('grant permissions mid-test', async ({ browser }) => {
  const context = await browser.newContext();
  const page = await context.newPage();
  await page.goto('/camera-app');

  await context.grantPermissions(['camera'], { origin: 'https://localhost:3000' });
  await page.getByRole('button', { name: 'Enable camera' }).click();
  await expect(page.getByTestId('camera-preview')).toBeVisible();

  await context.clearPermissions();
  await context.close();
});
```

### API Clipboard

**Quand l'utiliser** : Tester les fonctions de copier/coller, les boutons « Copier dans le presse-papiers » ou les fonctionnalités de collage depuis le presse-papiers.
**À éviter quand** : Ton application n'interagit pas avec le presse-papiers.

Depuis Playwright 1.62, le presse-papiers est isolé du système d'exploitation en mode headless : les tests en parallèle ne lisent donc plus et n'écrasent plus le presse-papiers de la machine.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('copy button puts text on clipboard', async ({ browser }) => {
  const context = await browser.newContext({
    permissions: ['clipboard-read', 'clipboard-write'],
  });
  const page = await context.newPage();

  await page.goto('/share');
  await page.getByRole('button', { name: 'Copy link' }).click();

  // Read clipboard content
  const clipboardText = await page.evaluate(() => navigator.clipboard.readText());
  expect(clipboardText).toContain('https://example.com/share/');

  await context.close();
});

test('paste from clipboard into editor', async ({ browser }) => {
  const context = await browser.newContext({
    permissions: ['clipboard-read', 'clipboard-write'],
  });
  const page = await context.newPage();

  await page.goto('/editor');

  // Write to clipboard programmatically
  await page.evaluate(() => navigator.clipboard.writeText('Pasted content from clipboard'));

  // Focus the editor and trigger paste
  const editor = page.getByRole('textbox', { name: 'Editor' });
  await editor.focus();
  await page.keyboard.press('ControlOrMeta+v');

  await expect(editor).toContainText('Pasted content from clipboard');

  await context.close();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('copy button puts text on clipboard', async ({ browser }) => {
  const context = await browser.newContext({
    permissions: ['clipboard-read', 'clipboard-write'],
  });
  const page = await context.newPage();

  await page.goto('/share');
  await page.getByRole('button', { name: 'Copy link' }).click();

  const clipboardText = await page.evaluate(() => navigator.clipboard.readText());
  expect(clipboardText).toContain('https://example.com/share/');
  await context.close();
});
```

### Mock de la caméra et du microphone

**Quand l'utiliser** : Tester des appels vidéo, des scanners de QR code, de l'enregistrement vocal, ou toute fonctionnalité utilisant `getUserMedia`.
**À éviter quand** : Ton application n'utilise ni la caméra ni le microphone.

Chromium peut utiliser de faux périphériques média. Ce n'est pas disponible dans Firefox ni WebKit.

**TypeScript**
```typescript
import { test, expect, chromium } from '@playwright/test';

test('video call shows local preview with fake camera', async () => {
  // Launch Chromium with fake media streams
  const browser = await chromium.launch({
    args: [
      '--use-fake-device-for-media-stream',
      '--use-fake-ui-for-media-stream',
    ],
  });

  const context = await browser.newContext({
    permissions: ['camera', 'microphone'],
  });
  const page = await context.newPage();

  await page.goto('/video-call');
  await page.getByRole('button', { name: 'Start camera' }).click();

  // Verify the video element is playing
  const isPlaying = await page.evaluate(() => {
    const video = document.querySelector('video#local-preview') as HTMLVideoElement;
    return video && !video.paused && video.readyState >= 2;
  });
  expect(isPlaying).toBe(true);

  await context.close();
  await browser.close();
});
```

**JavaScript**
```javascript
const { test, expect, chromium } = require('@playwright/test');

test('video call shows local preview with fake camera', async () => {
  const browser = await chromium.launch({
    args: [
      '--use-fake-device-for-media-stream',
      '--use-fake-ui-for-media-stream',
    ],
  });

  const context = await browser.newContext({
    permissions: ['camera', 'microphone'],
  });
  const page = await context.newPage();

  await page.goto('/video-call');
  await page.getByRole('button', { name: 'Start camera' }).click();

  const isPlaying = await page.evaluate(() => {
    const video = document.querySelector('video#local-preview');
    return video && !video.paused && video.readyState >= 2;
  });
  expect(isPlaying).toBe(true);

  await context.close();
  await browser.close();
});
```

### localStorage et sessionStorage

**Quand l'utiliser** : Ton application persiste de l'état, des tokens, des préférences ou des feature flags dans le web storage.
**À éviter quand** : Tu peux définir l'état via l'UI ou l'API à la place. Privilégie ces approches pour plus de réalisme.

Playwright 1.61 ajoute une API Web Storage de premier plan — `page.localStorage` et `page.sessionStorage` — avec `getItem`, `setItem`, `removeItem`, `clear` et `items()`. Préfère-la à `page.evaluate()` : pas de code de sérialisation superflu. Elle opère sur l'origine de la page courante, donc navigue d'abord.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('app loads dark theme from localStorage preference', async ({ page }) => {
  // Set localStorage before the app reads it (Playwright 1.61+)
  await page.goto('/');
  await page.localStorage.setItem('theme', 'dark');

  // Reload to pick up the stored preference
  await page.reload();

  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
});

test('clear localStorage between scenarios', async ({ page }) => {
  await page.goto('/');

  // Seed some data
  await page.localStorage.setItem('cart', JSON.stringify([{ id: 1, qty: 2 }]));
  await page.localStorage.setItem('user_prefs', JSON.stringify({ currency: 'EUR' }));

  // Read and verify
  const cart = JSON.parse((await page.localStorage.getItem('cart')) ?? '[]');
  expect(cart).toHaveLength(1);

  // List everything stored
  const all = await page.localStorage.items();

  // Clear specific keys
  await page.localStorage.removeItem('cart');

  // Or clear everything
  await page.localStorage.clear();
});

test('sessionStorage survives navigations within the session', async ({ page }) => {
  await page.goto('/step-1');
  await page.sessionStorage.setItem('wizard_step', '1');

  await page.goto('/step-2');
  expect(await page.sessionStorage.getItem('wizard_step')).toBe('1');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('app loads dark theme from localStorage preference', async ({ page }) => {
  await page.goto('/');
  await page.localStorage.setItem('theme', 'dark');
  await page.reload();

  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
});

test('sessionStorage survives navigations within the session', async ({ page }) => {
  await page.goto('/step-1');
  await page.sessionStorage.setItem('wizard_step', '1');

  await page.goto('/step-2');
  expect(await page.sessionStorage.getItem('wizard_step')).toBe('1');
});
```

**Sur Playwright < 1.61**, replie-toi sur `page.evaluate()` :

```typescript
await page.evaluate(() => localStorage.setItem('theme', 'dark'));
const step = await page.evaluate(() => sessionStorage.getItem('wizard_step'));
```

### Tester IndexedDB

**Quand l'utiliser** : Ton application utilise IndexedDB pour le stockage hors ligne, le cache ou de grands jeux de données (progressive web apps, applications offline-first).
**À éviter quand** : Ton application n'utilise que localStorage ou un stockage côté serveur.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('offline-first app stores data in IndexedDB', async ({ page }) => {
  await page.goto('/notes');

  // Create a note through the UI
  await page.getByRole('button', { name: 'New note' }).click();
  await page.getByRole('textbox', { name: 'Title' }).fill('Test Note');
  await page.getByRole('textbox', { name: 'Content' }).fill('This is stored in IndexedDB');
  await page.getByRole('button', { name: 'Save' }).click();

  // Verify it is stored in IndexedDB
  const storedNotes = await page.evaluate(() => {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open('NotesDB', 1);
      request.onsuccess = () => {
        const db = request.result;
        const tx = db.transaction('notes', 'readonly');
        const store = tx.objectStore('notes');
        const getAll = store.getAll();
        getAll.onsuccess = () => resolve(getAll.result);
        getAll.onerror = () => reject(getAll.error);
      };
      request.onerror = () => reject(request.error);
    });
  });

  expect(storedNotes).toHaveLength(1);
  expect(storedNotes[0]).toMatchObject({
    title: 'Test Note',
    content: 'This is stored in IndexedDB',
  });
});

test('clear IndexedDB for a clean test state', async ({ page }) => {
  await page.goto('/');

  // Delete the entire database
  await page.evaluate(() => {
    return new Promise((resolve, reject) => {
      const request = indexedDB.deleteDatabase('NotesDB');
      request.onsuccess = () => resolve(undefined);
      request.onerror = () => reject(request.error);
    });
  });

  await page.reload();
  await expect(page.getByText('No notes yet')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('offline-first app stores data in IndexedDB', async ({ page }) => {
  await page.goto('/notes');

  await page.getByRole('button', { name: 'New note' }).click();
  await page.getByRole('textbox', { name: 'Title' }).fill('Test Note');
  await page.getByRole('textbox', { name: 'Content' }).fill('This is stored in IndexedDB');
  await page.getByRole('button', { name: 'Save' }).click();

  const storedNotes = await page.evaluate(() => {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open('NotesDB', 1);
      request.onsuccess = () => {
        const db = request.result;
        const tx = db.transaction('notes', 'readonly');
        const store = tx.objectStore('notes');
        const getAll = store.getAll();
        getAll.onsuccess = () => resolve(getAll.result);
        getAll.onerror = () => reject(getAll.error);
      };
      request.onerror = () => reject(request.error);
    });
  });

  expect(storedNotes).toHaveLength(1);
  expect(storedNotes[0]).toMatchObject({
    title: 'Test Note',
    content: 'This is stored in IndexedDB',
  });
});
```

### Notifications

**Quand l'utiliser** : Ton application utilise l'API Notification du navigateur pour afficher des notifications de bureau.
**À éviter quand** : Les notifications sont purement côté serveur (push sans API Notification).

Playwright ne peut pas capturer la véritable notification système. À la place, mocke le constructeur Notification et vérifie que l'application l'appelle correctement.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('app triggers a browser notification on new message', async ({ browser }) => {
  const context = await browser.newContext({
    permissions: ['notifications'],
  });
  const page = await context.newPage();

  // Intercept Notification constructor to capture calls
  await page.evaluate(() => {
    (window as any).__notifications = [];
    const OriginalNotification = window.Notification;
    (window as any).Notification = class MockNotification {
      constructor(title: string, options?: NotificationOptions) {
        (window as any).__notifications.push({ title, ...options });
      }
      static get permission() { return 'granted'; }
      static requestPermission() { return Promise.resolve('granted' as NotificationPermission); }
    };
  });

  await page.goto('/chat');

  // Simulate receiving a message that triggers a notification
  await page.evaluate(() => {
    window.dispatchEvent(new CustomEvent('new-message', {
      detail: { from: 'Alice', text: 'Hey there!' },
    }));
  });

  // Check the notification was created with correct content
  const notifications = await page.evaluate(() => (window as any).__notifications);
  expect(notifications).toHaveLength(1);
  expect(notifications[0].title).toBe('New message from Alice');
  expect(notifications[0].body).toBe('Hey there!');

  await context.close();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('app triggers a browser notification on new message', async ({ browser }) => {
  const context = await browser.newContext({
    permissions: ['notifications'],
  });
  const page = await context.newPage();

  await page.evaluate(() => {
    window.__notifications = [];
    window.Notification = class MockNotification {
      constructor(title, options) {
        window.__notifications.push({ title, ...options });
      }
      static get permission() { return 'granted'; }
      static requestPermission() { return Promise.resolve('granted'); }
    };
  });

  await page.goto('/chat');

  await page.evaluate(() => {
    window.dispatchEvent(new CustomEvent('new-message', {
      detail: { from: 'Alice', text: 'Hey there!' },
    }));
  });

  const notifications = await page.evaluate(() => window.__notifications);
  expect(notifications).toHaveLength(1);
  expect(notifications[0].title).toBe('New message from Alice');
  await context.close();
});
```

### Conserver le comportement d'un vrai navigateur à l'attachement (`connectOverCDP({ noDefaults })`, Playwright 1.60+)

**Quand l'utiliser** : Tu t'attaches à un navigateur existant, appartenant à l'utilisateur, via CDP et tu veux qu'il se comporte exactement comme l'utilisateur l'a laissé -- sinon Playwright écrase les réglages par défaut du contexte pour les téléchargements, le focus et l'émulation des médias.
**À éviter quand** : Tu as lancé le navigateur pour les tests. Les réglages par défaut apportent des téléchargements déterministes et une émulation du focus/des médias, ce que les tests veulent généralement.

Playwright 1.60 ajoute `noDefaults` à `browserType.connectOverCDP()` pour désactiver ces surcharges du contexte par défaut :

```typescript
import { chromium } from 'playwright';

test('drive a real browser without changing its focus/media behavior', async () => {
  const browser = await chromium.connectOverCDP('http://localhost:9222', {
    noDefaults: true, // don't override download/focus/media emulation
  });

  const context = browser.contexts()[0];
  const page = context.pages()[0] ?? (await context.newPage());
  await page.goto('https://example.com');

  await browser.close(); // detaches without closing the user's browser
});
```

Voir [playwright-cli/session-management.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/playwright-cli/session-management.md#attaching-to-a-real-browser-without-overrides-connectovercdp-nodefaults--playwright-160) pour le workflow d'attachement via CLI/agent.

## Guide de décision

| API du navigateur | Comment la tester | Configuration clé |
|---|---|---|
| Géolocalisation | Option de contexte `geolocation` + `permissions: ['geolocation']` | `context.setGeolocation()` pour les changements en cours de test |
| Permissions (toutes) | Tableau `permissions` dans les options de contexte | `context.grantPermissions()` / `context.clearPermissions()` |
| Presse-papiers | Accorder `clipboard-read`/`clipboard-write` + `page.evaluate(navigator.clipboard...)` | Nécessite un contexte sécurisé (HTTPS ou localhost) |
| Notifications | Mocker le constructeur `Notification` via `page.evaluate` | Accorder la permission `notifications` ; capturer les appels au constructeur |
| Caméra / Microphone | Argument de lancement Chromium `--use-fake-device-for-media-stream` | Fonctionne uniquement dans Chromium ; accorder les permissions `camera`/`microphone` |
| localStorage | `page.evaluate(() => localStorage.getItem/setItem(...))` | À définir avant la navigation ou avec un rechargement pour prendre effet |
| sessionStorage | `page.evaluate(() => sessionStorage.getItem/setItem(...))` | Limité à la session de navigation ; vidé à la fermeture du contexte |
| IndexedDB | `page.evaluate` avec `indexedDB.open()` | Encapsuler dans des Promises pour les opérations asynchrones |

## Anti-patterns

| À ne pas faire | Problème | À faire plutôt |
|---|---|---|
| Définir `geolocation` sans accorder la permission | `getCurrentPosition` renvoie une erreur de permission | Associe toujours `geolocation` à `permissions: ['geolocation']` |
| Tester le presse-papiers sans contexte sécurisé | `navigator.clipboard` lève une erreur dans les contextes non HTTPS | Utilise `localhost` ou configure HTTPS dans ton serveur de test |
| Accéder à localStorage avant de naviguer vers l'origine | `page.evaluate` s'exécute d'abord dans le contexte `about:blank` | Fais d'abord `page.goto('/')`, puis définis localStorage, puis recharge |
| Stocker directement des tokens de test dans localStorage | Contourne le parcours d'authentification ; peut masquer de vrais bugs de login | Utilise `storageState` ou de vrais fixtures d'authentification |
| Compter sur l'état IndexedDB d'un test précédent | Les tests doivent être indépendants | Vide ou supprime la base dans le setup du test |
| Ne pas nettoyer les mocks injectés (Notification, etc.) | Le mock fuit dans les tests suivants s'ils partagent le même contexte | Chaque test reçoit un contexte neuf par défaut ; ne concerne que les contextes partagés |

## Dépannage

| Symptôme | Cause | Solution |
|---|---|---|
| `geolocation` renvoie `undefined` dans l'application | Permission non accordée | Ajoute `permissions: ['geolocation']` aux options du contexte |
| `readText()` du presse-papiers lève une `DOMException` | Permissions du presse-papiers manquantes ou contexte non sécurisé | Accorde `clipboard-read` ; assure-toi d'utiliser HTTPS ou localhost |
| `localStorage.getItem()` renvoie `null` après `setItem` | Le set a été fait sur une autre origine ou avant la navigation | Vérifie que tu as navigué vers la bonne origine avant d'appeler `setItem` |
| La caméra ne fonctionne pas dans Firefox/WebKit | Les faux périphériques média n'existent que dans Chromium | Ignore les tests de caméra sur les navigateurs non-Chromium ou mocke `getUserMedia` via `page.evaluate` |
| `evaluate` sur IndexedDB renvoie `undefined` | La Promise n'a pas été retournée | Assure-toi que le callback de `page.evaluate` retourne `new Promise(...)` |
| Le changement de permissions n'est pas pris en compte | L'application met en cache l'état des permissions au chargement | Recharge la page après `grantPermissions()` ou `clearPermissions()` |

## Voir aussi

- [core/configuration.md](configuration.md) -- géolocalisation/permissions globales dans la config
- [core/service-workers-and-pwa.md](service-workers-and-pwa.md) -- tests hors ligne et de cache avec IndexedDB et les service workers
- [core/fixtures-and-hooks.md](fixtures-and-hooks.md) -- encapsuler la configuration des API du navigateur dans des fixtures réutilisables
- [core/debugging.md](debugging.md) -- inspecter le storage et les permissions dans les traces Playwright
