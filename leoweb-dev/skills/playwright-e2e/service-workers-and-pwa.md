# Tests des service workers et des PWA

> **Quand l'utiliser** : quand ton application est une Progressive Web App (PWA) ou utilise des service workers pour le mode hors ligne, le cache, les notifications push ou la synchronisation en arrière-plan.
> **Prérequis** : [core/configuration.md](configuration.md), [core/assertions-and-waiting.md](assertions-and-waiting.md)

## Référence rapide

```typescript
// Service workers require a persistent context — use launchPersistentContext
const context = await chromium.launchPersistentContext(userDataDir, {
  baseURL: 'https://localhost:3000',
});

// Enable/disable offline mode
await context.setOffline(true);   // Go offline
await context.setOffline(false);  // Come back online

// Wait for service worker to register
const sw = await context.waitForEvent('serviceworker');
console.log('SW URL:', sw.url());
```

## Patterns

### Enregistrement du service worker

**À utiliser quand** : tu dois vérifier que ton service worker s'enregistre correctement, s'active et contrôle la page.
**À éviter quand** : ton application n'utilise pas de service workers.

Les service workers nécessitent un contexte de navigateur persistant, car ils sont liés à un profil. La fixture `page` par défaut utilise un contexte temporaire qui ne conserve pas de façon fiable les enregistrements de service workers entre les navigations.

**TypeScript**
```typescript
import { test as base, expect, chromium, BrowserContext } from '@playwright/test';
import path from 'path';
import fs from 'fs';

// Create a fixture with a persistent context for SW testing
const test = base.extend<{ swContext: BrowserContext }>({
  swContext: async ({}, use) => {
    const userDataDir = path.join(__dirname, '.tmp-profile');
    const context = await chromium.launchPersistentContext(userDataDir, {
      baseURL: 'https://localhost:3000',
    });
    await use(context);
    await context.close();
    fs.rmSync(userDataDir, { recursive: true, force: true });
  },
});

test('service worker registers and activates', async ({ swContext }) => {
  const page = await swContext.newPage();

  // Listen for the service worker event
  const swPromise = swContext.waitForEvent('serviceworker');

  await page.goto('/');

  const sw = await swPromise;
  expect(sw.url()).toContain('service-worker.js');

  // Verify the SW is controlling the page
  const isControlled = await page.evaluate(() => {
    return navigator.serviceWorker.controller !== null;
  });
  expect(isControlled).toBe(true);
});
```

**JavaScript**
```javascript
const { test: base, expect, chromium } = require('@playwright/test');
const path = require('path');
const fs = require('fs');

const test = base.extend({
  swContext: async ({}, use) => {
    const userDataDir = path.join(__dirname, '.tmp-profile');
    const context = await chromium.launchPersistentContext(userDataDir, {
      baseURL: 'https://localhost:3000',
    });
    await use(context);
    await context.close();
    fs.rmSync(userDataDir, { recursive: true, force: true });
  },
});

test('service worker registers and activates', async ({ swContext }) => {
  const page = await swContext.newPage();
  const swPromise = swContext.waitForEvent('serviceworker');

  await page.goto('/');

  const sw = await swPromise;
  expect(sw.url()).toContain('service-worker.js');

  const isControlled = await page.evaluate(() => {
    return navigator.serviceWorker.controller !== null;
  });
  expect(isControlled).toBe(true);
});
```

### Tests du mode hors ligne

**À utiliser quand** : ta PWA doit fonctionner hors ligne -- servir des pages en cache, afficher des indicateurs hors ligne, mettre des données en file d'attente pour la synchronisation.
**À éviter quand** : ton application n'a pas de prise en charge du mode hors ligne.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('app serves cached page when offline', async ({ swContext }) => {
  const page = await swContext.newPage();

  // First visit — caches the page and assets
  await page.goto('/');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  // Wait for the service worker to finish caching
  await page.evaluate(async () => {
    const registration = await navigator.serviceWorker.ready;
    // Wait for the SW to be in the 'activated' state
    return registration.active?.state === 'activated';
  });

  // Go offline
  await swContext.setOffline(true);

  // Reload — should serve from cache
  await page.reload();
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  // Verify offline indicator appears
  await expect(page.getByText('You are offline')).toBeVisible();

  // Come back online
  await swContext.setOffline(false);
  await expect(page.getByText('You are offline')).toBeHidden();
});

