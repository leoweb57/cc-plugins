# Tests d'accessibilité

> **Quand l'utiliser** : Tous les projets. L'accessibilité n'est pas une fonctionnalité : c'est un socle de qualité. Intègre des vérifications automatisées (axe-core) à chaque suite de tests et complète-les par une vérification manuelle au clavier / lecteur d'écran pour les parcours critiques.
> **Prérequis** : [core/configuration.md](configuration.md), [core/locators.md](locators.md)

## Référence rapide

```typescript
// Install: npm install -D @axe-core/playwright
import AxeBuilder from '@axe-core/playwright';

// Full page scan
const results = await new AxeBuilder({ page }).analyze();
expect(results.violations).toEqual([]);

// Scoped scan — only the main content area
const results = await new AxeBuilder({ page }).include('#main-content').analyze();

// WCAG AA only
const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze();

// Exclude known issues during migration
const results = await new AxeBuilder({ page }).disableRules(['color-contrast']).analyze();

// Playwright 1.59+: capture the accessibility tree for the whole page
const pageTree = await page.ariaSnapshot();

// Or scope it to one region
const dialogTree = await page.getByRole('dialog', { name: 'Checkout' }).ariaSnapshot();

// Playwright 1.60+: assert the whole page's aria tree, and capture bounding boxes
await expect(page).toMatchAriaSnapshot();
const treeWithBoxes = await page.ariaSnapshot({ boxes: true });

// Playwright 1.63+: the same tree as a JSON value instead of YAML (accepts mode, depth, boxes)
const treeJson = await page.getByRole('navigation').ariaSnapshotJSON();
```

## Patterns

### Snapshots ARIA pour vérifier la structure

**Quand l'utiliser** : Tu veux vérifier la forme de l'arbre d'accessibilité d'une page, d'une région, d'une boîte de dialogue ou d'un widget, en plus de lancer axe.
**À éviter quand** : Tu n'as besoin que des vérifications WCAG basées sur des règles. Commence par axe pour une couverture large, puis utilise les snapshots ARIA pour les assertions de structure à forte valeur.

Playwright 1.59 ajoute `page.ariaSnapshot()` comme raccourci pour capturer l'arbre d'accessibilité au niveau de la page, et enrichit `locator.ariaSnapshot()` avec plus de contrôle sur la profondeur et le mode du snapshot. C'est utile pour les menus, les boîtes de dialogue, les widgets composites et les autres composants où la structure sémantique compte autant que la forme brute du DOM.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('checkout dialog exposes the expected accessibility structure', async ({ page }) => {
  await page.goto('/checkout');
  await page.getByRole('button', { name: 'Open checkout' }).click();

  const dialogTree = await page
    .getByRole('dialog', { name: 'Checkout' })
    .ariaSnapshot();

  expect(dialogTree).toContain('heading "Checkout"');
  expect(dialogTree).toContain('button "Apply coupon"');
});
```

**Options de snapshot**

Quand l'arbre d'accessibilité complet est trop bruité, utilise les options les plus récentes pour limiter le résultat au niveau de détail qui t'intéresse vraiment.

```typescript
const menuTree = await page.getByRole('menu', { name: 'Account' }).ariaSnapshot({
  depth: 2,
});

const summaryTree = await page.getByRole('dialog', { name: 'Checkout' }).ariaSnapshot({
  mode: 'summary',
});
```

Privilégie des snapshots plus petits pour des assertions stables. Les snapshots d'arbre complet et profond sont puissants, mais ils peuvent devenir fragiles si la structure du composant change souvent.

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('checkout dialog exposes the expected accessibility structure', async ({ page }) => {
  await page.goto('/checkout');
  await page.getByRole('button', { name: 'Open checkout' }).click();

  const dialogTree = await page
    .getByRole('dialog', { name: 'Checkout' })
    .ariaSnapshot();

  expect(dialogTree).toContain('heading "Checkout"');
  expect(dialogTree).toContain('button "Apply coupon"');
});
```

### Assertions de snapshot ARIA au niveau de la page (Playwright 1.60+)

**Quand l'utiliser** : Tu veux vérifier l'arbre d'accessibilité de toute la page par rapport à un snapshot enregistré, ou tu as besoin des bounding boxes des éléments en plus de l'arbre (utile pour la consommation par une IA / un agent et pour les vérifications sensibles à la mise en page).
**À éviter quand** : Une assertion sur un locator ciblé suffit : les snapshots de page entière sont larges et changent souvent. Préfère une région stable.

Playwright 1.60 permet à `expect(page).toMatchAriaSnapshot()` de s'exécuter **au niveau de la page** (équivalent à une assertion sur `page.locator('body')`), et ajoute une option `boxes` à `ariaSnapshot()` qui ajoute la bounding box de chaque élément.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('home page matches its aria snapshot', async ({ page }) => {
  await page.goto('/');

  // Page-level assertion — no need to target body explicitly.
  // First run writes the snapshot; later runs compare against it.
  await expect(page).toMatchAriaSnapshot();
});

