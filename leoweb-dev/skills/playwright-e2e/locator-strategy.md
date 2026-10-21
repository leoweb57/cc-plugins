# Choosing a Locator Strategy

> **Quand l'utiliser** : quand tu dois décider quelle méthode de locator Playwright utiliser pour un élément

## Réponse rapide

Utilise `getByRole()` pour tout ce qui a un rôle HTML sémantique (boutons, liens, titres, champs de formulaire, dialogs). Replie-toi sur `getByLabel()` pour les champs de formulaire, `getByText()` pour le contenu textuel simple, et `getByTestId()` uniquement en dernier recours pour les composants custom sans rôle accessible.

## Arbre de décision

```
Start: You need to locate an element
  |
  v
Does the element have a semantic role?
(button, link, heading, textbox, checkbox, combobox, dialog, img, row, cell, navigation...)
  |
  +-- YES --> Use getByRole('role', { name: 'accessible name' })
  |             |
  |             +-- Need to narrow scope? Chain from a parent role locator:
  |                   getByRole('navigation').getByRole('link', { name: '...' })
  |
  +-- NO
       |
       v
     Is it a form field with a visible <label>?
       |
       +-- YES --> Use getByLabel('label text')
       |
       +-- NO
            |
            v
          Is it static text content (paragraph, span, div with text)?
            |
            +-- YES --> Use getByText('text content')
            |             Prefer { exact: true } when text is short or common
            |
            +-- NO
                 |
                 v
               Does it have a placeholder?
                 |
                 +-- YES --> Use getByPlaceholder('placeholder text')
                 |             (Less preferred -- placeholders disappear on input)
                 |
                 +-- NO
                      |
                      v
                    Does it have a title attribute or alt text?
                      |
                      +-- YES --> Use getByTitle('...') or getByAltText('...')
                      |
                      +-- NO
                           |
                           v
                         Add data-testid="..." to the markup
                         Use getByTestId('identifier')
                         |
                         +--> NEVER fall back to CSS selectors or XPath.
                              Fix the markup instead.
```

## Matrice de décision

| Type d'élément | Locator recommandé | Repli | Exemple |
|---|---|---|---|
| Bouton | `getByRole('button', { name })` | `getByText()` si le rôle est absent | `getByRole('button', { name: 'Submit' })` |
| Lien | `getByRole('link', { name })` | `getByText()` pour le texte de l'ancre | `getByRole('link', { name: 'Sign up' })` |
| Champ texte | `getByLabel('...')` | `getByRole('textbox', { name })` | `getByLabel('Email address')` |
| Case à cocher | `getByRole('checkbox', { name })` | `getByLabel()` | `getByRole('checkbox', { name: 'Accept terms' })` |
| Bouton radio | `getByRole('radio', { name })` | `getByLabel()` | `getByRole('radio', { name: 'Express shipping' })` |
| Dropdown / Select | `getByRole('combobox', { name })` | `getByLabel()` | `getByLabel('Country')` |
| Titre | `getByRole('heading', { name, level })` | `getByText()` | `getByRole('heading', { name: 'Dashboard', level: 1 })` |
| Lien de navigation | chaînage : `getByRole('navigation').getByRole('link', { name })` | cadrer avec `locator('nav')` | voir l'exemple détaillé plus bas |
| Cellule de tableau | chaînage : `getByRole('row').filter().getByRole('cell')` | `locator('td')` cadré | voir l'exemple détaillé plus bas |
| Image | `getByRole('img', { name })` | `getByAltText()` | `getByRole('img', { name: 'Company logo' })` |
| Modal / Dialog | `getByRole('dialog')` puis chaîner à l'intérieur | `locator('[role="dialog"]')` | `getByRole('dialog').getByRole('button', { name: 'Confirm' })` |
| Élément de liste dynamique | `.filter({ hasText })` ou `.filter({ has })` | `nth()` en dernier recours | `getByRole('listitem').filter({ hasText: 'Milk' })` |
| Composant custom | `getByTestId('...')` | Ajouter `data-testid` au markup | `getByTestId('color-picker')` |

## Analyse détaillée

### Niveau 1 : `getByRole()` -- à utiliser par défaut

Le locator le plus solide. Il reflète la façon dont les technologies d'assistance et les vrais utilisateurs perçoivent la page.

