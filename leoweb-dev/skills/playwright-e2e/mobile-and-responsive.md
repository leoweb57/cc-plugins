# Tests mobiles et responsives

> **Quand l'utiliser** : Tester le comportement de ton application sur téléphones, tablettes et à travers différentes tailles de viewport. Couvre l'émulation d'appareils, les interactions tactiles, la géolocalisation, les changements d'orientation et les patterns d'UI propres au mobile.
> **Prérequis** : [core/configuration.md](configuration.md), [core/locators.md](locators.md)

## Référence rapide

```typescript
import { devices } from '@playwright/test';

// Predefined device profiles (viewport, userAgent, touch, deviceScaleFactor)
devices['iPhone 14']           // 390x844, touch, Safari mobile UA
devices['iPhone 14 Pro Max']   // 430x932, touch, Safari mobile UA
devices['Pixel 7']             // 412x915, touch, Chrome mobile UA
devices['iPad Pro 11']         // 834x1194, touch, Safari tablet UA
devices['Galaxy S9+']          // 320x658, touch, Chrome mobile UA
devices['Desktop Chrome']      // 1280x720, no touch, Chrome desktop UA
devices['Desktop Safari']      // 1280x720, no touch, Safari desktop UA

// Landscape variants
devices['iPhone 14 landscape'] // 844x390, touch, Safari mobile UA
devices['iPad Pro 11 landscape'] // 1194x834, touch, Safari tablet UA
```

```bash
# Run mobile project only
npx playwright test --project=mobile-chrome
npx playwright test --project=mobile-safari

# Run all projects (desktop + mobile in parallel)
npx playwright test

# List available device names
npx playwright test --list-devices 2>/dev/null || node -e "const {devices}=require('@playwright/test');console.log(Object.keys(devices).join('\n'))"
```

## Patterns

### 1. Émulation d'appareils

**À utiliser quand** : Tu testes ton app telle qu'elle apparaît sur un appareil réel précis -- iPhone, Pixel, iPad. Applique d'un seul coup le bon viewport, le bon user agent, le bon device scale factor et le support tactile.
**À éviter quand** : Tu as seulement besoin de tester une largeur de viewport précise (utilise plutôt des viewports personnalisés). L'émulation d'appareil ne remplace pas les tests sur appareil réel quand le rendu au pixel près compte.

#### TypeScript

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  projects: [
    {
      name: 'Desktop Chrome',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 7'] },
    },
    {
      name: 'Mobile Safari',
      use: { ...devices['iPhone 14'] },
    },
    {
      name: 'Tablet',
      use: { ...devices['iPad Pro 11'] },
    },
  ],
});
```

```typescript
// tests/mobile-navigation.spec.ts
import { test, expect } from '@playwright/test';

test('mobile user can navigate via hamburger menu', async ({ page, isMobile }) => {
  await page.goto('/');

  if (isMobile) {
    // Mobile: hamburger menu is visible, desktop nav is hidden
    await expect(page.getByRole('button', { name: 'Menu' })).toBeVisible();
    await expect(page.getByRole('navigation', { name: 'Main' })).toBeHidden();

    // Open hamburger menu
    await page.getByRole('button', { name: 'Menu' }).click();
    await expect(page.getByRole('navigation', { name: 'Main' })).toBeVisible();
    await page.getByRole('link', { name: 'Products' }).click();
    await page.waitForURL('**/products');
  } else {
    // Desktop: nav links are directly visible
    await expect(page.getByRole('navigation', { name: 'Main' })).toBeVisible();
    await page.getByRole('link', { name: 'Products' }).click();
    await page.waitForURL('**/products');
  }

  await expect(page.getByRole('heading', { name: 'Products', level: 1 })).toBeVisible();
});
```

#### JavaScript

```javascript
// playwright.config.js
const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  projects: [
    {
      name: 'Desktop Chrome',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 7'] },
    },
    {
      name: 'Mobile Safari',
      use: { ...devices['iPhone 14'] },
    },
    {
      name: 'Tablet',
      use: { ...devices['iPad Pro 11'] },
    },
  ],
});
```

```javascript
// tests/mobile-navigation.spec.js
const { test, expect } = require('@playwright/test');

test('mobile user can navigate via hamburger menu', async ({ page, isMobile }) => {
  await page.goto('/');

  if (isMobile) {
    await expect(page.getByRole('button', { name: 'Menu' })).toBeVisible();
    await expect(page.getByRole('navigation', { name: 'Main' })).toBeHidden();

    await page.getByRole('button', { name: 'Menu' }).click();
    await expect(page.getByRole('navigation', { name: 'Main' })).toBeVisible();
    await page.getByRole('link', { name: 'Products' }).click();
    await page.waitForURL('**/products');
  } else {
    await expect(page.getByRole('navigation', { name: 'Main' })).toBeVisible();
    await page.getByRole('link', { name: 'Products' }).click();
    await page.waitForURL('**/products');
  }

  await expect(page.getByRole('heading', { name: 'Products', level: 1 })).toBeVisible();
});
```

> **Breaking change de Playwright 1.64** : la taille `screen` est désormais transmise depuis les descripteurs d'appareils. Avec `...devices['Desktop Chrome']` (ou n'importe quel appareil), `window.screen` et les media queries basées sur l'écran voient désormais l'écran émulé, et non celui de l'hôte. Les tests qui reposaient sur la taille réelle de l'écran peuvent s'en exclure :
>
> ```typescript
> use: { ...devices['Desktop Chrome'], screen: undefined }
> ```

### 2. Viewports personnalisés

**À utiliser quand** : Tu testes des mises en page responsives à des breakpoints précis sans émulation complète d'appareil. Idéal pour vérifier que les media queries CSS se déclenchent aux bonnes largeurs.
**À éviter quand** : Tu as besoin d'un comportement mobile réaliste (événements tactiles, user agent mobile, device scale factor). Utilise plutôt l'émulation d'appareil.

#### TypeScript

```typescript
// tests/responsive-layout.spec.ts
import { test, expect } from '@playwright/test';

const breakpoints = [
  { name: 'mobile-small', width: 320, height: 568 },
  { name: 'mobile', width: 375, height: 667 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'desktop', width: 1024, height: 768 },
  { name: 'desktop-large', width: 1440, height: 900 },
];

for (const bp of breakpoints) {
  test(`layout adapts correctly at ${bp.name} (${bp.width}px)`, async ({ page }) => {
    await page.setViewportSize({ width: bp.width, height: bp.height });
    await page.goto('/');

    if (bp.width < 768) {
      // Mobile layout: stacked, hamburger menu visible
      await expect(page.getByRole('button', { name: 'Menu' })).toBeVisible();
      await expect(page.getByTestId('sidebar')).toBeHidden();
    } else if (bp.width < 1024) {
      // Tablet layout: collapsible sidebar
      await expect(page.getByRole('button', { name: 'Menu' })).toBeHidden();
      await expect(page.getByTestId('sidebar')).toBeVisible();
    } else {
      // Desktop layout: full sidebar, no hamburger
      await expect(page.getByRole('button', { name: 'Menu' })).toBeHidden();
      await expect(page.getByTestId('sidebar')).toBeVisible();
      await expect(page.getByTestId('sidebar')).toHaveCSS('width', '280px');
    }
  });
}
```

```typescript
// Per-file viewport override (applies to all tests in this file)
import { test, expect } from '@playwright/test';

