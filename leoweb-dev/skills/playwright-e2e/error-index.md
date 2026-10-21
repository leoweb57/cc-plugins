# Index des erreurs Playwright

Référence rapide pour des messages d'erreur Playwright précis. Retrouve ton erreur, comprends la cause, applique le correctif.

> **Mode d'emploi** : Cherche dans ce fichier le texte exact de l'erreur affichée dans ton terminal ou ton rapport de test. Chaque entrée donne la cause et un correctif qui fonctionne.

---

## Erreurs de locators et d'éléments

---

### "locator.click: Target page, context or browser has been closed"

**Cause** : La page, le contexte ou le navigateur a été fermé alors que l'action était encore en cours. (Les anciennes versions de Playwright affichaient `Target closed`.)

**Causes fréquentes** :
- Une popup ou une fenêtre se ferme d'elle-même à la suite du clic, et le test continue d'agir dessus
- Appel de `page.close()` ou `context.close()` dans un bloc `finally` qui entre en concurrence avec une action en cours
- Un `await` manquant laisse le test se terminer et ses fixtures détruire la page alors que l'action est encore en attente
- Le test a dépassé son timeout et Playwright a fermé la page ; l'erreur affiche alors `Test timeout of 30000ms exceeded.`

**Correctif** : Utilise `await` sur chaque action, et ne ferme pas la page ou le contexte tant que toutes les actions en cours dessus ne sont pas terminées. Si la page se ferme volontairement (par exemple une popup), capture une référence avant l'action :

```typescript
// TypeScript — handle popup that closes itself
const popupPromise = page.waitForEvent('popup');
await page.getByRole('button', { name: 'Open popup' }).click();
const popup = await popupPromise;
await popup.waitForLoadState();
// interact with popup before it closes
await popup.getByRole('button', { name: 'Confirm' }).click();
```

```javascript
// JavaScript — handle popup that closes itself
const popupPromise = page.waitForEvent('popup');
await page.getByRole('button', { name: 'Open popup' }).click();
const popup = await popupPromise;
await popup.waitForLoadState();
await popup.getByRole('button', { name: 'Confirm' }).click();
```

**Voir aussi** : [core/assertions-and-waiting.md](assertions-and-waiting.md), [core/multi-context-and-popups.md](multi-context-and-popups.md)

---

### "waiting for locator('...') to be visible"

**Cause** : L'auto-waiting de Playwright a expiré parce que l'élément n'est jamais apparu dans le DOM ou est resté caché (par exemple `display: none`, `visibility: hidden`, taille nulle, ou derrière `aria-hidden`).

**Causes fréquentes** :
- L'élément s'affiche de façon conditionnelle et la condition n'était pas remplie (données manquantes, état non authentifié)
- Le contenu se charge de façon asynchrone et le locator a été évalué avant l'arrivée de la réponse de l'API
- Le sélecteur est incorrect : faute de frappe dans le rôle, le nom ou le test ID
- L'élément existe mais est hors écran ou dans un conteneur replié
- Une animation ou transition CSS maintient l'élément à `opacity: 0` sans le rendre visible pour Playwright

**Correctif** : Commence par vérifier avec le Playwright Inspector que le locator correspond bien à ce que tu attends. Ensuite, assure-toi que la précondition d'apparition de l'élément est remplie.

```typescript
// TypeScript — debug: check what the locator resolves to
console.log(await page.getByRole('button', { name: 'Submit' }).count());
// If 0, the element is not in the DOM — check your selector or page state

// Correct approach: wait for the data to load first
await page.waitForResponse(resp =>
  resp.url().includes('/api/data') && resp.status() === 200
);
await expect(page.getByRole('button', { name: 'Submit' })).toBeVisible();
```

```javascript
// JavaScript — same approach
console.log(await page.getByRole('button', { name: 'Submit' }).count());

await page.waitForResponse(resp =>
  resp.url().includes('/api/data') && resp.status() === 200
);
await expect(page.getByRole('button', { name: 'Submit' })).toBeVisible();
```

**Voir aussi** : [core/locators.md](locators.md), [core/assertions-and-waiting.md](assertions-and-waiting.md)

---

### "locator.click: Error: strict mode violation"

**Cause** : Le locator correspond à plus d'un élément et le strict mode de Playwright (activé par défaut) refuse d'agir sur des correspondances ambiguës.

**Causes fréquentes** :
- Utilisation de `getByRole('button')` alors que plusieurs boutons existent sur la page
- Utilisation de `getByText('Save')` alors que « Save » et « Save as draft » sont tous deux présents
- Correspondance partielle du texte alors que `exact: true` est nécessaire
- Le même composant est rendu plusieurs fois (par exemple dans une liste)

**Correctif** : Rends le locator plus précis pour qu'il corresponde à exactement un élément.

```typescript
// TypeScript

// BAD — matches multiple buttons
await page.getByRole('button', { name: 'Save' }).click();

// GOOD — use exact matching
await page.getByRole('button', { name: 'Save', exact: true }).click();

// GOOD — scope to a specific container
await page.getByRole('dialog')
  .getByRole('button', { name: 'Save' }).click();

// GOOD — use .first(), .last(), .nth() when order is meaningful
await page.getByRole('listitem').first().click();

// GOOD — chain with filter for list items
await page.getByRole('listitem')
  .filter({ hasText: 'Project Alpha' })
  .getByRole('button', { name: 'Delete' }).click();
```

```javascript
// JavaScript

// BAD — matches multiple buttons
await page.getByRole('button', { name: 'Save' }).click();

// GOOD — use exact matching
await page.getByRole('button', { name: 'Save', exact: true }).click();

// GOOD — scope to a specific container
await page.getByRole('dialog')
  .getByRole('button', { name: 'Save' }).click();

// GOOD — use .first(), .last(), .nth() when order is meaningful
await page.getByRole('listitem').first().click();

// GOOD — chain with filter for list items
await page.getByRole('listitem')
  .filter({ hasText: 'Project Alpha' })
  .getByRole('button', { name: 'Delete' }).click();
```

**Voir aussi** : [core/locators.md](locators.md), [core/locator-strategy.md](locator-strategy.md)

---

### "Error: expect(locator).toBeVisible() failed"

**Cause** : Quand la sortie continue avec `Error: strict mode violation: ... resolved to N elements`, la cause racine est la même que pour la strict mode violation ci-dessus : le locator de l'assertion correspond à plusieurs éléments, donc Playwright ne sait pas sur lequel faire l'assertion. Si elle affiche plutôt `Expected: visible` avec `element(s) not found` (ou une valeur `Received:` non visible), l'élément est absent ou caché ; voir « waiting for locator('...') to be visible » plus haut.

**Causes fréquentes** :
- Identiques aux causes de la strict mode violation ci-dessus
- Écriture de `expect(page.locator('.item')).toBeVisible()` alors qu'il y a de nombreux éléments `.item`

**Correctif** : Restreins le locator à un seul élément (voir le correctif de la strict mode violation ci-dessus). Sinon, si tu veux volontairement vérifier toutes les correspondances :

```typescript
// TypeScript — assert count instead of visibility
await expect(page.getByRole('listitem')).toHaveCount(5);

// Or assert on a specific one
await expect(page.getByRole('listitem').first()).toBeVisible();

// Or assert all are visible with a loop
for (const item of await page.getByRole('listitem').all()) {
  await expect(item).toBeVisible();
}
```

```javascript
// JavaScript — assert count instead of visibility
await expect(page.getByRole('listitem')).toHaveCount(5);

// Or assert on a specific one
await expect(page.getByRole('listitem').first()).toBeVisible();

// Or assert all are visible with a loop
for (const item of await page.getByRole('listitem').all()) {
  await expect(item).toBeVisible();
}
```

**Voir aussi** : [core/locators.md](locators.md), [core/assertions-and-waiting.md](assertions-and-waiting.md)

---

### "locator.fill: Error: Element is not an <input>, <textarea> or [contenteditable] element"

**Cause** : `fill()` ne fonctionne que sur `<input>`, `<textarea>` ou les éléments avec `contenteditable`. Le locator a résolu un autre type d'élément (par exemple un `<div>`, un `<label>` ou le `<form>` lui-même).

