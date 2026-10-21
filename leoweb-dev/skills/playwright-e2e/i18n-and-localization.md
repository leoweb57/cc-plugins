# Tests d'internationalisation et de localisation

> **Quand l'utiliser** : vérifier que ton application fonctionne correctement selon les locales, les langues, les directions de texte, les formats de date/nombre et les fuseaux horaires. Détecte les layouts cassés, les traductions manquantes et les erreurs de format avant qu'ils n'atteignent les utilisateurs internationaux.
> **Prérequis** : [core/configuration.md](configuration.md), [core/locators.md](locators.md)

## Référence rapide

```typescript
// Set locale and timezone per context
const context = await browser.newContext({
  locale: 'de-DE',
  timezoneId: 'Europe/Berlin',
});

// Or in playwright.config.ts for project-level locale testing
projects: [
  { name: 'english', use: { locale: 'en-US', timezoneId: 'America/New_York' } },
  { name: 'german',  use: { locale: 'de-DE', timezoneId: 'Europe/Berlin' } },
  { name: 'arabic',  use: { locale: 'ar-SA', timezoneId: 'Asia/Riyadh' } },
],
```

## Patterns

### Définir la locale du navigateur

**À utiliser quand** : tu testes un rendu dépendant de la locale -- formats de date, de nombre, devise, tri et localisation au niveau du navigateur.
**À éviter quand** : ton application n'utilise pas la locale du navigateur et s'appuie sur une préférence utilisateur stockée côté serveur.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('locale-specific formatting', () => {
  test('US locale formats dates as MM/DD/YYYY', async ({ browser }) => {
    const context = await browser.newContext({ locale: 'en-US' });
    const page = await context.newPage();
    await page.goto('/dashboard');

    // Verify date format matches US convention
    await expect(page.getByTestId('last-updated')).toHaveText(/\d{1,2}\/\d{1,2}\/\d{4}/);
    await context.close();
  });

  test('German locale formats dates as DD.MM.YYYY', async ({ browser }) => {
    const context = await browser.newContext({ locale: 'de-DE' });
    const page = await context.newPage();
    await page.goto('/dashboard');

    await expect(page.getByTestId('last-updated')).toHaveText(/\d{1,2}\.\d{1,2}\.\d{4}/);
    await context.close();
  });

  test('Japanese locale formats numbers with commas', async ({ browser }) => {
    const context = await browser.newContext({ locale: 'ja-JP' });
    const page = await context.newPage();
    await page.goto('/pricing');

    // Japanese yen: no decimal places, uses comma grouping
    await expect(page.getByTestId('price')).toHaveText(/[\d,]+円/);
    await context.close();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('German locale formats dates as DD.MM.YYYY', async ({ browser }) => {
  const context = await browser.newContext({ locale: 'de-DE' });
  const page = await context.newPage();
  await page.goto('/dashboard');

  await expect(page.getByTestId('last-updated')).toHaveText(/\d{1,2}\.\d{1,2}\.\d{4}/);
  await context.close();
});
```

### Configuration de projet multi-locales

**À utiliser quand** : tu lances toute la suite de tests sur plusieurs locales en CI.
**À éviter quand** : tu n'as besoin de tester qu'une seule locale ou que l'application ne varie pas selon la locale.

**TypeScript**
```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  projects: [
    {
      name: 'en-US',
      use: {
        locale: 'en-US',
        timezoneId: 'America/New_York',
      },
    },
    {
      name: 'de-DE',
      use: {
        locale: 'de-DE',
        timezoneId: 'Europe/Berlin',
      },
    },
    {
      name: 'ar-SA',
      use: {
        locale: 'ar-SA',
        timezoneId: 'Asia/Riyadh',
      },
    },
    {
      name: 'ja-JP',
      use: {
        locale: 'ja-JP',
        timezoneId: 'Asia/Tokyo',
      },
    },
  ],
});
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  projects: [
    { name: 'en-US', use: { locale: 'en-US', timezoneId: 'America/New_York' } },
    { name: 'de-DE', use: { locale: 'de-DE', timezoneId: 'Europe/Berlin' } },
    { name: 'ar-SA', use: { locale: 'ar-SA', timezoneId: 'Asia/Riyadh' } },
    { name: 'ja-JP', use: { locale: 'ja-JP', timezoneId: 'Asia/Tokyo' } },
  ],
});
```

### Test de layout RTL

**À utiliser quand** : ton application prend en charge les langues de droite à gauche (arabe, hébreu, persan, ourdou) et que tu dois vérifier la direction du layout, l'alignement du texte et l'UI en miroir.
**À éviter quand** : ton application n'a aucune prise en charge du RTL.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('RTL layout', () => {
  test('Arabic locale renders RTL layout', async ({ browser }) => {
    const context = await browser.newContext({ locale: 'ar-SA' });
    const page = await context.newPage();
    await page.goto('/');

    // Verify the document direction
    const dir = await page.getAttribute('html', 'dir');
    expect(dir).toBe('rtl');

    // Verify navigation is right-aligned
    const nav = page.getByRole('navigation', { name: 'Main' });
    const navBox = await nav.boundingBox();
    const viewportWidth = page.viewportSize()!.width;
    // Nav should start from the right side
    expect(navBox!.x + navBox!.width).toBeGreaterThan(viewportWidth * 0.5);

    // Verify text alignment
    const heading = page.getByRole('heading', { level: 1 });
    const textAlign = await heading.evaluate((el) =>
      window.getComputedStyle(el).textAlign
    );
    expect(textAlign).toMatch(/right|start/);

    await context.close();
  });

  test('RTL layout does not cause horizontal overflow', async ({ browser }) => {
    const context = await browser.newContext({ locale: 'ar-SA' });
    const page = await context.newPage();
    await page.goto('/dashboard');

    // Check for horizontal scrollbar (content overflow)
    const hasHorizontalOverflow = await page.evaluate(() => {
      return document.documentElement.scrollWidth > document.documentElement.clientWidth;
    });
    expect(hasHorizontalOverflow).toBe(false);

    await context.close();
  });

  test('icons and directional elements are mirrored in RTL', async ({ browser }) => {
    const context = await browser.newContext({ locale: 'ar-SA' });
    const page = await context.newPage();
    await page.goto('/dashboard');

    // Back arrow should point right in RTL
    const backButton = page.getByRole('button', { name: /back|رجوع/i });
    const transform = await backButton.evaluate((el) =>
      window.getComputedStyle(el).transform
    );
    // CSS transform for horizontal flip: matrix(-1, 0, 0, 1, 0, 0) or scaleX(-1)
    // Or check the logical property direction
    expect(transform).not.toBe('none');

    await context.close();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('Arabic locale renders RTL layout', async ({ browser }) => {
  const context = await browser.newContext({ locale: 'ar-SA' });
  const page = await context.newPage();
  await page.goto('/');

  const dir = await page.getAttribute('html', 'dir');
  expect(dir).toBe('rtl');

  const hasHorizontalOverflow = await page.evaluate(() =>
    document.documentElement.scrollWidth > document.documentElement.clientWidth
  );
  expect(hasHorizontalOverflow).toBe(false);

  await context.close();
});
```