test.use({ viewport: { width: 375, height: 667 } });

test('mobile checkout flow fits on small screen', async ({ page }) => {
  await page.goto('/checkout');

  // Verify no horizontal scrollbar
  const hasHorizontalScroll = await page.evaluate(
    () => document.documentElement.scrollWidth > document.documentElement.clientWidth
  );
  expect(hasHorizontalScroll).toBe(false);

  // Verify all form fields are visible without horizontal scroll
  await expect(page.getByLabel('Card number')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Pay now' })).toBeVisible();
});
```

#### JavaScript

```javascript
// tests/responsive-layout.spec.js
const { test, expect } = require('@playwright/test');

const breakpoints = [
  { name: 'mobile-small', width: 320, height: 568 },
  { name: 'mobile', width: 375, height: 667 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'desktop', width: 1024, height: 768 },
  { name: 'desktop-large', width: 1440, height: 900 },
];

for (const bp of breakpoints) {
  test(`layout adapts correctly at ${bp.name} (${bp.width}px)`, async ({ page }) => {
    await page.setViewportSize({ width: bp.width, height: bp.height });
    await page.goto('/');

    if (bp.width < 768) {
      await expect(page.getByRole('button', { name: 'Menu' })).toBeVisible();
      await expect(page.getByTestId('sidebar')).toBeHidden();
    } else if (bp.width < 1024) {
      await expect(page.getByRole('button', { name: 'Menu' })).toBeHidden();
      await expect(page.getByTestId('sidebar')).toBeVisible();
    } else {
      await expect(page.getByRole('button', { name: 'Menu' })).toBeHidden();
      await expect(page.getByTestId('sidebar')).toBeVisible();
      await expect(page.getByTestId('sidebar')).toHaveCSS('width', '280px');
    }
  });
}
```

```javascript
// Per-file viewport override
const { test, expect } = require('@playwright/test');

test.use({ viewport: { width: 375, height: 667 } });

test('mobile checkout flow fits on small screen', async ({ page }) => {
  await page.goto('/checkout');

  const hasHorizontalScroll = await page.evaluate(
    () => document.documentElement.scrollWidth > document.documentElement.clientWidth
  );
  expect(hasHorizontalScroll).toBe(false);

  await expect(page.getByLabel('Card number')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Pay now' })).toBeVisible();
});
```

### 3. Événements tactiles

**À utiliser quand** : Tu testes des interactions propres au tactile -- tap, swipe, pinch. Indispensable pour les gestes exclusivement mobiles sans équivalent à la souris.
**À éviter quand** : La fonctionnalité marche de façon identique avec des clics souris. Le `click()` de Playwright déclenche automatiquement des événements tactiles sur les profils d'appareil tactiles.

#### TypeScript

```typescript
// tests/touch-interactions.spec.ts
import { test, expect, devices } from '@playwright/test';

test.use({ ...devices['iPhone 14'] });

test('tap to select an item', async ({ page }) => {
  await page.goto('/gallery');

  // tap() dispatches touchstart → touchend → click
  // Only available when hasTouch is true (device profiles set this)
  await page.getByRole('img', { name: 'Sunset photo' }).tap();
  await expect(page.getByText('Selected: Sunset photo')).toBeVisible();
});

test('swipe to dismiss a card', async ({ page }) => {
  await page.goto('/notifications');

  const card = page.getByTestId('notification-card').first();
  const box = await card.boundingBox();

  if (box) {
    // Simulate a left swipe: touchstart on right side, touchmove to left, touchend
    await page.touchscreen.tap(box.x + box.width - 20, box.y + box.height / 2);

    // Swipe gesture using mouse (touch events are synthesized from mouse on emulated devices)
    await card.hover({ position: { x: box.width - 20, y: box.height / 2 } });
    await page.mouse.down();
    await page.mouse.move(box.x - 100, box.y + box.height / 2, { steps: 10 });
    await page.mouse.up();

    await expect(card).toBeHidden();
  }
});

test('long press to open context menu', async ({ page }) => {
  await page.goto('/files');

  const file = page.getByRole('listitem').filter({ hasText: 'Report.pdf' });

  // Long press: dispatch pointerdown, wait, then pointerup
  await file.click({ delay: 800 }); // delay in ms simulates long press
  await expect(page.getByRole('menu')).toBeVisible();
  await page.getByRole('menuitem', { name: 'Delete' }).click();
});

test('pinch to zoom on a map', async ({ page }) => {
  await page.goto('/map');

  // Pinch-to-zoom requires dispatching multi-touch events via JavaScript
  const mapElement = page.getByTestId('map-container');

  await mapElement.evaluate((el) => {
    // Simulate pinch-out (zoom in) with two touch points moving apart
    const center = { x: el.clientWidth / 2, y: el.clientHeight / 2 };

    const touch1 = new Touch({
      identifier: 0,
      target: el,
      clientX: center.x - 50,
      clientY: center.y,
    });
    const touch2 = new Touch({
      identifier: 1,
      target: el,
      clientX: center.x + 50,
      clientY: center.y,
    });

    el.dispatchEvent(new TouchEvent('touchstart', {
      touches: [touch1, touch2],
      changedTouches: [touch1, touch2],
      bubbles: true,
    }));

    const touch1Moved = new Touch({
      identifier: 0,
      target: el,
      clientX: center.x - 120,
      clientY: center.y,
    });
    const touch2Moved = new Touch({
      identifier: 1,
      target: el,
      clientX: center.x + 120,
      clientY: center.y,
    });

    el.dispatchEvent(new TouchEvent('touchmove', {
      touches: [touch1Moved, touch2Moved],
      changedTouches: [touch1Moved, touch2Moved],
      bubbles: true,
    }));

    el.dispatchEvent(new TouchEvent('touchend', {
      touches: [],
      changedTouches: [touch1Moved, touch2Moved],
      bubbles: true,
    }));
  });

  // Verify zoom level changed
  await expect(page.getByTestId('zoom-level')).not.toHaveText('1x');
});
```

#### JavaScript

```javascript
// tests/touch-interactions.spec.js
const { test, expect, devices } = require('@playwright/test');

test.use({ ...devices['iPhone 14'] });

test('tap to select an item', async ({ page }) => {
  await page.goto('/gallery');

  await page.getByRole('img', { name: 'Sunset photo' }).tap();
  await expect(page.getByText('Selected: Sunset photo')).toBeVisible();
});

test('swipe to dismiss a card', async ({ page }) => {
  await page.goto('/notifications');

  const card = page.getByTestId('notification-card').first();
  const box = await card.boundingBox();

  if (box) {
    await card.hover({ position: { x: box.width - 20, y: box.height / 2 } });
    await page.mouse.down();
    await page.mouse.move(box.x - 100, box.y + box.height / 2, { steps: 10 });
    await page.mouse.up();

    await expect(card).toBeHidden();
  }
});

test('long press to open context menu', async ({ page }) => {
  await page.goto('/files');

  const file = page.getByRole('listitem').filter({ hasText: 'Report.pdf' });
  await file.click({ delay: 800 });
  await expect(page.getByRole('menu')).toBeVisible();
  await page.getByRole('menuitem', { name: 'Delete' }).click();
});
```

### 4. UI spécifique au mobile

**À utiliser quand** : Tu testes des composants d'UI qui n'apparaissent que sur mobile -- menus hamburger, bottom sheets, pull-to-refresh, headers mobiles sticky, boutons d'action flottants.
**À éviter quand** : Le composant s'affiche de façon identique sur desktop et sur mobile.

#### TypeScript

```typescript
// tests/mobile-ui.spec.ts
import { test, expect, devices } from '@playwright/test';

test.use({ ...devices['iPhone 14'] });

test('hamburger menu opens and closes', async ({ page }) => {
  await page.goto('/');

  const menuButton = page.getByRole('button', { name: 'Menu' });
  const nav = page.getByRole('navigation', { name: 'Main' });

  // Menu starts closed
  await expect(nav).toBeHidden();

  // Open menu
  await menuButton.click();
  await expect(nav).toBeVisible();

  // Verify all nav items are visible
  await expect(nav.getByRole('link', { name: 'Home' })).toBeVisible();
  await expect(nav.getByRole('link', { name: 'Products' })).toBeVisible();
  await expect(nav.getByRole('link', { name: 'Account' })).toBeVisible();

  // Close menu by tapping outside (overlay)
  await page.getByTestId('menu-overlay').click();
  await expect(nav).toBeHidden();
});

test('bottom sheet slides up on mobile', async ({ page }) => {
  await page.goto('/products/1');

  await page.getByRole('button', { name: 'Add to cart' }).click();

  // Bottom sheet appears with cart summary
  const bottomSheet = page.getByTestId('bottom-sheet');
  await expect(bottomSheet).toBeVisible();
  await expect(bottomSheet).toContainText('Added to cart');

  // Dismiss by swiping down
  const box = await bottomSheet.boundingBox();
  if (box) {
    const startX = box.x + box.width / 2;
    const startY = box.y + 20;
    await page.mouse.move(startX, startY);
    await page.mouse.down();
    await page.mouse.move(startX, startY + 300, { steps: 10 });
    await page.mouse.up();
  }

  await expect(bottomSheet).toBeHidden();
});

test('pull to refresh reloads content', async ({ page }) => {
  await page.goto('/feed');

  // Store initial first item text
  const firstItem = page.getByRole('listitem').first();
  const initialText = await firstItem.textContent();

  // Pull-to-refresh: swipe down from top of scrollable area
  const feed = page.getByTestId('feed-container');
  const box = await feed.boundingBox();

  if (box) {
    await page.mouse.move(box.x + box.width / 2, box.y + 10);
    await page.mouse.down();
    await page.mouse.move(box.x + box.width / 2, box.y + 250, { steps: 15 });
    await page.mouse.up();
  }

  // Wait for refresh indicator and then content reload
  await expect(page.getByTestId('refresh-spinner')).toBeVisible();
  await expect(page.getByTestId('refresh-spinner')).toBeHidden();
});

test('sticky mobile header remains visible on scroll', async ({ page }) => {
  await page.goto('/products');

  const header = page.getByRole('banner');

  // Scroll down significantly
  await page.evaluate(() => window.scrollTo(0, 2000));

  // Header should remain visible (sticky positioning)
  await expect(header).toBeVisible();
  await expect(header).toBeInViewport();
});
```

#### JavaScript

```javascript
// tests/mobile-ui.spec.js
const { test, expect, devices } = require('@playwright/test');

test.use({ ...devices['iPhone 14'] });

test('hamburger menu opens and closes', async ({ page }) => {
  await page.goto('/');

  const menuButton = page.getByRole('button', { name: 'Menu' });
  const nav = page.getByRole('navigation', { name: 'Main' });

  await expect(nav).toBeHidden();
  await menuButton.click();
  await expect(nav).toBeVisible();

  await expect(nav.getByRole('link', { name: 'Home' })).toBeVisible();
  await expect(nav.getByRole('link', { name: 'Products' })).toBeVisible();
  await expect(nav.getByRole('link', { name: 'Account' })).toBeVisible();

  await page.getByTestId('menu-overlay').click();
  await expect(nav).toBeHidden();
});

test('bottom sheet slides up on mobile', async ({ page }) => {
  await page.goto('/products/1');

  await page.getByRole('button', { name: 'Add to cart' }).click();

  const bottomSheet = page.getByTestId('bottom-sheet');
  await expect(bottomSheet).toBeVisible();
  await expect(bottomSheet).toContainText('Added to cart');

  const box = await bottomSheet.boundingBox();
  if (box) {
    const startX = box.x + box.width / 2;
    const startY = box.y + 20;
    await page.mouse.move(startX, startY);
    await page.mouse.down();
    await page.mouse.move(startX, startY + 300, { steps: 10 });
    await page.mouse.up();
  }

  await expect(bottomSheet).toBeHidden();
});

test('sticky mobile header remains visible on scroll', async ({ page }) => {
  await page.goto('/products');

  const header = page.getByRole('banner');
  await page.evaluate(() => window.scrollTo(0, 2000));
  await expect(header).toBeVisible();
  await expect(header).toBeInViewport();
});
```

### 5. Géolocalisation

**À utiliser quand** : Tu testes des fonctionnalités dépendantes de la position -- recherche de magasins, zones de livraison, widgets météo, tarification selon la localisation.
**À éviter quand** : La fonctionnalité n'utilise pas l'API Geolocation. Si elle se base sur la localisation par IP, mocke plutôt la réponse de l'API.

#### TypeScript

```typescript
// playwright.config.ts -- set geolocation per project
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  projects: [
    {
      name: 'mobile-nyc',
      use: {
        ...devices['iPhone 14'],
        geolocation: { latitude: 40.7128, longitude: -74.0060 },
        permissions: ['geolocation'],
      },
    },
    {
      name: 'mobile-london',
      use: {
        ...devices['iPhone 14'],
        geolocation: { latitude: 51.5074, longitude: -0.1278 },
        permissions: ['geolocation'],
        locale: 'en-GB',
        timezoneId: 'Europe/London',
      },
    },
  ],
});
```

```typescript
// tests/store-locator.spec.ts
import { test, expect } from '@playwright/test';

