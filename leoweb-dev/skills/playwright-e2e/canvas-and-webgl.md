# Tests de Canvas et WebGL

> **Quand l'utiliser** : quand ton application affiche du contenu dans des éléments `<canvas>` -- graphiques (Chart.js, D3), cartes (Mapbox, Leaflet), jeux, éditeurs d'images, visualisations WebGL, outils de dessin, pads de signature.
> **Prérequis** : [core/assertions-and-waiting.md](assertions-and-waiting.md), [core/locators.md](locators.md)

## Référence rapide

```typescript
// Screenshot comparison — the primary strategy for canvas
await expect(page.locator('canvas#chart')).toHaveScreenshot('revenue-chart.png');

// Click at specific coordinates on canvas
await page.locator('canvas').click({ position: { x: 200, y: 150 } });

// Read canvas state via page.evaluate
const pixelColor = await page.evaluate(() => {
  const canvas = document.querySelector('canvas') as HTMLCanvasElement;
  const ctx = canvas.getContext('2d')!;
  const pixel = ctx.getImageData(100, 100, 1, 1).data;
  return { r: pixel[0], g: pixel[1], b: pixel[2], a: pixel[3] };
});
```

## Patterns

### Comparaison de captures d'écran (régression visuelle)

**À utiliser quand** : tu vérifies le rendu visuel d'un contenu dessiné dans un canvas -- graphiques, courbes, cartes, dessins. C'est l'approche la plus fiable, car les pixels d'un canvas ne sont pas interrogeables via le DOM.
**À éviter quand** : le contenu du canvas change à chaque rendu (animations, timestamps). Utilise les options de seuil (threshold) ou de masque.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('revenue chart renders correctly', async ({ page }) => {
  await page.goto('/dashboard');

  // Wait for the chart to finish rendering
  await expect(page.locator('canvas#revenue-chart')).toBeVisible();

  // Optionally wait for a loading indicator to disappear
  await expect(page.getByTestId('chart-loading')).toBeHidden();

  // Screenshot comparison against a baseline
  await expect(page.locator('canvas#revenue-chart')).toHaveScreenshot('revenue-chart.png', {
    maxDiffPixelRatio: 0.01,  // Allow 1% pixel difference for anti-aliasing
  });
});

test('chart updates after date range change', async ({ page }) => {
  await page.goto('/dashboard');

  // Change date range
  await page.getByRole('combobox', { name: 'Date range' }).selectOption('Last 30 days');

  // Wait for chart to re-render
  await expect(page.getByTestId('chart-loading')).toBeHidden();

  // Compare against a different baseline
  await expect(page.locator('canvas#revenue-chart')).toHaveScreenshot('revenue-chart-30d.png', {
    maxDiffPixelRatio: 0.01,
  });
});

