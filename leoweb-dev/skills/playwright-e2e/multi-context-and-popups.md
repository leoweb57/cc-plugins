# Multi-contextes, popups et nouvelles fenêtres

> **Quand l'utiliser** : gérer les fenêtres popup, les nouveaux onglets, les flux d'autorisation OAuth, les redirections vers une passerelle de paiement, la coordination multi-onglets, et tout scénario où ton application ouvre des fenêtres ou onglets de navigateur supplémentaires.
> **Prérequis** : [core/assertions-and-waiting.md](assertions-and-waiting.md), [core/fixtures-and-hooks.md](fixtures-and-hooks.md)

## Référence rapide

```typescript
// Catch a popup triggered by a click
const popupPromise = page.waitForEvent('popup');
await page.getByRole('button', { name: 'Open preview' }).click();
const popup = await popupPromise;
await popup.waitForLoadState();
await expect(popup.getByRole('heading')).toContainText('Preview');

// List all open pages in a context
const allPages = context.pages();
console.log(`Open tabs: ${allPages.length}`);
```

**Concept clé** : dans Playwright, une « popup » est toute nouvelle page ouverte par `window.open()`, par des liens `target="_blank"` ou par des nouvelles fenêtres déclenchées en JavaScript. Toutes émettent l'événement `popup` sur la page d'origine.

## Patterns

### Gérer les popups de base

**À utiliser quand** : une action utilisateur ouvre un nouvel onglet ou une nouvelle fenêtre et que tu dois interagir avec.
**À éviter quand** : la « popup » est en réalité une boîte de dialogue modale dans la même page -- utilise plutôt `getByRole('dialog')`.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('handle popup opened by target="_blank" link', async ({ page }) => {
  await page.goto('/help');

  // Set up the popup listener BEFORE the action that triggers it
  const popupPromise = page.waitForEvent('popup');
  await page.getByRole('link', { name: 'Documentation' }).click();
  const popup = await popupPromise;

  // Wait for the popup to load
  await popup.waitForLoadState();

  // Interact with the popup
  await expect(popup.getByRole('heading', { level: 1 })).toContainText('Documentation');
  expect(popup.url()).toContain('/docs');

  // Close the popup when done
  await popup.close();
});