test('shows nearby stores based on geolocation', async ({ page, context }) => {
  // Geolocation is already set via project config above.
  // To override in a specific test:
  await context.setGeolocation({ latitude: 34.0522, longitude: -118.2437 }); // Los Angeles

  await page.goto('/store-locator');
  await page.getByRole('button', { name: 'Use my location' }).click();

  // Verify the app uses the mocked location
  await expect(page.getByText('Stores near Los Angeles')).toBeVisible();
  await expect(page.getByRole('listitem')).toHaveCount(5); // nearest 5 stores
});

test('geolocation updates in real time', async ({ page, context }) => {
  await context.setGeolocation({ latitude: 40.7128, longitude: -74.0060 });
  await page.goto('/delivery-tracker');

  await expect(page.getByText('New York')).toBeVisible();

  // Simulate user moving to a new location
  await context.setGeolocation({ latitude: 40.7580, longitude: -73.9855 }); // Times Square

  // Trigger a location refresh (app-specific)
  await page.getByRole('button', { name: 'Refresh location' }).click();
  await expect(page.getByText('Times Square')).toBeVisible();
});

test('handles geolocation permission denied', async ({ page, context }) => {
  // Clear geolocation permissions to simulate denial
  await context.clearPermissions();
  await page.goto('/store-locator');

  await page.getByRole('button', { name: 'Use my location' }).click();

  // App should show fallback UI
  await expect(page.getByText('Location access denied')).toBeVisible();
  await expect(page.getByLabel('Enter your zip code')).toBeVisible();
});
```

#### JavaScript

```javascript
// tests/store-locator.spec.js
const { test, expect } = require('@playwright/test');

