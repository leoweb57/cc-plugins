# Locators

> **Quand l'utiliser** : Chaque fois que tu dois trouver un élément sur la page. Commence ici avant de te tourner vers CSS ou XPath.
> **Prérequis** : [core/configuration.md](configuration.md)

## Référence rapide

```typescript
// Priority order — use the first one that works:
page.getByRole('button', { name: 'Submit' })        // 1. Role (default)
page.getByLabel('Email address')                     // 2. Label (form fields)
page.getByText('Welcome back')                       // 3. Text (non-interactive)
page.getByPlaceholder('Search...')                    // 4. Placeholder
page.getByAltText('Company logo')                    // 5. Alt text (images)
page.getByTitle('Close dialog')                      // 6. Title attribute
page.getByTestId('checkout-summary')                 // 7. Test ID (last semantic option)
page.locator('.legacy-widget button')                // 8. CSS/XPath (last resort)
```

## Helpers de locators récents (Playwright 1.59+)

> Playwright 1.60 ajoute aussi une option `description` à `getByRole()` pour départager des contrôles de même nom — voir [Locators basés sur le rôle](#disambiguating-by-accessible-description-description-playwright-160) ci-dessous.

Playwright 1.59 a ajouté deux helpers utiles pour la découverte de locators :

- Sélection interactive de locator pour le debug et l'exploration
- `locator.normalize()` pour réécrire des sélecteurs fragiles selon les bonnes pratiques Playwright

Utilise-les pendant le debug, les refactors et l'écriture de tests. Ne les prends pas pour un substitut à la réflexion sur le locator le plus orienté utilisateur. Le meilleur locator en production reste généralement `getByRole()`, `getByLabel()` ou `getByTestId()` quand la sémantique n'est pas disponible.

### `page.pickLocator()` pour la découverte interactive

**Quand l'utiliser** : Tu explores une page, tu débogues un sélecteur ou tu migres une suite legacy et tu veux que Playwright te suggère un locator pour l'élément sous ton curseur.
**Quand l'éviter** : Pour écrire les tests finaux de production sans relecture. Considère le locator choisi comme un point de départ, pas comme la réponse finale.

**TypeScript**
```typescript
import { test } from '@playwright/test';

test('pick a locator during debugging', async ({ page }) => {
  await page.goto('/checkout');

  const picked = await page.pickLocator();
  console.log(picked);

  await page.cancelPickLocator();
});
```

**JavaScript**
```javascript
const { test } = require('@playwright/test');

test('pick a locator during debugging', async ({ page }) => {
  await page.goto('/checkout');

  const picked = await page.pickLocator();
  console.log(picked);

  await page.cancelPickLocator();
});
```

Relis le locator suggéré avant de le garder. Préfère le réécrire en `getByRole()` ou un autre locator sémantique si cela rend le test plus clair.

### `locator.visible()` pour ne cibler que le visible (Playwright 1.63+)

`locator.visible()` renvoie un locator restreint aux éléments visibles uniquement. Il remplace la pseudo-classe CSS `:visible`, qui était une syntaxe spécifique à Playwright, ne fonctionnait que dans les chaînes de `locator()` et ne pouvait pas être chaînée à un locator sémantique.

```javascript
await page.locator('button').visible().click();
```

**Utilise-le pour une UI réellement dupliquée**, pas pour masquer des violations du strict mode. Un layout responsive qui rend à la fois une navigation desktop et une navigation mobile, en masquant l'une par media query, est le vrai cas d'usage : les deux correspondent à `getByRole('link', { name: 'Settings' })`, une seule est visible, et `.visible()` le dit directement.

```javascript
// Responsive layout renders both navs; only one is visible at this viewport
await page.getByRole('link', { name: 'Settings' }).visible().click();
```

**Quand c'est le mauvais outil** : si deux éléments visibles correspondent, `.visible()` n'aide pas et tu obtiens toujours une violation du strict mode. Restreins plutôt avec le chaînage ou `filter()` — voir [Locator Chaining and Filtering](#locator-chaining-and-filtering). Et si un élément est masqué parce que l'application n'a pas fini son rendu, `.visible()` restreint la correspondance au moment de la requête au lieu d'attendre l'apparition du bon élément ; fais plutôt une assertion sur l'élément attendu.

### `locator.within()` pour combiner deux locators (Playwright 1.64+)

**Quand l'utiliser** : Tu as déjà deux locators, une cible et un conteneur, et tu veux « ce bouton, dans cette boîte de dialogue » sans réécrire ni l'un ni l'autre.
**Quand l'éviter** : Quand un simple chaînage se lit tout aussi bien : `dialog.getByRole('button', { name: 'Save' })` reste le choix par défaut.

**Avant la 1.64**, tu ne pouvais restreindre qu'en chaînant depuis le conteneur : `container.getByRole(...)`. Cela t'obligeait à construire la cible à partir du conteneur, donc un locator cible réutilisable (venant d'un page object, d'une fixture ou d'un helper) devait être redéclaré pour chaque conteneur dans lequel il se trouvait.

**La 1.64** ajoute `target.within(container)`, qui se lit dans l'ordre naturel et réutilise les deux locators tels quels :

```javascript
const saveButton = page.getByRole('button', { name: 'Save' });
const dialog = page.getByTestId('settings-dialog');

await saveButton.within(dialog).click();
```

**Requêtes de type colonne** : les parties relatives comme `nth()` ou `first()` sont résolues **à l'intérieur de chaque parent séparément**. « La troisième cellule de chaque ligne » devient ainsi un seul locator au lieu d'une boucle :

```javascript
// The third cell of every row, not the third cell in the whole table
const thirdColumn = page.getByRole('cell').nth(2).within(page.getByRole('row'));
await expect(thirdColumn).toHaveText(['Apple', 'Banana', 'Cherry']);
```

Compare avec `page.getByRole('row').getByRole('cell').nth(2)`, qui choisit la troisième cellule sur l'ensemble des résultats. Quand tu veux dire « par ligne », utilise `within()`.

### `page.getByRef()` pour les refs de snapshot aria (Playwright 1.64+)

`page.ariaSnapshot({ mode: 'ai' })` étiquette chaque élément avec une ref courte comme `e2`. `page.getByRef('e2')` retransforme cette ref en locator. C'est le pont entre un agent qui lit le snapshot et le code de test qui agit dessus.

```javascript
const snapshot = await page.ariaSnapshot({ mode: 'ai' });
// ... an agent picks "e2" from the snapshot ...
await page.getByRef('e2').click();
```

Les refs sont liées à un snapshot d'un état de page donné. Utilise-les dans les boucles d'agent et les scripts d'exploration ; dans les tests commités, réécris la cible en `getByRole()` pour que le test survive à un nouveau rendu.

### `locator.normalize()` pour les refactors

**Quand l'utiliser** : Tu hérites de locators fragiles à base de CSS/XPath et tu veux que Playwright suggère une forme plus idiomatique pendant le nettoyage.
**Quand l'éviter** : Tu n'as pas encore réfléchi à la sémantique de l'élément. Un locator normalisé peut rester moins clair qu'un locator role ou label écrit à la main.

**TypeScript**
```typescript
import { test } from '@playwright/test';

test('normalize a legacy locator', async ({ page }) => {
  await page.goto('/settings');

  const legacy = page.locator('.settings-panel button.save');
  const normalized = await legacy.normalize();

  console.log(normalized);
});
```

**JavaScript**
```javascript
const { test } = require('@playwright/test');

test('normalize a legacy locator', async ({ page }) => {
  await page.goto('/settings');

  const legacy = page.locator('.settings-panel button.save');
  const normalized = await legacy.normalize();

  console.log(normalized);
});
```

Utilise `normalize()` comme assistant de refactoring. Le test final doit toujours refléter l'intention de l'utilisateur, pas seulement « le sélecteur que Playwright a pu dériver ».

## Patterns

### Locators basés sur le rôle (choix par défaut)

**Quand l'utiliser** : Toujours. C'est ton point de départ pour chaque élément.
**Quand l'éviter** : L'élément n'a pas de rôle ARIA et en ajouter un est hors de ton contrôle.

Les locators basés sur le rôle reflètent la façon dont les technologies d'assistance voient ta page. Ils survivent aux refactors, aux renommages de classes et aux changements de bibliothèque de composants.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('role-based locators cover most UI elements', async ({ page }) => {
  await page.goto('/dashboard');

  // Buttons — matches <button>, <input type="submit">, role="button"
  await page.getByRole('button', { name: 'Save changes' }).click();

  // Links — matches <a href>
  await page.getByRole('link', { name: 'View profile' }).click();

  // Headings — use level to target specific h1-h6
  await expect(page.getByRole('heading', { name: 'Dashboard', level: 1 })).toBeVisible();

  // Text inputs — match by accessible name (label association)
  await page.getByRole('textbox', { name: 'Email' }).fill('user@example.com');

  // Checkboxes and radios
  await page.getByRole('checkbox', { name: 'Remember me' }).check();
  await page.getByRole('radio', { name: 'Monthly billing' }).click();

  // Dropdowns — <select> elements
  await page.getByRole('combobox', { name: 'Country' }).selectOption('US');

  // Navigation landmarks
  const nav = page.getByRole('navigation', { name: 'Main' });
  await expect(nav.getByRole('link', { name: 'Settings' })).toBeVisible();

  // Tables
  const table = page.getByRole('table', { name: 'Recent orders' });
  await expect(table.getByRole('row')).toHaveCount(5);

  // Dialogs
  const dialog = page.getByRole('dialog', { name: 'Confirm deletion' });
  await dialog.getByRole('button', { name: 'Delete' }).click();

  // Exact matching — prevents "Log" from matching "Log out"
  await page.getByRole('button', { name: 'Log', exact: true }).click();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('role-based locators cover most UI elements', async ({ page }) => {
  await page.goto('/dashboard');

  await page.getByRole('button', { name: 'Save changes' }).click();
  await page.getByRole('link', { name: 'View profile' }).click();
  await expect(page.getByRole('heading', { name: 'Dashboard', level: 1 })).toBeVisible();
  await page.getByRole('textbox', { name: 'Email' }).fill('user@example.com');
  await page.getByRole('checkbox', { name: 'Remember me' }).check();
  await page.getByRole('radio', { name: 'Monthly billing' }).click();
  await page.getByRole('combobox', { name: 'Country' }).selectOption('US');

  const nav = page.getByRole('navigation', { name: 'Main' });
  await expect(nav.getByRole('link', { name: 'Settings' })).toBeVisible();

  const dialog = page.getByRole('dialog', { name: 'Confirm deletion' });
  await dialog.getByRole('button', { name: 'Delete' }).click();

  await page.getByRole('button', { name: 'Log', exact: true }).click();
});
```

#### Disambiguating by accessible description (`description`, Playwright 1.60+)

Quand deux contrôles partagent le même nom accessible mais diffèrent par leur *description* accessible (`aria-describedby` / `aria-description`), l'option `description` de `getByRole()` (et des autres rôles `getBy*`) introduite en Playwright 1.60 cible le bon sans recourir au CSS.

**TypeScript**
```typescript
// Two "Delete" buttons, distinguished by their helper text / aria-describedby
await page
  .getByRole('button', { name: 'Delete', description: 'Permanently removes this project' })
  .click();

// Pair it with `exact` for tight matching
await page.getByRole('link', {
  name: 'Download',
  description: 'PDF, 2.3 MB',
  exact: true,
}).click();
```

**JavaScript**
```javascript
await page
  .getByRole('button', { name: 'Delete', description: 'Permanently removes this project' })
  .click();
```

N'utilise `description` que lorsque `name` + `role` (et `exact`) ne suffisent pas à départager — c'est un outil de précision, pas un réflexe par défaut.

### Locators basés sur le label

**Quand l'utiliser** : Cibler des champs de formulaire associés à des éléments `<label>` ou à `aria-label`.
**Quand l'éviter** : L'élément n'est pas un contrôle de formulaire. Utilise plutôt `getByRole` avec le nom accessible — il couvre aussi les labels.

`getByLabel` est un raccourci pour les champs de formulaire. Il correspond à `<label for="">`, à un `<label>` englobant et à `aria-label` / `aria-labelledby`.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('fill a registration form using labels', async ({ page }) => {
  await page.goto('/register');

  await page.getByLabel('First name').fill('Jane');
  await page.getByLabel('Last name').fill('Doe');
  await page.getByLabel('Email address').fill('jane@example.com');
  await page.getByLabel('Password', { exact: true }).fill('s3cure!Pass');
  await page.getByLabel('Confirm password').fill('s3cure!Pass');
  await page.getByLabel('I agree to the terms').check();

  await page.getByRole('button', { name: 'Create account' }).click();
  await expect(page.getByRole('heading', { name: 'Welcome' })).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('fill a registration form using labels', async ({ page }) => {
  await page.goto('/register');

  await page.getByLabel('First name').fill('Jane');
  await page.getByLabel('Last name').fill('Doe');
  await page.getByLabel('Email address').fill('jane@example.com');
  await page.getByLabel('Password', { exact: true }).fill('s3cure!Pass');
  await page.getByLabel('Confirm password').fill('s3cure!Pass');
  await page.getByLabel('I agree to the terms').check();

  await page.getByRole('button', { name: 'Create account' }).click();
  await expect(page.getByRole('heading', { name: 'Welcome' })).toBeVisible();
});
```

### Locators basés sur le texte

**Quand l'utiliser** : Cibler du contenu non interactif — messages de statut, paragraphes, bannières, labels hors formulaires.
**Quand l'éviter** : L'élément est un bouton, un lien, un titre ou un champ de formulaire. Utilise plutôt `getByRole`.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('verify text content on the page', async ({ page }) => {
  await page.goto('/order/confirmation');

  // Substring match (default)
  await expect(page.getByText('Order confirmed')).toBeVisible();

  // Exact match — use when substring hits multiple elements
  await expect(page.getByText('Order #12345', { exact: true })).toBeVisible();

  // Regex match — for dynamic content patterns
  await expect(page.getByText(/Order #\d+/)).toBeVisible();

  // DO NOT use getByText for buttons or links:
  // Bad:  page.getByText('Submit')
  // Good: page.getByRole('button', { name: 'Submit' })
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('verify text content on the page', async ({ page }) => {
  await page.goto('/order/confirmation');

  await expect(page.getByText('Order confirmed')).toBeVisible();
  await expect(page.getByText('Order #12345', { exact: true })).toBeVisible();
  await expect(page.getByText(/Order #\d+/)).toBeVisible();
});
```

### Locators par test ID

**Quand l'utiliser** : Aucun locator sémantique ne fonctionne — l'élément n'a ni rôle accessible, ni label, ni texte stable. Fréquent avec les composants rendus sur canvas, les data grids complexes ou les widgets tiers.
**Quand l'éviter** : Un locator sémantique (`getByRole`, `getByLabel`, `getByText`) permet d'identifier l'élément. Les test IDs sont invisibles pour les utilisateurs et les technologies d'assistance.

Configure le nom de l'attribut une fois pour toutes dans `playwright.config` :

**TypeScript**
```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  use: {
    testIdAttribute: 'data-testid', // default; change to match your codebase
  },
});
```

```typescript
import { test, expect } from '@playwright/test';

test('interact with a custom widget using test IDs', async ({ page }) => {
  await page.goto('/analytics');

  // Only when the chart component exposes no accessible roles
  const chart = page.getByTestId('revenue-chart');
  await expect(chart).toBeVisible();
  await chart.click({ position: { x: 150, y: 75 } });

  await expect(page.getByTestId('chart-tooltip')).toContainText('$12,400');
});
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  use: {
    testIdAttribute: 'data-testid',
  },
});
```

```javascript
const { test, expect } = require('@playwright/test');

test('interact with a custom widget using test IDs', async ({ page }) => {
  await page.goto('/analytics');

  const chart = page.getByTestId('revenue-chart');
  await expect(chart).toBeVisible();
  await chart.click({ position: { x: 150, y: 75 } });

  await expect(page.getByTestId('chart-tooltip')).toContainText('$12,400');
});
```

### CSS/XPath — dernier recours

**Quand l'utiliser** : Tu n'as aucun contrôle sur le balisage, pas de test IDs, pas de noms accessibles et aucun moyen d'en ajouter. Applications legacy avec des noms de classes générés et sans HTML sémantique.
**Quand l'éviter** : Tout autre type de locator fonctionne. Toujours.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('legacy app with no semantic markup', async ({ page }) => {
  await page.goto('/legacy-admin');

  // CSS — prefer short, structural selectors over fragile class chains
  await page.locator('table.report-grid td:has-text("Overdue")').first().click();

  // XPath — only when CSS cannot express the query (e.g., text + ancestor traversal)
  await page.locator('xpath=//td[contains(text(),"Overdue")]/ancestor::tr//button').click();

  // Scope a CSS container, then chain a semantic locator (preferred over `>>` selector chaining)
  await page.locator('.sidebar').getByRole('button', { name: 'Expand' }).click();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('legacy app with no semantic markup', async ({ page }) => {
  await page.goto('/legacy-admin');

  await page.locator('table.report-grid td:has-text("Overdue")').first().click();
  await page.locator('xpath=//td[contains(text(),"Overdue")]/ancestor::tr//button').click();
  await page.locator('.sidebar').getByRole('button', { name: 'Expand' }).click();
});
```

### Locator Chaining and Filtering

**Quand l'utiliser** : Un seul locator correspond à plusieurs éléments et tu dois restreindre par contexte, contenu ou position.
**Quand l'éviter** : Un `getByRole` direct avec `name` identifie déjà l'élément de façon unique.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('chaining and filtering locators', async ({ page }) => {
  await page.goto('/products');

  // Chain: scope a locator within another
  const productCard = page.getByRole('listitem').filter({ hasText: 'Running Shoes' });
  await productCard.getByRole('button', { name: 'Add to cart' }).click();

  // Filter by child locator — more precise than hasText
  const row = page.getByRole('row').filter({
    has: page.getByRole('cell', { name: 'Premium Plan' }),
  });
  await row.getByRole('button', { name: 'Upgrade' }).click();

  // Filter with hasNot — exclude elements containing a child
  const availableItems = page.getByRole('listitem').filter({
    hasNot: page.getByText('Sold out'),
  });
  await expect(availableItems).toHaveCount(3);

  // Filter with hasNotText — exclude by text content
  const nonFeatured = page.getByRole('listitem').filter({
    hasNotText: 'Featured',
  });

  // Positional: nth, first, last — use sparingly, only when order is stable
  const thirdItem = page.getByRole('listitem').nth(2); // 0-indexed
  const firstItem = page.getByRole('listitem').first();
  const lastItem = page.getByRole('listitem').last();

  // Combining multiple filters
  const activeAdminRow = page
    .getByRole('row')
    .filter({ has: page.getByRole('cell', { name: 'Admin' }) })
    .filter({ has: page.getByText('Active') });
  await expect(activeAdminRow).toHaveCount(1);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('chaining and filtering locators', async ({ page }) => {
  await page.goto('/products');

  const productCard = page.getByRole('listitem').filter({ hasText: 'Running Shoes' });
  await productCard.getByRole('button', { name: 'Add to cart' }).click();

  const row = page.getByRole('row').filter({
    has: page.getByRole('cell', { name: 'Premium Plan' }),
  });
  await row.getByRole('button', { name: 'Upgrade' }).click();

  const availableItems = page.getByRole('listitem').filter({
    hasNot: page.getByText('Sold out'),
  });
  await expect(availableItems).toHaveCount(3);

  const thirdItem = page.getByRole('listitem').nth(2);
  const firstItem = page.getByRole('listitem').first();
  const lastItem = page.getByRole('listitem').last();

  const activeAdminRow = page
    .getByRole('row')
    .filter({ has: page.getByRole('cell', { name: 'Admin' }) })
    .filter({ has: page.getByText('Active') });
  await expect(activeAdminRow).toHaveCount(1);
});
```

### Frame Locators

**Quand l'utiliser** : Interagir avec du contenu dans des éléments `<iframe>` ou `<frame>` — widgets de paiement, éditeurs embarqués, widgets tiers.
**Quand l'éviter** : Le contenu est dans le frame principal ou dans un Shadow DOM (utilise plutôt la traversée).

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('interact with content inside an iframe', async ({ page }) => {
  await page.goto('/checkout');

  // Locate the iframe, then use normal locators inside it
  const paymentFrame = page.frameLocator('iframe[title="Payment"]');
  await paymentFrame.getByLabel('Card number').fill('4242424242424242');
  await paymentFrame.getByLabel('Expiration').fill('12/28');
  await paymentFrame.getByLabel('CVC').fill('123');
  await paymentFrame.getByRole('button', { name: 'Pay' }).click();

  // Nested iframes — chain frameLocator calls
  const nestedFrame = page
    .frameLocator('#outer-frame')
    .frameLocator('#inner-frame');
  await expect(nestedFrame.getByText('Payment confirmed')).toBeVisible();

  // Frame by nth index — when no better selector exists
  const secondFrame = page.frameLocator('iframe').nth(1);
  await expect(secondFrame.getByRole('heading')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('interact with content inside an iframe', async ({ page }) => {
  await page.goto('/checkout');

  const paymentFrame = page.frameLocator('iframe[title="Payment"]');
  await paymentFrame.getByLabel('Card number').fill('4242424242424242');
  await paymentFrame.getByLabel('Expiration').fill('12/28');
  await paymentFrame.getByLabel('CVC').fill('123');
  await paymentFrame.getByRole('button', { name: 'Pay' }).click();

  const nestedFrame = page
    .frameLocator('#outer-frame')
    .frameLocator('#inner-frame');
  await expect(nestedFrame.getByText('Payment confirmed')).toBeVisible();

  const secondFrame = page.frameLocator('iframe').nth(1);
  await expect(secondFrame.getByRole('heading')).toBeVisible();
});
```

### Traversée du Shadow DOM

**Quand l'utiliser** : Cibler des éléments dans des web components utilisant le Shadow DOM (custom elements, composants de design system, Salesforce Lightning).
**Quand l'éviter** : L'élément est dans le DOM classique ou dans une iframe.

Playwright traverse automatiquement le Shadow DOM ouvert avec `locator()`. La famille `getByRole` / `getByText` traverse aussi les shadow roots par défaut.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('interact with Shadow DOM elements', async ({ page }) => {
  await page.goto('/design-system-demo');

  // getByRole automatically pierces open Shadow DOM — just use it normally
  await page.getByRole('button', { name: 'Toggle menu' }).click();

  // locator() with CSS also pierces shadow roots by default
  await page.locator('my-dropdown').getByRole('option', { name: 'Settings' }).click();

  // Chain into nested shadow DOMs
  await page
    .locator('my-app')
    .locator('my-sidebar')
    .getByRole('link', { name: 'Profile' })
    .click();

  // `css:light=` (non-piercing) is undocumented and listed as removed in the 1.58 notes, though 1.64
  // still parses it; prefer scoping from a light-DOM parent
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('interact with Shadow DOM elements', async ({ page }) => {
  await page.goto('/design-system-demo');

  await page.getByRole('button', { name: 'Toggle menu' }).click();
  await page.locator('my-dropdown').getByRole('option', { name: 'Settings' }).click();

  await page
    .locator('my-app')
    .locator('my-sidebar')
    .getByRole('link', { name: 'Profile' })
    .click();
});
```

### Contenu dynamique — attendre les éléments

**Quand l'utiliser** : Les éléments apparaissent après des appels API, des animations, du lazy loading ou des transitions de route.
**Quand l'éviter** : L'élément est déjà sur la page. Playwright attend automatiquement lors des actions, donc les attentes explicites sont rarement nécessaires.

N'utilise jamais `page.waitForTimeout()`. Utilise des assertions à attente automatique ou des attentes explicites d'événements.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('handle dynamic content without manual waits', async ({ page }) => {
  await page.goto('/search');

  // Auto-waiting: actions like click(), fill() wait for the element automatically
  await page.getByRole('textbox', { name: 'Search' }).fill('playwright');
  await page.getByRole('button', { name: 'Search' }).click();

  // Web-first assertion: auto-retries until timeout (default 5s)
  await expect(page.getByRole('listitem')).toHaveCount(10);

  // Wait for a specific element to appear after an async operation
  await expect(page.getByRole('heading', { name: 'Results' })).toBeVisible();

  // Wait for loading indicators to disappear
  await expect(page.getByRole('progressbar')).toBeHidden();

  // Wait for network-dependent content: wait for response then assert
  const responsePromise = page.waitForResponse('**/api/search*');
  await page.getByRole('button', { name: 'Load more' }).click();
  await responsePromise;
  await expect(page.getByRole('listitem')).toHaveCount(20);

  // Wait for URL change after navigation
  await page.getByRole('link', { name: 'First result' }).click();
  await page.waitForURL('**/results/**');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('handle dynamic content without manual waits', async ({ page }) => {
  await page.goto('/search');

  await page.getByRole('textbox', { name: 'Search' }).fill('playwright');
  await page.getByRole('button', { name: 'Search' }).click();

  await expect(page.getByRole('listitem')).toHaveCount(10);
  await expect(page.getByRole('heading', { name: 'Results' })).toBeVisible();
  await expect(page.getByRole('progressbar')).toBeHidden();

  const responsePromise = page.waitForResponse('**/api/search*');
  await page.getByRole('button', { name: 'Load more' }).click();
  await responsePromise;
  await expect(page.getByRole('listitem')).toHaveCount(20);

  await page.getByRole('link', { name: 'First result' }).click();
  await page.waitForURL('**/results/**');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
});
```

## Guide de décision

| Type d'élément | Locator recommandé | Exemple | Pourquoi |
|---|---|---|---|
| Bouton | `getByRole('button', { name })` | `getByRole('button', { name: 'Submit' })` | Correspond à `<button>`, `<input type="submit">`, `role="button"` |
| Lien | `getByRole('link', { name })` | `getByRole('link', { name: 'Home' })` | Correspond à tout `<a href>` quel que soit son style |
| Champ texte | `getByRole('textbox', { name })` | `getByRole('textbox', { name: 'Email' })` | Correspond par nom accessible (label) |
| Champ mot de passe | `getByLabel()` | `getByLabel('Password')` | Les champs mot de passe n'ont pas de rôle distinct ; le label est la meilleure correspondance |
| Case à cocher | `getByRole('checkbox', { name })` | `getByRole('checkbox', { name: 'Agree' })` | Utilise aussi `.check()` / `.uncheck()` plutôt que `.click()` |
| Bouton radio | `getByRole('radio', { name })` | `getByRole('radio', { name: 'Express' })` | Groupe les radios avec `getByRole('radiogroup')` |
| Select / liste déroulante | `getByRole('combobox', { name })` | `getByRole('combobox', { name: 'Country' })` | Le `<select>` natif correspond au rôle combobox |
| Liste déroulante personnalisée | `getByRole('listbox')` + `getByRole('option')` | Clique sur le déclencheur, puis `getByRole('option', { name })` | Pattern ARIA listbox pour les listes déroulantes personnalisées |
| Titre | `getByRole('heading', { name, level })` | `getByRole('heading', { name: 'Dashboard', level: 2 })` | Utilise `level` pour distinguer h1-h6 |
| Tableau | `getByRole('table', { name })` | `getByRole('table', { name: 'Users' })` | Chaîne avec `getByRole('row')`, `getByRole('cell')` |
| Ligne de tableau | `getByRole('row').filter({ has })` | `.filter({ has: getByRole('cell', { name: 'Jane' }) })` | Filtre les lignes selon le contenu des cellules |
| Navigation | `getByRole('navigation', { name })` | `getByRole('navigation', { name: 'Main' })` | Correspond à `<nav>` avec `aria-label` |
| Dialogue / modale | `getByRole('dialog', { name })` | `getByRole('dialog', { name: 'Confirm' })` | Restreins toutes les interactions du dialogue sous ce locator |
| Onglet | `getByRole('tab', { name })` | `getByRole('tab', { name: 'Settings' })` | À utiliser avec `getByRole('tabpanel')` |
| Image | `getByAltText()` | `getByAltText('User avatar')` | Correspond à l'attribut `alt` |
| Champ de formulaire (tous) | `getByLabel()` | `getByLabel('Date of birth')` | Solution de repli quand le rôle est ambigu (date pickers, inputs personnalisés) |
| Texte statique | `getByText()` | `getByText('No results found')` | Contenu non interactif uniquement |
| Pas de balisage sémantique | `getByTestId()` | `getByTestId('sparkline-chart')` | Dernière option sémantique avant CSS |
| Contenu d'iframe | `frameLocator()` puis n'importe quel locator | `frameLocator('#payment').getByLabel('Card')` | Requis pour l'accès inter-frames |
| Shadow DOM | `getByRole()` / `locator()` | Fonctionne automatiquement | Playwright traverse les shadow roots ouverts par défaut |

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| `page.locator('.btn-primary')` | Casse quand les classes CSS changent (renommages, CSS modules, Tailwind) | `page.getByRole('button', { name: 'Save' })` |
| `page.locator('#submit-btn')` | Les IDs sont des détails d'implémentation ; souvent générés automatiquement | `page.getByRole('button', { name: 'Submit' })` |
| `page.locator('div > span:nth-child(3)')` | Casse à la moindre restructuration du DOM | `page.getByText('Expected content')` ou `getByTestId()` |
| `page.locator('xpath=//div[@class="form"]//input[2]')` | Fragile, illisible, dépend de la position | `page.getByLabel('Last name')` |
| `page.getByText('Submit')` pour un bouton | Les locators texte ne vérifient pas que l'élément est interactif | `page.getByRole('button', { name: 'Submit' })` |
| `page.locator('.item').nth(0)` sur des listes dynamiques | L'index change quand des éléments sont ajoutés, supprimés ou réordonnés | `.filter({ hasText: 'Specific item' })` |
| `page.getByText('Aceptar')` texte i18n en dur | Échoue quand la locale change | `page.getByRole('button', { name: /accept/i })` ou `getByTestId('confirm-btn')` |
| `await page.waitForTimeout(3000)` | Délai arbitraire ; trop lent dans les environnements rapides, trop court dans les lents | `await expect(locator).toBeVisible()` |
| `page.locator('.card').locator('.card-title').locator('a')` | Le chaînage CSS profond casse à la moindre modification de structure | `page.getByRole('link', { name: 'Card title text' })` |
| `page.$('selector')` (API ElementHandle) | Renvoie un snapshot, sans attente automatique ; pattern déconseillé | `page.locator('selector')` — les locators sont lazy et attendent automatiquement |
| `page.locator('text=Click here')` | Ancienne syntaxe de sélecteur texte | `page.getByText('Click here')` ou `getByRole` avec name |
| Plusieurs locators successifs pour un même élément | Chaque appel à `locator()` dans une chaîne relance la recherche | Stocke dans une variable : `const btn = page.getByRole('button', { name: 'Save' })` |

## Dépannage

### « strict mode violation » — le locator correspond à plusieurs éléments

**Cause** : Ton locator n'est pas assez précis et Playwright refuse de choisir à ta place.

```typescript
// Error: locator.click: strict mode violation, getByRole('button') resolved to 5 elements
await page.getByRole('button').click(); // Too broad

// Fix 1: Add a name filter
await page.getByRole('button', { name: 'Save' }).click();

// Fix 2: Scope within a parent
await page.getByRole('dialog').getByRole('button', { name: 'Save' }).click();

// Fix 3: Use exact matching when names are substrings of each other
await page.getByRole('button', { name: 'Save', exact: true }).click();

// Fix 4: Use filter to narrow down
await page.getByRole('button').filter({ hasText: 'Save draft' }).click();

// Debug: see what matched
console.log(await page.getByRole('button').all()); // list all matches
```

### L'élément existe mais le locator expire (timeout)

**Cause** : L'élément est dans une iframe, dans un Shadow DOM, ou est masqué ou recouvert.

```typescript
// Check if element is inside an iframe
const frame = page.frameLocator('iframe');
await frame.getByRole('button', { name: 'Submit' }).click();

// Check if element is in a Shadow DOM — getByRole pierces automatically,
// but page.$() and CSS selectors may not. Switch to getByRole.

// Check if element is hidden (display: none, visibility: hidden, opacity: 0)
// Use toBeVisible() to confirm, or toBeAttached() if hidden is expected
await expect(page.getByRole('button', { name: 'Submit' })).toBeAttached();
```

### `getByRole` ne trouve pas l'élément

**Cause** : Le rôle ARIA implicite de l'élément ne correspond pas à ce que tu attends, ou il n'a pas de rôle.

```typescript
// Debug: inspect the accessibility tree
const snapshot = await page.accessibility.snapshot();
console.log(JSON.stringify(snapshot, null, 2));

// Common mismatches:
// - <div onclick="..."> has no button role → add role="button" or use <button>
// - <input type="text"> with no label has no accessible name → add <label> or aria-label
// - <a> without href has no link role → add href or role="link"

// Fallback chain: try getByLabel → getByText → getByTestId → locator()
```

## Voir aussi

- [core/locator-strategy.md](locator-strategy.md) — cadre de décision approfondi pour choisir les stratégies de locators au niveau du projet
- [core/assertions-and-waiting.md](assertions-and-waiting.md) — associe les locators à des assertions web-first
- [pom/page-object-model.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/pom/page-object-model.md) — encapsule les locators dans des page objects
- [core/iframes-and-shadow-dom.md](iframes-and-shadow-dom.md) — patterns avancés pour les iframes et le Shadow DOM
- [core/i18n-and-localization.md](i18n-and-localization.md) — stratégies de locators pour les applications internationalisées
