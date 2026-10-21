# Performance Testing

> **Quand l'utiliser** : mesurer et faire respecter les Web Vitals, les temps de chargement des ressources, les tailles de bundle et la performance à l'exécution. Utilise Playwright pour détecter les régressions de performance en CI avant que les utilisateurs ne les remarquent.
> **Prérequis** : [core/configuration.md](configuration.md), [core/assertions-and-waiting.md](assertions-and-waiting.md)

## Référence rapide

```typescript
// Measure Largest Contentful Paint (LCP)
const lcp = await page.evaluate(() => {
  return new Promise<number>((resolve) => {
    new PerformanceObserver((list) => {
      const entries = list.getEntries();
      resolve(entries[entries.length - 1].startTime);
    }).observe({ type: 'largest-contentful-paint', buffered: true });
  });
});
expect(lcp).toBeLessThan(2500); // Good LCP threshold

// Throttle network to 3G
const client = await page.context().newCDPSession(page);
await client.send('Network.emulateNetworkConditions', {
  offline: false, downloadThroughput: 1.6 * 1024 * 1024 / 8,
  uploadThroughput: 750 * 1024 / 8, latency: 150,
});
```

## Patterns

### Mesure des Web Vitals (LCP, CLS, FID/INP)

**À utiliser quand** : tu fais respecter les seuils des Core Web Vitals dans ta suite de tests.
**À éviter quand** : tu n'as besoin que de données de terrain agrégées -- utilise plutôt Chrome UX Report ou des outils de RUM.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('Core Web Vitals meet thresholds on homepage', async ({ page }) => {
  // Inject Web Vitals observer before navigation
  await page.addInitScript(() => {
    (window as any).__webVitals = { lcp: 0, cls: 0, fid: 0 };

    new PerformanceObserver((list) => {
      const entries = list.getEntries();
      (window as any).__webVitals.lcp = entries[entries.length - 1].startTime;
    }).observe({ type: 'largest-contentful-paint', buffered: true });

    new PerformanceObserver((list) => {
      let clsValue = 0;
      for (const entry of list.getEntries()) {
        if (!(entry as any).hadRecentInput) {
          clsValue += (entry as any).value;
        }
      }
      (window as any).__webVitals.cls = clsValue;
    }).observe({ type: 'layout-shift', buffered: true });

    new PerformanceObserver((list) => {
      const entries = list.getEntries();
      (window as any).__webVitals.fid = entries[0]?.processingStart - entries[0]?.startTime;
    }).observe({ type: 'first-input', buffered: true });
  });

  await page.goto('/');

  // Trigger a user interaction to measure FID
  await page.getByRole('button', { name: 'Get started' }).click();

  // Wait for LCP to settle
  await page.waitForTimeout(1000); // Acceptable here: waiting for metric to finalize

  const vitals = await page.evaluate(() => (window as any).__webVitals);

  expect(vitals.lcp).toBeLessThan(2500);   // Good: <2.5s
  expect(vitals.cls).toBeLessThan(0.1);    // Good: <0.1
  // FID may be 0 in automated tests due to no real user delay
  if (vitals.fid > 0) {
    expect(vitals.fid).toBeLessThan(100);  // Good: <100ms
  }
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('LCP meets threshold on homepage', async ({ page }) => {
  await page.addInitScript(() => {
    window.__lcp = 0;
    new PerformanceObserver((list) => {
      const entries = list.getEntries();
      window.__lcp = entries[entries.length - 1].startTime;
    }).observe({ type: 'largest-contentful-paint', buffered: true });
  });

  await page.goto('/');
  await page.waitForTimeout(1000);

  const lcp = await page.evaluate(() => window.__lcp);
  expect(lcp).toBeLessThan(2500);
});
```

### Accès à la Performance API

**À utiliser quand** : tu mesures le navigation timing, le chargement des ressources ou des performance marks custom.
**À éviter quand** : les Web Vitals suffisent à couvrir ton besoin.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('page load timing is within budget', async ({ page }) => {
  await page.goto('/dashboard');

  const timing = await page.evaluate(() => {
    const nav = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
    return {
      dns: nav.domainLookupEnd - nav.domainLookupStart,
      tcp: nav.connectEnd - nav.connectStart,
      ttfb: nav.responseStart - nav.requestStart,
      domContentLoaded: nav.domContentLoadedEventEnd - nav.startTime,
      loadComplete: nav.loadEventEnd - nav.startTime,
      domInteractive: nav.domInteractive - nav.startTime,
    };
  });

  expect(timing.ttfb).toBeLessThan(600);           // TTFB under 600ms
  expect(timing.domContentLoaded).toBeLessThan(2000); // DOM ready under 2s
  expect(timing.loadComplete).toBeLessThan(5000);     // Full load under 5s
});

test('critical API calls complete within budget', async ({ page }) => {
  await page.goto('/dashboard');

  const apiTimings = await page.evaluate(() => {
    return performance
      .getEntriesByType('resource')
      .filter((r) => r.name.includes('/api/'))
      .map((r) => ({
        name: r.name.split('/api/')[1],
        duration: r.duration,
        size: (r as PerformanceResourceTiming).transferSize,
      }));
  });

  for (const api of apiTimings) {
    expect(api.duration, `API ${api.name} too slow`).toBeLessThan(1000);
  }
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('page load timing is within budget', async ({ page }) => {
  await page.goto('/dashboard');

  const timing = await page.evaluate(() => {
    const nav = performance.getEntriesByType('navigation')[0];
    return {
      ttfb: nav.responseStart - nav.requestStart,
      domContentLoaded: nav.domContentLoadedEventEnd - nav.startTime,
      loadComplete: nav.loadEventEnd - nav.startTime,
    };
  });

  expect(timing.ttfb).toBeLessThan(600);
  expect(timing.domContentLoaded).toBeLessThan(2000);
  expect(timing.loadComplete).toBeLessThan(5000);
});
```