### Vérification des formats de date, de nombre et de devise

**À utiliser quand** : ton application utilise `Intl.DateTimeFormat`, `Intl.NumberFormat` ou des API similaires sensibles à la locale.
**À éviter quand** : les formats sont codés en dur et ne dépendent pas de la locale.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

const FORMAT_EXPECTATIONS = {
  'en-US': {
    date: /\d{1,2}\/\d{1,2}\/\d{4}/,            // 1/15/2025
    number: /1,234,567\.89/,                       // 1,234,567.89
    currency: /\$[\d,]+\.\d{2}/,                   // $1,234.56
  },
  'de-DE': {
    date: /\d{1,2}\.\d{1,2}\.\d{4}/,             // 15.1.2025
    number: /1\.234\.567,89/,                      // 1.234.567,89
    currency: /[\d.,]+\s?€/,                       // 1.234,56 €
  },
  'ja-JP': {
    date: /\d{4}\/\d{1,2}\/\d{1,2}/,             // 2025/1/15
    number: /1,234,567\.89/,                       // 1,234,567.89
    currency: /[¥￥][\d,]+/,                        // ¥1,235
  },
} as const;

for (const [locale, expected] of Object.entries(FORMAT_EXPECTATIONS)) {
  test.describe(`${locale} formatting`, () => {
    test(`dates match ${locale} format`, async ({ browser }) => {
      const context = await browser.newContext({ locale });
      const page = await context.newPage();
      await page.goto('/account');

      const dateText = await page.getByTestId('member-since').textContent();
      expect(dateText).toMatch(expected.date);
      await context.close();
    });

    test(`currency matches ${locale} format`, async ({ browser }) => {
      const context = await browser.newContext({ locale });
      const page = await context.newPage();
      await page.goto('/pricing');

      const priceText = await page.getByTestId('monthly-price').textContent();
      expect(priceText).toMatch(expected.currency);
      await context.close();
    });
  });
}
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