test('shows nearby stores based on geolocation', async ({ page, context }) => {
  await context.setGeolocation({ latitude: 34.0522, longitude: -118.2437 });

  await page.goto('/store-locator');
  await page.getByRole('button', { name: 'Use my location' }).click();

  await expect(page.getByText('Stores near Los Angeles')).toBeVisible();
  await expect(page.getByRole('listitem')).toHaveCount(5);
});

test('geolocation updates in real time', async ({ page, context }) => {
  await context.setGeolocation({ latitude: 40.7128, longitude: -74.0060 });
  await page.goto('/delivery-tracker');

  await expect(page.getByText('New York')).toBeVisible();

  await context.setGeolocation({ latitude: 40.7580, longitude: -73.9855 });
  await page.getByRole('button', { name: 'Refresh location' }).click();
  await expect(page.getByText('Times Square')).toBeVisible();
});

test('handles geolocation permission denied', async ({ page, context }) => {
  await context.clearPermissions();
  await page.goto('/store-locator');

  await page.getByRole('button', { name: 'Use my location' }).click();

  await expect(page.getByText('Location access denied')).toBeVisible();
  await expect(page.getByLabel('Enter your zip code')).toBeVisible();
});
```

### 6. Tests responsives multi-projets

**À utiliser quand** : Tu lances les mêmes tests en parallèle sur des navigateurs desktop et mobiles. L'approche standard pour les apps responsives.
**À éviter quand** : Ton app est uniquement desktop ou uniquement mobile.

#### TypeScript

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  retries: process.env.CI ? 2 : 0,

  projects: [
    // ── Desktop ────────────────────────────────────────────
    {
      name: 'desktop-chrome',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'desktop-firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'desktop-safari',
      use: { ...devices['Desktop Safari'] },
    },

    // ── Mobile ─────────────────────────────────────────────
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 7'] },
    },
    {
      name: 'mobile-safari',
      use: { ...devices['iPhone 14'] },
    },

    // ── Tablet ─────────────────────────────────────────────
    {
      name: 'tablet',
      use: { ...devices['iPad Pro 11'] },
    },
  ],
});
```

```typescript
// tests/responsive-checkout.spec.ts
import { test, expect } from '@playwright/test';

test('checkout works across all viewports', async ({ page, isMobile }) => {
  await page.goto('/products');

  // Add item -- same action on all viewports
  await page.getByRole('button', { name: 'Add to cart' }).first().click();

  // Navigate to cart
  if (isMobile) {
    // Mobile: cart link may be in hamburger or bottom nav
    await page.getByRole('link', { name: 'Cart' }).click();
  } else {
    // Desktop: cart icon in header
    await page.getByRole('link', { name: /Cart \(\d+\)/ }).click();
  }

  await page.waitForURL('**/cart');
  await expect(page.getByRole('heading', { name: 'Your cart' })).toBeVisible();

  // Proceed to checkout
  await page.getByRole('link', { name: 'Checkout' }).click();
  await page.waitForURL('**/checkout');

  // Fill form -- same fields on all viewports
  await page.getByLabel('Email').fill('test@example.com');
  await page.getByLabel('Card number').fill('4242424242424242');
  await page.getByRole('button', { name: 'Pay now' }).click();

  await expect(page.getByText('Order confirmed')).toBeVisible();
});
```

```bash
# Run desktop projects only
npx playwright test --project=desktop-chrome --project=desktop-firefox --project=desktop-safari

# Run mobile projects only
npx playwright test --project=mobile-chrome --project=mobile-safari

# Run specific test file on all projects
npx playwright test tests/responsive-checkout.spec.ts

# CI optimization: mobile + desktop-chrome on PRs, all browsers on main
# In CI config:
# PR:   npx playwright test --project=desktop-chrome --project=mobile-chrome --project=mobile-safari
# Main: npx playwright test
```

#### JavaScript

```javascript
// playwright.config.js
const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  fullyParallel: true,
  retries: process.env.CI ? 2 : 0,

  projects: [
    {
      name: 'desktop-chrome',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'desktop-firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'desktop-safari',
      use: { ...devices['Desktop Safari'] },
    },
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 7'] },
    },
    {
      name: 'mobile-safari',
      use: { ...devices['iPhone 14'] },
    },
    {
      name: 'tablet',
      use: { ...devices['iPad Pro 11'] },
    },
  ],
});
```

```javascript
// tests/responsive-checkout.spec.js
const { test, expect } = require('@playwright/test');

test('checkout works across all viewports', async ({ page, isMobile }) => {
  await page.goto('/products');

  await page.getByRole('button', { name: 'Add to cart' }).first().click();

  if (isMobile) {
    await page.getByRole('link', { name: 'Cart' }).click();
  } else {
    await page.getByRole('link', { name: /Cart \(\d+\)/ }).click();
  }

  await page.waitForURL('**/cart');
  await expect(page.getByRole('heading', { name: 'Your cart' })).toBeVisible();

  await page.getByRole('link', { name: 'Checkout' }).click();
  await page.waitForURL('**/checkout');

  await page.getByLabel('Email').fill('test@example.com');
  await page.getByLabel('Card number').fill('4242424242424242');
  await page.getByRole('button', { name: 'Pay now' }).click();

  await expect(page.getByText('Order confirmed')).toBeVisible();
});
```

### 7. Tests des breakpoints responsives

**À utiliser quand** : Tu vérifies systématiquement le comportement de la mise en page à chaque breakpoint CSS majeur. À associer de préférence aux tests de régression visuelle.
**À éviter quand** : Tu n'as besoin que d'une ou deux tailles de viewport -- utilise simplement des surcharges `test.use()`.

#### TypeScript

```typescript
// tests/fixtures/responsive.fixture.ts
import { test as base, expect } from '@playwright/test';

type Breakpoint = {
  name: string;
  width: number;
  height: number;
  isMobileExpected: boolean;
};

const BREAKPOINTS: Breakpoint[] = [
  { name: 'xs',  width: 320,  height: 568, isMobileExpected: true },
  { name: 'sm',  width: 640,  height: 800, isMobileExpected: true },
  { name: 'md',  width: 768,  height: 1024, isMobileExpected: false },
  { name: 'lg',  width: 1024, height: 768, isMobileExpected: false },
  { name: 'xl',  width: 1280, height: 800, isMobileExpected: false },
  { name: '2xl', width: 1440, height: 900, isMobileExpected: false },
];

// Custom fixture that runs a test at every breakpoint
export const test = base.extend<{ forEachBreakpoint: void }>({
  forEachBreakpoint: [async ({ page }, use, testInfo) => {
    // This fixture is used as a tag -- actual breakpoint iteration is done via test.describe
    await use();
  }, { auto: false }],
});

// Helper: create a describe block that tests every breakpoint
export function describeBreakpoints(
  title: string,
  fn: (bp: Breakpoint) => void
) {
  for (const bp of BREAKPOINTS) {
    base.describe(`${title} @ ${bp.name} (${bp.width}px)`, () => {
      base.use({ viewport: { width: bp.width, height: bp.height } });
      fn(bp);
    });
  }
}

export { expect, BREAKPOINTS };
```