test('capture aria tree with bounding boxes', async ({ page }) => {
  await page.goto('/dashboard');

  // `boxes: true` appends each node's bounding box as [box=x,y,width,height]
  const treeWithBoxes = await page.ariaSnapshot({ boxes: true });
  expect(treeWithBoxes).toContain('heading "Dashboard"');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('home page matches its aria snapshot', async ({ page }) => {
  await page.goto('/');
  await expect(page).toMatchAriaSnapshot();
});
```

> Le `toMatchAriaSnapshot()` au niveau de la page est large : cible plutôt une région (`expect(page.getByRole('main')).toMatchAriaSnapshot()`) quand tu veux des assertions qui survivent aux changements de mise en page sans rapport.

### Intégration axe-core/playwright

**Quand l'utiliser** : Tu veux une détection automatisée des violations WCAG sur n'importe quelle page ou n'importe quel composant. C'est ta première ligne de défense et elle doit tourner dans chaque suite de tests.
**À éviter quand** : Tu dois vérifier la qualité subjective de l'UX (ordre de lecture, charge cognitive, langage clair). axe-core détecte les violations structurelles, pas les problèmes d'utilisabilité.

axe-core détecte automatiquement environ 30 à 40 % des problèmes WCAG. Ces 30-40 % incluent les violations les plus courantes et les plus flagrantes : texte alternatif manquant, associations de labels cassées, ARIA invalide et échecs de contraste. Les attraper automatiquement te libère du temps pour traiter manuellement les problèmes plus difficiles.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('accessibility', () => {
  test('home page has no accessibility violations', async ({ page }) => {
    await page.goto('/');

    const results = await new AxeBuilder({ page }).analyze();

    expect(results.violations).toEqual([]);
  });

  test('dashboard has no accessibility violations after login', async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('Email').fill('user@example.com');
    await page.getByLabel('Password').fill('password123');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await page.waitForURL('/dashboard');

    // Scan after the page is fully interactive
    const results = await new AxeBuilder({ page }).analyze();

    expect(results.violations).toEqual([]);
  });

  test('report violations with helpful details on failure', async ({ page }) => {
    await page.goto('/products');

    const results = await new AxeBuilder({ page }).analyze();

    // Format violations for readable test output
    const violationSummary = results.violations.map((v) => ({
      rule: v.id,
      impact: v.impact,
      description: v.description,
      nodes: v.nodes.length,
      help: v.helpUrl,
    }));

    expect(results.violations, JSON.stringify(violationSummary, null, 2)).toEqual([]);
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;

test.describe('accessibility', () => {
  test('home page has no accessibility violations', async ({ page }) => {
    await page.goto('/');

    const results = await new AxeBuilder({ page }).analyze();

    expect(results.violations).toEqual([]);
  });

  test('report violations with helpful details on failure', async ({ page }) => {
    await page.goto('/products');

    const results = await new AxeBuilder({ page }).analyze();

    const violationSummary = results.violations.map((v) => ({
      rule: v.id,
      impact: v.impact,
      description: v.description,
      nodes: v.nodes.length,
      help: v.helpUrl,
    }));

    expect(results.violations, JSON.stringify(violationSummary, null, 2)).toEqual([]);
  });
});
```

### Analyser des zones précises

**Quand l'utiliser** : Tu veux concentrer axe-core sur un composant précis (nouvelle fonctionnalité, section refondue) ou exclure des zones que tu ne maîtrises pas (widgets tiers, publicités, iframes intégrées).
**À éviter quand** : Tu veux une baseline sur la page entière. Analyse d'abord tout, puis affine.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('scoped accessibility scans', () => {
  test('scan only the checkout form', async ({ page }) => {
    await page.goto('/checkout');

    const results = await new AxeBuilder({ page })
      .include('#checkout-form')
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('scan page excluding third-party chat widget', async ({ page }) => {
    await page.goto('/support');

    const results = await new AxeBuilder({ page })
      .exclude('#intercom-widget')
      .exclude('.third-party-ads')
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('scan multiple specific regions', async ({ page }) => {
    await page.goto('/dashboard');

    // Include multiple areas — each is scanned independently
    const results = await new AxeBuilder({ page })
      .include('#navigation')
      .include('#main-content')
      .include('#footer')
      .exclude('.ad-banner')
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('scan a modal after it opens', async ({ page }) => {
    await page.goto('/settings');
    await page.getByRole('button', { name: 'Delete account' }).click();

    // Wait for the modal to be fully rendered
    await expect(page.getByRole('dialog', { name: 'Confirm deletion' })).toBeVisible();

    const results = await new AxeBuilder({ page })
      .include('[role="dialog"]')
      .analyze();

    expect(results.violations).toEqual([]);
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;

test.describe('scoped accessibility scans', () => {
  test('scan only the checkout form', async ({ page }) => {
    await page.goto('/checkout');

    const results = await new AxeBuilder({ page })
      .include('#checkout-form')
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('scan page excluding third-party chat widget', async ({ page }) => {
    await page.goto('/support');

    const results = await new AxeBuilder({ page })
      .exclude('#intercom-widget')
      .exclude('.third-party-ads')
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('scan a modal after it opens', async ({ page }) => {
    await page.goto('/settings');
    await page.getByRole('button', { name: 'Delete account' }).click();
    await expect(page.getByRole('dialog', { name: 'Confirm deletion' })).toBeVisible();

    const results = await new AxeBuilder({ page })
      .include('[role="dialog"]')
      .analyze();

    expect(results.violations).toEqual([]);
  });
});
```

### Niveaux de conformité WCAG

**Quand l'utiliser** : Ton projet vise un niveau de conformité WCAG précis (la plupart visent AA). Utilise les tags pour limiter axe-core aux règles qui comptent pour ton exigence de conformité.
**À éviter quand** : Tu veux le scan le plus large possible. Omettre `withTags()` exécute toutes les règles, y compris les bonnes pratiques au-delà de WCAG.

Référence des tags :
- `wcag2a` — WCAG 2.0 niveau A (minimum)
- `wcag2aa` — WCAG 2.0 niveau AA (cible standard pour la plupart des organisations)
- `wcag2aaa` — WCAG 2.0 niveau AAA (strict ; rarement exigé)
- `wcag21a`, `wcag21aa`, `wcag21aaa` — ajouts de WCAG 2.1
- `wcag22aa` — ajouts de WCAG 2.2
- `best-practice` — hors WCAG, mais patterns recommandés

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('WCAG compliance levels', () => {
  test('meets WCAG 2.1 AA (standard compliance target)', async ({ page }) => {
    await page.goto('/');

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('meets WCAG 2.2 AA (latest standard)', async ({ page }) => {
    await page.goto('/');

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('meets WCAG AAA (strict — use for government or healthcare)', async ({ page }) => {
    await page.goto('/');

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag2aaa', 'wcag21a', 'wcag21aa', 'wcag21aaa'])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('best practices beyond WCAG', async ({ page }) => {
    await page.goto('/');

    const results = await new AxeBuilder({ page })
      .withTags(['best-practice'])
      .analyze();

    // Use soft assertion — best practices are advisory, not blocking
    expect.soft(results.violations).toEqual([]);
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;

test.describe('WCAG compliance levels', () => {
  test('meets WCAG 2.1 AA (standard compliance target)', async ({ page }) => {
    await page.goto('/');

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('meets WCAG 2.2 AA (latest standard)', async ({ page }) => {
    await page.goto('/');

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
      .analyze();

    expect(results.violations).toEqual([]);
  });
});
```

### Désactiver des règles précises

**Quand l'utiliser** : Tu migres progressivement une application legacy vers la conformité d'accessibilité. Tu as des violations connues, documentées dans un système de suivi, et tu veux que la suite de tests détecte les nouvelles régressions sans échouer sur les problèmes existants.
**À éviter quand** : Tu masques des violations que tu n'as pas l'intention de corriger. Chaque règle désactivée doit avoir un ticket de suivi.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

// Centralize known exceptions — makes them visible and trackable
const KNOWN_ISSUES = {
  // JIRA-1234: Legacy header component, scheduled for redesign Q2
  rules: ['color-contrast'],
  // JIRA-1235: Third-party date picker has no label association
  selectors: ['#legacy-datepicker'],
};

test.describe('accessibility with known exceptions', () => {
  test('no new violations (excluding tracked known issues)', async ({ page }) => {
    await page.goto('/dashboard');

    const results = await new AxeBuilder({ page })
      .disableRules(KNOWN_ISSUES.rules)
      .exclude(KNOWN_ISSUES.selectors[0])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('verify known issues still exist (remove when fixed)', async ({ page }) => {
    await page.goto('/dashboard');

    // Scan ONLY for the known issues to confirm they still exist
    // When this test fails (violations disappear), remove the exception
    const results = await new AxeBuilder({ page })
      .withRules(KNOWN_ISSUES.rules)
      .analyze();

    if (results.violations.length === 0) {
      console.warn(
        'Known accessibility issues appear to be fixed. ' +
        'Remove exceptions from KNOWN_ISSUES and close tracking tickets.'
      );
    }
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;

const KNOWN_ISSUES = {
  rules: ['color-contrast'],
  selectors: ['#legacy-datepicker'],
};

test.describe('accessibility with known exceptions', () => {
  test('no new violations (excluding tracked known issues)', async ({ page }) => {
    await page.goto('/dashboard');

    const results = await new AxeBuilder({ page })
      .disableRules(KNOWN_ISSUES.rules)
      .exclude(KNOWN_ISSUES.selectors[0])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('verify known issues still exist (remove when fixed)', async ({ page }) => {
    await page.goto('/dashboard');

    const results = await new AxeBuilder({ page })
      .withRules(KNOWN_ISSUES.rules)
      .analyze();

    if (results.violations.length === 0) {
      console.warn(
        'Known accessibility issues appear to be fixed. ' +
        'Remove exceptions from KNOWN_ISSUES and close tracking tickets.'
      );
    }
  });
});
```

### Tests de navigation au clavier

**Quand l'utiliser** : Tu vérifies que tous les éléments interactifs sont atteignables et utilisables au clavier seul. C'est critique pour les utilisateurs en situation de handicap moteur et pour les power users qui naviguent sans souris.
**À éviter quand** : Ne jamais s'en passer. Les outils automatisés ne peuvent pas vérifier entièrement la navigation au clavier : cela demande des tests comportementaux.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('keyboard navigation', () => {
  test('tab order follows logical reading order', async ({ page }) => {
    await page.goto('/login');

    // Tab through interactive elements and verify focus order
    await page.keyboard.press('Tab');
    await expect(page.getByLabel('Email')).toBeFocused();

    await page.keyboard.press('Tab');
    await expect(page.getByLabel('Password')).toBeFocused();

    await page.keyboard.press('Tab');
    await expect(page.getByRole('link', { name: 'Forgot password?' })).toBeFocused();

    await page.keyboard.press('Tab');
    await expect(page.getByRole('button', { name: 'Sign in' })).toBeFocused();

    // Verify Enter activates the focused button
    await page.getByLabel('Email').fill('user@example.com');
    await page.getByLabel('Password').fill('password123');
    await page.getByRole('button', { name: 'Sign in' }).focus();
    await page.keyboard.press('Enter');
    await page.waitForURL('/dashboard');
  });

  test('skip navigation link moves focus to main content', async ({ page }) => {
    await page.goto('/');

    // First Tab should land on the skip link (visually hidden until focused)
    await page.keyboard.press('Tab');
    const skipLink = page.getByRole('link', { name: 'Skip to main content' });
    await expect(skipLink).toBeFocused();

    // Activating the skip link moves focus past the nav
    await page.keyboard.press('Enter');
    await expect(page.locator('#main-content')).toBeFocused();
  });

  test('dropdown menu operates with keyboard', async ({ page }) => {
    await page.goto('/dashboard');

    const menuButton = page.getByRole('button', { name: 'User menu' });
    await menuButton.focus();

    // Open menu with Enter or Space
    await page.keyboard.press('Enter');
    const menu = page.getByRole('menu');
    await expect(menu).toBeVisible();

    // Arrow keys navigate menu items
    await page.keyboard.press('ArrowDown');
    await expect(page.getByRole('menuitem', { name: 'Profile' })).toBeFocused();

    await page.keyboard.press('ArrowDown');
    await expect(page.getByRole('menuitem', { name: 'Settings' })).toBeFocused();

    // Escape closes the menu and returns focus to the trigger
    await page.keyboard.press('Escape');
    await expect(menu).not.toBeVisible();
    await expect(menuButton).toBeFocused();
  });

  test('keyboard shortcuts work correctly', async ({ page }) => {
    await page.goto('/editor');

    // Ctrl+S / Cmd+S triggers save
    const modifier = process.platform === 'darwin' ? 'Meta' : 'Control';
    const saveResponse = page.waitForResponse('**/api/save');
    await page.keyboard.press(`${modifier}+s`);
    await saveResponse;

    await expect(page.getByText('Saved')).toBeVisible();
  });

  test('no keyboard traps in form navigation', async ({ page }) => {
    await page.goto('/complex-form');

    // Tab through every field — focus should never get stuck
    const interactiveElements = page.locator(
      'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const count = await interactiveElements.count();

    for (let i = 0; i < count; i++) {
      await page.keyboard.press('Tab');
      // Verify something is focused (focus did not get trapped or lost)
      const focused = page.locator(':focus');
      await expect(focused).toBeAttached();
    }
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('keyboard navigation', () => {
  test('tab order follows logical reading order', async ({ page }) => {
    await page.goto('/login');

    await page.keyboard.press('Tab');
    await expect(page.getByLabel('Email')).toBeFocused();

    await page.keyboard.press('Tab');
    await expect(page.getByLabel('Password')).toBeFocused();

    await page.keyboard.press('Tab');
    await expect(page.getByRole('link', { name: 'Forgot password?' })).toBeFocused();

    await page.keyboard.press('Tab');
    await expect(page.getByRole('button', { name: 'Sign in' })).toBeFocused();
  });

  test('dropdown menu operates with keyboard', async ({ page }) => {
    await page.goto('/dashboard');

    const menuButton = page.getByRole('button', { name: 'User menu' });
    await menuButton.focus();

    await page.keyboard.press('Enter');
    const menu = page.getByRole('menu');
    await expect(menu).toBeVisible();

    await page.keyboard.press('ArrowDown');
    await expect(page.getByRole('menuitem', { name: 'Profile' })).toBeFocused();

    await page.keyboard.press('Escape');
    await expect(menu).not.toBeVisible();
    await expect(menuButton).toBeFocused();
  });

  test('no keyboard traps in form navigation', async ({ page }) => {
    await page.goto('/complex-form');

    const interactiveElements = page.locator(
      'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const count = await interactiveElements.count();

    for (let i = 0; i < count; i++) {
      await page.keyboard.press('Tab');
      const focused = page.locator(':focus');
      await expect(focused).toBeAttached();
    }
  });
});
```

### Patterns de test avec lecteur d'écran

**Quand l'utiliser** : Tu vérifies que les attributs ARIA, les live regions et les rôles produisent la bonne expérience d'accessibilité. Tu ne peux pas lancer un vrai lecteur d'écran en CI, mais tu peux vérifier la structure sémantique dont les lecteurs d'écran dépendent.
**À éviter quand** : Tu veux tester la sortie réelle d'un lecteur d'écran (utilise pour cela des tests manuels avec NVDA/VoiceOver).

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('screen reader semantics', () => {
  test('ARIA labels provide meaningful context', async ({ page }) => {
    await page.goto('/dashboard');

    // Navigation landmarks must have distinct labels
    const mainNav = page.getByRole('navigation', { name: 'Main' });
    const footerNav = page.getByRole('navigation', { name: 'Footer' });
    await expect(mainNav).toBeVisible();
    await expect(footerNav).toBeVisible();

    // Regions should have accessible names
    const mainRegion = page.getByRole('main');
    await expect(mainRegion).toBeAttached();

    // Buttons with icons must have accessible names
    const closeButton = page.getByRole('button', { name: 'Close' });
    await expect(closeButton).toBeAttached();

    // Images must have alt text (getByRole('img') only matches with accessible name)
    const logo = page.getByRole('img', { name: 'Company logo' });
    await expect(logo).toBeVisible();
  });

  test('live regions announce dynamic content changes', async ({ page }) => {
    await page.goto('/notifications');

    // Verify the live region exists before triggering content
    const statusRegion = page.locator('[aria-live="polite"]');
    await expect(statusRegion).toBeAttached();

    // Trigger an action that updates the live region
    await page.getByRole('button', { name: 'Save' }).click();

    // Verify the live region received the update
    await expect(statusRegion).toHaveText('Changes saved successfully');
  });

  test('alert live region announces errors immediately', async ({ page }) => {
    await page.goto('/checkout');

    // aria-live="assertive" or role="alert" interrupts the screen reader
    await page.getByRole('button', { name: 'Place order' }).click();

    const alert = page.getByRole('alert');
    await expect(alert).toBeVisible();
    await expect(alert).toHaveText('Payment method is required');
  });

  test('expandable sections announce their state', async ({ page }) => {
    await page.goto('/faq');

    const faqButton = page.getByRole('button', { name: 'How do I reset my password?' });

    // aria-expanded should reflect the current state
    await expect(faqButton).toHaveAttribute('aria-expanded', 'false');

    await faqButton.click();
    await expect(faqButton).toHaveAttribute('aria-expanded', 'true');

    // The controlled panel should be visible
    const panel = page.locator(`#${await faqButton.getAttribute('aria-controls')}`);
    await expect(panel).toBeVisible();
  });

  test('page headings form a logical hierarchy', async ({ page }) => {
    await page.goto('/about');

    // There should be exactly one h1
    await expect(page.getByRole('heading', { level: 1 })).toHaveCount(1);

    // Heading levels should not skip (h1 -> h3 without h2 is a violation)
    const headings = page.getByRole('heading');
    const count = await headings.count();
    let previousLevel = 0;

    for (let i = 0; i < count; i++) {
      const heading = headings.nth(i);
      const tagName = await heading.evaluate((el) => el.tagName.toLowerCase());
      const level = parseInt(tagName.replace('h', ''), 10);

      // Level can go up by 1 or drop to any lower level, but never skip forward
      if (level > previousLevel + 1 && previousLevel !== 0) {
        throw new Error(
          `Heading hierarchy skipped from h${previousLevel} to h${level}: "${await heading.textContent()}"`
        );
      }
      previousLevel = level;
    }
  });

  test('table has proper headers and caption', async ({ page }) => {
    await page.goto('/reports');

    const table = page.getByRole('table', { name: 'Monthly revenue' });
    await expect(table).toBeVisible();

    // Column headers
    const columnHeaders = table.getByRole('columnheader');
    await expect(columnHeaders).toHaveCount(4);
    await expect(columnHeaders.first()).toHaveText('Month');

    // Row headers (if applicable)
    const rowHeaders = table.getByRole('rowheader');
    await expect(rowHeaders.first()).toHaveText('January');
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('screen reader semantics', () => {
  test('ARIA labels provide meaningful context', async ({ page }) => {
    await page.goto('/dashboard');

    const mainNav = page.getByRole('navigation', { name: 'Main' });
    const footerNav = page.getByRole('navigation', { name: 'Footer' });
    await expect(mainNav).toBeVisible();
    await expect(footerNav).toBeVisible();

    const closeButton = page.getByRole('button', { name: 'Close' });
    await expect(closeButton).toBeAttached();

    const logo = page.getByRole('img', { name: 'Company logo' });
    await expect(logo).toBeVisible();
  });

  test('live regions announce dynamic content changes', async ({ page }) => {
    await page.goto('/notifications');

    const statusRegion = page.locator('[aria-live="polite"]');
    await expect(statusRegion).toBeAttached();

    await page.getByRole('button', { name: 'Save' }).click();
    await expect(statusRegion).toHaveText('Changes saved successfully');
  });

  test('expandable sections announce their state', async ({ page }) => {
    await page.goto('/faq');

    const faqButton = page.getByRole('button', { name: 'How do I reset my password?' });
    await expect(faqButton).toHaveAttribute('aria-expanded', 'false');

    await faqButton.click();
    await expect(faqButton).toHaveAttribute('aria-expanded', 'true');
  });
});
```

### Vérification du contraste des couleurs

**Quand l'utiliser** : Tu t'assures que le texte et les composants d'interface respectent les ratios de contraste WCAG. axe-core vérifie le contraste automatiquement, mais tu peux avoir besoin de vérifications explicites pour les thèmes dynamiques, le dark mode ou les changements de couleurs de marque.
**À éviter quand** : La règle de contraste native d'axe-core couvre ton cas. N'ajoute des vérifications explicites que pour les changements de couleurs dynamiques qu'axe ne peut pas observer en un seul scan.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('color contrast', () => {
  test('light theme meets contrast requirements', async ({ page }) => {
    await page.goto('/');

    const results = await new AxeBuilder({ page })
      .withRules(['color-contrast'])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('dark theme meets contrast requirements', async ({ page }) => {
    await page.goto('/');

    // Activate dark mode
    await page.getByRole('button', { name: 'Toggle dark mode' }).click();

    // Wait for theme transition to complete
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');

    const results = await new AxeBuilder({ page })
      .withRules(['color-contrast'])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('high contrast mode meets AAA contrast requirements', async ({ page }) => {
    await page.goto('/settings/display');
    await page.getByRole('checkbox', { name: 'High contrast' }).check();

    // AAA requires 7:1 for normal text, 4.5:1 for large text
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2aaa'])
      .withRules(['color-contrast'])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('focus indicators are visible', async ({ page }) => {
    await page.goto('/');

    // Tab to an element and verify focus outline has sufficient contrast
    await page.keyboard.press('Tab');
    const focusedElement = page.locator(':focus');

    // Verify the outline is not transparent or zero-width
    const outline = await focusedElement.evaluate((el) => {
      const styles = window.getComputedStyle(el);
      return {
        outlineStyle: styles.outlineStyle,
        outlineWidth: styles.outlineWidth,
        outlineColor: styles.outlineColor,
        boxShadow: styles.boxShadow,
      };
    });

    // Focus must be visible — either outline or box-shadow
    const hasVisibleFocus =
      (outline.outlineStyle !== 'none' && outline.outlineWidth !== '0px') ||
      outline.boxShadow !== 'none';

    expect(hasVisibleFocus, 'Focused element must have a visible focus indicator').toBe(true);
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;

test.describe('color contrast', () => {
  test('light theme meets contrast requirements', async ({ page }) => {
    await page.goto('/');

    const results = await new AxeBuilder({ page })
      .withRules(['color-contrast'])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('dark theme meets contrast requirements', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('button', { name: 'Toggle dark mode' }).click();
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');

    const results = await new AxeBuilder({ page })
      .withRules(['color-contrast'])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('focus indicators are visible', async ({ page }) => {
    await page.goto('/');
    await page.keyboard.press('Tab');
    const focusedElement = page.locator(':focus');

    const outline = await focusedElement.evaluate((el) => {
      const styles = window.getComputedStyle(el);
      return {
        outlineStyle: styles.outlineStyle,
        outlineWidth: styles.outlineWidth,
        boxShadow: styles.boxShadow,
      };
    });

    const hasVisibleFocus =
      (outline.outlineStyle !== 'none' && outline.outlineWidth !== '0px') ||
      outline.boxShadow !== 'none';

    expect(hasVisibleFocus, 'Focused element must have a visible focus indicator').toBe(true);
  });
});
```

**Émuler les préférences d'affichage de l'utilisateur (1.63+)** : `contrast`, `forcedColors` et `reducedMotion` sont des options de test autonomes, donc un projet ou `test.use()` peut exécuter le même scan de contraste sous des préférences au niveau de l'OS au lieu de basculer un réglage dans l'application :

```typescript
test.use({ contrast: 'more', forcedColors: 'active', reducedMotion: 'reduce' });
```

### Test de piège à focus

**Quand l'utiliser** : Tu testes des modales, boîtes de dialogue, menus déroulants, panneaux coulissants et tout overlay qui doit piéger le focus à l'intérieur de lui-même pour empêcher les utilisateurs d'interagir par erreur avec le contenu d'arrière-plan.
**À éviter quand** : Le composant ne se superpose pas au contenu (les sections dépliables en ligne n'ont pas besoin de piège à focus).

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('focus trap', () => {
  test('modal traps focus within itself', async ({ page }) => {
    await page.goto('/settings');

    // Open the modal
    await page.getByRole('button', { name: 'Delete account' }).click();
    const dialog = page.getByRole('dialog', { name: 'Confirm deletion' });
    await expect(dialog).toBeVisible();

    // Focus should move into the dialog automatically
    const firstFocusable = dialog.getByRole('button', { name: 'Cancel' });
    await expect(firstFocusable).toBeFocused();

    // Tab should cycle within the dialog
    await page.keyboard.press('Tab');
    await expect(dialog.getByRole('button', { name: 'Delete' })).toBeFocused();

    // Tab again wraps back to the first focusable element
    await page.keyboard.press('Tab');
    await expect(dialog.getByRole('button', { name: 'Cancel' })).toBeFocused();

    // Shift+Tab wraps to the last focusable element
    await page.keyboard.press('Shift+Tab');
    await expect(dialog.getByRole('button', { name: 'Delete' })).toBeFocused();

    // Escape closes the dialog
    await page.keyboard.press('Escape');
    await expect(dialog).not.toBeVisible();

    // Focus returns to the trigger element
    await expect(page.getByRole('button', { name: 'Delete account' })).toBeFocused();
  });

  test('dropdown menu traps focus and returns it on close', async ({ page }) => {
    await page.goto('/dashboard');

    const trigger = page.getByRole('button', { name: 'Actions' });
    await trigger.click();

    const menu = page.getByRole('menu');
    await expect(menu).toBeVisible();

    // First menu item receives focus
    await expect(page.getByRole('menuitem').first()).toBeFocused();

    // ArrowDown moves through items
    await page.keyboard.press('ArrowDown');
    await expect(page.getByRole('menuitem').nth(1)).toBeFocused();

    // Escape closes and returns focus
    await page.keyboard.press('Escape');
    await expect(menu).not.toBeVisible();
    await expect(trigger).toBeFocused();
  });

  test('background content is inert when modal is open', async ({ page }) => {
    await page.goto('/settings');
    await page.getByRole('button', { name: 'Delete account' }).click();

    const dialog = page.getByRole('dialog');
    await expect(dialog).toBeVisible();

    // Background content should have aria-hidden="true" or be inert
    const mainContent = page.locator('main');
    const isHidden = await mainContent.evaluate((el) => {
      return el.getAttribute('aria-hidden') === 'true' || el.hasAttribute('inert');
    });

    expect(isHidden, 'Background content must be hidden from assistive technology').toBe(true);
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('focus trap', () => {
  test('modal traps focus within itself', async ({ page }) => {
    await page.goto('/settings');
    await page.getByRole('button', { name: 'Delete account' }).click();

    const dialog = page.getByRole('dialog', { name: 'Confirm deletion' });
    await expect(dialog).toBeVisible();

    const firstFocusable = dialog.getByRole('button', { name: 'Cancel' });
    await expect(firstFocusable).toBeFocused();

    await page.keyboard.press('Tab');
    await expect(dialog.getByRole('button', { name: 'Delete' })).toBeFocused();

    await page.keyboard.press('Tab');
    await expect(dialog.getByRole('button', { name: 'Cancel' })).toBeFocused();

    await page.keyboard.press('Escape');
    await expect(dialog).not.toBeVisible();
    await expect(page.getByRole('button', { name: 'Delete account' })).toBeFocused();
  });

  test('background content is inert when modal is open', async ({ page }) => {
    await page.goto('/settings');
    await page.getByRole('button', { name: 'Delete account' }).click();
    await expect(page.getByRole('dialog')).toBeVisible();

    const mainContent = page.locator('main');
    const isHidden = await mainContent.evaluate((el) => {
      return el.getAttribute('aria-hidden') === 'true' || el.hasAttribute('inert');
    });

    expect(isHidden, 'Background content must be hidden from assistive technology').toBe(true);
  });
});
```

### Formulaires accessibles

**Quand l'utiliser** : Tu testes que les formulaires sont utilisables avec les technologies d'assistance. Chaque champ de formulaire doit avoir un label associé, les messages d'erreur doivent être liés par programmation et les champs obligatoires doivent être annoncés.
**À éviter quand** : Ne jamais s'en passer, pour aucun formulaire.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('accessible forms', () => {
  test('all form fields have associated labels', async ({ page }) => {
    await page.goto('/register');

    // Every input should be reachable via getByLabel (proves label association)
    await expect(page.getByLabel('First name')).toBeVisible();
    await expect(page.getByLabel('Last name')).toBeVisible();
    await expect(page.getByLabel('Email')).toBeVisible();
    await expect(page.getByLabel('Password')).toBeVisible();

    // Run axe to catch any we missed
    const results = await new AxeBuilder({ page })
      .include('form')
      .withRules(['label', 'label-title-only'])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('required fields are announced to screen readers', async ({ page }) => {
    await page.goto('/register');

    // Required fields must have aria-required="true" or the required attribute
    const emailField = page.getByLabel('Email');
    const hasRequired = await emailField.evaluate((el) => {
      return el.hasAttribute('required') || el.getAttribute('aria-required') === 'true';
    });

    expect(hasRequired, 'Email field must be marked as required').toBe(true);
  });

  test('error messages are linked to their fields via aria-describedby', async ({ page }) => {
    await page.goto('/register');

    // Submit empty form to trigger validation
    await page.getByRole('button', { name: 'Create account' }).click();

    // The error message should be visible
    const errorMessage = page.getByText('Email is required');
    await expect(errorMessage).toBeVisible();

    // The error must be linked to the field via aria-describedby
    const emailField = page.getByLabel('Email');
    const describedBy = await emailField.getAttribute('aria-describedby');
    expect(describedBy).toBeTruthy();

    // The id of the error message matches the aria-describedby value
    const errorId = await errorMessage.getAttribute('id');
    expect(describedBy).toContain(errorId);

    // The field should also indicate invalid state
    await expect(emailField).toHaveAttribute('aria-invalid', 'true');
  });

  test('form error summary is announced and links to fields', async ({ page }) => {
    await page.goto('/register');
    await page.getByRole('button', { name: 'Create account' }).click();

    // Error summary should appear with role="alert" for immediate announcement
    const errorSummary = page.getByRole('alert');
    await expect(errorSummary).toBeVisible();
    await expect(errorSummary).toContainText('Please fix the following errors');

    // Error summary links should move focus to the corresponding field
    await errorSummary.getByRole('link', { name: 'Email is required' }).click();
    await expect(page.getByLabel('Email')).toBeFocused();
  });

  test('autocomplete attributes are set for common fields', async ({ page }) => {
    await page.goto('/checkout');

    // Autocomplete helps password managers and assistive tech fill forms
    await expect(page.getByLabel('Full name')).toHaveAttribute('autocomplete', 'name');
    await expect(page.getByLabel('Email')).toHaveAttribute('autocomplete', 'email');
    await expect(page.getByLabel('Street address')).toHaveAttribute('autocomplete', 'street-address');
    await expect(page.getByLabel('Postal code')).toHaveAttribute('autocomplete', 'postal-code');
  });

  test('fieldsets group related fields with legends', async ({ page }) => {
    await page.goto('/checkout');

    // Related fields should be grouped in fieldsets with legends
    const shippingGroup = page.getByRole('group', { name: 'Shipping address' });
    await expect(shippingGroup).toBeVisible();
    await expect(shippingGroup.getByLabel('Street address')).toBeVisible();

    const billingGroup = page.getByRole('group', { name: 'Billing address' });
    await expect(billingGroup).toBeVisible();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;

test.describe('accessible forms', () => {
  test('all form fields have associated labels', async ({ page }) => {
    await page.goto('/register');

    await expect(page.getByLabel('First name')).toBeVisible();
    await expect(page.getByLabel('Last name')).toBeVisible();
    await expect(page.getByLabel('Email')).toBeVisible();
    await expect(page.getByLabel('Password')).toBeVisible();

    const results = await new AxeBuilder({ page })
      .include('form')
      .withRules(['label', 'label-title-only'])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('error messages are linked to their fields via aria-describedby', async ({ page }) => {
    await page.goto('/register');
    await page.getByRole('button', { name: 'Create account' }).click();

    const errorMessage = page.getByText('Email is required');
    await expect(errorMessage).toBeVisible();

    const emailField = page.getByLabel('Email');
    const describedBy = await emailField.getAttribute('aria-describedby');
    expect(describedBy).toBeTruthy();

    const errorId = await errorMessage.getAttribute('id');
    expect(describedBy).toContain(errorId);

    await expect(emailField).toHaveAttribute('aria-invalid', 'true');
  });

  test('autocomplete attributes are set for common fields', async ({ page }) => {
    await page.goto('/checkout');

    await expect(page.getByLabel('Full name')).toHaveAttribute('autocomplete', 'name');
    await expect(page.getByLabel('Email')).toHaveAttribute('autocomplete', 'email');
    await expect(page.getByLabel('Street address')).toHaveAttribute('autocomplete', 'street-address');
  });
});
```

### Accessibilité en CI

**Quand l'utiliser** : Tu veux que les violations d'accessibilité fassent échouer les builds, afin d'empêcher les régressions d'atteindre la production. Chaque équipe devrait conditionner son pipeline CI à l'accessibilité.
**À éviter quand** : Jamais. Si tu ne lances les vérifications d'accessibilité qu'en local, elles seront ignorées.

**TypeScript**
```typescript
// playwright.config.ts — dedicated accessibility project
import { defineConfig } from '@playwright/test';

export default defineConfig({
  projects: [
    {
      name: 'accessibility',
      testMatch: '**/*.a11y.spec.ts',
      use: {
        browserName: 'chromium', // axe-core works best with Chromium
      },
    },
    {
      name: 'e2e-chromium',
      testMatch: '**/*.spec.ts',
      testIgnore: '**/*.a11y.spec.ts',
      use: { browserName: 'chromium' },
    },
  ],
});
```

```typescript
// tests/pages.a11y.spec.ts — scan all critical pages
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const PAGES_TO_SCAN = [
  { name: 'Home', path: '/' },
  { name: 'Login', path: '/login' },
  { name: 'Register', path: '/register' },
  { name: 'Dashboard', path: '/dashboard' },
  { name: 'Products', path: '/products' },
  { name: 'Checkout', path: '/checkout' },
  { name: 'Contact', path: '/contact' },
];

for (const { name, path } of PAGES_TO_SCAN) {
  test(`${name} page (${path}) has no WCAG AA violations`, async ({ page }) => {
    await page.goto(path);

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
      .analyze();

    // Attach violation details to the test report
    await test.info().attach('accessibility-scan-results', {
      body: JSON.stringify(results.violations, null, 2),
      contentType: 'application/json',
    });

    expect(results.violations).toEqual([]);
  });
}
```

```typescript
// tests/helpers/a11y-fixture.ts — reusable axe-core fixture
import { test as base, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

type A11yFixtures = {
  makeAxeBuilder: () => AxeBuilder;
};

export const test = base.extend<A11yFixtures>({
  makeAxeBuilder: async ({ page }, use) => {
    const makeAxeBuilder = () =>
      new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']);
    await use(makeAxeBuilder);
  },
});

export { expect };
```

```typescript
// tests/dashboard.a11y.spec.ts — using the fixture
import { test, expect } from './helpers/a11y-fixture';

test('dashboard has no violations after data loads', async ({ page, makeAxeBuilder }) => {
  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  const results = await makeAxeBuilder().analyze();

  await test.info().attach('a11y-results', {
    body: JSON.stringify(results.violations, null, 2),
    contentType: 'application/json',
  });

  expect(results.violations).toEqual([]);
});
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  projects: [
    {
      name: 'accessibility',
      testMatch: '**/*.a11y.spec.js',
      use: { browserName: 'chromium' },
    },
    {
      name: 'e2e-chromium',
      testMatch: '**/*.spec.js',
      testIgnore: '**/*.a11y.spec.js',
      use: { browserName: 'chromium' },
    },
  ],
});
```

```javascript
// tests/pages.a11y.spec.js
const { test, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;

const PAGES_TO_SCAN = [
  { name: 'Home', path: '/' },
  { name: 'Login', path: '/login' },
  { name: 'Dashboard', path: '/dashboard' },
  { name: 'Products', path: '/products' },
];

for (const { name, path } of PAGES_TO_SCAN) {
  test(`${name} page (${path}) has no WCAG AA violations`, async ({ page }) => {
    await page.goto(path);

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
      .analyze();

    await test.info().attach('accessibility-scan-results', {
      body: JSON.stringify(results.violations, null, 2),
      contentType: 'application/json',
    });

    expect(results.violations).toEqual([]);
  });
}
```

**Intégration GitHub Actions :**

```yaml
# .github/workflows/accessibility.yml
name: Accessibility Tests
on: [push, pull_request]

jobs:
  accessibility:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: lts/*
      - run: npm ci
      - run: npx playwright install --with-deps chromium

      - name: Run accessibility tests
        run: npx playwright test --project=accessibility

      - name: Upload accessibility report
        if: always()
        uses: actions/upload-artifact@v7
        with:
          name: accessibility-report
          path: playwright-report/
          retention-days: 30
```

## Guide de décision

| Élément à vérifier | Automatisé (axe-core) | Manuel (clavier / lecteur d'écran) | Pourquoi |
|---|---|---|---|
| Texte alternatif manquant | Oui | Non | axe-core le détecte de façon fiable |
| Ratios de contraste des couleurs | Oui | Non | Calculés automatiquement à partir du CSS |
| Labels de formulaire manquants | Oui | Non | Détecte les `<label>` et associations aria manquants |
| Attributs ARIA invalides | Oui | Non | Validation par rapport à la spécification WAI-ARIA |
| IDs dupliqués | Oui | Non | Analyse du DOM |
| Ordre de tabulation / flux logique | Non | Oui | Nécessite de comprendre la mise en page et l'intention de l'utilisateur |
| Gestion du focus dans les modales | Partiel (axe vérifie `aria-hidden`) | Oui | Le comportement de piège à focus exige des tests comportementaux |
| Qualité de l'UX avec lecteur d'écran | Non | Oui | Le caractère utile des annonces est subjectif |
| Charge cognitive / lisibilité | Non | Oui | Non automatisable : demande un jugement humain |
| Taille des cibles tactiles (mobile) | Oui (WCAG 2.2) | Oui | axe vérifie la taille minimale ; le ressenti sur appareil réel demande un test manuel |
| Annonces de contenu dynamique | Non | Oui | Le comportement des live regions dépend du timing et du lecteur d'écran |
| Conflits de raccourcis clavier | Non | Oui | Nécessite de connaître les raccourcis de l'OS, du navigateur et des technologies d'assistance |
| Ordre de lecture vs ordre visuel | Non | Oui | Le réordonnancement CSS (flexbox `order`, grid) peut le casser |
| Parcours de récupération après erreur | Non | Oui | Juger si le guidage est compréhensible demande un jugement humain |
| Sous-titres vidéo / audiodescriptions | Partiel (vérifie `<track>`) | Oui | La qualité des sous-titres doit être vérifiée manuellement |

**Règle empirique** : automatise tout ce qu'axe-core peut détecter (lance-le en CI sur chaque page), puis consacre ton budget de tests manuels à la navigation au clavier, à la gestion du focus et aux annonces du lecteur d'écran pour tes parcours utilisateur les plus critiques.

## Anti-patterns

| À ne pas faire | Problème | À faire plutôt |
|---|---|---|
| Tester uniquement avec axe-core | Détecte ~30-40 % des problèmes WCAG. Ne voit pas la navigation au clavier, la gestion du focus, l'ordre de lecture ni la qualité de l'UX. | Combine axe-core avec des tests de navigation au clavier et des audits manuels périodiques au lecteur d'écran |
| Ignorer la navigation au clavier | ~8 % des utilisateurs naviguent uniquement au clavier. Une UX clavier inaccessible bloque de vrais utilisateurs. | Teste l'ordre de tabulation, l'activation avec Entrée/Espace, Échap pour fermer et les flèches pour chaque composant interactif |
| Négliger la gestion du focus dans les modales | Les utilisateurs tabulent vers le contenu d'arrière-plan derrière la modale, perdent le contexte ou ne peuvent pas fermer la boîte de dialogue. | Teste le piège à focus, Échap pour fermer et le retour du focus sur l'élément déclencheur |
| Tester l'accessibilité une seule fois | Des régressions s'insinuent à chaque PR. Un audit réussi aujourd'hui ne vaut plus rien au prochain sprint. | Lance axe-core en CI à chaque build ; planifie des audits manuels trimestriels |
| Utiliser `tabindex` > 0 | Écrase l'ordre de tabulation naturel et crée une navigation imprévisible. Extrêmement difficile à maintenir. | Utilise `tabindex="0"` pour rendre des éléments focusables et `tabindex="-1"` pour le focus programmatique ; n'utilise jamais de valeurs positives |
| S'appuyer sur l'attribut `title` pour l'accessibilité | Les lecteurs d'écran traitent `title` de façon incohérente : beaucoup l'ignorent. | Utilise `aria-label`, `aria-labelledby` ou des labels textuels visibles |
| Ajouter `role="button"` à un `<div>` sans support clavier | Crée un « bouton » qui ne fonctionne qu'à la souris. Le lecteur d'écran l'annonce comme un bouton, mais Entrée/Espace ne font rien. | Utilise des éléments `<button>`. Si tu dois utiliser un `<div>`, ajoute `tabindex="0"`, `role="button"` et des handlers `keydown` pour Entrée et Espace |
| Masquer du contenu avec `display: none` en s'attendant à ce que les lecteurs d'écran le lisent | `display: none` masque le contenu pour tout le monde, y compris les technologies d'assistance. | Utilise le pattern CSS `.sr-only` / visually-hidden pour masquer visuellement tout en gardant le contenu accessible |
| Utiliser `aria-label` sur un `<div>` ou `<span>` non interactif | `aria-label` est ignoré sur les éléments sans rôle. Les lecteurs d'écran ne l'annonceront pas. | Ajoute un rôle approprié (`role="region"`) ou utilise `aria-labelledby` pointant vers un titre visible |
| Tester uniquement le cas nominal | On rate les états d'erreur, les états vides et les états de chargement, dont les caractéristiques d'accessibilité peuvent différer. | Teste les formulaires avec erreurs de validation, les résultats de recherche vides, les skeletons de chargement et les états de timeout |
| Désactiver définitivement la règle `color-contrast` | Les utilisateurs malvoyants ne peuvent pas lire ton contenu. | Corrige le contraste. En cas de migration, suis les exceptions avec des tickets et fixe une échéance |

## Dépannage

### axe-core ne signale aucune violation mais l'expérience au lecteur d'écran est médiocre

**Cause** : axe-core vérifie la correction structurelle du HTML/ARIA, pas la qualité de l'expérience utilisateur. Un élément peut avoir un `aria-label` techniquement valide mais inutile ("button", "click here", "x").

**Solution** : Audite tes parcours les plus critiques avec un vrai lecteur d'écran (VoiceOver sur macOS : Cmd+F5 ; NVDA sur Windows : téléchargement gratuit). Écoute les annonces et demande-toi : un utilisateur qui ne voit pas l'écran comprendrait-il quoi faire ?

### Violation "color-contrast" sur des éléments qui semblent corrects

**Cause** : axe-core calcule le contraste par rapport à l'arrière-plan réel, ce qui peut impliquer des éléments superposés, des dégradés ou des images de fond. L'arrière-plan calculé peut différer de ce que tu vois.

**Solution** :
- Inspecte l'élément dans les DevTools : vérifie la couleur d'arrière-plan calculée, y compris celle des éventuels éléments superposés.
- Pour du texte sur des images/dégradés, ajoute un arrière-plan semi-transparent derrière le texte.
- Si axe signale un faux positif (rare), vérifie avec un outil manuel de contraste et utilise `disableRules` avec une justification documentée.

### Le focus est perdu après un changement de contenu dynamique

**Cause** : Quand un élément est retiré du DOM (fermeture d'une modale, suppression d'un élément de liste, navigation dans une SPA), le focus retombe sur `<body>`, laissant les utilisateurs au clavier perdus.

**Solution** :
```typescript
// After closing a modal, return focus to the trigger
await page.getByRole('button', { name: 'Close' }).click();
await expect(page.getByRole('button', { name: 'Open modal' })).toBeFocused();

// After deleting an item, move focus to the next item or a logical landmark
await page.getByRole('button', { name: 'Delete item 3' }).click();
await expect(page.getByRole('listitem').nth(2)).toBeFocused(); // next item
```

### Le scan axe-core renvoie des résultats incomplets (et non des violations)

**Cause** : `results.incomplete` contient les vérifications qu'axe n'a pas pu déterminer automatiquement. Ce ne sont pas des échecs : ce sont des éléments à revoir manuellement. Fréquent pour le contraste des couleurs sur des arrière-plans complexes.

**Solution** :
```typescript
const results = await new AxeBuilder({ page }).analyze();

// Log incomplete checks for manual review
if (results.incomplete.length > 0) {
  console.log('Needs manual review:', results.incomplete.map((i) => i.id));
}

// Still fail on definite violations
expect(results.violations).toEqual([]);
```

### Le test d'ordre de tabulation échoue par intermittence

**Cause** : Le comportement du focus dépend de la page entièrement chargée et interactive. Les animations, le contenu chargé en lazy-loading ou les scripts d'autofocus peuvent interférer.

**Solution** :
```typescript
// Wait for the page to be fully interactive before testing tab order
await page.goto('/login');
await expect(page.getByLabel('Email')).toBeVisible();

// Click the body first to ensure focus starts from a known position
await page.locator('body').click();

// Now test tab order
await page.keyboard.press('Tab');
await expect(page.getByLabel('Email')).toBeFocused();
```

## Voir aussi

- [core/locators.md](locators.md) — les locators basés sur les rôles s'alignent sur les bonnes pratiques d'accessibilité
- [core/forms-and-validation.md](forms-and-validation.md) — patterns d'interaction avec les formulaires, y compris la gestion accessible des erreurs
- [ci/ci-github-actions.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/ci-github-actions.md) — configuration de la CI pour exécuter les tests d'accessibilité
- [core/i18n-and-localization.md](i18n-and-localization.md) — considérations d'accessibilité pour les applications multilingues
- [core/component-testing.md](component-testing.md) — tester l'accessibilité de composants individuels en isolation