test('handle popup opened by window.open()', async ({ page }) => {
  await page.goto('/reports');

  const popupPromise = page.waitForEvent('popup');
  await page.getByRole('button', { name: 'Print report' }).click();
  const popup = await popupPromise;

  await popup.waitForLoadState();
  await expect(popup.getByTestId('print-preview')).toBeVisible();

  // The original page is still accessible
  await expect(page.getByRole('heading', { name: 'Reports' })).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('handle popup opened by target="_blank" link', async ({ page }) => {
  await page.goto('/help');

  const popupPromise = page.waitForEvent('popup');
  await page.getByRole('link', { name: 'Documentation' }).click();
  const popup = await popupPromise;

  await popup.waitForLoadState();
  await expect(popup.getByRole('heading', { level: 1 })).toContainText('Documentation');

  await popup.close();
});
```

### Flux OAuth en popup

**À utiliser quand** : ton application ouvre une fenêtre OAuth tierce (Google, GitHub, Microsoft, etc.) pour l'authentification.
**À éviter quand** : tu peux contourner entièrement OAuth en injectant directement des tokens d'authentification -- voir [core/authentication.md](authentication.md).

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('Google OAuth popup flow', async ({ page }) => {
  await page.goto('/login');

  // Listen for the popup before clicking the OAuth button
  const popupPromise = page.waitForEvent('popup');
  await page.getByRole('button', { name: 'Sign in with Google' }).click();
  const oauthPopup = await popupPromise;

  // Wait for the OAuth provider page to load
  await oauthPopup.waitForLoadState();
  expect(oauthPopup.url()).toContain('accounts.google.com');

  // Fill in credentials on the OAuth provider page
  await oauthPopup.getByLabel('Email or phone').fill('testuser@gmail.com');
  await oauthPopup.getByRole('button', { name: 'Next' }).click();
  await oauthPopup.getByLabel('Enter your password').fill('test-password');
  await oauthPopup.getByRole('button', { name: 'Next' }).click();

  // The popup closes automatically after authorization
  // Wait for the original page to receive the auth callback
  await page.waitForURL('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});

test('GitHub OAuth popup flow', async ({ page }) => {
  await page.goto('/login');

  const popupPromise = page.waitForEvent('popup');
  await page.getByRole('button', { name: 'Sign in with GitHub' }).click();
  const popup = await popupPromise;

  await popup.waitForLoadState();
  expect(popup.url()).toContain('github.com');

  await popup.getByLabel('Username or email address').fill('testuser');
  await popup.getByLabel('Password').fill('test-password');
  await popup.getByRole('button', { name: 'Sign in' }).click();

  // Authorize the app if prompted
  const authorizeButton = popup.getByRole('button', { name: 'Authorize' });
  if (await authorizeButton.isVisible({ timeout: 3000 }).catch(() => false)) {
    await authorizeButton.click();
  }

  // Popup closes, original page redirects
  await page.waitForURL('/dashboard');
  await expect(page.getByText(/Welcome/)).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('GitHub OAuth popup flow', async ({ page }) => {
  await page.goto('/login');

  const popupPromise = page.waitForEvent('popup');
  await page.getByRole('button', { name: 'Sign in with GitHub' }).click();
  const popup = await popupPromise;

  await popup.waitForLoadState();
  await popup.getByLabel('Username or email address').fill('testuser');
  await popup.getByLabel('Password').fill('test-password');
  await popup.getByRole('button', { name: 'Sign in' }).click();

  await page.waitForURL('/dashboard');
  await expect(page.getByText(/Welcome/)).toBeVisible();
});
```

### Popups de passerelle de paiement

**À utiliser quand** : les flux de checkout ouvrent un fournisseur de paiement dans une nouvelle fenêtre (PayPal, vérification 3D Secure).
**À éviter quand** : la passerelle de paiement se charge dans une iframe de la même page -- utilise plutôt `frameLocator`.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('PayPal popup checkout flow', async ({ page }) => {
  await page.goto('/checkout');

  await page.getByLabel('Email').fill('buyer@example.com');
  await page.getByRole('button', { name: 'Proceed to payment' }).click();

  // PayPal opens in a popup
  const popupPromise = page.waitForEvent('popup');
  await page.getByRole('button', { name: 'Pay with PayPal' }).click();
  const paypalPopup = await popupPromise;

  await paypalPopup.waitForLoadState();
  expect(paypalPopup.url()).toContain('paypal.com');

  // Complete PayPal flow
  await paypalPopup.getByLabel('Email').fill('buyer@paypal-test.com');
  await paypalPopup.getByRole('button', { name: 'Next' }).click();
  await paypalPopup.getByLabel('Password').fill('test-password');
  await paypalPopup.getByRole('button', { name: 'Log In' }).click();
  await paypalPopup.getByRole('button', { name: 'Complete Purchase' }).click();

  // Popup closes, return to original page
  await page.waitForURL('/order/confirmation');
  await expect(page.getByText('Payment successful')).toBeVisible();
});

test('3D Secure verification popup', async ({ page }) => {
  await page.goto('/checkout');
  await page.getByLabel('Card number').fill('4000000000003220'); // 3DS test card
  await page.getByLabel('Expiry').fill('12/28');
  await page.getByLabel('CVC').fill('123');
  await page.getByRole('button', { name: 'Pay' }).click();

  // 3DS challenge opens in popup or iframe -- handle both
  const popupPromise = page.waitForEvent('popup', { timeout: 5000 }).catch(() => null);
  const popup = await popupPromise;

  if (popup) {
    await popup.waitForLoadState();
    await popup.getByRole('button', { name: 'Complete authentication' }).click();
  } else {
    // Fallback: 3DS in iframe
    const frame = page.frameLocator('iframe[name*="challenge"]');
    await frame.getByRole('button', { name: 'Complete authentication' }).click();
  }

  await expect(page.getByText('Payment successful')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('PayPal popup checkout flow', async ({ page }) => {
  await page.goto('/checkout');
  await page.getByRole('button', { name: 'Proceed to payment' }).click();

  const popupPromise = page.waitForEvent('popup');
  await page.getByRole('button', { name: 'Pay with PayPal' }).click();
  const paypalPopup = await popupPromise;

  await paypalPopup.waitForLoadState();
  await paypalPopup.getByLabel('Email').fill('buyer@paypal-test.com');
  await paypalPopup.getByRole('button', { name: 'Next' }).click();
  await paypalPopup.getByLabel('Password').fill('test-password');
  await paypalPopup.getByRole('button', { name: 'Log In' }).click();
  await paypalPopup.getByRole('button', { name: 'Complete Purchase' }).click();

  await page.waitForURL('/order/confirmation');
  await expect(page.getByText('Payment successful')).toBeVisible();
});
```

### Coordination multi-onglets

**À utiliser quand** : tu testes des scénarios où plusieurs onglets partagent un état -- collaboration en temps réel, synchronisation de panier ou gestion de session entre onglets.
**À éviter quand** : chaque onglet est indépendant et peut être testé dans des cas de test séparés.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('cart updates reflect across tabs', async ({ context }) => {
  // Open two tabs in the same context (shared cookies/storage)
  const page1 = await context.newPage();
  const page2 = await context.newPage();

  await page1.goto('/products');
  await page2.goto('/cart');

  // Add item in tab 1
  await page1.getByRole('button', { name: 'Add to cart' }).first().click();

  // Tab 2 should reflect the update (via WebSocket, polling, or storage event)
  await expect(page2.getByTestId('cart-count')).toHaveText('1', { timeout: 5000 });
});

test('logout in one tab logs out all tabs', async ({ context }) => {
  const page1 = await context.newPage();
  const page2 = await context.newPage();

  // Both tabs are on authenticated pages
  await page1.goto('/dashboard');
  await page2.goto('/settings');

  // Log out from tab 1
  await page1.getByRole('button', { name: 'Log out' }).click();
  await page1.waitForURL('/login');

  // Tab 2 should redirect to login on next action or automatically
  await page2.reload();
  expect(page2.url()).toContain('/login');
});

test('manage multiple tabs with context.pages()', async ({ context, page }) => {
  await page.goto('/dashboard');

  // Open several new tabs
  const popupPromise1 = page.waitForEvent('popup');
  await page.getByRole('link', { name: 'Report A' }).click();
  const tab1 = await popupPromise1;

  const popupPromise2 = page.waitForEvent('popup');
  await page.getByRole('link', { name: 'Report B' }).click();
  const tab2 = await popupPromise2;

  // List all pages in this context
  const allPages = context.pages();
  expect(allPages).toHaveLength(3); // original + 2 popups

  // Interact with specific tabs
  await tab1.waitForLoadState();
  await expect(tab1.getByRole('heading')).toContainText('Report A');

  await tab2.waitForLoadState();
  await expect(tab2.getByRole('heading')).toContainText('Report B');

  // Close tabs when done
  await tab2.close();
  await tab1.close();
  expect(context.pages()).toHaveLength(1);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('cart updates reflect across tabs', async ({ context }) => {
  const page1 = await context.newPage();
  const page2 = await context.newPage();

  await page1.goto('/products');
  await page2.goto('/cart');

  await page1.getByRole('button', { name: 'Add to cart' }).first().click();
  await expect(page2.getByTestId('cart-count')).toHaveText('1', { timeout: 5000 });
});

test('manage tabs with context.pages()', async ({ context, page }) => {
  await page.goto('/dashboard');

  const popupPromise = page.waitForEvent('popup');
  await page.getByRole('link', { name: 'Report A' }).click();
  const newTab = await popupPromise;

  expect(context.pages()).toHaveLength(2);
  await newTab.close();
  expect(context.pages()).toHaveLength(1);
});
```

### Téléchargements déclenchés dans de nouveaux onglets

**À utiliser quand** : un téléchargement est déclenché par l'ouverture d'un nouvel onglet (par ex. une génération de PDF qui s'ouvre dans une nouvelle fenêtre avant le téléchargement).
**À éviter quand** : le téléchargement démarre directement sans ouvrir de nouvel onglet -- utilise directement `page.waitForEvent('download')`.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('PDF download from new tab', async ({ page }) => {
  await page.goto('/invoices');

  // Some apps open the PDF in a new tab, which then triggers a download
  const popupPromise = page.waitForEvent('popup');
  await page.getByRole('link', { name: 'Download Invoice #123' }).click();
  const popup = await popupPromise;

  // The popup may directly trigger a download
  const downloadPromise = popup.waitForEvent('download');
  const download = await downloadPromise;

  expect(download.suggestedFilename()).toContain('invoice');
  const path = await download.path();
  expect(path).toBeTruthy();

  await popup.close();
});

test('export opens in new tab then auto-downloads', async ({ page }) => {
  await page.goto('/reports');

  // Handle both: popup that downloads AND popup that shows content
  const popupPromise = page.waitForEvent('popup');
  await page.getByRole('button', { name: 'Export CSV' }).click();
  const popup = await popupPromise;

  // Try to catch a download; if no download, the popup has the content
  try {
    const download = await popup.waitForEvent('download', { timeout: 5000 });
    const filename = download.suggestedFilename();
    expect(filename).toMatch(/\.csv$/);
    await download.saveAs(`./downloads/${filename}`);
  } catch {
    // No download event — content displayed in the popup
    const content = await popup.textContent('body');
    expect(content).toContain('Report Data');
  }

  await popup.close();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('PDF download from new tab', async ({ page }) => {
  await page.goto('/invoices');

  const popupPromise = page.waitForEvent('popup');
  await page.getByRole('link', { name: 'Download Invoice #123' }).click();
  const popup = await popupPromise;

  const downloadPromise = popup.waitForEvent('download');
  const download = await downloadPromise;

  expect(download.suggestedFilename()).toContain('invoice');
  await popup.close();
});
```

### Multi-contextes pour des sessions isolées

**À utiliser quand** : tu testes des interactions entre différents utilisateurs (par ex. admin et utilisateur standard, deux participants d'un chat).
**À éviter quand** : tu n'as besoin que du point de vue d'un seul utilisateur -- un seul contexte suffit.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('admin sees user changes in real-time', async ({ browser }) => {
  // Create separate contexts for two users (separate sessions)
  const adminContext = await browser.newContext();
  const userContext = await browser.newContext();

  const adminPage = await adminContext.newPage();
  const userPage = await userContext.newPage();

  // Admin logs in and watches the user list
  await adminPage.goto('/admin/users');

  // User signs up
  await userPage.goto('/register');
  await userPage.getByLabel('Name').fill('New User');
  await userPage.getByLabel('Email').fill('newuser@example.com');
  await userPage.getByLabel('Password').fill('password123');
  await userPage.getByRole('button', { name: 'Register' }).click();

  // Admin should see the new user appear
  await expect(adminPage.getByText('newuser@example.com')).toBeVisible({ timeout: 10000 });

  await adminContext.close();
  await userContext.close();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('admin sees user changes in real-time', async ({ browser }) => {
  const adminContext = await browser.newContext();
  const userContext = await browser.newContext();

  const adminPage = await adminContext.newPage();
  const userPage = await userContext.newPage();

  await adminPage.goto('/admin/users');

  await userPage.goto('/register');
  await userPage.getByLabel('Name').fill('New User');
  await userPage.getByLabel('Email').fill('newuser@example.com');
  await userPage.getByLabel('Password').fill('password123');
  await userPage.getByRole('button', { name: 'Register' }).click();

  await expect(adminPage.getByText('newuser@example.com')).toBeVisible({ timeout: 10000 });

  await adminContext.close();
  await userContext.close();
});
```

### Observer les nouveaux contextes et les événements en miroir (Playwright 1.60+)

**À utiliser quand** : tu orchestres de nombreux contextes/pages (suites multi-utilisateurs, sessions pilotées par un agent) et tu veux un point unique pour réagir à la création d'un nouveau contexte, ou écouter les événements de cycle de vie des pages au niveau du contexte plutôt que de brancher un listener sur chaque page.
**À éviter quand** : tu as un seul contexte et une seule page -- écoute directement sur la `page`.

Playwright 1.60 ajoute `browser.on('context')`, émis à chaque création d'un nouveau contexte, et fait en sorte que `BrowserContext` reflète les événements de cycle de vie de ses pages (`download`, événements de frames, fermeture/chargement de page). Tu peux ainsi attacher du logging ou des diagnostics une seule fois au niveau du navigateur/contexte.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('log every context and download across the browser', async ({ browser }) => {
  // Fires for each new context created on this browser (1.60+)
  browser.on('context', (context) => {
    console.log('New context created');

    // Context mirrors page-level events — no per-page wiring needed (1.60+)
    context.on('download', (download) => {
      console.log('Download started:', download.suggestedFilename());
    });
  });

  const userA = await browser.newContext();
  const userB = await browser.newContext();

  const pageA = await userA.newPage();
  await pageA.goto('/reports');
  await pageA.getByRole('button', { name: 'Export CSV' }).click();

  await userA.close();
  await userB.close();
});
```

**JavaScript**
```javascript
const { test } = require('@playwright/test');

test('log every context and download across the browser', async ({ browser }) => {
  browser.on('context', (context) => {
    context.on('download', (download) => {
      console.log('Download started:', download.suggestedFilename());
    });
  });

  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  await page.goto('/reports');
  await page.getByRole('button', { name: 'Export CSV' }).click();
  await ctx.close();
});
```

> Les événements en miroir au niveau du contexte servent aux préoccupations transverses (logging, artefacts, compteurs). Pour les assertions liées à une page précise, écoute toujours sur cette `page`.

## Guide de décision

| Scénario | Approche | Pourquoi |
|---|---|---|
| Lien `target="_blank"` | `page.waitForEvent('popup')` | Playwright émet `popup` pour toutes les nouvelles fenêtres/onglets |
| Appel à `window.open()` | `page.waitForEvent('popup')` | Même mécanisme quelle que soit la façon dont la fenêtre s'ouvre |
| Popup de login OAuth | `waitForEvent('popup')` + interagir + attendre la fermeture | Les fournisseurs OAuth redirigent puis ferment la popup |
| Popup de paiement (PayPal) | `waitForEvent('popup')` + terminer le flux | Comme OAuth mais avec une UI propre au paiement |
| Téléchargement dans un nouvel onglet | `popup.waitForEvent('download')` | Capturer l'événement de téléchargement sur la page popup |
| Plusieurs onglets, même utilisateur | Ouvrir les pages dans le même `context` | Cookies, localStorage et session partagés |
| Plusieurs utilisateurs (sessions séparées) | Créer un `browser.newContext()` distinct par utilisateur | Cookies, stockage et état d'authentification isolés |
| Test de synchronisation d'onglets | Plusieurs `context.newPage()` + vérifier l'état partagé | Teste la synchronisation d'état en temps réel |
| Popup qui peut apparaître ou non | `waitForEvent('popup', { timeout })` avec try/catch | Gestion propre des popups conditionnelles |

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| Cliquer puis appeler `waitForEvent('popup')` | La popup peut s'ouvrir avant que le listener soit enregistré (race condition) | Mets en place `waitForEvent` AVANT le clic |
| Utiliser `context.pages()[1]` pour obtenir une popup | L'ordre des index n'est pas garanti ; fragile | Utilise `waitForEvent('popup')` qui renvoie exactement la bonne page |
| Oublier `popup.waitForLoadState()` | La page popup peut ne pas être chargée quand tu interagis avec | Appelle toujours `waitForLoadState()` après avoir reçu la popup |
| Ne pas fermer les popups après le test | Les pages qui fuient consomment de la mémoire et peuvent affecter les tests suivants | Ferme les popups avec `popup.close()` dans le test ou utilise des fixtures |
| Utiliser des `browser.newContext()` séparés alors que les onglets devraient partager l'état | Des contextes séparés ont des cookies/sessions séparés | Utilise `context.newPage()` pour les onglets d'une même session |
| Utiliser `context.newPage()` pour des utilisateurs isolés | Les pages d'un même contexte partagent l'état | Utilise `browser.newContext()` pour des sessions utilisateur séparées |
| `page.waitForTimeout()` après le déclenchement de la popup | Le timing de la popup est imprévisible | Utilise `page.waitForEvent('popup')` qui se résout à l'ouverture de la popup |
| Capter la popup sur la mauvaise page | L'événement popup est émis sur la page qui l'a déclenchée | Écoute `popup` sur la page où le clic/l'action a lieu |

## Dépannage

| Symptôme | Cause probable | Correctif |
|---|---|---|
| `waitForEvent('popup')` expire | L'action n'a pas ouvert de nouvelle fenêtre ; elle a navigué dans le même onglet | Vérifie si le lien a `target="_blank"` ou si `window.open` est appelé |
| La popup s'ouvre mais est vide | La popup est encore en cours de chargement ; tu as interagi trop tôt | Ajoute `await popup.waitForLoadState()` avant d'interagir |
| L'URL de la popup est `about:blank` | La popup est créée vide, puis navigue via JavaScript | Attends `popup.waitForURL()` avec le motif d'URL attendu |
| La popup OAuth est bloquée par le navigateur | Le bloqueur de popups est actif | Playwright désactive le blocage des popups par défaut ; vérifie si un argument du navigateur le réactive |
| Deux popups s'ouvrent mais une seule est captée | `waitForEvent` ne se résout que pour le premier événement | Utilise `page.on('popup', callback)` pour capter toutes les popups, ou enchaîne deux appels à `waitForEvent` |
| `context.pages()` renvoie un nombre inattendu | Un test précédent a laissé des pages ouvertes | Ferme toutes les pages en trop dans `afterEach` ou utilise des contextes par test |
| La popup se ferme avant la fin de l'interaction | L'application ou le fournisseur OAuth la ferme automatiquement après un délai | Accélère le test ou retire `slowMo` ; interagis immédiatement avec la popup |
| L'interaction avec une popup cross-origin échoue | La popup a navigué vers une autre origine | Playwright gère les popups cross-origin ; assure-toi de ne pas définir `--disable-web-security` |

## Voir aussi

- [core/authentication.md](authentication.md) -- contourner les popups OAuth avec un état d'authentification stocké
- [core/multi-user-and-collaboration.md](multi-user-and-collaboration.md) -- tests de collaboration multi-utilisateurs en temps réel
- [core/file-operations.md](file-operations.md) -- gestion des téléchargements sans popups
- [core/third-party-integrations.md](third-party-integrations.md) -- mock des fournisseurs OAuth pour éviter les vraies popups
- [core/fixtures-and-hooks.md](fixtures-and-hooks.md) -- fixtures pour les configurations multi-contextes