```typescript
// tests/responsive-grid.spec.ts
import { test, expect, describeBreakpoints } from './fixtures/responsive.fixture';

describeBreakpoints('product grid', (bp) => {
  test('shows correct number of columns', async ({ page }) => {
    await page.goto('/products');

    const grid = page.getByTestId('product-grid');
    const columns = await grid.evaluate((el) => {
      const style = window.getComputedStyle(el);
      return style.gridTemplateColumns.split(' ').length;
    });

    if (bp.width < 640) {
      expect(columns).toBe(1);     // xs: single column
    } else if (bp.width < 1024) {
      expect(columns).toBe(2);     // sm-md: two columns
    } else {
      expect(columns).toBe(4);     // lg+: four columns
    }
  });

  test('no content overflow', async ({ page }) => {
    await page.goto('/products');

    const hasOverflow = await page.evaluate(
      () => document.documentElement.scrollWidth > document.documentElement.clientWidth
    );
    expect(hasOverflow).toBe(false);
  });
});
```

#### JavaScript

```javascript
// tests/fixtures/responsive.fixture.js
const { test: base, expect } = require('@playwright/test');

const BREAKPOINTS = [
  { name: 'xs',  width: 320,  height: 568, isMobileExpected: true },
  { name: 'sm',  width: 640,  height: 800, isMobileExpected: true },
  { name: 'md',  width: 768,  height: 1024, isMobileExpected: false },
  { name: 'lg',  width: 1024, height: 768, isMobileExpected: false },
  { name: 'xl',  width: 1280, height: 800, isMobileExpected: false },
  { name: '2xl', width: 1440, height: 900, isMobileExpected: false },
];

function describeBreakpoints(title, fn) {
  for (const bp of BREAKPOINTS) {
    base.describe(`${title} @ ${bp.name} (${bp.width}px)`, () => {
      base.use({ viewport: { width: bp.width, height: bp.height } });
      fn(bp);
    });
  }
}

module.exports = { test: base, expect, BREAKPOINTS, describeBreakpoints };
```

```javascript
// tests/responsive-grid.spec.js
const { test, expect, describeBreakpoints } = require('./fixtures/responsive.fixture');

describeBreakpoints('product grid', (bp) => {
  test('shows correct number of columns', async ({ page }) => {
    await page.goto('/products');

    const grid = page.getByTestId('product-grid');
    const columns = await grid.evaluate((el) => {
      const style = window.getComputedStyle(el);
      return style.gridTemplateColumns.split(' ').length;
    });

    if (bp.width < 640) {
      expect(columns).toBe(1);
    } else if (bp.width < 1024) {
      expect(columns).toBe(2);
    } else {
      expect(columns).toBe(4);
    }
  });

  test('no content overflow', async ({ page }) => {
    await page.goto('/products');

    const hasOverflow = await page.evaluate(
      () => document.documentElement.scrollWidth > document.documentElement.clientWidth
    );
    expect(hasOverflow).toBe(false);
  });
});
```

### 8. Tests d'orientation

**À utiliser quand** : Tu testes les mises en page portrait vs paysage. Essentiel pour les apps tablette, les lecteurs multimédia, les dashboards et toute app qui s'adapte à l'orientation.
**À éviter quand** : Ton app ne change pas de mise en page selon l'orientation (responsive uniquement à la largeur -- teste plutôt avec des viewports personnalisés).

#### TypeScript

```typescript
// tests/orientation.spec.ts
import { test, expect, devices } from '@playwright/test';

test.describe('iPad orientation changes', () => {
  test.use({ ...devices['iPad Pro 11'] });

  test('dashboard adjusts layout in landscape', async ({ page }) => {
    // Start in portrait (834x1194 -- default for iPad Pro 11)
    await page.goto('/dashboard');

    // Portrait: sidebar collapses, chart stacks vertically
    await expect(page.getByTestId('sidebar')).toHaveCSS('position', 'fixed');

    // Switch to landscape by changing viewport
    await page.setViewportSize({ width: 1194, height: 834 });

    // Landscape: sidebar visible inline, charts side-by-side
    await expect(page.getByTestId('sidebar')).toHaveCSS('position', 'relative');
  });

  test('video player switches to fullscreen in landscape', async ({ page }) => {
    await page.goto('/videos/1');

    // Portrait: video in inline player
    const player = page.getByTestId('video-player');
    const portraitBox = await player.boundingBox();

    // Switch to landscape
    await page.setViewportSize({ width: 1194, height: 834 });

    // Video should expand to fill width
    const landscapeBox = await player.boundingBox();
    expect(landscapeBox!.width).toBeGreaterThan(portraitBox!.width);
  });
});

test.describe('iPhone orientation changes', () => {
  test('portrait mode', () => {
    test.use({ ...devices['iPhone 14'] }); // 390x844
  });

  test('landscape mode', () => {
    test.use({ ...devices['iPhone 14 landscape'] }); // 844x390
  });
});

// Test both orientations with a loop
const orientations = [
  { name: 'portrait', device: devices['iPad Pro 11'] },
  { name: 'landscape', device: devices['iPad Pro 11 landscape'] },
];

for (const { name, device } of orientations) {
  test.describe(`form usability in ${name}`, () => {
    test.use({ ...device });

    test('all form fields are visible without scrolling', async ({ page }) => {
      await page.goto('/contact');

      const form = page.getByRole('form');
      await expect(form).toBeVisible();

      // Check form fits within viewport
      const formBox = await form.boundingBox();
      const viewport = page.viewportSize()!;
      expect(formBox!.width).toBeLessThanOrEqual(viewport.width);
    });
  });
}
```

#### JavaScript

```javascript
// tests/orientation.spec.js
const { test, expect, devices } = require('@playwright/test');

test.describe('iPad orientation changes', () => {
  test.use({ ...devices['iPad Pro 11'] });

  test('dashboard adjusts layout in landscape', async ({ page }) => {
    await page.goto('/dashboard');

    await expect(page.getByTestId('sidebar')).toHaveCSS('position', 'fixed');

    await page.setViewportSize({ width: 1194, height: 834 });

    await expect(page.getByTestId('sidebar')).toHaveCSS('position', 'relative');
  });

  test('video player switches to fullscreen in landscape', async ({ page }) => {
    await page.goto('/videos/1');

    const player = page.getByTestId('video-player');
    const portraitBox = await player.boundingBox();

    await page.setViewportSize({ width: 1194, height: 834 });

    const landscapeBox = await player.boundingBox();
    expect(landscapeBox.width).toBeGreaterThan(portraitBox.width);
  });
});

const orientations = [
  { name: 'portrait', device: devices['iPad Pro 11'] },
  { name: 'landscape', device: devices['iPad Pro 11 landscape'] },
];

for (const { name, device } of orientations) {
  test.describe(`form usability in ${name}`, () => {
    test.use({ ...device });

    test('all form fields are visible without scrolling', async ({ page }) => {
      await page.goto('/contact');

      const form = page.getByRole('form');
      await expect(form).toBeVisible();

      const formBox = await form.boundingBox();
      const viewport = page.viewportSize();
      expect(formBox.width).toBeLessThanOrEqual(viewport.width);
    });
  });
}
```