const locales = [
  { locale: 'en-US', datePattern: /\d{1,2}\/\d{1,2}\/\d{4}/, currencyPattern: /\$[\d,]+\.\d{2}/ },
  { locale: 'de-DE', datePattern: /\d{1,2}\.\d{1,2}\.\d{4}/, currencyPattern: /[\d.,]+\s?€/ },
];

for (const { locale, datePattern, currencyPattern } of locales) {
  test(`${locale} date format`, async ({ browser }) => {
    const context = await browser.newContext({ locale });
    const page = await context.newPage();
    await page.goto('/account');

    const dateText = await page.getByTestId('member-since').textContent();
    expect(dateText).toMatch(datePattern);
    await context.close();
  });
}
```

### Test du sélecteur de langue

**À utiliser quand** : ton application a un sélecteur de langue intégré qui change la langue de l'UI sans dépendre de la locale du navigateur.
**À éviter quand** : la langue est déterminée uniquement par la locale du navigateur, sans possibilité de surcharge par l'utilisateur.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('language switcher changes UI language', async ({ page }) => {
  await page.goto('/');

  // Default language
  await expect(page.getByRole('heading', { level: 1 })).toContainText('Welcome');
  await expect(page.getByRole('button', { name: 'Sign in' })).toBeVisible();

  // Switch to French
  await page.getByRole('combobox', { name: /language|langue/i }).selectOption('fr');

  // UI should update to French
  await expect(page.getByRole('heading', { level: 1 })).toContainText('Bienvenue');
  await expect(page.getByRole('button', { name: 'Se connecter' })).toBeVisible();

  // Verify language persists after navigation
  await page.getByRole('link', { name: /about|à propos/i }).click();
  await expect(page.getByRole('heading', { level: 1 })).not.toContainText('About');
});

test('language preference persists across sessions', async ({ page, context }) => {
  await page.goto('/');
  await page.getByRole('combobox', { name: /language/i }).selectOption('es');
  await expect(page.getByRole('button', { name: 'Iniciar sesión' })).toBeVisible();

  // Reload page — language should persist (cookie/localStorage)
  await page.reload();
  await expect(page.getByRole('button', { name: 'Iniciar sesión' })).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('language switcher changes UI language', async ({ page }) => {
  await page.goto('/');

  await expect(page.getByRole('heading', { level: 1 })).toContainText('Welcome');

  await page.getByRole('combobox', { name: /language/i }).selectOption('fr');

  await expect(page.getByRole('heading', { level: 1 })).toContainText('Bienvenue');
  await expect(page.getByRole('button', { name: 'Se connecter' })).toBeVisible();
});
```

### Vérification de l'exhaustivité des traductions

**À utiliser quand** : tu vérifies que toutes les chaînes visibles de l'UI sont traduites et qu'aucune clé de repli ne fuite dans l'UI.
**À éviter quand** : tu as déjà une étape de validation des traductions au build qui détecte les clés manquantes.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