### Surveillance du chargement des ressources et de la taille des bundles

**À utiliser quand** : tu fais respecter des budgets de taille de bundle et détectes les grosses ressources inattendues.
**À éviter quand** : l'analyse des bundles est déjà couverte par webpack-bundle-analyzer ou un outil de build équivalent.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('JavaScript bundle sizes are within budget', async ({ page }) => {
  const resourceSizes: { name: string; size: number }[] = [];

  page.on('response', async (response) => {
    const url = response.url();
    if (url.endsWith('.js') || url.includes('.js?')) {
      const headers = response.headers();
      const size = parseInt(headers['content-length'] || '0');
      resourceSizes.push({
        name: url.split('/').pop()!.split('?')[0],
        size,
      });
    }
  });

  await page.goto('/');
  await page.waitForLoadState('networkidle');

  // No single JS bundle should exceed 250KB compressed
  for (const resource of resourceSizes) {
    expect(
      resource.size,
      `Bundle ${resource.name} is ${(resource.size / 1024).toFixed(1)}KB`
    ).toBeLessThan(250 * 1024);
  }

  // Total JS payload should not exceed 500KB
  const totalSize = resourceSizes.reduce((sum, r) => sum + r.size, 0);
  expect(totalSize, `Total JS: ${(totalSize / 1024).toFixed(1)}KB`).toBeLessThan(500 * 1024);
});

