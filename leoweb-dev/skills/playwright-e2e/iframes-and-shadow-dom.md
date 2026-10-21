# Iframes and Shadow DOM

> **Quand l'utiliser** : quand ton application intègre du contenu dans des éléments `<iframe>` (widgets de paiement, embeds tiers, modules legacy) ou utilise des Web Components avec Shadow DOM (design systems, custom elements, Salesforce Lightning).
> **Prérequis** : [core/locators.md](locators.md), [core/assertions-and-waiting.md](assertions-and-waiting.md)

## Référence rapide

```typescript
// Iframes — use frameLocator to reach inside
const frame = page.frameLocator('iframe[title="Payment"]');
await frame.getByLabel('Card number').fill('4242424242424242');

// Nested iframes — chain frameLocator calls
const inner = page.frameLocator('#outer').frameLocator('#inner');
await inner.getByRole('button', { name: 'Submit' }).click();

// Shadow DOM — Playwright pierces open shadow roots automatically
await page.getByRole('button', { name: 'Toggle' }).click();       // auto-pierces
await page.locator('my-component').getByText('Hello').click();     // auto-pierces
```

## Patterns

### Interaction de base avec une iframe via `frameLocator()`

**À utiliser quand** : tu dois interagir avec du contenu à l'intérieur d'une `<iframe>` -- formulaires de paiement, éditeurs embarqués, captchas, widgets tiers.
**À éviter quand** : le contenu est dans la frame principale. N'utilise jamais `frameLocator` pour le Shadow DOM.

`frameLocator()` renvoie un objet de type locator cadré sur le document de l'iframe. Toutes les méthodes de locator standard y fonctionnent.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('complete payment inside Stripe iframe', async ({ page }) => {
  await page.goto('/checkout');

  // Locate the iframe by its title, name, or a CSS selector
  const paymentFrame = page.frameLocator('iframe[title="Secure payment"]');

  // Use normal locators inside the frame
  await paymentFrame.getByLabel('Card number').fill('4242424242424242');
  await paymentFrame.getByLabel('Expiry').fill('12/28');
  await paymentFrame.getByLabel('CVC').fill('123');
  await paymentFrame.getByRole('button', { name: 'Pay' }).click();

  // Assertion on content inside the iframe
  await expect(paymentFrame.getByText('Payment successful')).toBeVisible();

  // Assertion on the parent page (outside the iframe)
  await expect(page.getByRole('heading', { name: 'Order confirmed' })).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('complete payment inside Stripe iframe', async ({ page }) => {
  await page.goto('/checkout');

  const paymentFrame = page.frameLocator('iframe[title="Secure payment"]');
  await paymentFrame.getByLabel('Card number').fill('4242424242424242');
  await paymentFrame.getByLabel('Expiry').fill('12/28');
  await paymentFrame.getByLabel('CVC').fill('123');
  await paymentFrame.getByRole('button', { name: 'Pay' }).click();

  await expect(paymentFrame.getByText('Payment successful')).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Order confirmed' })).toBeVisible();
});
```

### Sélectionner la bonne iframe

**À utiliser quand** : plusieurs iframes existent sur la page ou l'iframe n'a pas d'identifiant évident.
**À éviter quand** : il n'y a qu'une seule iframe et un simple `page.frameLocator('iframe')` suffit.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('interact with the correct iframe among many', async ({ page }) => {
  await page.goto('/dashboard');

  // By title attribute (best — accessible and stable)
  const chatFrame = page.frameLocator('iframe[title="Live chat"]');

  // By name attribute
  const reportFrame = page.frameLocator('iframe[name="analytics-report"]');

  // By src URL pattern
  const adFrame = page.frameLocator('iframe[src*="ads.example.com"]');

  // By index — when nothing else works (0-indexed)
  const thirdFrame = page.frameLocator('iframe').nth(2);

  // By parent container — scope to a section first
  const sidebar = page.getByRole('complementary');
  const sidebarFrame = sidebar.frameLocator('iframe');

  await chatFrame.getByRole('textbox', { name: 'Message' }).fill('Help');
  await expect(reportFrame.getByRole('heading')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('interact with the correct iframe among many', async ({ page }) => {
  await page.goto('/dashboard');

  const chatFrame = page.frameLocator('iframe[title="Live chat"]');
  const reportFrame = page.frameLocator('iframe[name="analytics-report"]');
  const adFrame = page.frameLocator('iframe[src*="ads.example.com"]');
  const thirdFrame = page.frameLocator('iframe').nth(2);

  await chatFrame.getByRole('textbox', { name: 'Message' }).fill('Help');
  await expect(reportFrame.getByRole('heading')).toBeVisible();
});
```