test('mask dynamic areas in canvas screenshot', async ({ page }) => {
  await page.goto('/dashboard');

  await expect(page.locator('canvas#chart')).toHaveScreenshot('chart-stable.png', {
    // Mask the timestamp area that changes every render
    mask: [page.locator('.chart-timestamp')],
    maxDiffPixelRatio: 0.02,
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('revenue chart renders correctly', async ({ page }) => {
  await page.goto('/dashboard');
  await expect(page.locator('canvas#revenue-chart')).toBeVisible();
  await expect(page.getByTestId('chart-loading')).toBeHidden();

  await expect(page.locator('canvas#revenue-chart')).toHaveScreenshot('revenue-chart.png', {
    maxDiffPixelRatio: 0.01,
  });
});

test('chart updates after date range change', async ({ page }) => {
  await page.goto('/dashboard');
  await page.getByRole('combobox', { name: 'Date range' }).selectOption('Last 30 days');
  await expect(page.getByTestId('chart-loading')).toBeHidden();

  await expect(page.locator('canvas#revenue-chart')).toHaveScreenshot('revenue-chart-30d.png', {
    maxDiffPixelRatio: 0.01,
  });
});
```

### Interagir avec un canvas via des coordonnées

**À utiliser quand** : tu testes des interactions utilisateur sur un canvas -- clic sur des points de données d'un graphique, glisser sur un outil de dessin, sélection de régions d'une carte.
**À éviter quand** : l'élément possède une surcouche DOM accessible (beaucoup de bibliothèques de graphiques affichent les tooltips en HTML). Interagis alors avec la surcouche.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('click on chart data point shows tooltip', async ({ page }) => {
  await page.goto('/analytics');

  const canvas = page.locator('canvas#line-chart');
  await expect(canvas).toBeVisible();

  // Click at a specific coordinate on the canvas
  await canvas.click({ position: { x: 200, y: 100 } });

  // Tooltip appears as an HTML overlay (most chart libraries)
  await expect(page.getByTestId('chart-tooltip')).toContainText('Revenue: $12,400');
});

test('draw a line on the canvas', async ({ page }) => {
  await page.goto('/drawing-tool');

  const canvas = page.locator('canvas#drawing-area');

  // Simulate a drag to draw a line
  await canvas.hover({ position: { x: 50, y: 50 } });
  await page.mouse.down();
  await page.mouse.move(200, 200, { steps: 10 }); // Smooth drag
  await page.mouse.up();

  // Verify via screenshot
  await expect(canvas).toHaveScreenshot('drawn-line.png');
});

test('pinch-to-zoom on a map canvas', async ({ page }) => {
  await page.goto('/map');

  const canvas = page.locator('canvas#map');

  // Scroll to zoom (common in map libraries)
  await canvas.hover({ position: { x: 300, y: 300 } });
  await page.mouse.wheel(0, -500); // Scroll up = zoom in

  // Verify zoom level changed
  await expect(page.getByTestId('zoom-level')).toHaveText('Zoom: 12');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('click on chart data point shows tooltip', async ({ page }) => {
  await page.goto('/analytics');

  const canvas = page.locator('canvas#line-chart');
  await expect(canvas).toBeVisible();

  await canvas.click({ position: { x: 200, y: 100 } });
  await expect(page.getByTestId('chart-tooltip')).toContainText('Revenue: $12,400');
});

test('draw a line on the canvas', async ({ page }) => {
  await page.goto('/drawing-tool');

  const canvas = page.locator('canvas#drawing-area');
  await canvas.hover({ position: { x: 50, y: 50 } });
  await page.mouse.down();
  await page.mouse.move(200, 200, { steps: 10 });
  await page.mouse.up();

  await expect(canvas).toHaveScreenshot('drawn-line.png');
});
```

### Tester l'API Canvas via `page.evaluate()`

**À utiliser quand** : tu dois inspecter les données de pixels du canvas, lire l'état du contexte de rendu ou vérifier des opérations programmatiques sur le canvas.
**À éviter quand** : une comparaison de captures d'écran suffit. Les assertions au niveau du pixel sont fragiles.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('verify specific pixel color on canvas', async ({ page }) => {
  await page.goto('/color-picker');

  // Click the red swatch
  await page.getByRole('button', { name: 'Red' }).click();

  // Read the pixel color at the canvas center
  const color = await page.evaluate(() => {
    const canvas = document.querySelector('canvas#preview') as HTMLCanvasElement;
    const ctx = canvas.getContext('2d')!;
    const centerX = Math.floor(canvas.width / 2);
    const centerY = Math.floor(canvas.height / 2);
    const pixel = ctx.getImageData(centerX, centerY, 1, 1).data;
    return { r: pixel[0], g: pixel[1], b: pixel[2], a: pixel[3] };
  });

  expect(color.r).toBeGreaterThan(200); // Red channel high
  expect(color.g).toBeLessThan(50);     // Green channel low
  expect(color.b).toBeLessThan(50);     // Blue channel low
});

test('verify canvas dimensions match expected size', async ({ page }) => {
  await page.goto('/editor');

  const dimensions = await page.evaluate(() => {
    const canvas = document.querySelector('canvas#main') as HTMLCanvasElement;
    return { width: canvas.width, height: canvas.height };
  });

  expect(dimensions).toEqual({ width: 1920, height: 1080 });
});

test('canvas has content (is not blank)', async ({ page }) => {
  await page.goto('/chart');

  // Wait for rendering
  await expect(page.getByTestId('chart-loading')).toBeHidden();

  const isBlank = await page.evaluate(() => {
    const canvas = document.querySelector('canvas') as HTMLCanvasElement;
    const ctx = canvas.getContext('2d')!;
    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
    // Check if all pixels are transparent (blank canvas)
    return imageData.data.every((value, index) => {
      return index % 4 === 3 ? value === 0 : true; // Check alpha channel
    });
  });

  expect(isBlank).toBe(false);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('verify specific pixel color on canvas', async ({ page }) => {
  await page.goto('/color-picker');
  await page.getByRole('button', { name: 'Red' }).click();

  const color = await page.evaluate(() => {
    const canvas = document.querySelector('canvas#preview');
    const ctx = canvas.getContext('2d');
    const centerX = Math.floor(canvas.width / 2);
    const centerY = Math.floor(canvas.height / 2);
    const pixel = ctx.getImageData(centerX, centerY, 1, 1).data;
    return { r: pixel[0], g: pixel[1], b: pixel[2], a: pixel[3] };
  });

  expect(color.r).toBeGreaterThan(200);
  expect(color.g).toBeLessThan(50);
  expect(color.b).toBeLessThan(50);
});

test('canvas has content (is not blank)', async ({ page }) => {
  await page.goto('/chart');
  await expect(page.getByTestId('chart-loading')).toBeHidden();

  const isBlank = await page.evaluate(() => {
    const canvas = document.querySelector('canvas');
    const ctx = canvas.getContext('2d');
    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
    return imageData.data.every((value, index) => {
      return index % 4 === 3 ? value === 0 : true;
    });
  });

  expect(isBlank).toBe(false);
});
```

### Vérification du rendu WebGL

**À utiliser quand** : ton application utilise WebGL pour des visualisations 3D, des graphiques de données ou des jeux.
**À éviter quand** : le canvas utilise uniquement le contexte 2D.

Un canvas WebGL ne peut pas être lu avec `getImageData` depuis un contexte 2D. Utilise `toDataURL()` ou la comparaison de captures d'écran.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('WebGL scene renders a 3D model', async ({ page }) => {
  await page.goto('/3d-viewer');

  // Wait for WebGL to finish rendering
  await page.waitForFunction(() => {
    const canvas = document.querySelector('canvas#scene') as HTMLCanvasElement;
    const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
    return gl !== null;
  });

  // Give the renderer time to complete the first frame
  await expect(page.getByTestId('render-status')).toHaveText('Ready');

  // Screenshot comparison is the most reliable approach for WebGL
  await expect(page.locator('canvas#scene')).toHaveScreenshot('3d-model.png', {
    maxDiffPixelRatio: 0.02, // WebGL has more rendering variance
  });
});

test('WebGL canvas is not blank', async ({ page }) => {
  await page.goto('/3d-viewer');
  await expect(page.getByTestId('render-status')).toHaveText('Ready');

  // Check that the WebGL canvas has drawn something
  const hasContent = await page.evaluate(() => {
    const canvas = document.querySelector('canvas#scene') as HTMLCanvasElement;
    // Convert canvas to data URL and check it's not a blank image
    const dataUrl = canvas.toDataURL();
    // A blank canvas produces a very short data URL
    return dataUrl.length > 1000;
  });

  expect(hasContent).toBe(true);
});

test('rotate 3D model and verify new angle', async ({ page }) => {
  await page.goto('/3d-viewer');
  await expect(page.getByTestId('render-status')).toHaveText('Ready');

  // Take baseline screenshot
  const canvas = page.locator('canvas#scene');

  // Drag to rotate
  await canvas.hover({ position: { x: 300, y: 300 } });
  await page.mouse.down();
  await page.mouse.move(450, 300, { steps: 20 });
  await page.mouse.up();

  // Screenshot should differ from default angle
  await expect(canvas).toHaveScreenshot('3d-model-rotated.png', {
    maxDiffPixelRatio: 0.02,
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('WebGL scene renders a 3D model', async ({ page }) => {
  await page.goto('/3d-viewer');

  await page.waitForFunction(() => {
    const canvas = document.querySelector('canvas#scene');
    const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
    return gl !== null;
  });

  await expect(page.getByTestId('render-status')).toHaveText('Ready');
  await expect(page.locator('canvas#scene')).toHaveScreenshot('3d-model.png', {
    maxDiffPixelRatio: 0.02,
  });
});

test('WebGL canvas is not blank', async ({ page }) => {
  await page.goto('/3d-viewer');
  await expect(page.getByTestId('render-status')).toHaveText('Ready');

  const hasContent = await page.evaluate(() => {
    const canvas = document.querySelector('canvas#scene');
    const dataUrl = canvas.toDataURL();
    return dataUrl.length > 1000;
  });

  expect(hasContent).toBe(true);
});
```

### Stratégies de test des bibliothèques de graphiques

**À utiliser quand** : tu testes Chart.js, D3, Recharts, Highcharts ou des bibliothèques de graphiques similaires.
**À éviter quand** : les graphiques produisent un DOM HTML/SVG complet (D3 avec SVG). Utilise alors les locators standard pour les éléments SVG.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('bar chart shows correct number of bars (SVG-based chart)', async ({ page }) => {
  await page.goto('/analytics');

  // SVG-based charts (D3, Recharts) render DOM elements — use locators
  const bars = page.locator('svg.chart rect.bar');
  await expect(bars).toHaveCount(12); // 12 months

  // Check a specific bar's aria-label or tooltip
  await bars.nth(0).hover();
  await expect(page.getByTestId('chart-tooltip')).toContainText('January: $8,200');
});

test('canvas-based chart displays data (Chart.js)', async ({ page }) => {
  await page.goto('/analytics');

  // Canvas charts — no DOM elements to query, use screenshot
  await expect(page.getByTestId('chart-loading')).toBeHidden();
  await expect(page.locator('canvas#monthly-chart')).toHaveScreenshot('monthly-chart.png');
});

test('chart legend toggles data series', async ({ page }) => {
  await page.goto('/analytics');

  // Click legend item (usually HTML, not canvas)
  await page.getByRole('button', { name: 'Revenue' }).click();

  // Revenue series hidden — chart should look different
  await expect(page.locator('canvas#chart')).toHaveScreenshot('chart-no-revenue.png');

  // Click again to re-enable
  await page.getByRole('button', { name: 'Revenue' }).click();
  await expect(page.locator('canvas#chart')).toHaveScreenshot('chart-with-revenue.png');
});

test('export chart as image', async ({ page }) => {
  await page.goto('/analytics');

  // Many chart libraries offer "download as PNG"
  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Export as PNG' }).click();
  const download = await downloadPromise;

  expect(download.suggestedFilename()).toMatch(/chart.*\.png$/);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('bar chart shows correct number of bars (SVG-based)', async ({ page }) => {
  await page.goto('/analytics');

  const bars = page.locator('svg.chart rect.bar');
  await expect(bars).toHaveCount(12);

  await bars.nth(0).hover();
  await expect(page.getByTestId('chart-tooltip')).toContainText('January: $8,200');
});

test('canvas-based chart displays data', async ({ page }) => {
  await page.goto('/analytics');
  await expect(page.getByTestId('chart-loading')).toBeHidden();
  await expect(page.locator('canvas#monthly-chart')).toHaveScreenshot('monthly-chart.png');
});
```

## Guide de décision

| Scénario | Meilleure approche | Pourquoi |
|---|---|---|
| Vérifier que le graphique est correct visuellement | `toHaveScreenshot()` sur l'élément canvas | Les pixels du canvas ne sont pas dans le DOM ; la capture d'écran fait foi |
| Cliquer sur un point de données du graphique | `canvas.click({ position: { x, y } })` | Le canvas n'a pas d'éléments enfants cliquables |
| Vérifier que le canvas n'est pas vide | `page.evaluate` + `getImageData` ou `toDataURL` | Contrôle programmatique rapide, sans image de référence |
| Tester un graphique SVG (D3) | Locators standard (`svg rect`, `svg path`) | Les éléments SVG sont dans le DOM ; utiliser des requêtes de locator |
| Lire la couleur d'un pixel précis | `page.evaluate` + `getImageData` | Accès direct aux données de pixels |
| Tester le rendu WebGL | `toHaveScreenshot()` avec un `maxDiffPixelRatio` plus élevé | WebGL a de la variance de rendu ; les assertions sur les pixels ne sont pas fiables |
| Tester le glisser/dessiner sur un canvas | `mouse.down()` + `mouse.move()` + `mouse.up()` | Simule de vraies interactions de dessin |
| Tooltip de graphique après survol | `canvas.hover({ position })` puis assertion sur le DOM du tooltip | Les tooltips sont généralement des surcouches HTML |

## Anti-patterns

| À ne pas faire | Problème | À faire plutôt |
|---|---|---|
| `page.getByRole('button')` à l'intérieur d'un canvas | Le contenu d'un canvas n'a pas d'éléments DOM | Utiliser `canvas.click({ position })` avec des coordonnées |
| Asserter des couleurs de pixels avec des valeurs RGB exactes | L'anti-aliasing et les différences de GPU provoquent 1 à 2 unités d'écart | Utiliser des plages (`toBeGreaterThan(200)`) ou `toHaveScreenshot` |
| Omettre `maxDiffPixelRatio` dans les captures d'écran de canvas | Des GPU et versions d'OS différents rendent légèrement différemment | Définir `maxDiffPixelRatio: 0.01` à `0.02` |
| `waitForTimeout` pour attendre le rendu du graphique | Arbitraire ; trop lent ou trop rapide | Attendre la disparition d'un indicateur de chargement ou utiliser `waitForFunction` |
| Lire les pixels WebGL via `getImageData` d'un contexte 2D | Les contextes WebGL et 2D sont mutuellement exclusifs sur un même canvas | Utiliser `canvas.toDataURL()` ou la comparaison de captures d'écran |
| Prendre des captures d'écran de page entière pour les tests de canvas | Capture du contenu sans rapport ; références plus fragiles | Limiter la capture à `page.locator('canvas#specific')` |

## Dépannage

| Symptôme | Cause | Correction |
|---|---|---|
| La référence de capture d'écran diffère toujours | Différences de rendu GPU entre la CI et la machine locale | Utiliser Docker avec des réglages GPU cohérents, ou augmenter `maxDiffPixelRatio` |
| Le clic à des coordonnées du canvas touche le mauvais élément | Les coordonnées sont relatives à l'élément, mais le viewport a changé | Utiliser `position` relative à l'élément canvas, pas à la page |
| `getImageData` renvoie uniquement des pixels transparents | Le canvas n'avait pas fini son rendu au moment de l'évaluation | Attendre un signal de fin de rendu ou utiliser `waitForFunction` |
| `toDataURL` lève une `SecurityError` | Le canvas est « tainted » par une image cross-origin | Servir les images depuis la même origine ou utiliser des en-têtes CORS |
| Le contexte WebGL est null | Le navigateur ne supporte pas WebGL ou il est désactivé en CI | Utiliser le flag `--enable-webgl` ou exécuter les tests sur un runner CI avec GPU |
| Le test de capture passe en local mais échoue en CI | Rendu des polices, DPI ou OS différents | Figer l'image Docker, utiliser la config `fonts`, ou augmenter le seuil |

## Voir aussi

- [core/assertions-and-waiting.md](assertions-and-waiting.md) -- assertions avec retry automatique et options de comparaison visuelle
- [core/configuration.md](configuration.md) -- configurer les seuils de capture d'écran et mettre à jour les références
- [core/iframes-and-shadow-dom.md](iframes-and-shadow-dom.md) -- éléments canvas à l'intérieur d'iframes
- [core/debugging.md](debugging.md) -- déboguer les échecs de régression visuelle avec le trace viewer