**Causes fréquentes** :
- Localisation par le texte du label alors que le label et l'input ne sont pas correctement associés via `for`/`id`
- Utilisation de `getByText()` au lieu de `getByLabel()` ou `getByRole('textbox')`
- Composants personnalisés qui enveloppent le vrai `<input>` dans un `<div>` stylé
- Éditeurs de texte riche qui utilisent `contenteditable` sur un élément interne, pas sur le wrapper externe

**Correctif** : Cible l'élément input réel.

```typescript
// TypeScript

// BAD — targets the label, not the input
await page.getByText('Email').fill('user@example.com');

// GOOD — getByLabel finds the associated input
await page.getByLabel('Email').fill('user@example.com');

// GOOD — target by role
await page.getByRole('textbox', { name: 'Email' }).fill('user@example.com');

// For contenteditable rich text editors
await page.locator('[contenteditable="true"]').fill('Hello world');

// If fill() still doesn't work (e.g., custom widget), use keyboard input
await page.getByRole('textbox', { name: 'Email' }).click();
await page.keyboard.type('user@example.com');
```

```javascript
// JavaScript

// BAD — targets the label, not the input
await page.getByText('Email').fill('user@example.com');

// GOOD — getByLabel finds the associated input
await page.getByLabel('Email').fill('user@example.com');

// GOOD — target by role
await page.getByRole('textbox', { name: 'Email' }).fill('user@example.com');

// For contenteditable rich text editors
await page.locator('[contenteditable="true"]').fill('Hello world');

// If fill() still doesn't work (e.g., custom widget), use keyboard input
await page.getByRole('textbox', { name: 'Email' }).click();
await page.keyboard.type('user@example.com');
```

**Voir aussi** : [core/locators.md](locators.md), [core/forms-and-validation.md](forms-and-validation.md)

---

### "Element is not attached to the DOM"

**Cause** : Tu utilises l'ancienne API ElementHandle (ou un `waitForSelector` ciblé) et le handle est devenu obsolète : le nœud DOM sous-jacent a été supprimé ou remplacé par un re-render. Les locators ne lèvent pas d'erreur ici : le call log affiche `element was detached from the DOM, retrying` et Playwright refait la requête.

**Causes fréquentes** :
- Stockage d'un `elementHandle` dans une variable puis utilisation après une navigation ou un re-render React/Vue
- Utilisation de `page.$()` ou `page.$$()` au lieu de l'API Locator
- L'hydratation du framework remplace le nœud rendu côté serveur par un nœud rendu côté client

**Correctif** : Passe d'ElementHandle à Locator. Les locators refont la requête sur le DOM à chaque action et ne deviennent jamais obsolètes.

```typescript
// TypeScript

// BAD — stale handle
const button = await page.$('button.submit');
// ... page re-renders ...
await button!.click(); // Element is not attached to the DOM

// GOOD — locator always re-queries
const button = page.getByRole('button', { name: 'Submit' });
// ... page re-renders ...
await button.click(); // works fine
```

```javascript
// JavaScript

// BAD — stale handle
const button = await page.$('button.submit');
// ... page re-renders ...
await button.click(); // Element is not attached to the DOM

// GOOD — locator always re-queries
const button = page.getByRole('button', { name: 'Submit' });
// ... page re-renders ...
await button.click(); // works fine
```

**Voir aussi** : [core/locators.md](locators.md)

---

### "Error: locator.click: Timeout 30000ms exceeded"

**Cause** : L'élément a été trouvé dans le DOM mais n'était pas actionnable dans le délai imparti. « Actionnable » signifie visible, stable (sans animation), activé et non masqué par un autre élément.

Sous Playwright Test, ce message n'apparaît que si un timeout est défini pour l'appel ou dans la config (`actionTimeout`, `navigationTimeout`, option `timeout`) ; avec les valeurs par défaut (0), le test échoue à la place avec `Test timeout of 30000ms exceeded.`

**Causes fréquentes** :
- Un overlay, une modale ou un toast recouvre l'élément
- L'élément est désactivé (attribut `disabled` ou `aria-disabled="true"`)
- Une animation CSS n'est pas terminée (l'élément bouge encore)
- Un spinner de chargement recouvre le bouton
- L'élément est hors du viewport et l'auto-scroll de Playwright a échoué

**Correctif** : Identifie ce qui bloque l'action grâce aux traces, puis traite-le.

```typescript
// TypeScript

// Step 1: Enable tracing to diagnose
// In playwright.config.ts:
// use: { trace: 'on-first-retry' }
// Then run: npx playwright show-trace trace.zip

// Common fix: wait for the overlay to disappear
await expect(page.locator('.loading-overlay')).toBeHidden();
await page.getByRole('button', { name: 'Submit' }).click();

// Common fix: force click when you know the overlay is benign
// (use sparingly — this skips actionability checks)
await page.getByRole('button', { name: 'Submit' }).click({ force: true });

// Common fix: wait for the element to be enabled
await expect(page.getByRole('button', { name: 'Submit' })).toBeEnabled();
await page.getByRole('button', { name: 'Submit' }).click();
```

```javascript
// JavaScript

// Common fix: wait for the overlay to disappear
await expect(page.locator('.loading-overlay')).toBeHidden();
await page.getByRole('button', { name: 'Submit' }).click();

// Common fix: force click (use sparingly)
await page.getByRole('button', { name: 'Submit' }).click({ force: true });

// Common fix: wait for the element to be enabled
await expect(page.getByRole('button', { name: 'Submit' })).toBeEnabled();
await page.getByRole('button', { name: 'Submit' }).click();
```

**Voir aussi** : [core/assertions-and-waiting.md](assertions-and-waiting.md), [core/debugging.md](debugging.md)

---

### "<element> intercepts pointer events"

**Cause** : Une ligne de call log sous un timeout d'action (`retrying click action` ... `<div class="overlay"> intercepts pointer events`). L'élément a passé les vérifications visible/activé/stable, mais la vérification de la cible du clic a trouvé un autre élément au-dessus du point de clic.