### Iframes imbriquées

**À utiliser quand** : une iframe en contient une autre (fréquent dans les hiérarchies de widgets complexes, les conteneurs publicitaires ou les outils tiers embarqués).
**À éviter quand** : il n'y a qu'un seul niveau d'imbrication d'iframe.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('interact with deeply nested iframe content', async ({ page }) => {
  await page.goto('/embed-page');

  // Chain frameLocator calls for each level of nesting
  const outerFrame = page.frameLocator('#widget-container');
  const innerFrame = outerFrame.frameLocator('#payment-form');

  await innerFrame.getByLabel('Amount').fill('99.99');
  await innerFrame.getByRole('button', { name: 'Confirm' }).click();

  // Three levels deep
  const deepFrame = page
    .frameLocator('#level-1')
    .frameLocator('#level-2')
    .frameLocator('#level-3');
  await expect(deepFrame.getByText('Success')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('interact with deeply nested iframe content', async ({ page }) => {
  await page.goto('/embed-page');

  const outerFrame = page.frameLocator('#widget-container');
  const innerFrame = outerFrame.frameLocator('#payment-form');

  await innerFrame.getByLabel('Amount').fill('99.99');
  await innerFrame.getByRole('button', { name: 'Confirm' }).click();

  const deepFrame = page
    .frameLocator('#level-1')
    .frameLocator('#level-2')
    .frameLocator('#level-3');
  await expect(deepFrame.getByText('Success')).toBeVisible();
});
```

### Iframes cross-origin

**À utiliser quand** : l'iframe charge du contenu depuis un autre domaine (fournisseurs de paiement, flux OAuth, embeds tiers).
**À éviter quand** : l'iframe est de même origine.

Playwright gère les iframes cross-origin de façon transparente. `frameLocator()` fonctionne quelle que soit l'origine. Aucune configuration spéciale n'est nécessaire.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('complete OAuth login in cross-origin iframe', async ({ page }) => {
  await page.goto('/login');
  await page.getByRole('button', { name: 'Sign in with Google' }).click();

  // The OAuth provider renders in a cross-origin iframe or popup
  // For iframes:
  const oauthFrame = page.frameLocator('iframe[src*="accounts.google.com"]');
  await oauthFrame.getByLabel('Email').fill('user@gmail.com');
  await oauthFrame.getByRole('button', { name: 'Next' }).click();
});

test('cross-origin payment widget', async ({ page }) => {
  await page.goto('/checkout');

  // Stripe, PayPal, etc. load in cross-origin iframes
  const stripeFrame = page.frameLocator('iframe[src*="js.stripe.com"]');

  // All locator methods work across origins
  await stripeFrame.getByLabel('Card number').fill('4242424242424242');
  await stripeFrame.getByLabel('MM / YY').fill('12 / 28');
  await stripeFrame.getByLabel('CVC').fill('123');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('cross-origin payment widget', async ({ page }) => {
  await page.goto('/checkout');

  const stripeFrame = page.frameLocator('iframe[src*="js.stripe.com"]');
  await stripeFrame.getByLabel('Card number').fill('4242424242424242');
  await stripeFrame.getByLabel('MM / YY').fill('12 / 28');
  await stripeFrame.getByLabel('CVC').fill('123');
});
```

### Utiliser l'API Frame pour les scénarios avancés

**À utiliser quand** : tu dois accéder à l'URL de la frame, attendre une navigation de frame ou exécuter `evaluate` à l'intérieur de la frame.
**À éviter quand** : `frameLocator()` couvre ton besoin. C'est plus simple et ça attend automatiquement.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('use Frame API for URL checks and evaluate', async ({ page }) => {
  await page.goto('/dashboard');

  // Get the Frame object (not FrameLocator)
  const frame = page.frame({ url: /analytics\.example\.com/ });
  expect(frame).not.toBeNull();

  // Check the frame's URL
  expect(frame!.url()).toContain('analytics.example.com');

  // Run JavaScript inside the frame
  const title = await frame!.evaluate(() => document.title);
  expect(title).toBe('Analytics Dashboard');

  // Wait for a frame to navigate
  const frameNavPromise = page.waitForEvent('framenavigated', {
    predicate: (f) => f.url().includes('/reports'),
  });
  await page.frameLocator('iframe[name="analytics"]')
    .getByRole('link', { name: 'Reports' }).click();
  await frameNavPromise;
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('use Frame API for URL checks and evaluate', async ({ page }) => {
  await page.goto('/dashboard');

  const frame = page.frame({ url: /analytics\.example\.com/ });
  expect(frame).not.toBeNull();

  expect(frame.url()).toContain('analytics.example.com');

  const title = await frame.evaluate(() => document.title);
  expect(title).toBe('Analytics Dashboard');
});
```

### Shadow DOM -- piercing automatique

**À utiliser quand** : ton app utilise des Web Components avec Shadow DOM ouvert. C'est le comportement par défaut -- aucune configuration spéciale nécessaire.
**À éviter quand** : le shadow root est fermé (voir le contournement ci-dessous).

`locator()`, `getByRole()`, `getByText()` et tous les locators sémantiques de Playwright traversent le Shadow DOM ouvert par défaut.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('interact with web components using Shadow DOM', async ({ page }) => {
  await page.goto('/design-system-demo');

  // getByRole pierces shadow roots automatically
  await page.getByRole('button', { name: 'Open menu' }).click();

  // locator() with CSS also pierces
  await page.locator('my-dropdown').getByRole('option', { name: 'Settings' }).click();

  // Nested web components — each shadow root is pierced
  await page
    .locator('my-app')
    .locator('my-sidebar')
    .getByRole('link', { name: 'Dashboard' })
    .click();

  // Assertions pierce too
  await expect(page.locator('my-card').getByText('Welcome back')).toBeVisible();

  // getByTestId pierces shadow DOM
  await expect(page.getByTestId('user-avatar')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('interact with web components using Shadow DOM', async ({ page }) => {
  await page.goto('/design-system-demo');

  await page.getByRole('button', { name: 'Open menu' }).click();
  await page.locator('my-dropdown').getByRole('option', { name: 'Settings' }).click();

  await page
    .locator('my-app')
    .locator('my-sidebar')
    .getByRole('link', { name: 'Dashboard' })
    .click();

  await expect(page.locator('my-card').getByText('Welcome back')).toBeVisible();
});
```

### Contournement du Shadow DOM fermé

**À utiliser quand** : un composant tiers utilise `attachShadow({ mode: 'closed' })`, ce qui bloque le piercing automatique de Playwright.
**À éviter quand** : le shadow root est ouvert (par défaut). Le piercing automatique gère les roots ouverts.

Surcharge `attachShadow` avant le chargement de la page pour forcer le mode ouvert.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('access closed shadow DOM by forcing open mode', async ({ page }) => {
  // Intercept attachShadow before the page scripts run
  await page.addInitScript(() => {
    const originalAttachShadow = Element.prototype.attachShadow;
    Element.prototype.attachShadow = function (init: ShadowRootInit) {
      return originalAttachShadow.call(this, { ...init, mode: 'open' });
    };
  });

  await page.goto('/third-party-widget');

  // Now the previously closed shadow root is accessible
  await page.locator('closed-component').getByRole('button', { name: 'Action' }).click();
  await expect(page.locator('closed-component').getByText('Done')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('access closed shadow DOM by forcing open mode', async ({ page }) => {
  await page.addInitScript(() => {
    const originalAttachShadow = Element.prototype.attachShadow;
    Element.prototype.attachShadow = function (init) {
      return originalAttachShadow.call(this, { ...init, mode: 'open' });
    };
  });

  await page.goto('/third-party-widget');

  await page.locator('closed-component').getByRole('button', { name: 'Action' }).click();
  await expect(page.locator('closed-component').getByText('Done')).toBeVisible();
});
```

### Web Components avec slots et événements custom

**À utiliser quand** : tu testes des web components qui utilisent `<slot>` pour la projection de contenu ou qui émettent des événements custom.
**À éviter quand** : le composant n'utilise ni slots ni événements custom.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('slotted content is visible through web component', async ({ page }) => {
  await page.goto('/components-demo');

  // Content projected into a <slot> is in the light DOM (not shadow)
  // Playwright sees it at its original location
  const card = page.locator('my-card');
  await expect(card.getByRole('heading', { name: 'Product Title' })).toBeVisible();
  await expect(card.getByText('Product description here')).toBeVisible();
});

test('listen for custom events from web components', async ({ page }) => {
  await page.goto('/components-demo');

  // Set up a listener for a custom event
  const eventPromise = page.evaluate(() => {
    return new Promise<{ detail: unknown }>((resolve) => {
      document.querySelector('my-color-picker')!.addEventListener(
        'color-change',
        (e: Event) => resolve({ detail: (e as CustomEvent).detail }),
        { once: true }
      );
    });
  });

  // Trigger the event by interacting with the component
  await page.locator('my-color-picker').getByRole('button', { name: 'Red' }).click();

  const event = await eventPromise;
  expect(event.detail).toEqual({ color: '#ff0000' });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('slotted content is visible through web component', async ({ page }) => {
  await page.goto('/components-demo');

  const card = page.locator('my-card');
  await expect(card.getByRole('heading', { name: 'Product Title' })).toBeVisible();
  await expect(card.getByText('Product description here')).toBeVisible();
});

test('listen for custom events from web components', async ({ page }) => {
  await page.goto('/components-demo');

  const eventPromise = page.evaluate(() => {
    return new Promise((resolve) => {
      document.querySelector('my-color-picker').addEventListener(
        'color-change',
        (e) => resolve({ detail: e.detail }),
        { once: true }
      );
    });
  });

  await page.locator('my-color-picker').getByRole('button', { name: 'Red' }).click();

  const event = await eventPromise;
  expect(event.detail).toEqual({ color: '#ff0000' });
});
```

### Les iframes cachées masquent leur contenu (breaking change de Playwright 1.64)

Les éléments à l'intérieur d'une iframe qui n'est pas visible, par exemple stylée en `visibility: hidden`, sont désormais considérés comme **cachés** par les actions, `locator.isVisible()` et `toBeVisible()`. Avant la 1.64, ils pouvaient être signalés comme visibles car seul l'élément lui-même était vérifié.

Si un test se met à échouer après la mise à jour avec une erreur « not visible » dans une frame, inspecte l'élément iframe lui-même. En général, le test cliquait dans une frame que l'utilisateur ne pouvait pas voir, ce qui était un faux positif ; affiche d'abord la frame (ouvre le panneau, change d'onglet), puis interagis.

### Sérialiser le Shadow DOM avec `page.content()` (Playwright 1.64+)

`page.content()` et `frame.content()` ne renvoyaient que le light DOM, si bien que les snapshots HTML des apps à base de web components perdaient l'essentiel de leur markup. Passe `includeShadow: true` pour sérialiser les shadow roots ouverts en [declarative shadow DOM](https://developer.mozilla.org/en-US/docs/Web/API/Web_components/Using_shadow_DOM#declaratively_with_html) :

```typescript
const html = await page.content({ includeShadow: true });
// <my-card><template shadowrootmode="open">...</template></my-card>
```

Utile pour joindre un snapshot HTML complet à un test en échec, ou pour fournir le markup rendu d'un composant à un validateur HTML.

### Localiser à travers les frames sans sélecteur (Playwright 1.63+)

`page.frameLocator()` appelé sans sélecteur cherche dans la frame principale et dans toutes les iframes, donc tu n'as pas besoin de savoir quelle iframe héberge l'élément :

```typescript
await page.frameLocator().getByRole('button', { name: 'Pay now' }).click();
```

Le reste du locator se résout toujours dans une seule frame, et il lève une erreur si la correspondance s'étend sur plusieurs frames. Préfère un `frameLocator('iframe[title="..."]')` explicite quand la page contient plusieurs iframes similaires.

## Guide de décision

| Scénario | Approche | Pourquoi |
|---|---|---|
| Contenu dans une `<iframe>` | `page.frameLocator('selector')` | Renvoie un locator cadré sur le document de l'iframe |
| Plusieurs iframes sur la page | Utiliser des sélecteurs d'attribut `title`, `name` ou `src` | Plus stable que `nth()` basé sur l'index |
| Iframes imbriquées | Chaîner `frameLocator().frameLocator()` | Chaque appel descend d'un niveau |
| Iframe cross-origin | Comme n'importe quelle iframe -- `frameLocator()` | Playwright gère le cross-origin de façon transparente |
| Vérification d'URL ou `evaluate` dans la frame | `page.frame({ url })` (API Frame) | FrameLocator n'expose ni l'URL ni evaluate |
| Shadow DOM ouvert | Locators standard -- aucun changement nécessaire | Playwright traverse les shadow roots ouverts par défaut |
| Shadow DOM fermé | `addInitScript` pour surcharger `attachShadow` | Force l'ouverture des roots fermés avant le chargement de la page |
| Contenu slotté dans les Web Components | Localiser à l'intérieur de la balise du custom element | Le contenu slotté est du light DOM, accessible normalement |
| CSS sans piercing (rare) | Éviter `css:light=` : non documenté et indiqué comme retiré dans les notes de la 1.58, même si la 1.64 le parse encore | Cadrer depuis un parent en light DOM ou vérifier dans `evaluate()` |

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| `page.locator('#element-inside-iframe')` | Les locators ne traversent pas les frontières d'iframe | `page.frameLocator('iframe').locator('#element')` |
| `page.frameLocator('iframe').frameLocator('iframe')` sans sélecteurs précis | Cible les mauvaises iframes quand il y en a plusieurs | Utiliser des attributs précis : `frameLocator('iframe[title="..."]')` |
| `page.$('>>> .shadow-element')` | Le sélecteur de piercing `>>>` n'est pas standard dans Playwright | Utiliser `page.locator('host-element').getByRole(...)` -- le piercing automatique fonctionne |
| Utiliser `contentFrame()` sur un locator pour des interactions courantes | API plus complexe que `frameLocator` pour les cas simples | Utiliser `frameLocator()` -- plus simple, attend automatiquement |
| `page.evaluate` pour interroger le Shadow DOM | Contourne l'auto-waiting et la logique de retry de Playwright | Utiliser `page.locator()` qui traverse automatiquement |
| Coder en dur l'index d'iframe (`nth(0)`) alors que des attributs sont disponibles | L'index change quand des iframes sont ajoutées/retirées | Utiliser un pattern `title`, `name` ou `src` |

## Dépannage

| Symptôme | Cause | Correctif |
|---|---|---|
| Le locator expire à l'intérieur de l'iframe | Utilisation de `page.locator()` au lieu de `frameLocator().locator()` | Passe à `page.frameLocator('selector').locator(...)` |
| `frameLocator` ne renvoie aucun élément | L'iframe n'est pas encore chargée quand le locator se résout | `frameLocator` attend automatiquement ; vérifie que le sélecteur d'iframe correspond |
| Contenu d'iframe cross-origin inaccessible | Rare : politique de sécurité spécifique du navigateur | Playwright gère le cross-origin ; vérifie que tu n'utilises pas `page.frame()` avec une mauvaise URL |
| Élément du Shadow DOM introuvable avec `locator()` | Le shadow root est fermé (`mode: 'closed'`) | Utilise `addInitScript` pour surcharger `attachShadow` et forcer le mode ouvert |
| `getByRole` trouve des éléments du mauvais shadow root | Plusieurs web components ont des éléments de même rôle et de même nom | Cadre le locator : `page.locator('my-specific-component').getByRole(...)` |
| Contenu slotté introuvable | Recherche à l'intérieur du shadow root au lieu du light DOM | Le contenu slotté reste dans le light DOM ; localise-le via le custom element parent |
| `frame.evaluate()` renvoie null | La frame a navigué ailleurs ou a été retirée du DOM | Ré-acquiers la référence de la frame après la navigation |

## Voir aussi

- [core/locators.md](locators.md) -- fondamentaux des locators, dont les bases des frames et du Shadow DOM
- [core/browser-apis.md](browser-apis.md) -- tester les API du navigateur qui peuvent vivre dans des iframes
- [core/canvas-and-webgl.md](canvas-and-webgl.md) -- éléments canvas dans des iframes ou des web components
- [core/debugging.md](debugging.md) -- utiliser le Playwright Inspector pour identifier les frontières d'iframe et les shadow roots