### 9. Performances mobiles

**À utiliser quand** : Tu simules des conditions mobiles réelles -- réseaux 3G lents, CPU peu puissants. Essentiel pour tester les états de chargement, les skeleton screens et la gestion des timeouts.
**À éviter quand** : Tu testes uniquement la correction fonctionnelle. Le throttling de performance ralentit nettement ta suite de tests.

#### TypeScript

```typescript
// tests/mobile-performance.spec.ts
import { test, expect, devices } from '@playwright/test';

test.describe('mobile on slow network', () => {
  test.use({ ...devices['Pixel 7'] });

  test('shows skeleton loader on slow 3G', async ({ page }) => {
    // Get the CDP session for network throttling (Chromium only)
    const cdpSession = await page.context().newCDPSession(page);

    // Simulate slow 3G: 500kbps download, 500kbps upload, 400ms RTT
    await cdpSession.send('Network.emulateNetworkConditions', {
      offline: false,
      downloadThroughput: (500 * 1024) / 8,  // bytes per second
      uploadThroughput: (500 * 1024) / 8,
      latency: 400,                            // ms
    });

    await page.goto('/products');

    // Skeleton screen should appear while content loads
    await expect(page.getByTestId('product-skeleton')).toBeVisible();

    // Eventually, real content replaces skeleton
    await expect(page.getByRole('listitem')).toHaveCount(12, { timeout: 30_000 });
    await expect(page.getByTestId('product-skeleton')).toBeHidden();
  });

  test('shows offline message when network drops', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

    // Drop network entirely
    await page.context().setOffline(true);

    // Try to navigate -- should show offline message
    await page.getByRole('link', { name: 'Settings' }).click();
    await expect(page.getByText(/you.*offline|no.*connection/i)).toBeVisible();

    // Restore network
    await page.context().setOffline(false);
    await page.reload();
    await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible();
  });

  test('images lazy-load on slow connections', async ({ page }) => {
    const cdpSession = await page.context().newCDPSession(page);
    await cdpSession.send('Network.emulateNetworkConditions', {
      offline: false,
      downloadThroughput: (1000 * 1024) / 8,
      uploadThroughput: (500 * 1024) / 8,
      latency: 200,
    });

    await page.goto('/gallery');

    // Images below the fold should have loading="lazy" and not load immediately
    const belowFoldImages = page.locator('img[loading="lazy"]');
    const count = await belowFoldImages.count();
    expect(count).toBeGreaterThan(0);

    // Scroll to trigger lazy loading
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await expect(belowFoldImages.first()).toHaveJSProperty('complete', true);
  });

  test('CPU throttling shows performance impact', async ({ page }) => {
    const cdpSession = await page.context().newCDPSession(page);

    // Simulate 4x CPU slowdown (typical mid-range mobile device)
    await cdpSession.send('Emulation.setCPUThrottlingRate', { rate: 4 });

    await page.goto('/');

    // Measure time to interactive
    const tti = await page.evaluate(() => {
      const entries = performance.getEntriesByType('navigation') as PerformanceNavigationTiming[];
      return entries[0]?.domInteractive ?? 0;
    });

    // Assert TTI is within acceptable range for throttled mobile
    expect(tti).toBeLessThan(5000);

    // Reset throttling
    await cdpSession.send('Emulation.setCPUThrottlingRate', { rate: 1 });
  });
});
```

#### JavaScript

```javascript
// tests/mobile-performance.spec.js
const { test, expect, devices } = require('@playwright/test');

test.describe('mobile on slow network', () => {
  test.use({ ...devices['Pixel 7'] });

  test('shows skeleton loader on slow 3G', async ({ page }) => {
    const cdpSession = await page.context().newCDPSession(page);

    await cdpSession.send('Network.emulateNetworkConditions', {
      offline: false,
      downloadThroughput: (500 * 1024) / 8,
      uploadThroughput: (500 * 1024) / 8,
      latency: 400,
    });

    await page.goto('/products');

    await expect(page.getByTestId('product-skeleton')).toBeVisible();
    await expect(page.getByRole('listitem')).toHaveCount(12, { timeout: 30_000 });
    await expect(page.getByTestId('product-skeleton')).toBeHidden();
  });

  test('shows offline message when network drops', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

    await page.context().setOffline(true);

    await page.getByRole('link', { name: 'Settings' }).click();
    await expect(page.getByText(/you.*offline|no.*connection/i)).toBeVisible();

    await page.context().setOffline(false);
    await page.reload();
    await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible();
  });

  test('CPU throttling shows performance impact', async ({ page }) => {
    const cdpSession = await page.context().newCDPSession(page);

    await cdpSession.send('Emulation.setCPUThrottlingRate', { rate: 4 });

    await page.goto('/');

    const tti = await page.evaluate(() => {
      const entries = performance.getEntriesByType('navigation');
      return entries[0]?.domInteractive ?? 0;
    });

    expect(tti).toBeLessThan(5000);
    await cdpSession.send('Emulation.setCPUThrottlingRate', { rate: 1 });
  });
});
```

### 10. Tests PWA mobiles

**À utiliser quand** : Tu testes les fonctionnalités d'une Progressive Web App -- service workers, invites d'installation, mode hors ligne, notifications push sur mobile.
**À éviter quand** : Ton app n'est pas une PWA. Pour les tests hors ligne en général, voir le pattern réseau offline du Pattern 9.

#### TypeScript