test('no unexpected large images', async ({ page }) => {
  const largeImages: { url: string; size: number }[] = [];

  page.on('response', async (response) => {
    const contentType = response.headers()['content-type'] || '';
    if (contentType.startsWith('image/')) {
      const size = parseInt(response.headers()['content-length'] || '0');
      if (size > 200 * 1024) {
        largeImages.push({ url: response.url(), size });
      }
    }
  });

  await page.goto('/');
  await page.waitForLoadState('networkidle');

  expect(
    largeImages,
    `Found ${largeImages.length} images over 200KB: ${largeImages.map(i => i.url).join(', ')}`
  ).toHaveLength(0);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('JavaScript bundle sizes are within budget', async ({ page }) => {
  const resourceSizes = [];

  page.on('response', async (response) => {
    const url = response.url();
    if (url.endsWith('.js') || url.includes('.js?')) {
      const size = parseInt(response.headers()['content-length'] || '0');
      resourceSizes.push({ name: url.split('/').pop().split('?')[0], size });
    }
  });

  await page.goto('/');
  await page.waitForLoadState('networkidle');

  const totalSize = resourceSizes.reduce((sum, r) => sum + r.size, 0);
  expect(totalSize).toBeLessThan(500 * 1024);
});
```

### Simulation d'un réseau lent via CDP

**À utiliser quand** : tu testes le comportement et la performance de ton app sous des conditions réseau contraintes.
**À éviter quand** : l'option `offline` intégrée à Playwright suffit pour ton test.

**TypeScript**
```typescript
import { test, expect, type Page } from '@playwright/test';

// Network presets
const NETWORK_PRESETS = {
  slow3G: {
    offline: false,
    downloadThroughput: (500 * 1024) / 8,  // 500 Kbps
    uploadThroughput: (500 * 1024) / 8,
    latency: 400,
  },
  fast3G: {
    offline: false,
    downloadThroughput: (1.6 * 1024 * 1024) / 8,  // 1.6 Mbps
    uploadThroughput: (750 * 1024) / 8,
    latency: 150,
  },
  regularLTE: {
    offline: false,
    downloadThroughput: (4 * 1024 * 1024) / 8,  // 4 Mbps
    uploadThroughput: (3 * 1024 * 1024) / 8,
    latency: 20,
  },
} as const;

async function throttleNetwork(page: Page, preset: keyof typeof NETWORK_PRESETS) {
  const client = await page.context().newCDPSession(page);
  await client.send('Network.enable');
  await client.send('Network.emulateNetworkConditions', NETWORK_PRESETS[preset]);
  return client;
}

test('app shows loading states on slow network', async ({ page }) => {
  await throttleNetwork(page, 'slow3G');

  await page.goto('/dashboard');

  // Loading skeleton should appear while content loads slowly
  await expect(page.getByTestId('loading-skeleton')).toBeVisible();

  // Content should eventually load
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible({ timeout: 30000 });
});

test('images lazy-load on slow connection', async ({ page }) => {
  await throttleNetwork(page, 'fast3G');
  await page.goto('/gallery');

  // Only above-the-fold images should be loaded initially
  const loadedImages = await page.evaluate(() =>
    Array.from(document.querySelectorAll('img'))
      .filter((img) => img.complete && img.naturalWidth > 0).length
  );

  // Scroll to trigger lazy loading
  await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  await page.waitForTimeout(2000);

  const allLoadedImages = await page.evaluate(() =>
    Array.from(document.querySelectorAll('img'))
      .filter((img) => img.complete && img.naturalWidth > 0).length
  );

  expect(allLoadedImages).toBeGreaterThan(loadedImages);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

async function throttleNetwork(page, preset) {
  const presets = {
    slow3G: { offline: false, downloadThroughput: (500 * 1024) / 8, uploadThroughput: (500 * 1024) / 8, latency: 400 },
    fast3G: { offline: false, downloadThroughput: (1.6 * 1024 * 1024) / 8, uploadThroughput: (750 * 1024) / 8, latency: 150 },
  };
  const client = await page.context().newCDPSession(page);
  await client.send('Network.enable');
  await client.send('Network.emulateNetworkConditions', presets[preset]);
  return client;
}

test('app shows loading states on slow network', async ({ page }) => {
  await throttleNetwork(page, 'slow3G');
  await page.goto('/dashboard');

  await expect(page.getByTestId('loading-skeleton')).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible({ timeout: 30000 });
});
```

### Throttling du CPU via CDP

**À utiliser quand** : tu simules des appareils peu puissants pour tester la fluidité des animations, la réactivité des interactions ou les calculs lourds.
**À éviter quand** : le goulot d'étranglement est le réseau, pas le CPU.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('animations remain smooth under CPU throttling', async ({ page }) => {
  const client = await page.context().newCDPSession(page);

  // 4x slowdown simulates a mid-tier mobile device
  await client.send('Emulation.setCPUThrottlingRate', { rate: 4 });

  await page.goto('/animations-demo');
  await page.getByRole('button', { name: 'Start animation' }).click();

  // Measure frame rate during animation
  const fps = await page.evaluate(() => {
    return new Promise<number>((resolve) => {
      let frames = 0;
      const start = performance.now();
      function count() {
        frames++;
        if (performance.now() - start < 1000) {
          requestAnimationFrame(count);
        } else {
          resolve(frames);
        }
      }
      requestAnimationFrame(count);
    });
  });

  // Should maintain at least 30fps even on throttled CPU
  expect(fps).toBeGreaterThan(30);

  // Reset throttling
  await client.send('Emulation.setCPUThrottlingRate', { rate: 1 });
});

test('search input responds quickly under CPU constraint', async ({ page }) => {
  const client = await page.context().newCDPSession(page);
  await client.send('Emulation.setCPUThrottlingRate', { rate: 4 });

  await page.goto('/search');

  const start = Date.now();
  await page.getByRole('textbox', { name: 'Search' }).fill('test query');
  await expect(page.getByRole('listbox')).toBeVisible();
  const elapsed = Date.now() - start;

  // Autocomplete should appear within 500ms even under 4x CPU throttle
  expect(elapsed).toBeLessThan(500);

  await client.send('Emulation.setCPUThrottlingRate', { rate: 1 });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('animations remain smooth under CPU throttling', async ({ page }) => {
  const client = await page.context().newCDPSession(page);
  await client.send('Emulation.setCPUThrottlingRate', { rate: 4 });

  await page.goto('/animations-demo');
  await page.getByRole('button', { name: 'Start animation' }).click();

  const fps = await page.evaluate(() => {
    return new Promise((resolve) => {
      let frames = 0;
      const start = performance.now();
      function count() {
        frames++;
        if (performance.now() - start < 1000) {
          requestAnimationFrame(count);
        } else {
          resolve(frames);
        }
      }
      requestAnimationFrame(count);
    });
  });

  expect(fps).toBeGreaterThan(30);
  await client.send('Emulation.setCPUThrottlingRate', { rate: 1 });
});
```

### Budgets de performance en CI

**À utiliser quand** : tu fais respecter des limites de performance strictes qui bloquent les merges quand les seuils sont dépassés.
**À éviter quand** : la performance varie trop dans l'environnement de CI -- utilise plutôt un suivi de tendance.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// Define budgets in a shared config
const PERFORMANCE_BUDGETS = {
  homepage: {
    lcp: 2500,
    cls: 0.1,
    ttfb: 600,
    totalJsSize: 500 * 1024,
    totalImageSize: 1000 * 1024,
    domContentLoaded: 2000,
  },
  dashboard: {
    lcp: 3000,
    cls: 0.1,
    ttfb: 800,
    totalJsSize: 750 * 1024,
    totalImageSize: 500 * 1024,
    domContentLoaded: 3000,
  },
} as const;

test.describe('performance budgets', () => {
  test('homepage meets performance budget', async ({ page }) => {
    const budget = PERFORMANCE_BUDGETS.homepage;
    let totalJsSize = 0;

    page.on('response', (response) => {
      if (response.url().endsWith('.js') || response.url().includes('.js?')) {
        totalJsSize += parseInt(response.headers()['content-length'] || '0');
      }
    });

    // Inject LCP observer
    await page.addInitScript(() => {
      (window as any).__lcp = 0;
      new PerformanceObserver((list) => {
        const entries = list.getEntries();
        (window as any).__lcp = entries[entries.length - 1].startTime;
      }).observe({ type: 'largest-contentful-paint', buffered: true });
    });

    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const metrics = await page.evaluate(() => {
      const nav = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
      return {
        lcp: (window as any).__lcp,
        ttfb: nav.responseStart - nav.requestStart,
        domContentLoaded: nav.domContentLoadedEventEnd - nav.startTime,
      };
    });

    expect(metrics.lcp, 'LCP budget exceeded').toBeLessThan(budget.lcp);
    expect(metrics.ttfb, 'TTFB budget exceeded').toBeLessThan(budget.ttfb);
    expect(metrics.domContentLoaded, 'DOMContentLoaded budget exceeded').toBeLessThan(budget.domContentLoaded);
    expect(totalJsSize, 'JS bundle budget exceeded').toBeLessThan(budget.totalJsSize);
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

const PERFORMANCE_BUDGETS = {
  homepage: { lcp: 2500, ttfb: 600, totalJsSize: 500 * 1024, domContentLoaded: 2000 },
};

test('homepage meets performance budget', async ({ page }) => {
  const budget = PERFORMANCE_BUDGETS.homepage;
  let totalJsSize = 0;

  page.on('response', (response) => {
    if (response.url().endsWith('.js')) {
      totalJsSize += parseInt(response.headers()['content-length'] || '0');
    }
  });

  await page.addInitScript(() => {
    window.__lcp = 0;
    new PerformanceObserver((list) => {
      const entries = list.getEntries();
      window.__lcp = entries[entries.length - 1].startTime;
    }).observe({ type: 'largest-contentful-paint', buffered: true });
  });

  await page.goto('/');
  await page.waitForLoadState('networkidle');

  const metrics = await page.evaluate(() => {
    const nav = performance.getEntriesByType('navigation')[0];
    return {
      lcp: window.__lcp,
      ttfb: nav.responseStart - nav.requestStart,
      domContentLoaded: nav.domContentLoadedEventEnd - nav.startTime,
    };
  });

  expect(metrics.lcp).toBeLessThan(budget.lcp);
  expect(metrics.ttfb).toBeLessThan(budget.ttfb);
  expect(totalJsSize).toBeLessThan(budget.totalJsSize);
});
```

## Guide de décision

| Quoi mesurer | Technique | Quand l'utiliser |
|---|---|---|
| LCP, CLS, FID/INP | `PerformanceObserver` via `addInitScript` | Tests de régression des Core Web Vitals |
| TTFB, temps de chargement du DOM | `performance.getEntriesByType('navigation')` | Budgets de réponse serveur et de chargement de page |
| Durée des appels API | `performance.getEntriesByType('resource')` | Régression de performance backend |
| Tailles des bundles JS/CSS | `page.on('response')` + header `content-length` | Budgets de taille de bundle en CI |
| Comportement sur réseau lent | CDP `Network.emulateNetworkConditions` | Tester les états de chargement, le lazy loading, le mode hors ligne |
| Comportement sur appareil bas de gamme | CDP `Emulation.setCPUThrottlingRate` | Fluidité des animations, latence des interactions |
| Audit Lighthouse complet | `@playwright/test` + Lighthouse CLI via le port CDP | Score de performance exhaustif |
| Performance à l'exécution | `page.evaluate` + comptage de FPS avec `requestAnimationFrame` | Performance des animations et du rendu |

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| Fixer des seuils absolus à partir de la machine de dev locale | Les machines de CI sont plus lentes ; les seuils oscillent | Calibrer les budgets sur le matériel de CI ou utiliser des comparaisons relatives |
| Utiliser `networkidle` comme point de mesure de performance | `networkidle` inclut analytics, publicités et ressources non critiques | Mesurer directement des métriques précises (LCP, TTFB) via la Performance API |
| Lancer les tests de performance avec `--headed` en CI | Le mode headed ajoute une charge GPU et de l'incohérence | Utiliser le mode headless pour une mesure cohérente |
| Mesurer le FID dans des tests automatisés | Il n'y a aucun délai d'entrée utilisateur réel en automatisation | Mesurer l'INP ou utiliser Lighthouse pour estimer le FID |
| Lancer les tests de perf en parallèle d'autres jobs de CI | La contention CPU fausse les résultats | Lancer les tests de performance isolément ou sur des runners CI dédiés |
| Ignorer un `content-length` à `0` | Les réponses compressées peuvent ne pas indiquer leur taille | Utiliser `response.body().length` pour la taille réellement transférée |
| Ne tester que la performance du cas nominal | Les chemins d'erreur lents dégradent l'expérience utilisateur | Tester la performance des états d'erreur, des états vides et des gros jeux de données |
| Faire échouer la CI durement sur de petites régressions | Crée des frictions de merge pour des changements sans rapport avec la performance | Utiliser des seuils d'alerte avec revue obligatoire, n'échouer que sur de grosses régressions |

## Dépannage

| Symptôme | Cause probable | Correctif |
|---|---|---|
| Le LCP vaut 0 ou est anormalement bas | L'observer ne s'est pas déclenché ; la page n'a aucun élément LCP éligible | Vérifie que la page contient des images ou de gros blocs de texte ; ajoute `buffered: true` à l'observer |
| Le CLS vaut toujours 0 | Les layout shifts surviennent avant l'enregistrement de l'observer | Utilise `addInitScript` pour injecter l'observer avant le chargement de la page |
| Erreurs de session CDP avec Firefox/WebKit | CDP est réservé à Chromium | Protège le code CDP : `test.skip(browserName !== 'chromium')` |
| Les chiffres de performance varient énormément d'un run à l'autre | La charge de la machine de CI fluctue | Lance les tests de performance plusieurs fois et prends la médiane ; utilise des runners dédiés |
| Le header `content-length` est absent | Le serveur utilise le chunked transfer encoding | Utilise `response.body()` puis vérifie avec `Buffer.byteLength()` |
| Le throttling réseau n'a aucun effet | La session CDP a été créée sur la mauvaise page | Crée la session CDP depuis le contexte de la page, pas depuis un navigateur séparé |
| Le test de taille de bundle passe mais l'app paraît lente | Mesure de la taille compressée, pas de la taille parsée | Vérifie aussi `performance.getEntriesByType('resource')` pour `decodedBodySize` |

## Voir aussi

- [core/configuration.md](configuration.md) -- réglages de timeout et de retry pour les tests sensibles à la performance
- [core/network-mocking.md](network-mocking.md) -- mocker des API lentes pour tester les limites de performance
- [core/browser-apis.md](browser-apis.md) -- utiliser les API du navigateur pour la mesure
- [ci/ci-github-actions.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/ci-github-actions.md) -- configuration CI pour les budgets de performance
- [core/clock-and-time-mocking.md](clock-and-time-mocking.md) -- tests de performance liés au temps