**Avantages**
- Résiste aux refactos de markup (noms de classes, changements de balises)
- Impose un markup accessible -- si le locator casse, ton accessibilité a cassé aussi
- Fonctionne avec tous les frameworks (React, Vue, Angular, HTML pur)
- Permet de filtrer par `name`, `level`, `checked`, `pressed`, `expanded`, `selected` et (Playwright 1.60+) `description`

**Inconvénients**
- Nécessite que l'élément ait un rôle ARIA valide (implicite ou explicite)
- Peut correspondre à plusieurs éléments quand les noms sont dupliqués -- cadre avec du chaînage, `exact` ou `description`

**Quand ça échoue** : composants custom en « soupe de `<div>` » sans rôles ARIA. Corrige d'abord le composant ; n'ajoute `getByTestId()` que si tu ne peux pas modifier le markup.

**Départager les doublons (Playwright 1.60+)** : quand deux contrôles partagent un nom, privilégie d'abord le cadrage/chaînage ; s'ils ne diffèrent que par leur description accessible (`aria-describedby`), utilise l'option `description` plutôt que de descendre au CSS — `getByRole('button', { name: 'Delete', description: 'Removes this project' })`. Voir [core/locators.md](locators.md#disambiguating-by-accessible-description-description-playwright-160).

---

### Niveau 2 : `getByLabel()` -- champs de formulaire

Interroge par le texte du `<label>` associé. C'est souvent le locator le plus lisible pour les champs de formulaire.

**Avantages**
- Extrêmement lisible : `getByLabel('Password')` dit exactement de quel champ il s'agit
- Fonctionne avec `<label for="...">`, un `<label>` englobant et `aria-labelledby`

**Inconvénients**
- Ne fonctionne que pour les éléments de formulaire ayant des labels
- Casse si quelqu'un change le texte du label (mais c'est généralement voulu)

**À préférer à `getByRole('textbox')`** quand le texte du label est clair et unique. Utilise `getByRole()` quand tu dois différencier plusieurs champs aux labels proches par leur type de rôle.

---

### Niveau 3 : `getByText()` -- contenu statique

Trouve des éléments par leur contenu textuel visible.

**Avantages**
- Intuitif pour le texte non interactif (paragraphes, spans, badges, messages de statut)
- Prend en charge la correspondance exacte et par sous-chaîne

**Inconvénients**
- Fragile si le texte est dynamique, traduit ou dupliqué
- Peut cibler involontairement des éléments parents -- utilise `{ exact: true }` ou cadre la requête

**Règle générale** : utilise `getByText()` pour les assertions et la vérification de contenu, pas pour les éléments interactifs. Les éléments interactifs doivent utiliser `getByRole()`.

---

### Niveau 4 : `getByPlaceholder()` -- inputs sans label

Localise par la valeur de l'attribut placeholder.

**Avantages**
- Fonctionne quand les labels sont absents (barres de recherche, UI minimalistes)

**Inconvénients**
- Les placeholders disparaissent quand l'utilisateur tape -- mauvaise base d'UX
- Signale un manque d'accessibilité (pas de label)

**À traiter comme un signal d'alerte** : si tu l'utilises, envisage d'ouvrir un ticket pour ajouter un vrai label.

---

### Niveau 5 : `getByTestId()` -- dernier recours

Localise par l'attribut `data-testid`.

**Avantages**
- Totalement découplé du texte visible et de la structure
- Stable lors des refontes d'UI