```typescript
// tests/pwa-mobile.spec.ts
import { test, expect, devices } from '@playwright/test';

test.use({ ...devices['Pixel 7'] });

test('service worker registers and caches resources', async ({ page }) => {
  await page.goto('/');

  // Wait for service worker to register
  const swRegistered = await page.evaluate(async () => {
    const registration = await navigator.serviceWorker.ready;
    return registration.active?.state === 'activated';
  });
  expect(swRegistered).toBe(true);

  // Verify critical resources are cached
  const cacheContents = await page.evaluate(async () => {
    const cache = await caches.open('app-shell-v1');
    const keys = await cache.keys();
    return keys.map((req) => new URL(req.url).pathname);
  });

  expect(cacheContents).toContain('/');
  expect(cacheContents).toContain('/offline.html');
});

test('app works offline after initial load', async ({ page }) => {
  // Load the app online first -- service worker caches resources
  await page.goto('/');
  await expect(page.getByRole('heading', { name: 'Home' })).toBeVisible();

  // Wait for service worker to finish caching
  await page.evaluate(async () => {
    const registration = await navigator.serviceWorker.ready;
    // Wait for the service worker to activate
    if (registration.active?.state !== 'activated') {
      await new Promise<void>((resolve) => {
        registration.active?.addEventListener('statechange', () => {
          if (registration.active?.state === 'activated') resolve();
        });
      });
    }
  });

  // Go offline
  await page.context().setOffline(true);

  // Navigate to a cached page
  await page.goto('/about');

  // Cached page should render
  await expect(page.getByRole('heading', { name: 'About' })).toBeVisible();
});

test('offline fallback page shows when uncached route is accessed', async ({ page }) => {
  await page.goto('/');

  // Wait for service worker
  await page.evaluate(() => navigator.serviceWorker.ready);

  // Go offline and navigate to an uncached route
  await page.context().setOffline(true);
  await page.goto('/uncached-page');

  // Should show the offline fallback page
  await expect(page.getByText(/offline|no.*connection/i)).toBeVisible();
  await expect(page.getByRole('button', { name: 'Retry' })).toBeVisible();
});

test('app prompts to install on mobile', async ({ page, context }) => {
  // Listen for the beforeinstallprompt event
  await page.goto('/');

  const installPromptFired = await page.evaluate(() => {
    return new Promise<boolean>((resolve) => {
      // Check if the event has already fired
      window.addEventListener('beforeinstallprompt', (e) => {
        e.preventDefault(); // Prevent auto-prompt
        resolve(true);
      });

      // If PWA criteria are met, the event fires automatically
      // Timeout after 5s if it doesn't fire
      setTimeout(() => resolve(false), 5000);
    });
  });

  // Note: beforeinstallprompt only fires in Chromium and when PWA criteria are met
  // This test validates the event handler, not the browser chrome UI
  if (installPromptFired) {
    // App should show a custom install banner
    await expect(page.getByTestId('install-banner')).toBeVisible();
    await page.getByRole('button', { name: 'Install app' }).click();
  }
});

test('push notification permission request on mobile', async ({ page, context }) => {
  // Grant notification permission
  await context.grantPermissions(['notifications']);

  await page.goto('/settings/notifications');

  await page.getByRole('button', { name: 'Enable notifications' }).click();

  // Verify the app registered for push
  const pushSubscription = await page.evaluate(async () => {
    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.getSubscription();
    return subscription !== null;
  });

  expect(pushSubscription).toBe(true);
  await expect(page.getByText('Notifications enabled')).toBeVisible();
});
```

#### JavaScript

```javascript
// tests/pwa-mobile.spec.js
const { test, expect, devices } = require('@playwright/test');

test.use({ ...devices['Pixel 7'] });

test('service worker registers and caches resources', async ({ page }) => {
  await page.goto('/');

  const swRegistered = await page.evaluate(async () => {
    const registration = await navigator.serviceWorker.ready;
    return registration.active?.state === 'activated';
  });
  expect(swRegistered).toBe(true);

  const cacheContents = await page.evaluate(async () => {
    const cache = await caches.open('app-shell-v1');
    const keys = await cache.keys();
    return keys.map((req) => new URL(req.url).pathname);
  });

  expect(cacheContents).toContain('/');
  expect(cacheContents).toContain('/offline.html');
});

test('app works offline after initial load', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('heading', { name: 'Home' })).toBeVisible();

  await page.evaluate(async () => {
    await navigator.serviceWorker.ready;
  });

  await page.context().setOffline(true);
  await page.goto('/about');

  await expect(page.getByRole('heading', { name: 'About' })).toBeVisible();
});

test('offline fallback page shows when uncached route is accessed', async ({ page }) => {
  await page.goto('/');
  await page.evaluate(() => navigator.serviceWorker.ready);

  await page.context().setOffline(true);
  await page.goto('/uncached-page');

  await expect(page.getByText(/offline|no.*connection/i)).toBeVisible();
  await expect(page.getByRole('button', { name: 'Retry' })).toBeVisible();
});

test('push notification permission request on mobile', async ({ page, context }) => {
  await context.grantPermissions(['notifications']);

  await page.goto('/settings/notifications');

  await page.getByRole('button', { name: 'Enable notifications' }).click();

  const pushSubscription = await page.evaluate(async () => {
    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.getSubscription();
    return subscription !== null;
  });

  expect(pushSubscription).toBe(true);
  await expect(page.getByText('Notifications enabled')).toBeVisible();
});
```

## Guide de décision

| Question | Réponse | Approche |
|---|---|---|
| Besoin de tester l'apparence de l'app sur iPhone 14 ? | Oui | Utilise `devices['iPhone 14']` -- récupère viewport, UA, tactile, scale factor d'un coup |
| Besoin de tester un breakpoint CSS à 768px ? | Oui | Utilise `test.use({ viewport: { width: 768, height: 1024 } })` -- plus simple, sans changement d'UA |
| Besoin de tester le portrait et le paysage ? | Oui | Utilise un appareil nommé + sa variante paysage : `devices['iPad Pro 11']` et `devices['iPad Pro 11 landscape']` |
| Besoin de performances mobiles réalistes ? | Oui | Utilise CDP `Network.emulateNetworkConditions` + `Emulation.setCPUThrottlingRate` (Chromium uniquement) |
| Besoin de tester des gestes tactiles ? | Oui | Utilise un profil d'appareil avec `hasTouch: true`, puis `tap()` et des gestes souris pour le swipe |
| Besoin de tester la géolocalisation ? | Oui | Définis `geolocation` et `permissions: ['geolocation']` dans les options du contexte |
| Besoin de tests mobiles au pixel près ? | Non -- utilise de vrais appareils | L'émulation Playwright est approximative ; le rendu des polices et l'UI native diffèrent du matériel réel |
| Quels appareils tester par défaut ? | Commence par 3 | `Desktop Chrome` + `Pixel 7` (Android) + `iPhone 14` (iOS). Ajoute une tablette si ton app a une mise en page tablette. |
| Quand ajouter d'autres projets d'appareils ? | Quand des bugs passent entre les mailles | Si des utilisateurs signalent des bugs propres à un appareil, ajoute durablement ce profil d'appareil |
| Lancer tous les appareils à chaque PR ? | Non | Lance desktop + un mobile sur les PR. Lance tous les appareils lors des merges sur la branche main. |
| Émulation d'appareil ou viewport personnalisé ? | Selon l'objectif | Émulation : tester le comportement réel d'un appareil. Viewport personnalisé : tester les breakpoints CSS. |
| Faut-il tester toutes les tailles d'écran ? | Non | Teste tes vrais breakpoints CSS, plus les plus petites (320px) et plus grandes (1440px+) tailles supportées |

## Anti-patterns