const LANGUAGES = ['en', 'fr', 'de', 'es', 'ja'];
const PAGES_TO_CHECK = ['/', '/login', '/dashboard', '/settings', '/pricing'];

for (const lang of LANGUAGES) {
  test.describe(`${lang} translation completeness`, () => {
    for (const pagePath of PAGES_TO_CHECK) {
      test(`no missing translations on ${pagePath}`, async ({ page }) => {
        // Set language via URL param, cookie, or language switcher
        await page.goto(`${pagePath}?lang=${lang}`);

        // Check for common translation key leak patterns
        const pageText = await page.textContent('body');

        // Translation keys typically look like: key.subkey, UPPER_SNAKE_CASE, or {{key}}
        expect(pageText).not.toMatch(/\b[a-z]+\.[a-z]+\.[a-z]+\b/); // dot.notation.keys
        expect(pageText).not.toContain('{{');                          // Unresolved templates
        expect(pageText).not.toContain('}}');
        expect(pageText).not.toMatch(/\bTODO\b/i);                    // Placeholder text

        // Check for untranslated English text when in non-English locale
        if (lang !== 'en') {
          // These common English strings should be translated
          const untranslated = ['Sign in', 'Log out', 'Settings', 'Dashboard', 'Submit'];
          for (const text of untranslated) {
            const count = await page.getByText(text, { exact: true }).count();
            // Allow 0 matches (element not on page) but flag exact English matches
            if (count > 0) {
              console.warn(`Possible untranslated text "${text}" found on ${pagePath} for ${lang}`);
            }
          }
        }
      });
    }
  });
}
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

const LANGUAGES = ['en', 'fr', 'de'];
const PAGES = ['/', '/login', '/dashboard'];

for (const lang of LANGUAGES) {
  for (const pagePath of PAGES) {
    test(`${lang}: no missing translations on ${pagePath}`, async ({ page }) => {
      await page.goto(`${pagePath}?lang=${lang}`);

      const pageText = await page.textContent('body');
      expect(pageText).not.toMatch(/\b[a-z]+\.[a-z]+\.[a-z]+\b/);
      expect(pageText).not.toContain('{{');
      expect(pageText).not.toContain('}}');
    });
  }
}
```

### Test des fuseaux horaires

**À utiliser quand** : ton application affiche des données sensibles au temps (heures d'événements, échéances, planification) et que tu dois vérifier le bon rendu du fuseau horaire.
**À éviter quand** : toutes les heures sont affichées en UTC, sans conversion locale.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('timezone rendering', () => {
  test('event times adjust to user timezone', async ({ browser }) => {
    // Event stored as 2025-03-15T14:00:00Z (2 PM UTC)
    const contextNY = await browser.newContext({
      locale: 'en-US',
      timezoneId: 'America/New_York', // UTC-5 in March (EST)
    });
    const pageNY = await contextNY.newPage();
    await pageNY.goto('/events/123');
    // Should display 9:00 AM
    await expect(pageNY.getByTestId('event-time')).toContainText('9:00 AM');
    await contextNY.close();

    const contextTokyo = await browser.newContext({
      locale: 'en-US',
      timezoneId: 'Asia/Tokyo', // UTC+9
    });
    const pageTokyo = await contextTokyo.newPage();
    await pageTokyo.goto('/events/123');
    // Should display 11:00 PM
    await expect(pageTokyo.getByTestId('event-time')).toContainText('11:00 PM');
    await contextTokyo.close();
  });

  test('deadline displays correctly across DST boundary', async ({ browser }) => {
    const context = await browser.newContext({
      locale: 'en-US',
      timezoneId: 'America/Los_Angeles',
    });
    const page = await context.newPage();

    // Test a deadline that crosses DST (March second Sunday)
    await page.goto('/tasks?deadline=2025-03-10T07:00:00Z');
    // Before DST: UTC-8, so 11 PM on March 9
    await expect(page.getByTestId('deadline')).toContainText('Mar 9');

    await context.close();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('event times adjust to user timezone', async ({ browser }) => {
  const context = await browser.newContext({
    locale: 'en-US',
    timezoneId: 'America/New_York',
  });
  const page = await context.newPage();
  await page.goto('/events/123');
  await expect(page.getByTestId('event-time')).toContainText('9:00 AM');
  await context.close();
});
```