**Causes fréquentes** :
- Un fond de modale, un bandeau de cookies, un toast ou un overlay de chargement recouvre la cible
- Un header ou footer sticky chevauche l'élément après l'auto-scroll
- Un wrapper transparent (par exemple le `<span>` stylé d'une checkbox personnalisée) se trouve au-dessus du vrai `<input>`

**Correctif** : Ferme l'élément nommé dans le log ou attends sa disparition, ou agis sur l'élément qui reçoit réellement le clic.

```typescript
// TypeScript
await page.getByRole('button', { name: 'Accept cookies' }).click();
await expect(page.locator('.overlay')).toBeHidden();
await page.getByRole('button', { name: 'Submit' }).click();

// Custom checkbox: click the visible label instead of the covered input
await page.getByText('I agree to the terms').click();
```

```javascript
// JavaScript
await page.getByRole('button', { name: 'Accept cookies' }).click();
await expect(page.locator('.overlay')).toBeHidden();
await page.getByRole('button', { name: 'Submit' }).click();

await page.getByText('I agree to the terms').click();
```

**Voir aussi** : [core/assertions-and-waiting.md](assertions-and-waiting.md)

---

### "element is not stable"

**Cause** : Une ligne de call log sous un timeout d'action (après `waiting for element to be visible, enabled and stable`). Playwright exige que la bounding box de l'élément reste identique pendant deux frames d'animation consécutives ; elle a continué à bouger ou à changer de taille.

**Causes fréquentes** :
- Une animation ou transition CSS infinie sur l'élément ou l'un de ses ancêtres (spinners, boutons qui pulsent)
- Un carrousel ou un marquee qui ne s'arrête jamais
- Des décalages de mise en page dus à du contenu qui se charge au-dessus de l'élément

**Correctif** : Désactive les animations ou attends que la mise en page se stabilise.

```typescript
// TypeScript — playwright.config.ts: emulate reduced motion (works if the app honors prefers-reduced-motion)
export default defineConfig({
  use: { contextOptions: { reducedMotion: 'reduce' } },
});

// Or wait for the content that causes the shift
await expect(page.getByTestId('banner')).toBeVisible();
await page.getByRole('button', { name: 'Submit' }).click();
```

```javascript
// JavaScript — playwright.config.js
module.exports = defineConfig({
  use: { contextOptions: { reducedMotion: 'reduce' } },
});
```

**Voir aussi** : [core/assertions-and-waiting.md](assertions-and-waiting.md)

---

### "element is outside of the viewport"

**Cause** : Une ligne de call log sous un timeout d'action : après le scroll, le point de clic de l'élément est toujours en dehors du viewport. Avec `force: true`, l'erreur est levée immédiatement sous la forme `Element is outside of the viewport`.

**Causes fréquentes** :
- L'élément est positionné hors écran (décalages négatifs, tiroirs en `transform: translateX(-100%)`)
- Un conteneur avec `overflow: hidden` rogne l'élément, qui ne peut donc pas être amené dans la vue par scroll
- Le viewport est trop petit pour une mise en page de taille fixe

**Correctif** : Ouvre le conteneur qui contient l'élément, ou agrandis le viewport.

```typescript
// TypeScript
await page.getByRole('button', { name: 'Menu' }).click(); // slide the drawer in first
await page.getByRole('link', { name: 'Settings' }).click();

await page.setViewportSize({ width: 1440, height: 900 });
```

```javascript
// JavaScript
await page.getByRole('button', { name: 'Menu' }).click();
await page.getByRole('link', { name: 'Settings' }).click();

await page.setViewportSize({ width: 1440, height: 900 });
```

**Voir aussi** : [core/locators.md](locators.md)

---

## Erreurs de navigation et de page

---

### "page.goto: net::ERR_CONNECTION_REFUSED"

**Cause** : Playwright n'a pas pu se connecter à l'URL cible. Le serveur ne tourne pas ou n'écoute pas sur l'hôte/le port attendu.

**Causes fréquentes** :
- Oubli de démarrer le serveur de dev avant de lancer les tests
- Le serveur de dev est sur un autre port que `baseURL` dans la config
- Le serveur écoute sur `127.0.0.1` mais le test utilise `localhost` (ou l'inverse) et l'OS les résout différemment
- En CI, l'étape de build/démarrage de l'application a échoué silencieusement
- Réseau des conteneurs Docker : l'app tourne dans un conteneur mais le test tente d'atteindre `localhost`

**Correctif** : Utilise l'option de config `webServer` pour que Playwright démarre et gère automatiquement le serveur de dev.

```typescript
// TypeScript — playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000, // 2 minutes for server start
  },
  use: {
    baseURL: 'http://localhost:3000',
  },
});
```

```javascript
// JavaScript — playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
  use: {
    baseURL: 'http://localhost:3000',
  },
});
```

**Voir aussi** : [core/configuration.md](configuration.md), [ci/ci-github-actions.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/ci-github-actions.md)

---

### "page.goto: Timeout 30000ms exceeded"

**Cause** : La page n'a pas atteint l'état `load` (par défaut) dans le délai de navigation. Le serveur a répondu mais la page a mis trop de temps à se charger complètement.

Sous Playwright Test, ce message n'apparaît que si un timeout est défini pour l'appel ou dans la config (`actionTimeout`, `navigationTimeout`, option `timeout`) ; avec les valeurs par défaut (0), le test échoue à la place avec `Test timeout of 30000ms exceeded.`

**Causes fréquentes** :
- Des assets volumineux (images, polices, scripts) ralentissent le chargement de la page
- Des scripts tiers (analytics, publicités) bloquent l'événement load
- La page effectue de nombreux appels API avant de devenir interactive
- Le serveur a répondu par une chaîne de redirections trop longue

**Correctif** : Utilise une option `waitUntil` plus adaptée ou augmente le timeout de navigation.

```typescript
// TypeScript

// Use 'domcontentloaded' instead of 'load' if you don't need all assets
await page.goto('/dashboard', { waitUntil: 'domcontentloaded' });

// Or increase the navigation timeout for known slow pages
await page.goto('/dashboard', { timeout: 60_000 });

// Or set it globally in config
// playwright.config.ts
export default defineConfig({
  use: {
    navigationTimeout: 60_000,
  },
});
```

```javascript
// JavaScript

await page.goto('/dashboard', { waitUntil: 'domcontentloaded' });

await page.goto('/dashboard', { timeout: 60_000 });

// playwright.config.js
module.exports = defineConfig({
  use: {
    navigationTimeout: 60_000,
  },
});
```

**Voir aussi** : [core/configuration.md](configuration.md)

---

### "Error: page.goto: Target page, context or browser has been closed"

**Cause** : La page ou le contexte du navigateur a été fermé alors que `goto()` était encore en cours. Cela arrive typiquement dans des race conditions de teardown/nettoyage. (Les anciennes versions de Playwright affichaient `Navigation failed because page was closed!`.)

**Causes fréquentes** :
- `afterEach` ou une fixture ferme la page/le contexte avant la fin de la navigation
- Un autre test ou hook a appelé `browser.close()` prématurément
- Un test a échoué et le nettoyage s'est exécuté alors qu'une navigation asynchrone était encore en attente
- Utilisation de `test.fixme()` ou `test.skip()` après le démarrage d'une opération asynchrone

**Correctif** : Fais en sorte que le nettoyage ne s'exécute qu'après la fin de toutes les opérations sur la page. Utilise les fixtures pour gérer le cycle de vie plutôt qu'un `afterEach` manuel.

```typescript
// TypeScript

// BAD — race condition between test body and cleanup
test.afterEach(async ({ page }) => {
  await page.close(); // may race with in-flight navigation
});

// GOOD — let Playwright manage page lifecycle via fixtures
// Playwright automatically creates and destroys the page per test
// No manual cleanup needed

// If you need custom cleanup, make sure to await all navigation first
test('navigates to dashboard', async ({ page }) => {
  const responsePromise = page.waitForResponse('**/api/user');
  await page.goto('/dashboard');
  await responsePromise; // ensure all async ops are done
  // test assertions here
});
```

```javascript
// JavaScript — same pattern

test('navigates to dashboard', async ({ page }) => {
  const responsePromise = page.waitForResponse('**/api/user');
  await page.goto('/dashboard');
  await responsePromise;
  // test assertions here
});
```

**Voir aussi** : [core/fixtures-and-hooks.md](fixtures-and-hooks.md)

---

### "page.waitForNavigation: Timeout 30000ms exceeded"

**Cause** : `waitForNavigation()` a attendu une navigation de page complète qui n'a jamais eu lieu. Dans les SPA, le routage côté client ne déclenche pas d'événement de navigation.

Sous Playwright Test, ce message n'apparaît que si un timeout est défini pour l'appel ou dans la config (`actionTimeout`, `navigationTimeout`, option `timeout`) ; avec les valeurs par défaut (0), le test échoue à la place avec `Test timeout of 30000ms exceeded.`

**Causes fréquentes** :
- Utilisation de `waitForNavigation()` avec une SPA qui utilise React Router, Vue Router ou la navigation côté client de Next.js
- La navigation a déjà eu lieu avant l'appel de `waitForNavigation()` (race condition)
- Utilisation du pattern déprécié alors que `waitForURL()` est le bon remplaçant

**Correctif** : Remplace `waitForNavigation()` par `waitForURL()`, qui fonctionne aussi bien avec les SPA qu'avec les chargements de page classiques.

```typescript
// TypeScript

// BAD — deprecated, race-prone, doesn't work with SPA routing
await page.waitForNavigation();

// GOOD — works with SPAs and full navigations
await page.getByRole('link', { name: 'Dashboard' }).click();
await page.waitForURL('**/dashboard');

// GOOD — combine with glob patterns
await page.waitForURL(/\/dashboard\/\d+/);

// GOOD — for SPA route changes, assert on visible content
await page.getByRole('link', { name: 'Settings' }).click();
await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible();
```

```javascript
// JavaScript

// BAD — deprecated, race-prone
await page.waitForNavigation();

// GOOD — works with SPAs and full navigations
await page.getByRole('link', { name: 'Dashboard' }).click();
await page.waitForURL('**/dashboard');

// GOOD — combine with glob patterns
await page.waitForURL(/\/dashboard\/\d+/);

// GOOD — for SPA route changes, assert on visible content
await page.getByRole('link', { name: 'Settings' }).click();
await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible();
```

**Voir aussi** : [core/assertions-and-waiting.md](assertions-and-waiting.md)

---

### "Error: frame.goto: Frame was detached"

**Cause** : L'iframe a été retirée du DOM (détachée) pendant que Playwright y naviguait ou interagissait avec elle.

**Causes fréquentes** :
- La page parente a fait un re-render et recréé l'élément iframe
- Le JavaScript de la page parente a retiré puis rajouté l'iframe
- Un changement de route de la SPA a démonté le composant contenant l'iframe
- Une iframe publicitaire s'est rechargée d'elle-même

**Correctif** : Récupère à nouveau la référence de la frame après la mise à jour de la page parente.

```typescript
// TypeScript

// BAD — frame reference becomes stale
const frame = page.frameLocator('#my-iframe');
// ... parent page re-renders ...
await frame.getByRole('button').click(); // Frame was detached

// GOOD — use frameLocator (re-evaluates each time)
// frameLocator itself is lazy, but the frame it points to must exist
await expect(page.frameLocator('#my-iframe').getByRole('button')).toBeVisible();
await page.frameLocator('#my-iframe').getByRole('button').click();

// GOOD — wait for the iframe to be present after a re-render
await expect(page.locator('#my-iframe')).toBeAttached();
await page.frameLocator('#my-iframe').getByRole('button').click();
```

```javascript
// JavaScript

// GOOD — frameLocator re-evaluates lazily
await expect(page.frameLocator('#my-iframe').getByRole('button')).toBeVisible();
await page.frameLocator('#my-iframe').getByRole('button').click();

// GOOD — wait for the iframe to be present after a re-render
await expect(page.locator('#my-iframe')).toBeAttached();
await page.frameLocator('#my-iframe').getByRole('button').click();
```

**Voir aussi** : [core/iframes-and-shadow-dom.md](iframes-and-shadow-dom.md)

---

## Erreurs du framework de test

---

### "Error: Test timeout of 30000ms exceeded"

**Cause** : Le test entier (hooks et assertions compris) ne s'est pas terminé dans le timeout de test configuré.

**Causes fréquentes** :
- Attente d'un élément qui n'apparaît jamais (mauvais locator, données manquantes)
- `page.waitForEvent()` jamais résolu : l'événement attendu ne se déclenche jamais
- Environnement de test lent (CI avec des ressources limitées)
- Trop d'actions séquentielles dans un seul test
- Un hook `beforeEach` effectue une préparation coûteuse (login, seeding de données)

**Correctif** : Identifie l'étape lente avec `test.step()` et les traces, puis corrige la cause racine ou ajuste le timeout.

```typescript
// TypeScript

// Increase timeout for a specific slow test
test('generates large report', async ({ page }) => {
  test.setTimeout(120_000); // 2 minutes for this test only
  // ...
});

// Increase timeout globally in config
// playwright.config.ts
export default defineConfig({
  timeout: 60_000, // 60 seconds per test
});

// Better: diagnose with test.step() to find what's slow
test('checkout flow', async ({ page }) => {
  await test.step('add item to cart', async () => {
    await page.goto('/products');
    await page.getByRole('button', { name: 'Add to Cart' }).click();
  });

  await test.step('complete checkout', async () => {
    await page.getByRole('link', { name: 'Cart' }).click();
    await page.getByRole('button', { name: 'Checkout' }).click();
  });
});
```

```javascript
// JavaScript

test('generates large report', async ({ page }) => {
  test.setTimeout(120_000);
  // ...
});

// playwright.config.js
module.exports = defineConfig({
  timeout: 60_000,
});

test('checkout flow', async ({ page }) => {
  await test.step('add item to cart', async () => {
    await page.goto('/products');
    await page.getByRole('button', { name: 'Add to Cart' }).click();
  });

  await test.step('complete checkout', async () => {
    await page.getByRole('link', { name: 'Cart' }).click();
    await page.getByRole('button', { name: 'Checkout' }).click();
  });
});
```

**Voir aussi** : [core/configuration.md](configuration.md), [core/debugging.md](debugging.md)

---

### "Error: expect(page).toHaveScreenshot(expected) failed"

**Cause** : La capture d'écran actuelle ne correspond pas à la baseline enregistrée ; la sortie indique `N pixels (ratio 0.02 of all image pixels) are different.` Les snapshots de texte et de buffer échouent de la même façon, avec `expect(string).toMatchSnapshot(expected) failed`.

**Causes fréquentes** :
- Changements d'UI légitimes qui nécessitent de mettre à jour le snapshot
- Rendu différent entre le local et la CI (polices, anti-aliasing, rendu au niveau de l'OS)
- Contenu dynamique (timestamps, IDs aléatoires, publicités) qui change d'une exécution à l'autre
- Tailles de viewport ou réglages d'émulation d'appareil différents selon les environnements

**Correctif** : Mets à jour le snapshot si le changement est voulu, ou masque/cache les zones dynamiques.

```typescript
// TypeScript

// Update snapshots after intentional changes
// Run: npx playwright test --update-snapshots

// Mask dynamic content before taking a screenshot
await expect(page).toHaveScreenshot('dashboard.png', {
  mask: [
    page.locator('.timestamp'),
    page.locator('.random-ad'),
  ],
  maxDiffPixelRatio: 0.01, // allow 1% pixel difference
});

// Use text snapshot with a sanitizer for dynamic values
const content = await page.getByRole('main').textContent();
const sanitized = content!.replace(/\d{4}-\d{2}-\d{2}/g, 'DATE');
expect(sanitized).toMatchSnapshot('dashboard-content.txt');
```

```javascript
// JavaScript

// Update snapshots: npx playwright test --update-snapshots

await expect(page).toHaveScreenshot('dashboard.png', {
  mask: [
    page.locator('.timestamp'),
    page.locator('.random-ad'),
  ],
  maxDiffPixelRatio: 0.01,
});

const content = await page.getByRole('main').textContent();
const sanitized = content.replace(/\d{4}-\d{2}-\d{2}/g, 'DATE');
expect(sanitized).toMatchSnapshot('dashboard-content.txt');
```

**Voir aussi** : [core/visual-regression.md](visual-regression.md)

---

### "A snapshot doesn't exist at ..., writing actual."

**Cause** : Première exécution de `toHaveScreenshot()` ou `toMatchSnapshot()` : il n'existe pas encore de fichier de baseline. Playwright écrit l'image actuelle comme nouvelle baseline et fait échouer le test une fois. Avec `--update-snapshots=none`, le message se termine à `.` et rien n'est écrit.

**Causes fréquentes** :
- Un nouveau test visuel, ou une capture renommée
- Exécution sur un nouvel OS ou navigateur : les baselines sont propres à chaque plateforme (`-chromium-linux.png` vs `-chromium-darwin.png`)
- La CI récupère le dépôt sans le dossier de snapshots commité

**Correctif** : Relis la baseline écrite, commite-la et relance. Génère les baselines de CI dans le même environnement que celui de la CI.

```bash
npx playwright test --update-snapshots=missing
# Linux baselines from macOS/Windows: run inside the official image
docker run --rm --init --ipc=host -v $(pwd):/work -w /work mcr.microsoft.com/playwright:v1.64.0-noble npx playwright test --update-snapshots
```

**Voir aussi** : [core/visual-regression.md](visual-regression.md)

---

### "Playwright Test did not expect test() to be called here."

**Cause** : `test()` (ou `test.describe()`, `test.beforeEach()`, ...) s'est exécuté en dehors d'un fichier de test chargé par le runner.

**Causes fréquentes** :
- Appel de `test()` dans `playwright.config.ts` ou dans un fichier qu'il importe
- Deux versions différentes de `@playwright/test` installées (souvent, une dépendance embarque la sienne)
- Appel de `test()` dans un callback `async` de `test.describe()` : seuls les callbacks synchrones sont supportés
- Exécution directe d'un fichier spec avec `node` ou `ts-node`

**Correctif** :

```bash
npm ls @playwright/test   # must list exactly one version
npx playwright test       # never node tests/example.spec.ts
```

```typescript
// TypeScript — BAD: test() after an await inside an async describe. If the awaited promise is
// already resolved there's no error, but the test silently lands outside the describe.
test.describe('suite', async () => { await setup(); test('a', async () => {}); });
// GOOD
test.describe('suite', () => { test('a', async () => {}); });
```

**Voir aussi** : [core/configuration.md](configuration.md)

---

### "Error: duplicate test title"

**Cause** : Deux tests du même fichier ont le même titre complet (titres des describe + titre du test). Message complet : `Error: duplicate test title "<titles joined by ›>", first declared in <file>:<line>`. L'exécution échoue avant qu'aucun test ne s'exécute.

**Causes fréquentes** :
- Copier-coller d'un test sans le renommer
- Génération de tests dans une boucle avec un titre qui n'inclut pas la variable de boucle

**Correctif** : Rends chaque titre unique dans le fichier.

```typescript
// TypeScript
for (const user of ['admin', 'viewer']) {
  test(`login works for ${user}`, async ({ page }) => { /* ... */ });
}
```

```javascript
// JavaScript
for (const user of ['admin', 'viewer']) {
  test(`login works for ${user}`, async ({ page }) => { /* ... */ });
}
```

**Voir aussi** : [core/test-organization.md](test-organization.md)

---

### "Error: browserType.launch: Executable doesn't exist"

**Cause** : Les binaires des navigateurs Playwright ne sont pas installés sur cette machine, ou ils ont été installés pour une autre version de Playwright.

**Causes fréquentes** :
- Clone récent d'un projet sans avoir lancé l'étape d'installation
- Mise à jour de `@playwright/test` sans réinstaller les navigateurs
- Environnement de CI sans l'étape d'installation
- Utilisation de `npm ci`, qui nettoie `node_modules` mais ne déclenche pas le script postinstall d'installation des navigateurs
- Plusieurs versions de Playwright installées (globale vs locale)

**Correctif** : Installe les navigateurs.

```bash
# Install all browsers
npx playwright install

# Install only the browser you need (faster in CI)
npx playwright install chromium

# Install browsers with OS dependencies (needed in CI/Docker)
npx playwright install --with-deps

# If you're on a CI Dockerfile, add this to your Dockerfile
# RUN npx playwright install --with-deps chromium
```

Pour les pipelines de CI, inclus toujours l'étape d'installation :

```yaml
# GitHub Actions example
- name: Install Playwright Browsers
  run: npx playwright install --with-deps
```

**Voir aussi** : [ci/ci-github-actions.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/ci-github-actions.md), [ci/docker-and-containers.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/docker-and-containers.md)

---

### "Error: Cannot use import statement outside a module"

**Cause** : Node.js exécute le fichier de test en CommonJS alors que le fichier utilise la syntaxe ES module `import` sans la bonne configuration.

**Causes fréquentes** :
- `tsconfig.json` manquant ou mal configuré
- Utilisation de fichiers `.ts` sans que `@playwright/test` résolve correctement TypeScript
- `package.json` n'a pas `"type": "module"` alors que les fichiers de test utilisent `import`
- Exécution directe des fichiers de test avec `node` au lieu de passer par `npx playwright test`
- Configuration Babel ou ts-node en conflit

**Correctif** : Assure-toi que TypeScript est correctement configuré et lance toujours les tests via la CLI Playwright.

```bash
# Always run tests through the Playwright CLI — never with node directly
npx playwright test

# NOT this:
# node tests/example.spec.ts  <-- will fail
```

```typescript
// TypeScript — tsconfig.json (minimal working config)
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  }
}
```

Si tu utilises JavaScript sans TypeScript :

```javascript
// JavaScript — ensure package.json has "type": "module"
// Or rename files to .mjs

// In playwright.config.js — use require if package.json lacks "type": "module"
const { defineConfig } = require('@playwright/test');
module.exports = defineConfig({ /* ... */ });
```

**Voir aussi** : [core/configuration.md](configuration.md)

---

### "Fixture "xxx" has already been registered as a { scope: 'test' } fixture"

**Cause** : Un `test.extend()` ultérieur (ou une entrée de `mergeTests()`) redéfinit une fixture existante avec un réglage `scope`, `auto` ou `option` différent. Surcharger une fixture avec le même nom et les mêmes options est autorisé ; changer ces options ne l'est pas. La même erreur apparaît sous la forme `... registered as a { auto: ... }` ou `... { option: ... }` fixture, et indique le fichier où se trouve la première définition.

**Causes fréquentes** :
- Surcharge d'une fixture native ou partagée de portée test avec `{ scope: 'worker' }` (ou l'inverse)
- Deux fichiers de fixtures définissent le même nom, l'un comme fixture `option: true` et l'autre comme fixture simple
- Ajout de `{ auto: true }` dans la surcharge d'une fixture qui n'était pas auto

**Correctif** : Conserve les options de la fixture d'origine quand tu la surcharges, ou donne un autre nom à la nouvelle fixture.

```typescript
// TypeScript

// BAD — base defines `account` as test-scoped; this redefines it as worker-scoped
export const test = base.extend<{}, { account: Account }>({
  account: [async ({}, use) => { await use(await createAccount()); }, { scope: 'worker' }],
});

// GOOD — new name for the worker-scoped variant
export const test = base.extend<{}, { workerAccount: Account }>({
  workerAccount: [async ({}, use) => { await use(await createAccount()); }, { scope: 'worker' }],
});
```

```javascript
// JavaScript

// GOOD — new name for the worker-scoped variant
const test = base.extend({
  workerAccount: [async ({}, use) => { await use(await createAccount()); }, { scope: 'worker' }],
});
```

**Voir aussi** : [core/fixtures-and-hooks.md](fixtures-and-hooks.md)

---

## Erreurs réseau et API

---

### "Error: apiRequestContext.get: connect ECONNREFUSED"

**Cause** : La requête API faite via `request.get()` (ou `.post()`, `.put()`, etc.) n'a pas pu se connecter au serveur cible. Même problème de fond que `page.goto: net::ERR_CONNECTION_REFUSED`, mais pour les tests d'API.

**Causes fréquentes** :
- Serveur d'API non démarré lors de l'utilisation de la fixture `request`
- `baseURL` incorrect dans la config ou dans le contexte de requête API
- Lancement de tests d'API contre un service qui n'a pas encore démarré
- En CI, le conteneur du service d'API n'est pas prêt

**Correctif** : Assure-toi que le serveur d'API tourne. Utilise la config `webServer` pour le démarrer automatiquement, ou ajoute un healthcheck.

```typescript
// TypeScript — playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  webServer: [
    {
      command: 'npm run start:api',
      url: 'http://localhost:4000/health',
      reuseExistingServer: !process.env.CI,
    },
    {
      command: 'npm run start:web',
      url: 'http://localhost:3000',
      reuseExistingServer: !process.env.CI,
    },
  ],
  use: {
    baseURL: 'http://localhost:3000',
  },
});

// In tests, use the request fixture with explicit baseURL for API calls
test('fetch users', async ({ request }) => {
  const response = await request.get('http://localhost:4000/api/users');
  expect(response.ok()).toBeTruthy();
});
```

```javascript
// JavaScript — playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  webServer: [
    {
      command: 'npm run start:api',
      url: 'http://localhost:4000/health',
      reuseExistingServer: !process.env.CI,
    },
    {
      command: 'npm run start:web',
      url: 'http://localhost:3000',
      reuseExistingServer: !process.env.CI,
    },
  ],
  use: {
    baseURL: 'http://localhost:3000',
  },
});
```

**Voir aussi** : [core/api-testing.md](api-testing.md), [core/configuration.md](configuration.md)

---

## Erreurs d'authentification et d'état

---

### "Error reading storage state from ... ENOENT: no such file or directory"

**Cause** : Le chemin `storageState` référencé dans la config ou le test ne pointe pas vers un fichier existant, donc `browser.newContext` échoue avec `Error reading storage state from playwright/.auth/user.json:` suivi de `ENOENT: no such file or directory, open '...'`. Le fichier d'état d'authentification n'a pas encore été généré.

**Causes fréquentes** :
- Lancement des tests avant le projet de setup d'authentification
- Le `globalSetup` ou le projet de setup d'authentification ne s'est pas terminé correctement
- Le chemin du fichier dans la config ne correspond pas à celui utilisé dans le setup
- `.gitignore` exclut le fichier de storage state et il n'a pas été régénéré après un clone récent
- Le cache de CI a expiré et le fichier d'état n'a pas été recréé

**Correctif** : Assure-toi que le setup d'authentification s'exécute en premier et que le chemin du fichier est cohérent.

```typescript
// TypeScript — playwright.config.ts
import { defineConfig } from '@playwright/test';

const authFile = 'playwright/.auth/user.json';

export default defineConfig({
  projects: [
    // Setup project runs first and creates the auth state file
    {
      name: 'setup',
      testMatch: /.*\.setup\.ts/,
    },
    {
      name: 'chromium',
      use: {
        storageState: authFile,
      },
      dependencies: ['setup'], // ensures setup runs first
    },
  ],
});

// auth.setup.ts
import { test as setup, expect } from '@playwright/test';

const authFile = 'playwright/.auth/user.json';

setup('authenticate', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');
  // Save the authenticated state
  await page.context().storageState({ path: authFile });
});
```

```javascript
// JavaScript — playwright.config.js
const { defineConfig } = require('@playwright/test');

const authFile = 'playwright/.auth/user.json';

module.exports = defineConfig({
  projects: [
    {
      name: 'setup',
      testMatch: /.*\.setup\.js/,
    },
    {
      name: 'chromium',
      use: {
        storageState: authFile,
      },
      dependencies: ['setup'],
    },
  ],
});

// auth.setup.js
const { test: setup, expect } = require('@playwright/test');

const authFile = 'playwright/.auth/user.json';

setup('authenticate', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');
  await page.context().storageState({ path: authFile });
});
```

Assure-toi que le dossier d'authentification existe et figure dans `.gitignore` :

```bash
mkdir -p playwright/.auth
echo "playwright/.auth/" >> .gitignore
```

**Voir aussi** : [core/authentication.md](authentication.md), [core/auth-flows.md](auth-flows.md)

---

### "Error: Target page, context or browser has been closed"

**Cause** : Du code a tenté d'utiliser un objet `page`, `context` ou `browser` déjà fermé ou libéré.

**Causes fréquentes** :
- Utilisation d'une référence `page` après l'appel de `page.close()`
- Stockage d'une `page` ou d'un `context` dans une variable de niveau module et réutilisation entre les tests
- Une fixture a détruit le contexte du navigateur alors qu'un callback asynchrone était encore en cours
- Un `beforeAll` a créé un contexte qui a été fermé avant que tous les tests aient fini de l'utiliser
- Utilisation manuelle de `browser.newContext()` en oubliant de gérer son cycle de vie

**Correctif** : Ne stocke jamais de références de page/contexte dans un état mutable partagé. Utilise les fixtures Playwright pour gérer le cycle de vie.

```typescript
// TypeScript

// BAD — shared module-level variable
let sharedPage: Page;
test.beforeAll(async ({ browser }) => {
  sharedPage = await browser.newPage();
});
test.afterAll(async () => {
  await sharedPage.close();
});
test('first', async () => {
  await sharedPage.goto('/'); // might fail if afterAll from another describe ran first
});

// GOOD — use the built-in page fixture (one per test, auto-managed)
test('first', async ({ page }) => {
  await page.goto('/'); // always a fresh, open page
});

// GOOD — for shared state across tests, use a worker-scoped fixture
import { test as base } from '@playwright/test';

export const test = base.extend<{}, { adminContext: BrowserContext }>({
  adminContext: [async ({ browser }, use) => {
    const context = await browser.newContext();
    await use(context);
    await context.close();
  }, { scope: 'worker' }],
});
```

```javascript
// JavaScript

// GOOD — use the built-in page fixture
test('first', async ({ page }) => {
  await page.goto('/');
});

// GOOD — for shared state, use a worker-scoped fixture
const { test: base } = require('@playwright/test');

const test = base.extend({
  adminContext: [async ({ browser }, use) => {
    const context = await browser.newContext();
    await use(context);
    await context.close();
  }, { scope: 'worker' }],
});
```

**Voir aussi** : [core/fixtures-and-hooks.md](fixtures-and-hooks.md)

---

## Erreurs spécifiques à la CI

---

### "Error: browserType.launch: Failed to launch the browser process."

**Cause** : Le processus du navigateur s'est arrêté immédiatement après son lancement, généralement parce que des dépendances système requises manquent dans l'environnement de CI. La section `Browser logs:` qui suit nomme la bibliothèque manquante ou le problème de sandbox. (Les anciennes versions de Playwright affichaient `Browser closed unexpectedly`.)

**Causes fréquentes** :
- Exécution sur une image Docker minimale (par exemple `node:alpine`) sans les dépendances du navigateur
- Bibliothèques partagées manquantes (`libgbm`, `libnss3`, `libatk-bridge`, etc.) sur une CI Linux
- Mémoire partagée insuffisante (`/dev/shm` trop petit) : les navigateurs utilisent la mémoire partagée pour le rendu
- Exécution en root dans Docker sans `--no-sandbox` (Chromium refuse de tourner en root avec la sandbox)
- Kill pour manque de mémoire en CI (le processus du navigateur est tué par l'OOM killer de l'OS)

**Correctif** : Installe les dépendances système et configure l'environnement.

```bash
# Install browsers with their OS dependencies (recommended)
npx playwright install --with-deps chromium

# If using Docker, use the official Playwright image
# Dockerfile
FROM mcr.microsoft.com/playwright:v1.64.0-noble
WORKDIR /app
COPY . .
RUN npm ci
RUN npx playwright install chromium
CMD ["npx", "playwright", "test"]
```

Pour les problèmes de mémoire partagée :

```yaml
# GitHub Actions — increase /dev/shm
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: mcr.microsoft.com/playwright:v1.64.0-noble
      options: --shm-size=2gb

# Docker run — increase shared memory
# docker run --shm-size=2gb my-test-image
```

Pour l'exécution en root dans Docker :

```typescript
// TypeScript — playwright.config.ts (only for Docker/CI)
export default defineConfig({
  use: {
    launchOptions: {
      args: process.env.CI ? ['--no-sandbox', '--disable-setuid-sandbox'] : [],
    },
  },
});
```

```javascript
// JavaScript — playwright.config.js
module.exports = defineConfig({
  use: {
    launchOptions: {
      args: process.env.CI ? ['--no-sandbox', '--disable-setuid-sandbox'] : [],
    },
  },
});
```

**Voir aussi** : [ci/ci-github-actions.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/ci-github-actions.md), [ci/docker-and-containers.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/docker-and-containers.md)

---

### "Error: Playwright Test needs to be invoked via 'npx playwright test' and excluded from Jest test runs."

**Cause** : Jest a chargé un fichier de test Playwright. Playwright lève cette erreur quand il détecte qu'il s'exécute dans un worker Jest. (Lancer un spec directement avec `node` produit à la place « Playwright Test did not expect test() to be called here. » ; voir Erreurs du framework de test.)

**Causes fréquentes** :
- Le `testMatch` par défaut de Jest récupère les fichiers `*.spec.ts` du dossier de tests Playwright
- Lancement de `npm test` (Jest) à la racine d'un projet qui contient aussi des tests Playwright
- Une extension Jest d'IDE qui exécute automatiquement chaque fichier spec

**Correctif** : Garde les tests Playwright dans leur propre dossier, exclus-le de Jest, et lance-les avec la CLI Playwright.

```javascript
// jest.config.js
module.exports = {
  testPathIgnorePatterns: ['/node_modules/', '<rootDir>/e2e/'],
};
```

```bash
npx playwright test                           # run all tests
npx playwright test tests/login.spec.ts       # run specific file

# package.json
# "scripts": { "test": "jest", "test:e2e": "playwright test" }
npm run test:e2e
```

**Voir aussi** : [core/configuration.md](configuration.md)

---

## Autres erreurs courantes

---

### "Error: page.evaluate: Execution context was destroyed"

**Cause** : La page a navigué ou s'est rechargée pendant que `page.evaluate()` exécutait du JavaScript dans le contexte du navigateur.

**Causes fréquentes** :
- Appel de `evaluate()` alors que la page est en pleine navigation
- Un timer ou un événement de la page déclenche une redirection pendant l'évaluation
- Exécution de `evaluate()` dans un `beforeEach` qui entre en concurrence avec `page.goto()`

**Correctif** : Assure-toi que la page est stable avant d'évaluer.

```typescript
// TypeScript

// BAD — evaluate races with navigation
await page.goto('/dashboard');
const title = await page.evaluate(() => document.title); // context might be destroyed

// GOOD — wait for load state first
await page.goto('/dashboard');
await page.waitForLoadState('domcontentloaded');
const title = await page.evaluate(() => document.title);

// GOOD — prefer locator-based assertions (no evaluate needed)
await page.goto('/dashboard');
await expect(page).toHaveTitle('Dashboard');
```

```javascript
// JavaScript

// GOOD — wait for load state first
await page.goto('/dashboard');
await page.waitForLoadState('domcontentloaded');
const title = await page.evaluate(() => document.title);

// GOOD — prefer locator-based assertions
await page.goto('/dashboard');
await expect(page).toHaveTitle('Dashboard');
```

**Voir aussi** : [core/assertions-and-waiting.md](assertions-and-waiting.md)

---

### "Error: page.screenshot: Cannot take screenshot larger than 32767 pixels on any dimension"

**Cause** : WebKit ne peut pas capturer une image de plus de 32767 pixels de haut ou de large. Cela arrive avec les captures pleine page de pages très longues.

**Causes fréquentes** :
- `page.screenshot({ fullPage: true })` sur une page à défilement infini
- Pages avec un contenu extrêmement haut (longs tableaux de données, historiques de chat)
- Bugs CSS qui créent des hauteurs d'éléments énormes

**Correctif** : Découpe la capture sur une région précise ou limite le viewport.

```typescript
// TypeScript

// BAD — might exceed size limits on tall pages
await page.screenshot({ fullPage: true, path: 'full.png' });

// GOOD — clip to a specific region
await page.screenshot({
  path: 'clipped.png',
  clip: { x: 0, y: 0, width: 1280, height: 2000 },
});

// GOOD — screenshot a specific element instead
await page.getByRole('main').screenshot({ path: 'main-content.png' });

// GOOD — set a reasonable viewport before full-page screenshot
await page.setViewportSize({ width: 1280, height: 720 });
await page.screenshot({ fullPage: true, path: 'full.png' });
```

```javascript
// JavaScript

// GOOD — clip to a specific region
await page.screenshot({
  path: 'clipped.png',
  clip: { x: 0, y: 0, width: 1280, height: 2000 },
});

// GOOD — screenshot a specific element
await page.getByRole('main').screenshot({ path: 'main-content.png' });
```

**Voir aussi** : [core/visual-regression.md](visual-regression.md)

---

### "Error: expect(locator).toBeAttached() failed"

**Cause** : L'élément n'est jamais entré dans le DOM pendant le timeout de l'assertion (`Expected: attached`). Contrairement à `toBeVisible()`, `toBeAttached()` vérifie seulement la présence dans le DOM, mais l'élément n'a jamais été rendu du tout.

**Causes fréquentes** :
- Le composant est rendu de façon conditionnelle et la condition n'est pas remplie
- Une requête réseau qui fournit les données n'est pas terminée
- Sélecteur incorrect qui ne correspond à aucun élément
- L'élément est rendu par un chunk chargé en lazy loading qui n'a pas encore été téléchargé

**Correctif** : Vérifie la précondition de rendu de l'élément.

```typescript
// TypeScript

// Ensure the data loads before asserting
await page.goto('/users');
await page.waitForResponse(resp => resp.url().includes('/api/users'));
await expect(page.getByRole('table')).toBeAttached();

// For lazy-loaded content, wait longer or trigger the load
await page.getByRole('tab', { name: 'Advanced' }).click();
await expect(page.getByTestId('advanced-panel')).toBeAttached({ timeout: 10_000 });
```

```javascript
// JavaScript

await page.goto('/users');
await page.waitForResponse(resp => resp.url().includes('/api/users'));
await expect(page.getByRole('table')).toBeAttached();

await page.getByRole('tab', { name: 'Advanced' }).click();
await expect(page.getByTestId('advanced-panel')).toBeAttached({ timeout: 10_000 });
```

**Voir aussi** : [core/assertions-and-waiting.md](assertions-and-waiting.md), [core/locators.md](locators.md)

---

### "Protocol error (Target.createTarget): Failed to create web contents"

**Cause** : Chromium n'a pas pu créer une nouvelle page, généralement par épuisement des ressources. Le headless shell signale `Failed to create web contents` ; Chrome en mode headed signale `Failed to open a new tab`.

**Causes fréquentes** :
- Ouverture de trop nombreuses pages ou contextes sans les fermer
- Fuite mémoire dans les tests : chaque test ouvre un contexte sans jamais le fermer
- Lancement de nombreux workers en parallèle sur une machine de CI aux ressources limitées
- Le processus du navigateur est instable après un crash précédent

**Correctif** : Réduis le parallélisme, ferme les contextes inutilisés, ou utilise moins de workers.

```typescript
// TypeScript — playwright.config.ts

export default defineConfig({
  // Reduce parallelism if resources are limited
  workers: process.env.CI ? 2 : undefined,

  // Limit to one browser context per worker
  fullyParallel: false, // run test files serially within a worker
});
```

```javascript
// JavaScript — playwright.config.js

module.exports = defineConfig({
  workers: process.env.CI ? 2 : undefined,
  fullyParallel: false,
});
```

Si tu crées des contextes manuellement, ferme-les toujours :

```typescript
// TypeScript
test('multi-user test', async ({ browser }) => {
  const userContext = await browser.newContext();
  const adminContext = await browser.newContext();
  try {
    const userPage = await userContext.newPage();
    const adminPage = await adminContext.newPage();
    // ... test logic
  } finally {
    await userContext.close();
    await adminContext.close();
  }
});
```

```javascript
// JavaScript
test('multi-user test', async ({ browser }) => {
  const userContext = await browser.newContext();
  const adminContext = await browser.newContext();
  try {
    const userPage = await userContext.newPage();
    const adminPage = await adminContext.newPage();
    // ... test logic
  } finally {
    await userContext.close();
    await adminContext.close();
  }
});
```

**Voir aussi** : [ci/parallel-and-sharding.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/parallel-and-sharding.md), [core/multi-user-and-collaboration.md](multi-user-and-collaboration.md)

---

### "Error: expect(locator).toHaveText(expected) failed"

**Cause** : Quand il est suivi de `Error: strict mode violation: ... resolved to N elements`, le locator correspond à plusieurs éléments. Une attente de type chaîne ou regex est stricte et exige exactement un élément ; seule la forme tableau accepte plusieurs correspondances.

**Causes fréquentes** :
- Utilisation d'un locator trop large comme `page.locator('.item')` qui correspond à une liste
- Attente d'un seul titre alors que le sélecteur en trouve plusieurs
- Locator non restreint à un conteneur précis

**Correctif** : Restreins le locator à un seul élément ou utilise la forme tableau de `toHaveText()`.

```typescript
// TypeScript

// BAD — locator matches multiple elements
await expect(page.locator('.item')).toHaveText('First Item');

// GOOD — narrow to one element
await expect(page.locator('.item').first()).toHaveText('First Item');

// GOOD — assert against an array when multiple elements are expected
await expect(page.locator('.item')).toHaveText([
  'First Item',
  'Second Item',
  'Third Item',
]);

// GOOD — use a more specific locator
await expect(page.getByRole('heading', { level: 1 })).toHaveText('Welcome');
```

```javascript
// JavaScript

// GOOD — narrow to one element
await expect(page.locator('.item').first()).toHaveText('First Item');

// GOOD — assert against an array
await expect(page.locator('.item')).toHaveText([
  'First Item',
  'Second Item',
  'Third Item',
]);

// GOOD — use a more specific locator
await expect(page.getByRole('heading', { level: 1 })).toHaveText('Welcome');
```

**Voir aussi** : [core/assertions-and-waiting.md](assertions-and-waiting.md), [core/locators.md](locators.md)

---

### "Error: page.waitForSelector: Timeout 30000ms exceeded"

**Cause** : `page.waitForSelector()` a expiré. Cette méthode est déconseillée au profit des web-first assertions ou de `locator.waitFor()`.

Sous Playwright Test, ce message n'apparaît que si un timeout est défini pour l'appel ou dans la config (`actionTimeout`, `navigationTimeout`, option `timeout`) ; avec les valeurs par défaut (0), le test échoue à la place avec `Test timeout of 30000ms exceeded.`

**Causes fréquentes** :
- Utilisation de l'ancien `page.waitForSelector()` issu de vieux tutoriels ou d'une migration depuis Puppeteer
- Le sélecteur ne correspond à aucun élément du DOM
- L'élément existe mais ne remplit pas l'état exigé (par exemple `{ state: 'visible' }` alors que l'élément est caché)

**Correctif** : Remplace `waitForSelector()` par des assertions basées sur les locators.

```typescript
// TypeScript

// BAD — deprecated, no auto-retry, not composable
await page.waitForSelector('.loading', { state: 'hidden' });
await page.waitForSelector('.content', { state: 'visible' });

// GOOD — locator-based assertions with auto-retry
await expect(page.locator('.loading')).toBeHidden();
await expect(page.locator('.content')).toBeVisible();

// GOOD — use role-based locators for even more resilience
await expect(page.getByRole('progressbar')).toBeHidden();
await expect(page.getByRole('main')).toBeVisible();
```

```javascript
// JavaScript

// BAD — deprecated
await page.waitForSelector('.loading', { state: 'hidden' });
await page.waitForSelector('.content', { state: 'visible' });

// GOOD — locator-based assertions
await expect(page.locator('.loading')).toBeHidden();
await expect(page.locator('.content')).toBeVisible();

// GOOD — role-based locators
await expect(page.getByRole('progressbar')).toBeHidden();
await expect(page.getByRole('main')).toBeVisible();
```

**Voir aussi** : [core/locators.md](locators.md), [core/assertions-and-waiting.md](assertions-and-waiting.md), [migration/from-selenium.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/migration/from-selenium.md)

---

### "Error: expect(page).toHaveTitle(expected) failed"

**Cause** : L'assertion `expect(page).toHaveTitle()` a échoué parce que le titre de la page ne correspondait pas à la valeur ou au pattern attendu dans le délai imparti.

**Causes fréquentes** :
- La page n'a pas fini de se charger et le titre a encore sa valeur initiale vide ou par défaut
- La SPA met à jour le titre du document de façon asynchrone après le rendu
- Le titre attendu contient une faute de frappe ou ne correspond pas en tenant compte de la casse
- La page a redirigé vers une page d'erreur avec un titre différent

**Correctif** : Assure-toi que la page est entièrement chargée et utilise la bonne valeur attendue.

```typescript
// TypeScript

// toHaveTitle auto-retries, but ensure the page has loaded
await page.goto('/dashboard');
await expect(page).toHaveTitle('Dashboard | MyApp');

// Use regex for flexible matching
await expect(page).toHaveTitle(/Dashboard/);

// Debug: check what the actual title is
console.log(await page.title());
```

```javascript
// JavaScript

await page.goto('/dashboard');
await expect(page).toHaveTitle('Dashboard | MyApp');

// Use regex for flexible matching
await expect(page).toHaveTitle(/Dashboard/);

// Debug: check what the actual title is
console.log(await page.title());
```

**Voir aussi** : [core/assertions-and-waiting.md](assertions-and-waiting.md)

---

### "Error: page.setInputFiles: Non-multiple file input can only accept single file"

**Cause** : Tentative d'envoi de plusieurs fichiers vers un `<input type="file">` qui n'a pas l'attribut `multiple`.

**Causes fréquentes** :
- Passage d'un tableau de fichiers à un input d'upload à fichier unique
- L'app utilise un composant d'upload personnalisé qui ne gère qu'un fichier à la fois

**Correctif** : Envoie un fichier à la fois, ou assure-toi que l'input accepte plusieurs fichiers.

```typescript
// TypeScript

// BAD — input does not have multiple attribute
await page.getByLabel('Upload file').setInputFiles([
  'file1.pdf',
  'file2.pdf', // error: non-multiple input
]);

// GOOD — single file
await page.getByLabel('Upload file').setInputFiles('file1.pdf');

// GOOD — for multiple file input (must have multiple attribute in HTML)
await page.getByLabel('Upload files').setInputFiles([
  'file1.pdf',
  'file2.pdf',
]);

// To clear the file input
await page.getByLabel('Upload file').setInputFiles([]);
```

```javascript
// JavaScript

// GOOD — single file
await page.getByLabel('Upload file').setInputFiles('file1.pdf');

// GOOD — multiple files (input must have multiple attribute)
await page.getByLabel('Upload files').setInputFiles([
  'file1.pdf',
  'file2.pdf',
]);

// To clear the file input
await page.getByLabel('Upload file').setInputFiles([]);
```

**Voir aussi** : [core/file-operations.md](file-operations.md), [core/file-upload-download.md](file-upload-download.md)

---

### "Error reading storage state from ... is not valid JSON"

**Cause** : L'option `storageState` pointe vers un fichier au JSON invalide, donc `browser.newContext` échoue avec `Error reading storage state from <path>:` suivi de l'erreur du parseur JSON : `Unexpected end of JSON input` pour un fichier vide, ou `Unexpected token ..., "..." is not valid JSON` pour un fichier corrompu.

**Causes fréquentes** :
- Le setup d'authentification a écrit un fichier vide ou un JSON incomplet
- Le fichier de storage state a été corrompu ou tronqué
- Modification manuelle du fichier de storage state avec introduction d'une erreur de syntaxe
- Le setup d'authentification a échoué silencieusement (le login ne s'est pas terminé) et a enregistré un état invalide

**Correctif** : Supprime le fichier de storage state et régénère-le.

```bash
# Delete the corrupted file
rm -f playwright/.auth/user.json

# Re-run the setup
npx playwright test --project=setup
```

Pour l'éviter, ajoute une vérification d'erreur dans le setup d'authentification :

```typescript
// TypeScript — auth.setup.ts
import { test as setup, expect } from '@playwright/test';

const authFile = 'playwright/.auth/user.json';

setup('authenticate', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();

  // Verify login actually succeeded before saving state
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  await page.context().storageState({ path: authFile });
});
```

```javascript
// JavaScript — auth.setup.js
const { test: setup, expect } = require('@playwright/test');

const authFile = 'playwright/.auth/user.json';

setup('authenticate', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();

  // Verify login actually succeeded before saving state
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  await page.context().storageState({ path: authFile });
});
```

**Voir aussi** : [core/authentication.md](authentication.md), [core/auth-flows.md](auth-flows.md)

---

## Checklist de diagnostic rapide

Quand tu rencontres une erreur non listée ci-dessus, parcours cette checklist :

1. **Lis l'erreur en entier** — les erreurs Playwright incluent le locator, l'action et un `Call log:` de chaque tentative. Les dernières lignes du call log (par exemple `intercepts pointer events`, `element is not stable`) nomment généralement le blocage ; cherche-les dans ce fichier.
2. **Active les traces** — ajoute temporairement `trace: 'on'` ou `trace: 'on-first-retry'` dans la config. Lance `npx playwright show-trace trace.zip` pour voir les captures, le DOM, le réseau et la console au moment de l'échec.
3. **Utilise le Playwright Inspector** — lance `npx playwright test --debug` pour exécuter le test pas à pas de manière interactive.
4. **Vérifie le locator** — lance `npx playwright codegen <url>` pour valider les locators sur la page réelle.
5. **Vérifie la version de Playwright** — lance `npx playwright --version`. Assure-toi que `@playwright/test` et les binaires des navigateurs ont la même version.
6. **Cherche dans le bug tracker de Playwright** — de nombreuses erreurs ont des solutions connues sur [github.com/microsoft/playwright/issues](https://github.com/microsoft/playwright/issues).