**Inconvénients**
- Invisible pour les utilisateurs et les technologies d'assistance
- Pollue le markup de production (sauf s'il est retiré au build)
- Ne dit rien de l'apparence ni de la fonction de l'élément

**À utiliser uniquement quand** : le composant n'a ni rôle sémantique, ni label, ni texte, et que tu ne peux pas changer le markup. Cas courants : éléments canvas, widgets tiers, composants custom complexes.

---

### Ne jamais utiliser : sélecteurs CSS bruts ou XPath

```
// DO NOT do this
page.locator('.btn-primary');           // class names change
page.locator('#submit-btn');            // IDs are brittle
page.locator('div > span:nth-child(2)'); // structure changes break this
page.locator('xpath=//div[@class="foo"]'); // unreadable, fragile
```

Si tu es tenté d'utiliser un sélecteur CSS, arrête-toi. Remonte l'arbre de décision et trouve un locator sémantique. S'il n'en existe aucun, ajoute `data-testid`.

## Exemples concrets

### 1. Boutons

```typescript
// TypeScript
// Standard button
await page.getByRole('button', { name: 'Submit' }).click();

// Icon-only button (uses aria-label)
await page.getByRole('button', { name: 'Close' }).click();

// Button inside a specific section
await page.getByRole('region', { name: 'Billing' })
  .getByRole('button', { name: 'Update' }).click();
```

```javascript
// JavaScript
// Standard button
await page.getByRole('button', { name: 'Submit' }).click();

// Icon-only button (uses aria-label)
await page.getByRole('button', { name: 'Close' }).click();

// Button inside a specific section
await page.getByRole('region', { name: 'Billing' })
  .getByRole('button', { name: 'Update' }).click();
```

---

### 2. Liens

```typescript
// TypeScript
// Standard link
await page.getByRole('link', { name: 'Sign up' }).click();

// Link inside navigation
await page.getByRole('navigation')
  .getByRole('link', { name: 'Pricing' }).click();

// Link with exact match (avoid partial hits)
await page.getByRole('link', { name: 'Log in', exact: true }).click();
```

```javascript
// JavaScript
await page.getByRole('link', { name: 'Sign up' }).click();

await page.getByRole('navigation')
  .getByRole('link', { name: 'Pricing' }).click();

await page.getByRole('link', { name: 'Log in', exact: true }).click();
```

---

### 3. Champs texte

```typescript
// TypeScript
// Input with a visible label -- preferred
await page.getByLabel('Email address').fill('user@example.com');

// When multiple textboxes exist and you need role specificity
await page.getByRole('textbox', { name: 'Email address' }).fill('user@example.com');

// Textarea
await page.getByLabel('Message').fill('Hello, world');

// Search input (role = searchbox)
await page.getByRole('searchbox', { name: 'Search' }).fill('playwright');
```

```javascript
// JavaScript
await page.getByLabel('Email address').fill('user@example.com');

await page.getByRole('textbox', { name: 'Email address' }).fill('user@example.com');

await page.getByLabel('Message').fill('Hello, world');

await page.getByRole('searchbox', { name: 'Search' }).fill('playwright');
```

---

### 4. Cases à cocher et boutons radio

```typescript
// TypeScript
// Checkbox
await page.getByRole('checkbox', { name: 'Accept terms' }).check();

// Verify checked state
await expect(page.getByRole('checkbox', { name: 'Accept terms' })).toBeChecked();

// Radio button
await page.getByRole('radio', { name: 'Express shipping' }).check();

// Radio within a group (fieldset with legend)
await page.getByRole('group', { name: 'Shipping method' })
  .getByRole('radio', { name: 'Express' }).check();
```

```javascript
// JavaScript
await page.getByRole('checkbox', { name: 'Accept terms' }).check();

await expect(page.getByRole('checkbox', { name: 'Accept terms' })).toBeChecked();

await page.getByRole('radio', { name: 'Express shipping' }).check();

await page.getByRole('group', { name: 'Shipping method' })
  .getByRole('radio', { name: 'Express' }).check();
```

---

### 5. Dropdowns et selects

```typescript
// TypeScript
// Native <select> element
await page.getByLabel('Country').selectOption('Canada');

// Custom combobox (ARIA combobox role)
await page.getByRole('combobox', { name: 'Country' }).click();
await page.getByRole('option', { name: 'Canada' }).click();

// Listbox pattern
await page.getByRole('combobox', { name: 'Font size' }).click();
await page.getByRole('listbox').getByRole('option', { name: '16px' }).click();
```

```javascript
// JavaScript
await page.getByLabel('Country').selectOption('Canada');

await page.getByRole('combobox', { name: 'Country' }).click();
await page.getByRole('option', { name: 'Canada' }).click();

await page.getByRole('combobox', { name: 'Font size' }).click();
await page.getByRole('listbox').getByRole('option', { name: '16px' }).click();
```

---

### 6. Titres

```typescript
// TypeScript
// Specific heading level
await expect(page.getByRole('heading', { name: 'Dashboard', level: 1 })).toBeVisible();

// Any heading with that name (when level does not matter)
await expect(page.getByRole('heading', { name: 'Recent activity' })).toBeVisible();

// Heading within a section
await page.getByRole('region', { name: 'Sidebar' })
  .getByRole('heading', { name: 'Categories' });
```

```javascript
// JavaScript
await expect(page.getByRole('heading', { name: 'Dashboard', level: 1 })).toBeVisible();

await expect(page.getByRole('heading', { name: 'Recent activity' })).toBeVisible();

await page.getByRole('region', { name: 'Sidebar' })
  .getByRole('heading', { name: 'Categories' });
```

---

### 7. Éléments de navigation

```typescript
// TypeScript
// Link inside the main nav
await page.getByRole('navigation')
  .getByRole('link', { name: 'Pricing' }).click();

// When there are multiple navs, narrow by aria-label
await page.getByRole('navigation', { name: 'Main menu' })
  .getByRole('link', { name: 'Pricing' }).click();

// Breadcrumb navigation
await page.getByRole('navigation', { name: 'Breadcrumb' })
  .getByRole('link', { name: 'Products' }).click();
```

```javascript
// JavaScript
await page.getByRole('navigation')
  .getByRole('link', { name: 'Pricing' }).click();

await page.getByRole('navigation', { name: 'Main menu' })
  .getByRole('link', { name: 'Pricing' }).click();

await page.getByRole('navigation', { name: 'Breadcrumb' })
  .getByRole('link', { name: 'Products' }).click();
```

---

### 8. Cellules de tableau

```typescript
// TypeScript
// Find a cell in a specific row
await page.getByRole('row', { name: /Jane Smith/ })
  .getByRole('cell', { name: '$120.00' });

// Click an action button in a specific row
await page.getByRole('row', { name: /Jane Smith/ })
  .getByRole('button', { name: 'Edit' }).click();

// Filter rows using .filter() for complex matching
const row = page.getByRole('row').filter({ hasText: 'Pending' });
await row.getByRole('button', { name: 'Approve' }).click();

// Verify table header exists
await expect(page.getByRole('columnheader', { name: 'Status' })).toBeVisible();
```

```javascript
// JavaScript
await page.getByRole('row', { name: /Jane Smith/ })
  .getByRole('cell', { name: '$120.00' });

await page.getByRole('row', { name: /Jane Smith/ })
  .getByRole('button', { name: 'Edit' }).click();

const row = page.getByRole('row').filter({ hasText: 'Pending' });
await row.getByRole('button', { name: 'Approve' }).click();

await expect(page.getByRole('columnheader', { name: 'Status' })).toBeVisible();
```

---

### 9. Images

```typescript
// TypeScript
// Image with alt text
await expect(page.getByRole('img', { name: 'Company logo' })).toBeVisible();

// Alternative: getByAltText (same result, less preferred)
await expect(page.getByAltText('Company logo')).toBeVisible();

// Avatar image inside a card
await page.locator('article').filter({ hasText: 'Jane Smith' })
  .getByRole('img', { name: "Jane Smith's avatar" });
```

```javascript
// JavaScript
await expect(page.getByRole('img', { name: 'Company logo' })).toBeVisible();

await expect(page.getByAltText('Company logo')).toBeVisible();

await page.locator('article').filter({ hasText: 'Jane Smith' })
  .getByRole('img', { name: "Jane Smith's avatar" });
```

---

### 10. Composants custom (sans rôle ARIA)

```typescript
// TypeScript
// Third-party color picker with no semantic role
await page.getByTestId('color-picker').click();

// Custom drag-and-drop zone (locator.drop(), 1.60+)
await page.getByTestId('drop-zone').drop({ files: 'fixtures/report.pdf' });

// Canvas-based chart
const chart = page.getByTestId('revenue-chart');
await expect(chart).toBeVisible();
```

```javascript
// JavaScript
await page.getByTestId('color-picker').click();

await page.getByTestId('drop-zone').drop({ files: 'fixtures/report.pdf' });

const chart = page.getByTestId('revenue-chart');
await expect(chart).toBeVisible();
```

**Avant de recourir à `getByTestId`, demande-toi** : puis-je ajouter `role` et `aria-label` à ce composant à la place ? Si oui, fais-le et utilise `getByRole()`.

---

### 11. Listes dynamiques

```typescript
// TypeScript
// Filter a list item by text
const item = page.getByRole('listitem').filter({ hasText: 'Milk' });
await item.getByRole('button', { name: 'Remove' }).click();

// Filter by a child locator
const card = page.locator('.product-card').filter({
  has: page.getByText('Out of stock'),
});
await expect(card).toHaveCount(3);

// Count items in a list
await expect(page.getByRole('listitem')).toHaveCount(5);

// Iterate over list items for complex assertions
for (const item of await page.getByRole('listitem').all()) {
  await expect(item).toContainText('$');
}
```

```javascript
// JavaScript
const item = page.getByRole('listitem').filter({ hasText: 'Milk' });
await item.getByRole('button', { name: 'Remove' }).click();

const card = page.locator('.product-card').filter({
  has: page.getByText('Out of stock'),
});
await expect(card).toHaveCount(3);

await expect(page.getByRole('listitem')).toHaveCount(5);

for (const item of await page.getByRole('listitem').all()) {
  await expect(item).toContainText('$');
}
```

---

### 12. Modals et dialogs

```typescript
// TypeScript
// Wait for dialog to appear, then interact within it
const dialog = page.getByRole('dialog', { name: 'Confirm deletion' });
await expect(dialog).toBeVisible();
await dialog.getByRole('button', { name: 'Delete' }).click();

// Fill a form inside a dialog
const modal = page.getByRole('dialog', { name: 'Edit profile' });
await modal.getByLabel('Display name').fill('Jane');
await modal.getByRole('button', { name: 'Save' }).click();

// Verify dialog closed
await expect(dialog).toBeHidden();
```

```javascript
// JavaScript
const dialog = page.getByRole('dialog', { name: 'Confirm deletion' });
await expect(dialog).toBeVisible();
await dialog.getByRole('button', { name: 'Delete' }).click();

const modal = page.getByRole('dialog', { name: 'Edit profile' });
await modal.getByLabel('Display name').fill('Jane');
await modal.getByRole('button', { name: 'Save' }).click();

await expect(dialog).toBeHidden();
```

## Anti-patterns à éviter

| Anti-pattern | Pourquoi ça échoue | À utiliser à la place |
|---|---|---|
| `page.locator('.btn-primary')` | Les noms de classes changent lors des refactos et refontes | `getByRole('button', { name: '...' })` |
| `page.locator('#email-input')` | Les IDs sont des détails d'implémentation, pas visibles de l'utilisateur | `getByLabel('Email')` |
| `page.locator('div > form > input:first-child')` | Tout changement de structure casse le sélecteur | `getByLabel('...')` ou `getByRole('textbox', { name: '...' })` |
| `page.locator('[data-testid="submit"]')` | CSS brut pour les test IDs -- utilise la méthode intégrée | `getByTestId('submit')` |
| `page.getByText('Submit')` pour un bouton | Cible tout élément contenant ce texte, pas seulement le bouton | `getByRole('button', { name: 'Submit' })` |
| `page.locator('button').nth(2)` | Basé sur l'index -- casse quand l'ordre change | `getByRole('button', { name: '...' })` |

## Stratégie de cadrage : quand plusieurs éléments correspondent

Quand un locator correspond à plus d'un élément, restreins le périmètre plutôt que d'utiliser `nth()` :

```typescript
// BAD: fragile index
page.getByRole('button', { name: 'Edit' }).nth(0);

// GOOD: scope to a parent section
page.getByRole('region', { name: 'Billing' })
  .getByRole('button', { name: 'Edit' });

// GOOD: scope to a table row
page.getByRole('row', { name: /Order #1234/ })
  .getByRole('button', { name: 'Edit' });

// GOOD: scope with filter
page.locator('article').filter({ hasText: 'Draft' })
  .getByRole('button', { name: 'Edit' });
```

## Voir aussi

- [Documentation Playwright sur les locators](https://playwright.dev/docs/locators)
- [Bonnes pratiques Playwright](https://playwright.dev/docs/best-practices)
- [Référence des rôles ARIA (MDN)](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Roles)