| À ne pas faire | Problème | À faire plutôt |
|---|---|---|
| Tester uniquement en desktop 1280x720 | Rate tous les bugs de mise en page mobile et tablette ; la majorité du trafic web est mobile | Ajoute au moins les projets `Pixel 7` et `iPhone 14` |
| Utiliser l'émulation d'appareil pour des tests au pixel près | L'émulation approxime les appareils réels -- le rendu des polices, l'antialiasing sub-pixel et le chrome natif du navigateur diffèrent | Utilise l'émulation pour tester la mise en page et les interactions ; utilise des fermes d'appareils réels (BrowserStack, Sauce Labs) pour la validation au pixel près |
| Ignorer les interactions tactiles | Les utilisateurs mobiles tapent, swipent et font des appuis longs ; `click()` seul peut ne pas déclencher les handlers d'événements tactiles | Utilise `tap()` sur les profils d'appareils tactiles ; teste les swipes avec des séquences de mouvements de souris |
| Ne pas tester les changements d'orientation | Les utilisateurs font pivoter tablettes et téléphones ; les mises en page peuvent casser en paysage | Teste le portrait et le paysage avec des variantes d'appareils ou `page.setViewportSize()` |
| `page.setViewportSize()` sans `hasTouch: true` | Le viewport est petit mais le navigateur ne déclare aucun support tactile -- `@media (hover: hover)` correspond toujours au desktop | Utilise des profils d'appareils ou définis explicitement `hasTouch: true` dans `test.use()` |
| Coder en dur des vérifications `isMobile` dans chaque test | Duplique la logique, difficile à maintenir ; les tests deviennent fragiles | Utilise des page objects qui masquent derrière des méthodes la différence de comportement mobile vs desktop |
| Tester la mise en page mobile avec des vérifications `visibility: hidden` uniquement | L'élément peut quand même occuper de l'espace ; le CSS peut utiliser `display: none` ou `transform: translateX(-100%)` | Utilise `toBeHidden()` (vérifie la non-visibilité) ou `toHaveCSS('display', 'none')` pour un comportement CSS précis |
| Lancer plus de 10 projets d'appareils à chaque exécution de CI | Temps et coût de CI énormes pour des gains qui décroissent au-delà de 3-4 appareils | Choisis des appareils représentatifs : un téléphone Android, un iPhone, une tablette et des navigateurs desktop |
| Throttling réseau dans chaque test | Ralentit énormément toute la suite pour un gain de couverture minime | Crée un projet `mobile-perf` séparé ou tague les tests de performance avec `@slow` et lance-les à part |
| `await page.waitForTimeout(2000)` après un changement d'orientation | Délai arbitraire ; le reflow de la mise en page peut être plus rapide ou plus lent | `await expect(locator).toHaveCSS('property', 'value')` -- l'assertion réessaie automatiquement jusqu'à stabilisation de la mise en page |
| Tester la géolocalisation sans définir les permissions | Le navigateur bloque silencieusement la géolocalisation ; le test ne voit aucune donnée de position et passe à tort | Définis toujours `permissions: ['geolocation']` en plus des coordonnées `geolocation` |
| Throttling CDP sur Firefox ou WebKit | Les sessions CDP sont propres à Chromium ; le test lèvera une erreur sur les autres navigateurs | Protège les appels CDP par une vérification du navigateur ou utilise des projets Chromium uniquement pour les tests de performance |

## Dépannage

### `tap()` lève l'erreur « Page.tap: Not supported »

**Cause** : Le contexte du navigateur a été créé sans `hasTouch: true`. Les profils d'appareils le définissent automatiquement, mais pas les configurations de viewport personnalisées.

```typescript
// Wrong -- custom viewport without touch support
test.use({ viewport: { width: 375, height: 667 } });
test('tap fails', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button').tap(); // Error: Not supported
});

// Fix -- enable touch explicitly
test.use({
  viewport: { width: 375, height: 667 },
  hasTouch: true,
});
test('tap works', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button').tap(); // Works
});

// Or use a device profile that includes hasTouch
test.use({ ...devices['iPhone 14'] });
```

### `isMobile` vaut toujours `false`

**Cause** : `isMobile` est défini par la propriété `isMobile` du profil d'appareil, pas par la taille du viewport. Les viewports personnalisés ne le définissent pas.

```typescript
// isMobile is false here -- no device profile used
test.use({ viewport: { width: 375, height: 667 } });

test('isMobile is false', async ({ page, isMobile }) => {
  console.log(isMobile); // false
});

// Fix: use a device profile, or set isMobile explicitly
test.use({
  viewport: { width: 375, height: 667 },
  isMobile: true,
  hasTouch: true,
});

test('isMobile is true', async ({ page, isMobile }) => {
  console.log(isMobile); // true
});
```

### La géolocalisation ne fonctionne pas -- la position reste celle par défaut

**Cause** : `permissions: ['geolocation']` manque dans les options du contexte. Sans cette permission, le navigateur refuse silencieusement l'API Geolocation.

```typescript
// Wrong -- geolocation set but no permission granted
test.use({
  geolocation: { latitude: 40.7128, longitude: -74.0060 },
  // Missing: permissions: ['geolocation']
});

// Fix
test.use({
  geolocation: { latitude: 40.7128, longitude: -74.0060 },
  permissions: ['geolocation'],
});
```

### La session CDP lève une erreur sur Firefox/WebKit

**Cause** : `page.context().newCDPSession(page)` est réservé à Chromium. Firefox et WebKit ne supportent pas CDP.

```typescript
// Wrong -- crashes on Firefox and WebKit
test('throttle network', async ({ page }) => {
  const cdp = await page.context().newCDPSession(page); // Throws on non-Chromium
});

// Fix -- guard with browser name check
test('throttle network', async ({ page, browserName }) => {
  test.skip(browserName !== 'chromium', 'CDP throttling is Chromium-only');

  const cdp = await page.context().newCDPSession(page);
  await cdp.send('Network.emulateNetworkConditions', {
    offline: false,
    downloadThroughput: (500 * 1024) / 8,
    uploadThroughput: (500 * 1024) / 8,
    latency: 400,
  });
});

// Alternative -- use context.setOffline() which works on all browsers
test('offline mode', async ({ page }) => {
  await page.context().setOffline(true); // Works everywhere
});
```

### Le changement de viewport ne déclenche pas les media queries CSS

**Cause** : `page.setViewportSize()` change le viewport mais ne déclenche pas les événements `resize` ou `orientationchange` dans certains frameworks qui s'appuient sur une logique responsive en JavaScript plutôt que sur des media queries CSS.

```typescript
// If media queries don't fire after setViewportSize, dispatch manually
await page.setViewportSize({ width: 375, height: 667 });
await page.evaluate(() => window.dispatchEvent(new Event('resize')));

// Better: use the viewport in test.use() so it's set before page load
test.use({ viewport: { width: 375, height: 667 } });
```

### Le service worker ne s'enregistre pas dans les tests

**Cause** : Les service workers exigent HTTPS ou localhost. Le `baseURL` par défaut de Playwright, `http://localhost:3000`, fonctionne, mais pas les autres origines HTTP.

```typescript
// Ensure your baseURL is localhost or HTTPS
// playwright.config.ts
export default defineConfig({
  use: {
    baseURL: 'http://localhost:3000',          // Works for service workers
    // baseURL: 'http://192.168.1.100:3000',   // Does NOT work -- not localhost
  },
});

// If testing against a non-localhost server, use HTTPS
// or use serviceWorkers: 'allow' (default) in context options
```

## Voir aussi

- [core/configuration.md](configuration.md) -- configuration du projet avec profils d'appareils et config multi-projets
- [core/visual-regression.md](visual-regression.md) -- combine les tests responsives avec la comparaison de captures d'écran entre viewports
- [core/network-mocking.md](network-mocking.md) -- mocke les réponses d'API en complément des tests mobiles
- [core/service-workers-and-pwa.md](service-workers-and-pwa.md) -- tests PWA approfondis au-delà du contexte mobile
- [core/performance-testing.md](performance-testing.md) -- tests de performance complets, métriques mobiles comprises
- [core/browser-apis.md](browser-apis.md) -- géolocalisation, permissions et autres API du navigateur en détail
- [ci/projects-and-dependencies.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/projects-and-dependencies.md) -- patterns multi-projets avancés pour les matrices de tests responsives