### Comparaison de screenshots multi-langues

**À utiliser quand** : tu veux détecter les régressions visuelles de layout causées par l'expansion du texte, le miroir RTL ou les différences de rendu des polices selon les locales.
**À éviter quand** : la régression visuelle est gérée séparément et que la locale n'est pas un risque pour le layout.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

const LOCALES_TO_SCREENSHOT = [
  { locale: 'en-US', name: 'english' },
  { locale: 'de-DE', name: 'german' },     // German text is ~30% longer than English
  { locale: 'ja-JP', name: 'japanese' },    // CJK characters, different font metrics
  { locale: 'ar-SA', name: 'arabic' },      // RTL layout
];

for (const { locale, name } of LOCALES_TO_SCREENSHOT) {
  test(`visual snapshot for ${name} (${locale})`, async ({ browser }) => {
    const context = await browser.newContext({
      locale,
      viewport: { width: 1280, height: 720 },
    });
    const page = await context.newPage();
    await page.goto('/');

    // Wait for fonts and images to load
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshot(`homepage-${name}.png`, {
      maxDiffPixelRatio: 0.02, // Allow 2% pixel difference for font rendering
      fullPage: true,
    });

    await context.close();
  });
}

test('long German text does not overflow buttons', async ({ browser }) => {
  const context = await browser.newContext({ locale: 'de-DE' });
  const page = await context.newPage();
  await page.goto('/dashboard');

  // Check that no button has overflowing text
  const buttons = page.getByRole('button');
  const count = await buttons.count();
  for (let i = 0; i < count; i++) {
    const button = buttons.nth(i);
    const overflow = await button.evaluate((el) => {
      const style = window.getComputedStyle(el);
      return el.scrollWidth > el.clientWidth && style.overflow !== 'hidden';
    });
    if (overflow) {
      const text = await button.textContent();
      expect(overflow, `Button "${text}" overflows in German`).toBe(false);
    }
  }

  await context.close();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

const LOCALES = [
  { locale: 'en-US', name: 'english' },
  { locale: 'de-DE', name: 'german' },
  { locale: 'ar-SA', name: 'arabic' },
];

for (const { locale, name } of LOCALES) {
  test(`visual snapshot for ${name}`, async ({ browser }) => {
    const context = await browser.newContext({ locale, viewport: { width: 1280, height: 720 } });
    const page = await context.newPage();
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshot(`homepage-${name}.png`, {
      maxDiffPixelRatio: 0.02,
      fullPage: true,
    });
    await context.close();
  });
}
```

## Guide de décision

| Scénario | Approche | Pourquoi |
|---|---|---|
| Tester le formatage dépendant de la locale | Définir `locale` dans le contexte du navigateur | Playwright définit `navigator.language` et affecte les API `Intl` |
| Tester le sélecteur de langue de l'application | Interagir directement avec l'UI du sélecteur | Teste le vrai parcours utilisateur, pas seulement la locale du navigateur |
| Tester le rendu des fuseaux horaires | Définir `timezoneId` dans le contexte du navigateur | Surcharge le fuseau horaire de `Date` et `Intl.DateTimeFormat` |
| Détecter les débordements de texte dus aux traductions longues | Régression visuelle + vérifications de bounding box | Le texte allemand/finnois est 30 à 40 % plus long que l'anglais |
| Vérifier le layout RTL | Définir une locale arabe/hébreu + vérifier `dir="rtl"` | Teste à la fois le signal du navigateur et la réponse de l'application |
| Détecter les traductions manquantes | Scanner le texte de la page à la recherche de motifs de clés (`{{`, notation à points) | Détecte les problèmes de build/déploiement où les fichiers de traduction sont absents |
| Comparer les layouts entre locales | `toHaveScreenshot` par locale avec une configuration par projet | Capture automatiquement les différences visuelles |
| Tester les cas limites du passage à l'heure d'été | Définir un `timezoneId` précis + des dates limites connues | Les frontières DST causent le plus de bugs de fuseau horaire |

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| Coder en dur du texte traduit dans les assertions | Casse quand les traductions changent | Utilise `getByRole` avec une regex sur `name`, ou des test IDs pour une sélection indépendante de la locale |
| Ne tester que `en-US` | Passe à côté des bugs de RTL, de débordement de texte et de format | Teste au moins une locale LTR, une RTL et une CJK |
| Définir `locale` sur la page plutôt que sur le contexte | `locale` est une option au niveau du contexte, pas de la page | Définis la locale à la création du contexte ou dans la config du projet |
| Ignorer l'expansion du texte pour l'allemand/le finnois | Les boutons et libellés débordent dans les langues plus longues | Utilise la régression visuelle ou des assertions de bounding box |
| Utiliser `toHaveScreenshot` sans `maxDiffPixelRatio` | Le rendu des polices diffère légèrement selon l'OS/la CI | Définis `maxDiffPixelRatio: 0.02` ou plus pour une tolérance multi-plateforme |
| Tester les fuseaux horaires uniquement en UTC | Masque les bugs de conversion de fuseau horaire | Teste avec au moins 3 fuseaux : UTC négatif, UTC, UTC positif |
| Se fier à la locale du navigateur pour la langue de l'application | Beaucoup d'applications utilisent une langue côté serveur ou par cookie | Teste via le mécanisme de changement de langue propre à l'application |
| Ne pas tester les frontières DST | L'heure affichée peut être décalée d'une heure lors des transitions | Teste des dates proches des transitions DST pour tes fuseaux horaires cibles |

## Dépannage

| Symptôme | Cause probable | Correctif |
|---|---|---|
| L'option `locale` n'a aucun effet | L'application ignore `navigator.language` et utilise une locale côté serveur | Définis la locale via le mécanisme propre à l'application (cookie, paramètre d'URL, API) |
| Le format de date ne change pas avec la locale | L'application code le format de date en dur au lieu d'utiliser `Intl.DateTimeFormat` | C'est un bug de l'application à corriger, pas un problème de test |
| La page RTL s'affiche toujours en LTR | L'application vérifie la locale mais ne définit pas `dir="rtl"` | Vérifie la logique de détection RTL de l'application ; il faudra peut-être définir l'en-tête `Accept-Language` |
| Les screenshots visuels échouent selon l'OS | Le rendu des polices diffère entre macOS, Linux et Windows | Lance les tests visuels dans Docker pour la cohérence, ou augmente `maxDiffPixelRatio` |
| `timezoneId` n'affecte pas la page | L'application utilise l'heure du serveur, pas le `Date` client | Le test de fuseau horaire ne fonctionne que pour le rendu de dates côté client |
| Une clé de traduction apparaît brièvement puis disparaît | Les fichiers de traduction se chargent de manière asynchrone | Attends `networkidle` ou un élément traduit précis avant d'asserter |
| Problèmes d'encodage de caractères (texte illisible) | Charset incorrect dans le HTML ou police manquante | Vérifie `<meta charset="utf-8">` et que les polices CJK/arabes sont disponibles |

## Voir aussi

- [core/locators.md](locators.md) -- stratégies de locators qui fonctionnent quelle que soit la locale
- [core/configuration.md](configuration.md) -- configuration de la locale et du fuseau horaire au niveau du projet
- [core/visual-regression.md](visual-regression.md) -- bases de la comparaison de screenshots
- [core/clock-and-time-mocking.md](clock-and-time-mocking.md) -- mock du temps pour les tests dépendant des dates
- [ci/docker-and-containers.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/docker-and-containers.md) -- rendu cohérent des polices en CI avec Docker