test('form submission queues when offline', async ({ swContext }) => {
  const page = await swContext.newPage();
  await page.goto('/feedback');

  // Ensure SW is active
  await page.evaluate(() => navigator.serviceWorker.ready);

  // Go offline
  await swContext.setOffline(true);

  // Submit a form while offline
  await page.getByLabel('Feedback').fill('Great product!');
  await page.getByRole('button', { name: 'Submit' }).click();

  // App should show a "queued" message, not an error
  await expect(page.getByText('Saved offline. Will sync when connected.')).toBeVisible();

  // Come back online — the queued data should sync
  await swContext.setOffline(false);
  await expect(page.getByText('Feedback submitted successfully')).toBeVisible({ timeout: 10000 });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('app serves cached page when offline', async ({ swContext }) => {
  const page = await swContext.newPage();

  await page.goto('/');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  await page.evaluate(async () => {
    const registration = await navigator.serviceWorker.ready;
    return registration.active?.state === 'activated';
  });

  await swContext.setOffline(true);
  await page.reload();
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  await expect(page.getByText('You are offline')).toBeVisible();

  await swContext.setOffline(false);
  await expect(page.getByText('You are offline')).toBeHidden();
});
```

### Vérification du cache

**À utiliser quand** : tu dois confirmer que certaines ressources sont bien mises en cache par le service worker.
**À éviter quand** : tu fais confiance à la stratégie de cache du framework et tu as seulement besoin de vérifier l'UX hors ligne (teste plutôt le mode hors ligne).

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('critical assets are cached by the service worker', async ({ swContext }) => {
  const page = await swContext.newPage();
  await page.goto('/');

  // Wait for SW to be ready
  await page.evaluate(() => navigator.serviceWorker.ready);

  // Check the cache contents
  const cachedUrls = await page.evaluate(async () => {
    const cacheNames = await caches.keys();
    const allUrls: string[] = [];
    for (const name of cacheNames) {
      const cache = await caches.open(name);
      const keys = await cache.keys();
      allUrls.push(...keys.map((req) => new URL(req.url).pathname));
    }
    return allUrls;
  });

  // Verify critical resources are cached
  expect(cachedUrls).toContain('/');
  expect(cachedUrls).toContain('/offline.html');
  expect(cachedUrls.some((url) => url.endsWith('.js'))).toBe(true);
  expect(cachedUrls.some((url) => url.endsWith('.css'))).toBe(true);
});

test('cache is invalidated after service worker update', async ({ swContext }) => {
  const page = await swContext.newPage();
  await page.goto('/');

  // Get initial cache version
  const initialCaches = await page.evaluate(() => caches.keys());

  // Simulate a new SW version by clearing and reloading
  await page.evaluate(async () => {
    const registration = await navigator.serviceWorker.getRegistration();
    await registration?.update();
  });

  // After update, old caches should be cleaned up
  await page.reload();
  await page.evaluate(() => navigator.serviceWorker.ready);

  const updatedCaches = await page.evaluate(() => caches.keys());

  // The app should manage cache names with versioning
  expect(updatedCaches.length).toBeGreaterThanOrEqual(1);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('critical assets are cached by the service worker', async ({ swContext }) => {
  const page = await swContext.newPage();
  await page.goto('/');
  await page.evaluate(() => navigator.serviceWorker.ready);

  const cachedUrls = await page.evaluate(async () => {
    const cacheNames = await caches.keys();
    const allUrls = [];
    for (const name of cacheNames) {
      const cache = await caches.open(name);
      const keys = await cache.keys();
      allUrls.push(...keys.map((req) => new URL(req.url).pathname));
    }
    return allUrls;
  });

  expect(cachedUrls).toContain('/');
  expect(cachedUrls).toContain('/offline.html');
});
```

### Invite d'installation de la PWA

**À utiliser quand** : tu dois tester le parcours « Ajouter à l'écran d'accueil » / d'installation de la PWA.
**À éviter quand** : ton application n'est pas une PWA ou ne gère pas l'événement `beforeinstallprompt`.

L'événement `beforeinstallprompt` ne peut pas être déclenché de façon synthétique par Playwright. Vérifie plutôt que ton application capture et gère correctement l'événement.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('app captures install prompt and shows install button', async ({ swContext }) => {
  const page = await swContext.newPage();

  // Mock the beforeinstallprompt event
  await page.addInitScript(() => {
    let deferredPrompt: Event | null = null;

    // Simulate the browser firing beforeinstallprompt
    window.addEventListener('load', () => {
      const event = new Event('beforeinstallprompt');
      (event as any).preventDefault = () => {};
      (event as any).prompt = () => Promise.resolve();
      (event as any).userChoice = Promise.resolve({ outcome: 'accepted' });

      window.dispatchEvent(event);
    });
  });

  await page.goto('/');

  // Your app should show an install button when it captures the prompt
  await expect(page.getByRole('button', { name: 'Install app' })).toBeVisible();
});

test('web app manifest is valid', async ({ swContext }) => {
  const page = await swContext.newPage();
  await page.goto('/');

  // Verify manifest link exists
  const manifestUrl = await page.evaluate(() => {
    const link = document.querySelector('link[rel="manifest"]') as HTMLLinkElement;
    return link?.href;
  });
  expect(manifestUrl).toBeTruthy();

  // Fetch and validate the manifest
  const response = await page.request.get(manifestUrl!);
  expect(response.ok()).toBe(true);

  const manifest = await response.json();
  expect(manifest.name).toBeTruthy();
  expect(manifest.icons).toHaveLength(expect.any(Number));
  expect(manifest.start_url).toBeTruthy();
  expect(manifest.display).toBe('standalone');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('app captures install prompt and shows install button', async ({ swContext }) => {
  const page = await swContext.newPage();

  await page.addInitScript(() => {
    window.addEventListener('load', () => {
      const event = new Event('beforeinstallprompt');
      event.preventDefault = () => {};
      event.prompt = () => Promise.resolve();
      event.userChoice = Promise.resolve({ outcome: 'accepted' });
      window.dispatchEvent(event);
    });
  });

  await page.goto('/');
  await expect(page.getByRole('button', { name: 'Install app' })).toBeVisible();
});
```

### Tests des notifications push

**À utiliser quand** : ta PWA utilise l'API Push pour recevoir des notifications push depuis un serveur.
**À éviter quand** : les notifications sont gérées entièrement côté client, sans l'API Push.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('push notification triggers UI update', async ({ swContext }) => {
  const page = await swContext.newPage();
  await page.goto('/');

  // Wait for SW to be ready
  const swURL = await page.evaluate(async () => {
    const reg = await navigator.serviceWorker.ready;
    return reg.active?.scriptURL;
  });
  expect(swURL).toBeTruthy();

  // Get the service worker and evaluate inside it
  const sw = swContext.serviceWorkers()[0];

  // Simulate a push event inside the service worker
  await sw.evaluate(async () => {
    const event = new PushEvent('push', {
      data: new TextEncoder().encode(JSON.stringify({
        title: 'New Message',
        body: 'You have a new message from Alice',
        url: '/messages',
      })),
    });
    // @ts-ignore — dispatchEvent works in SW context
    self.dispatchEvent(event);
  });

  // Verify the app reacts (e.g., shows a badge or notification banner)
  await expect(page.getByTestId('notification-badge')).toHaveText('1');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('push notification triggers UI update', async ({ swContext }) => {
  const page = await swContext.newPage();
  await page.goto('/');

  const swURL = await page.evaluate(async () => {
    const reg = await navigator.serviceWorker.ready;
    return reg.active?.scriptURL;
  });
  expect(swURL).toBeTruthy();

  const sw = swContext.serviceWorkers()[0];

  await sw.evaluate(async () => {
    const event = new PushEvent('push', {
      data: new TextEncoder().encode(JSON.stringify({
        title: 'New Message',
        body: 'You have a new message from Alice',
        url: '/messages',
      })),
    });
    self.dispatchEvent(event);
  });

  await expect(page.getByTestId('notification-badge')).toHaveText('1');
});
```

### Tests de la synchronisation en arrière-plan

**À utiliser quand** : ton application utilise l'API Background Sync pour différer les requêtes réseau jusqu'au retour de la connectivité.
**À éviter quand** : ton application n'utilise pas la synchronisation en arrière-plan.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('background sync retries failed requests when online', async ({ swContext }) => {
  const page = await swContext.newPage();
  await page.goto('/tasks');

  // Ensure SW is active
  await page.evaluate(() => navigator.serviceWorker.ready);

  // Go offline
  await swContext.setOffline(true);

  // Create a task (will fail to sync)
  await page.getByLabel('New task').fill('Buy groceries');
  await page.getByRole('button', { name: 'Add' }).click();

  // Task shows as "pending sync"
  await expect(page.getByText('Buy groceries')).toBeVisible();
  await expect(page.getByTestId('sync-status')).toHaveText('Pending');

  // Come back online — background sync should fire
  await swContext.setOffline(false);

  // Wait for sync to complete
  await expect(page.getByTestId('sync-status')).toHaveText('Synced', { timeout: 15000 });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('background sync retries failed requests when online', async ({ swContext }) => {
  const page = await swContext.newPage();
  await page.goto('/tasks');
  await page.evaluate(() => navigator.serviceWorker.ready);

  await swContext.setOffline(true);

  await page.getByLabel('New task').fill('Buy groceries');
  await page.getByRole('button', { name: 'Add' }).click();

  await expect(page.getByText('Buy groceries')).toBeVisible();
  await expect(page.getByTestId('sync-status')).toHaveText('Pending');

  await swContext.setOffline(false);
  await expect(page.getByTestId('sync-status')).toHaveText('Synced', { timeout: 15000 });
});
```

## Guide de décision

| Scénario | Approche | Pourquoi |
|---|---|---|
| Vérifier que le SW s'enregistre | `context.waitForEvent('serviceworker')` | Confirme que le fichier du SW a été récupéré et enregistré |
| Tester le service de la page hors ligne | `context.setOffline(true)` + reload | Simule une perte réseau au niveau du navigateur |
| Vérifier que certains assets sont en cache | `page.evaluate(() => caches.keys())` | Interroge directement l'API Cache |
| Tester l'invite d'installation | `addInitScript` pour mocker `beforeinstallprompt` | Le navigateur ne déclenche pas cet événement en automatisation |
| Valider le web manifest | `page.request.get(manifestUrl)` | Récupère et analyse le manifest JSON |
| Tester les notifications push | `sw.evaluate()` pour dispatcher un PushEvent | Simule un message push à l'intérieur du SW |
| Tester la synchronisation en arrière-plan | Passer hors ligne, effectuer l'action, revenir en ligne | Vérifie que la file de synchronisation est bien traitée |
| Tester le flux de mise à jour du SW | `registration.update()` via `page.evaluate` | Déclenche une vérification manuelle de mise à jour du SW |

## Anti-patterns

| À ne pas faire | Problème | À faire plutôt |
|---|---|---|
| Tester les service workers avec la fixture `page` par défaut | Le contexte par défaut est temporaire ; les SW peuvent ne pas persister | Utiliser `launchPersistentContext` pour des tests de SW fiables |
| Ignorer `navigator.serviceWorker.ready` avant de passer hors ligne | Le SW peut ne pas avoir fini de mettre en cache | Toujours faire d'abord `await page.evaluate(() => navigator.serviceWorker.ready)` |
| Utiliser `page.route()` pour simuler le hors ligne | `page.route()` ne voit jamais les requêtes faites par le SW lui-même (seul `context.route()` les voit, Chromium 1.57+), et les requêtes que le SW sert depuis le cache n'atteignent jamais le réseau | Utiliser `context.setOffline(true)` pour un vrai mode hors ligne au niveau réseau |
| Tester le fichier JavaScript du SW uniquement avec des tests unitaires | Passe à côté de l'intégration avec la page et du comportement du cache | Combiner tests unitaires et tests de SW end-to-end avec Playwright |
| Supposer que les caches sont propres au début du test | Les exécutions précédentes peuvent laisser des caches obsolètes | Vider les caches dans le setup de la fixture ou utiliser un `userDataDir` neuf |
| `waitForTimeout` après `setOffline(false)` | Le timing de la synchronisation en arrière-plan est imprévisible | Utiliser `expect(...).toHaveText('Synced', { timeout: 15000 })` |

## Dépannage

| Symptôme | Cause | Correction |
|---|---|---|
| `context.waitForEvent('serviceworker')` ne se résout jamais | Le SW était déjà enregistré avant l'ajout du listener | Enregistrer le listener avant `page.goto()`, ou vérifier `context.serviceWorkers()` |
| Le SW ne s'active pas | Un ancien SW contrôle encore la page | Utiliser `skipWaiting()` dans le SW ou vider le `userDataDir` |
| Le test hors ligne charge quand même du contenu frais | Le cache du SW n'a pas été rempli avant de passer hors ligne | Attendre `navigator.serviceWorker.ready` et vérifier d'abord le contenu du cache |
| `context.setOffline(true)` n'a aucun effet | Utilisation d'un contexte non persistant ou du mauvais contexte | S'assurer que le mode hors ligne est activé sur le même contexte que celui qui possède la page |
| L'événement push ne fait rien | Le SW n'est pas le contrôleur actif | S'assurer que `sw.evaluate()` cible le bon service worker parmi `context.serviceWorkers()` |
| Les tests interfèrent entre eux | `userDataDir` partagé entre les tests | Utiliser un répertoire temporaire unique par test, nettoyé au teardown de la fixture |
| Les tests de service worker ne fonctionnent que dans Chromium | Firefox et WebKit ont une prise en charge limitée des SW dans Playwright | Exécuter les tests de SW uniquement dans Chromium via `test.skip` ou la config du projet |

## Voir aussi

- [core/browser-apis.md](browser-apis.md) -- IndexedDB et localStorage utilisés avec les service workers
- [core/configuration.md](configuration.md) -- configuration au niveau du projet pour tester une PWA
- [core/fixtures-and-hooks.md](fixtures-and-hooks.md) -- encapsuler le contexte persistant dans des fixtures
- [core/websockets-and-realtime.md](websockets-and-realtime.md) -- fonctionnalités temps réel qui interagissent avec l'état hors ligne / en ligne
