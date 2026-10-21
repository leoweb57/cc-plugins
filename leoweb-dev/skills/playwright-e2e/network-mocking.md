# Mock réseau

> **Quand l'utiliser** : isoler ton frontend des services externes, simuler des états d'erreur, tester les UI de chargement/vide/erreur, accélérer les tests en évitant les vrais appels réseau, et tester face à des APIs qui n'existent pas encore.
> **Prérequis** : [core/locators.md](locators.md), [core/assertions-and-waiting.md](assertions-and-waiting.md)

## Référence rapide

```typescript
// Intercept and return fake data
await page.route('**/api/users', (route) =>
  route.fulfill({ json: [{ id: 1, name: 'Jane' }] })
);

// Modify a real response before it reaches the browser
await page.route('**/api/users', async (route) => {
  const response = await route.fetch();
  const json = await response.json();
  json.push({ id: 999, name: 'Injected' });
  await route.fulfill({ response, json });
});

// Block third-party scripts
await page.route('**/*.{png,jpg,svg}', (route) => route.abort());

// Wait for a specific request/response
const responsePromise = page.waitForResponse('**/api/users');
await page.getByRole('button', { name: 'Load' }).click();
await responsePromise;

// HAR replay — serve recorded responses
await page.routeFromHAR('tests/data/api.har', { url: '**/api/**' });
```

## Patterns

### Bases de l'interception de routes

**Utiliser quand** : tu dois intercepter n'importe quelle requête HTTP émise par la page pour y répondre, la modifier ou la bloquer.
**Éviter quand** : tu veux tester la vraie intégration entre frontend et backend (utilise alors de vrais appels API).

`page.route()` enregistre un handler exécuté pour chaque requête correspondant à un pattern d'URL. Chaque handler doit appeler exactement une des méthodes `route.fulfill()`, `route.continue()` ou `route.abort()`.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('route interception basics', async ({ page }) => {
  // Intercept before navigating — routes must be set up first
  await page.route('**/api/users', (route) => {
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([{ id: 1, name: 'Alice' }]),
    });
  });

  await page.goto('/dashboard');
  await expect(page.getByText('Alice')).toBeVisible();

  // Remove the route when done (important for cleanup)
  await page.unroute('**/api/users');
});

test('context-level routes apply to all pages', async ({ context, page }) => {
  // Routes on the context apply to every page in that context
  await context.route('**/api/config', (route) =>
    route.fulfill({ json: { theme: 'dark', locale: 'en' } })
  );

  await page.goto('/settings');
  await expect(page.getByText('Dark')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('route interception basics', async ({ page }) => {
  await page.route('**/api/users', (route) => {
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([{ id: 1, name: 'Alice' }]),
    });
  });

  await page.goto('/dashboard');
  await expect(page.getByText('Alice')).toBeVisible();

  await page.unroute('**/api/users');
});

test('context-level routes apply to all pages', async ({ context, page }) => {
  await context.route('**/api/config', (route) =>
    route.fulfill({ json: { theme: 'dark', locale: 'en' } })
  );

  await page.goto('/settings');
  await expect(page.getByText('Dark')).toBeVisible();
});
```

### Mocker des réponses REST

**Utiliser quand** : ton frontend dépend d'une API REST et tu veux des réponses déterministes et instantanées avec des données maîtrisées.
**Éviter quand** : tu dois vérifier que ton frontend envoie le bon body ou les bons headers à la vraie API (utilise plutôt `route.continue()` avec `waitForRequest`).

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

const mockUsers = [
  { id: 1, name: 'Alice', email: 'alice@example.com', role: 'admin' },
  { id: 2, name: 'Bob', email: 'bob@example.com', role: 'user' },
];

test('mock a GET endpoint with JSON', async ({ page }) => {
  await page.route('**/api/users', (route) =>
    route.fulfill({ json: mockUsers })
  );

  await page.goto('/users');
  await expect(page.getByRole('row')).toHaveCount(3); // header + 2 data rows
});

test('mock a POST endpoint and verify the request', async ({ page }) => {
  await page.route('**/api/users', (route) => {
    if (route.request().method() === 'POST') {
      return route.fulfill({
        status: 201,
        json: { id: 3, name: 'Charlie', email: 'charlie@example.com' },
      });
    }
    // Let other methods through
    return route.continue();
  });

  await page.goto('/users/new');
  await page.getByLabel('Name').fill('Charlie');
  await page.getByLabel('Email').fill('charlie@example.com');
  await page.getByRole('button', { name: 'Create' }).click();

  await expect(page.getByText('Charlie')).toBeVisible();
});

test('mock with custom headers and status', async ({ page }) => {
  await page.route('**/api/users', (route) =>
    route.fulfill({
      status: 200,
      headers: {
        'content-type': 'application/json',
        'x-total-count': '42',
        'x-request-id': 'test-abc-123',
      },
      body: JSON.stringify(mockUsers),
    })
  );

  await page.goto('/users');
  await expect(page.getByText('42 total')).toBeVisible();
});

test('mock empty state', async ({ page }) => {
  await page.route('**/api/users', (route) =>
    route.fulfill({ json: [] })
  );

  await page.goto('/users');
  await expect(page.getByText('No users found')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

const mockUsers = [
  { id: 1, name: 'Alice', email: 'alice@example.com', role: 'admin' },
  { id: 2, name: 'Bob', email: 'bob@example.com', role: 'user' },
];

test('mock a GET endpoint with JSON', async ({ page }) => {
  await page.route('**/api/users', (route) =>
    route.fulfill({ json: mockUsers })
  );

  await page.goto('/users');
  await expect(page.getByRole('row')).toHaveCount(3);
});

test('mock a POST endpoint and verify the request', async ({ page }) => {
  await page.route('**/api/users', (route) => {
    if (route.request().method() === 'POST') {
      return route.fulfill({
        status: 201,
        json: { id: 3, name: 'Charlie', email: 'charlie@example.com' },
      });
    }
    return route.continue();
  });

  await page.goto('/users/new');
  await page.getByLabel('Name').fill('Charlie');
  await page.getByLabel('Email').fill('charlie@example.com');
  await page.getByRole('button', { name: 'Create' }).click();

  await expect(page.getByText('Charlie')).toBeVisible();
});

test('mock empty state', async ({ page }) => {
  await page.route('**/api/users', (route) =>
    route.fulfill({ json: [] })
  );

  await page.goto('/users');
  await expect(page.getByText('No users found')).toBeVisible();
});
```

### Mocker GraphQL

**Utiliser quand** : ton frontend utilise GraphQL et tu veux mocker des queries ou mutations précises par nom d'opération.
**Éviter quand** : l'endpoint GraphQL fait partie de ton propre backend et tu veux une couverture d'intégration complète.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('mock a GraphQL query by operation name', async ({ page }) => {
  await page.route('**/graphql', async (route) => {
    const request = route.request();
    const postData = request.postDataJSON();

    if (postData.operationName === 'GetUsers') {
      return route.fulfill({
        json: {
          data: {
            users: [
              { id: '1', name: 'Alice', email: 'alice@example.com' },
              { id: '2', name: 'Bob', email: 'bob@example.com' },
            ],
          },
        },
      });
    }

    if (postData.operationName === 'GetUser') {
      return route.fulfill({
        json: {
          data: {
            user: { id: '1', name: 'Alice', email: 'alice@example.com' },
          },
        },
      });
    }

    // Let unmocked operations through to the real server
    return route.continue();
  });

  await page.goto('/users');
  await expect(page.getByText('Alice')).toBeVisible();
  await expect(page.getByText('Bob')).toBeVisible();
});

test('mock a GraphQL mutation', async ({ page }) => {
  await page.route('**/graphql', async (route) => {
    const { operationName, variables } = route.request().postDataJSON();

    if (operationName === 'CreateUser') {
      return route.fulfill({
        json: {
          data: {
            createUser: {
              id: '99',
              name: variables.input.name,
              email: variables.input.email,
            },
          },
        },
      });
    }

    return route.continue();
  });

  await page.goto('/users/new');
  await page.getByLabel('Name').fill('Charlie');
  await page.getByLabel('Email').fill('charlie@example.com');
  await page.getByRole('button', { name: 'Create' }).click();

  await expect(page.getByText('Charlie')).toBeVisible();
});

test('mock GraphQL errors', async ({ page }) => {
  await page.route('**/graphql', async (route) => {
    const { operationName } = route.request().postDataJSON();

    if (operationName === 'GetUsers') {
      return route.fulfill({
        json: {
          data: null,
          errors: [
            {
              message: 'Not authorized',
              extensions: { code: 'UNAUTHORIZED' },
            },
          ],
        },
      });
    }

    return route.continue();
  });

  await page.goto('/users');
  await expect(page.getByText('Not authorized')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('mock a GraphQL query by operation name', async ({ page }) => {
  await page.route('**/graphql', async (route) => {
    const postData = route.request().postDataJSON();

    if (postData.operationName === 'GetUsers') {
      return route.fulfill({
        json: {
          data: {
            users: [
              { id: '1', name: 'Alice', email: 'alice@example.com' },
              { id: '2', name: 'Bob', email: 'bob@example.com' },
            ],
          },
        },
      });
    }

    return route.continue();
  });

  await page.goto('/users');
  await expect(page.getByText('Alice')).toBeVisible();
  await expect(page.getByText('Bob')).toBeVisible();
});

test('mock a GraphQL mutation', async ({ page }) => {
  await page.route('**/graphql', async (route) => {
    const { operationName, variables } = route.request().postDataJSON();

    if (operationName === 'CreateUser') {
      return route.fulfill({
        json: {
          data: {
            createUser: {
              id: '99',
              name: variables.input.name,
              email: variables.input.email,
            },
          },
        },
      });
    }

    return route.continue();
  });

  await page.goto('/users/new');
  await page.getByLabel('Name').fill('Charlie');
  await page.getByLabel('Email').fill('charlie@example.com');
  await page.getByRole('button', { name: 'Create' }).click();

  await expect(page.getByText('Charlie')).toBeVisible();
});
```

### Modifier des réponses

**Utiliser quand** : tu as besoin de la vraie réponse de l'API mais veux ajuster certains champs -- injecter des données de test, surcharger des feature flags, simuler des cas limites sur des données réelles.
**Éviter quand** : tu peux mocker entièrement la réponse. `route.fetch()` ajoute un vrai aller-retour réseau, donc c'est plus lent.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('modify a real API response', async ({ page }) => {
  await page.route('**/api/users', async (route) => {
    // Fetch the real response from the server
    const response = await route.fetch();
    const users = await response.json();

    // Inject a test user into the real data
    users.push({ id: 999, name: 'Test User', email: 'test@example.com' });

    await route.fulfill({ response, json: users });
  });

  await page.goto('/users');
  await expect(page.getByText('Test User')).toBeVisible();
});

test('override feature flags from real config', async ({ page }) => {
  await page.route('**/api/config', async (route) => {
    const response = await route.fetch();
    const config = await response.json();

    // Enable a feature flag for testing
    config.featureFlags = {
      ...config.featureFlags,
      newCheckout: true,
      darkMode: true,
    };

    await route.fulfill({ response, json: config });
  });

  await page.goto('/settings');
  await expect(page.getByRole('switch', { name: 'Dark mode' })).toBeVisible();
});

test('modify response headers', async ({ page }) => {
  await page.route('**/api/data', async (route) => {
    const response = await route.fetch();

    await route.fulfill({
      response,
      headers: {
        ...response.headers(),
        'cache-control': 'no-cache',
        'x-test-header': 'injected',
      },
    });
  });

  await page.goto('/data');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('modify a real API response', async ({ page }) => {
  await page.route('**/api/users', async (route) => {
    const response = await route.fetch();
    const users = await response.json();

    users.push({ id: 999, name: 'Test User', email: 'test@example.com' });

    await route.fulfill({ response, json: users });
  });

  await page.goto('/users');
  await expect(page.getByText('Test User')).toBeVisible();
});

test('override feature flags from real config', async ({ page }) => {
  await page.route('**/api/config', async (route) => {
    const response = await route.fetch();
    const config = await response.json();

    config.featureFlags = {
      ...config.featureFlags,
      newCheckout: true,
      darkMode: true,
    };

    await route.fulfill({ response, json: config });
  });

  await page.goto('/settings');
  await expect(page.getByRole('switch', { name: 'Dark mode' })).toBeVisible();
});
```

### Blocage de requêtes

**Utiliser quand** : tu bloques les analytics, les publicités, les scripts tiers, les images ou les polices pour accélérer les tests et éliminer le flakiness lié aux dépendances externes.
**Éviter quand** : la ressource bloquée est nécessaire à la fonctionnalité testée.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('block analytics and tracking scripts', async ({ page }) => {
  await page.route(/(google-analytics|segment|hotjar|mixpanel)/, (route) =>
    route.abort()
  );

  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});

test('block images to speed up tests', async ({ page }) => {
  await page.route('**/*.{png,jpg,jpeg,gif,svg,webp}', (route) =>
    route.abort()
  );

  await page.goto('/gallery');
  // Test interactions without waiting for image downloads
  await page.getByRole('button', { name: 'Next' }).click();
});

test('block specific third-party domains', async ({ page }) => {
  const blockedDomains = [
    'ads.example.com',
    'tracker.example.com',
    'cdn.slow-service.com',
  ];

  await page.route('**/*', (route) => {
    const url = new URL(route.request().url());
    if (blockedDomains.includes(url.hostname)) {
      return route.abort();
    }
    return route.continue();
  });

  await page.goto('/home');
});

test('block by resource type', async ({ context }) => {
  // Context-level blocking affects all pages
  await context.route('**/*', (route) => {
    const resourceType = route.request().resourceType();
    if (['image', 'font', 'media'].includes(resourceType)) {
      return route.abort();
    }
    return route.continue();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('block analytics and tracking scripts', async ({ page }) => {
  await page.route(/(google-analytics|segment|hotjar|mixpanel)/, (route) =>
    route.abort()
  );

  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});

test('block images to speed up tests', async ({ page }) => {
  await page.route('**/*.{png,jpg,jpeg,gif,svg,webp}', (route) =>
    route.abort()
  );

  await page.goto('/gallery');
  await page.getByRole('button', { name: 'Next' }).click();
});

test('block by resource type', async ({ context }) => {
  await context.route('**/*', (route) => {
    const resourceType = route.request().resourceType();
    if (['image', 'font', 'media'].includes(resourceType)) {
      return route.abort();
    }
    return route.continue();
  });
});
```

### Enregistrement et rejeu HAR

**Utiliser quand** : tu veux capturer le vrai trafic réseau une fois et le rejouer dans les tests pour gagner en vitesse et en déterminisme. Idéal pour les APIs complexes avec de nombreux endpoints ou quand l'accès à l'API est limité.
**Éviter quand** : les réponses de l'API changent souvent et des enregistrements périmés provoqueraient de faux positifs. Garde les fichiers HAR dans le contrôle de version et mets-les à jour régulièrement.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// Record a HAR file — run once to capture traffic, then replay
test('record HAR for later replay', async ({ page }) => {
  // With update: true, matching requests go to the real network (nothing is
  // served from the HAR) and the file is rewritten with the actual traffic
  // when the context closes.
  await page.routeFromHAR('tests/data/users-api.har', {
    url: '**/api/**',
    update: true, // set to true to record, false (or omit) to replay
  });

  await page.goto('/users');
  await expect(page.getByRole('row')).toHaveCount(6);
});

// Replay from a previously recorded HAR file
test('replay from HAR', async ({ page }) => {
  await page.routeFromHAR('tests/data/users-api.har', {
    url: '**/api/**',
    // update: false is the default — serves from the HAR file
  });

  await page.goto('/users');
  await expect(page.getByRole('row')).toHaveCount(6);
});

// HAR with notFound option — control what happens for unmatched requests
test('HAR replay with fallback behavior', async ({ page }) => {
  await page.routeFromHAR('tests/data/users-api.har', {
    url: '**/api/**',
    notFound: 'abort', // default; 'abort' fails unmatched requests, 'fallback' sends them to the network
  });

  await page.goto('/users');
  await expect(page.getByText('Alice')).toBeVisible();
});

// Context-level HAR replay
test('HAR replay at context level', async ({ context, page }) => {
  await context.routeFromHAR('tests/data/full-app.har', {
    url: '**/api/**',
  });

  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('record HAR for later replay', async ({ page }) => {
  await page.routeFromHAR('tests/data/users-api.har', {
    url: '**/api/**',
    update: true,
  });

  await page.goto('/users');
  await expect(page.getByRole('row')).toHaveCount(6);
});

test('replay from HAR', async ({ page }) => {
  await page.routeFromHAR('tests/data/users-api.har', {
    url: '**/api/**',
  });

  await page.goto('/users');
  await expect(page.getByRole('row')).toHaveCount(6);
});

test('HAR replay with fallback behavior', async ({ page }) => {
  await page.routeFromHAR('tests/data/users-api.har', {
    url: '**/api/**',
    notFound: 'abort',
  });

  await page.goto('/users');
  await expect(page.getByText('Alice')).toBeVisible();
});
```

### Enregistrement HAR à la demande dans le tracing (Playwright 1.60+)

**Utiliser quand** : tu veux capturer le trafic réseau pour une *portion précise* d'un test -- un parcours utilisateur, une étape -- plutôt que pour toute la session, et tu veux démarrer/arrêter l'enregistrement depuis le corps du test.
**Éviter quand** : tu as seulement besoin du rejeu pour mocker (utilise `routeFromHAR`), ou tu veux un HAR pour tout le context (définis `recordHar` à la création du context). Cette API sert à une capture ciblée et programmatique.

Playwright 1.60 élève l'enregistrement HAR au rang d'API de tracing à part entière : `context.tracing.startHar()` / `context.tracing.stopHar()`. Elle prend le chemin du HAR en premier argument, plus les mêmes options `content`, `mode` et `urlFilter` que le `recordHar` au niveau du context, et renvoie un disposable pour que `await using` nettoie automatiquement, même si le test lève une exception.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('capture HAR for the checkout flow only', async ({ context, page }) => {
  await page.goto('/cart');

  // Record only the network traffic during checkout
  await context.tracing.startHar('test-results/checkout.har', {
    urlFilter: '**/api/**',
    content: 'embed', // 'omit' | 'embed' | 'attach'
  });

  await page.getByRole('button', { name: 'Checkout' }).click();
  await page.getByRole('button', { name: 'Place order' }).click();
  await expect(page.getByText('Order confirmed')).toBeVisible();

  await context.tracing.stopHar();
});

test('scoped capture with automatic cleanup', async ({ context, page }) => {
  await page.goto('/search');

  // `await using` stops and flushes the HAR when the block exits — even on failure
  await using _har = await context.tracing.startHar('test-results/search.har', {
    urlFilter: '**/api/search**',
  });

  await page.getByLabel('Search').fill('playwright');
  await page.getByRole('button', { name: 'Search' }).click();
  await expect(page.getByRole('listitem')).not.toHaveCount(0);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('capture HAR for the checkout flow only', async ({ context, page }) => {
  await page.goto('/cart');

  await context.tracing.startHar('test-results/checkout.har', {
    urlFilter: '**/api/**',
    content: 'embed',
  });

  await page.getByRole('button', { name: 'Checkout' }).click();
  await page.getByRole('button', { name: 'Place order' }).click();
  await expect(page.getByText('Order confirmed')).toBeVisible();

  await context.tracing.stopHar();
});
```

> **Note sur `await using`** : la forme disposable nécessite TypeScript 5.2+ ou un runtime avec gestion explicite des ressources. Si ta toolchain ne la supporte pas, appelle plutôt `stopHar()` explicitement dans un bloc `finally`.

### Mock conditionnel

**Utiliser quand** : tu as besoin de réponses différentes selon la méthode, le body, les headers ou les paramètres de requête. Courant pour les APIs paginées, les endpoints de recherche et les accès basés sur les rôles.
**Éviter quand** : un simple mock statique suffit. Ne sur-complique pas les route handlers.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('respond based on request method', async ({ page }) => {
  await page.route('**/api/users', (route) => {
    const method = route.request().method();

    switch (method) {
      case 'GET':
        return route.fulfill({
          json: [{ id: 1, name: 'Alice' }],
        });
      case 'POST':
        return route.fulfill({
          status: 201,
          json: { id: 2, name: 'Bob' },
        });
      case 'DELETE':
        return route.fulfill({ status: 204, body: '' });
      default:
        return route.continue();
    }
  });

  await page.goto('/users');
  await expect(page.getByText('Alice')).toBeVisible();
});

test('respond based on query parameters', async ({ page }) => {
  await page.route('**/api/users*', (route) => {
    const url = new URL(route.request().url());
    const page_num = parseInt(url.searchParams.get('page') || '1');
    const role = url.searchParams.get('role');

    const allUsers = [
      { id: 1, name: 'Alice', role: 'admin' },
      { id: 2, name: 'Bob', role: 'user' },
      { id: 3, name: 'Charlie', role: 'user' },
      { id: 4, name: 'Diana', role: 'admin' },
    ];

    let filtered = allUsers;
    if (role) {
      filtered = allUsers.filter((u) => u.role === role);
    }

    const perPage = 2;
    const start = (page_num - 1) * perPage;
    const paginated = filtered.slice(start, start + perPage);

    return route.fulfill({
      json: paginated,
      headers: {
        'content-type': 'application/json',
        'x-total-count': String(filtered.length),
      },
    });
  });

  await page.goto('/users');
  await expect(page.getByRole('row')).toHaveCount(3); // header + 2 rows
});

test('respond based on request body', async ({ page }) => {
  await page.route('**/api/search', (route) => {
    const body = route.request().postDataJSON();
    const query = body?.query?.toLowerCase() || '';

    const results = {
      playwright: [{ title: 'Playwright Docs' }, { title: 'Playwright GitHub' }],
      cypress: [{ title: 'Cypress Docs' }],
    };

    return route.fulfill({
      json: results[query] || [],
    });
  });

  await page.goto('/search');
  await page.getByLabel('Search').fill('playwright');
  await page.getByRole('button', { name: 'Search' }).click();
  await expect(page.getByRole('listitem')).toHaveCount(2);
});

test('respond based on request headers', async ({ page }) => {
  await page.route('**/api/users', (route) => {
    const authHeader = route.request().headers()['authorization'];

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return route.fulfill({
        status: 401,
        json: { error: 'Unauthorized' },
      });
    }

    return route.fulfill({
      json: [{ id: 1, name: 'Alice' }],
    });
  });

  await page.goto('/login');
  await expect(page.getByText('Unauthorized')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('respond based on request method', async ({ page }) => {
  await page.route('**/api/users', (route) => {
    const method = route.request().method();

    switch (method) {
      case 'GET':
        return route.fulfill({ json: [{ id: 1, name: 'Alice' }] });
      case 'POST':
        return route.fulfill({ status: 201, json: { id: 2, name: 'Bob' } });
      case 'DELETE':
        return route.fulfill({ status: 204, body: '' });
      default:
        return route.continue();
    }
  });

  await page.goto('/users');
  await expect(page.getByText('Alice')).toBeVisible();
});

test('respond based on query parameters', async ({ page }) => {
  await page.route('**/api/users*', (route) => {
    const url = new URL(route.request().url());
    const role = url.searchParams.get('role');

    const allUsers = [
      { id: 1, name: 'Alice', role: 'admin' },
      { id: 2, name: 'Bob', role: 'user' },
      { id: 3, name: 'Charlie', role: 'user' },
    ];

    const filtered = role ? allUsers.filter((u) => u.role === role) : allUsers;

    return route.fulfill({ json: filtered });
  });

  await page.goto('/users?role=admin');
  await expect(page.getByText('Alice')).toBeVisible();
});

test('respond based on request body', async ({ page }) => {
  await page.route('**/api/search', (route) => {
    const body = route.request().postDataJSON();
    const query = body?.query?.toLowerCase() || '';

    const results = {
      playwright: [{ title: 'Playwright Docs' }, { title: 'Playwright GitHub' }],
      cypress: [{ title: 'Cypress Docs' }],
    };

    return route.fulfill({ json: results[query] || [] });
  });

  await page.goto('/search');
  await page.getByLabel('Search').fill('playwright');
  await page.getByRole('button', { name: 'Search' }).click();
  await expect(page.getByRole('listitem')).toHaveCount(2);
});
```

### Simulation d'erreurs réseau

**Utiliser quand** : tu testes comment ton UI gère les erreurs serveur, les timeouts et les échecs de connexion. Indispensable pour vérifier les error boundaries, la logique de retry et l'UX en mode dégradé.
**Éviter quand** : le test porte sur le cas nominal. N'introduis des erreurs que pour tester la gestion d'erreurs.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('simulate a 500 server error', async ({ page }) => {
  await page.route('**/api/users', (route) =>
    route.fulfill({
      status: 500,
      json: { error: 'Internal Server Error' },
    })
  );

  await page.goto('/users');
  await expect(page.getByText('Something went wrong')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Retry' })).toBeVisible();
});

test('simulate a 403 forbidden', async ({ page }) => {
  await page.route('**/api/admin/**', (route) =>
    route.fulfill({
      status: 403,
      json: { error: 'Forbidden', message: 'Admin access required' },
    })
  );

  await page.goto('/admin/settings');
  await expect(page.getByText('Admin access required')).toBeVisible();
});

test('simulate a 404 not found', async ({ page }) => {
  await page.route('**/api/users/999', (route) =>
    route.fulfill({
      status: 404,
      json: { error: 'User not found' },
    })
  );

  await page.goto('/users/999');
  await expect(page.getByText('User not found')).toBeVisible();
});

test('simulate a network error (connection refused)', async ({ page }) => {
  await page.route('**/api/users', (route) =>
    route.abort('connectionrefused')
  );

  await page.goto('/users');
  await expect(page.getByText('Network error')).toBeVisible();
});

test('simulate a timeout', async ({ page }) => {
  await page.route('**/api/users', async (route) => {
    // Delay longer than the app's fetch timeout to trigger a timeout error
    await new Promise((resolve) => setTimeout(resolve, 30_000));
    await route.fulfill({ json: [] });
  });

  await page.goto('/users');
  // The app should show a timeout message before the route resolves
  await expect(page.getByText('Request timed out')).toBeVisible({
    timeout: 15_000,
  });
});

test('simulate intermittent failures then recovery', async ({ page }) => {
  let requestCount = 0;

  await page.route('**/api/users', (route) => {
    requestCount++;
    if (requestCount <= 2) {
      return route.fulfill({
        status: 503,
        json: { error: 'Service Unavailable' },
      });
    }
    return route.fulfill({
      json: [{ id: 1, name: 'Alice' }],
    });
  });

  await page.goto('/users');
  await expect(page.getByText('Something went wrong')).toBeVisible();

  // Simulate user clicking retry (which makes the 3rd request)
  await page.getByRole('button', { name: 'Retry' }).click();
  await expect(page.getByText('Something went wrong')).toBeVisible();

  // Third attempt succeeds
  await page.getByRole('button', { name: 'Retry' }).click();
  await expect(page.getByText('Alice')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('simulate a 500 server error', async ({ page }) => {
  await page.route('**/api/users', (route) =>
    route.fulfill({
      status: 500,
      json: { error: 'Internal Server Error' },
    })
  );

  await page.goto('/users');
  await expect(page.getByText('Something went wrong')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Retry' })).toBeVisible();
});

test('simulate a network error (connection refused)', async ({ page }) => {
  await page.route('**/api/users', (route) =>
    route.abort('connectionrefused')
  );

  await page.goto('/users');
  await expect(page.getByText('Network error')).toBeVisible();
});

test('simulate intermittent failures then recovery', async ({ page }) => {
  let requestCount = 0;

  await page.route('**/api/users', (route) => {
    requestCount++;
    if (requestCount <= 2) {
      return route.fulfill({
        status: 503,
        json: { error: 'Service Unavailable' },
      });
    }
    return route.fulfill({
      json: [{ id: 1, name: 'Alice' }],
    });
  });

  await page.goto('/users');
  await expect(page.getByText('Something went wrong')).toBeVisible();

  await page.getByRole('button', { name: 'Retry' }).click();
  await expect(page.getByText('Something went wrong')).toBeVisible();

  await page.getByRole('button', { name: 'Retry' }).click();
  await expect(page.getByText('Alice')).toBeVisible();
});
```

**Raisons d'abandon** : `'aborted'`, `'accessdenied'`, `'addressunreachable'`, `'blockedbyclient'`, `'blockedbyresponse'`, `'connectionaborted'`, `'connectionclosed'`, `'connectionfailed'`, `'connectionrefused'`, `'connectionreset'`, `'internetdisconnected'`, `'namenotresolved'`, `'timedout'`, `'failed'`.

### Attente de requêtes

**Utiliser quand** : tu synchronises ton test avec l'activité réseau -- en attendant l'envoi d'une requête ou l'arrivée d'une réponse avant de faire des assertions sur l'UI.
**Éviter quand** : une assertion web-first sur un locator suffit. N'attends des requêtes que lorsque tu dois inspecter la requête ou la réponse elle-même.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('wait for response and verify UI updates', async ({ page }) => {
  await page.goto('/users');

  // CRITICAL: set up the wait BEFORE triggering the action
  const responsePromise = page.waitForResponse('**/api/users');
  await page.getByRole('button', { name: 'Refresh' }).click();
  const response = await responsePromise;

  expect(response.status()).toBe(200);
  const users = await response.json();
  expect(users).toHaveLength(5);
});

test('wait for request and verify payload', async ({ page }) => {
  await page.goto('/users/new');

  const requestPromise = page.waitForRequest('**/api/users');
  await page.getByLabel('Name').fill('Alice');
  await page.getByLabel('Email').fill('alice@example.com');
  await page.getByRole('button', { name: 'Create' }).click();
  const request = await requestPromise;

  expect(request.method()).toBe('POST');
  expect(request.postDataJSON()).toMatchObject({
    name: 'Alice',
    email: 'alice@example.com',
  });
});

test('wait for response with predicate function', async ({ page }) => {
  await page.goto('/dashboard');

  // Wait for a specific response matching custom criteria
  const responsePromise = page.waitForResponse(
    (response) =>
      response.url().includes('/api/users') &&
      response.status() === 200 &&
      response.request().method() === 'GET'
  );
  await page.getByRole('button', { name: 'Load users' }).click();
  const response = await responsePromise;

  const data = await response.json();
  expect(data.length).toBeGreaterThan(0);
});

test('wait for multiple requests in sequence', async ({ page }) => {
  await page.goto('/checkout');

  // Wait for multiple API calls that happen during a flow
  const [validateResponse, submitResponse] = await Promise.all([
    page.waitForResponse('**/api/cart/validate'),
    page.waitForResponse('**/api/orders'),
    page.getByRole('button', { name: 'Place order' }).click(),
  ]);

  expect(validateResponse.status()).toBe(200);
  expect(submitResponse.status()).toBe(201);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('wait for response and verify UI updates', async ({ page }) => {
  await page.goto('/users');

  const responsePromise = page.waitForResponse('**/api/users');
  await page.getByRole('button', { name: 'Refresh' }).click();
  const response = await responsePromise;

  expect(response.status()).toBe(200);
  const users = await response.json();
  expect(users).toHaveLength(5);
});

test('wait for request and verify payload', async ({ page }) => {
  await page.goto('/users/new');

  const requestPromise = page.waitForRequest('**/api/users');
  await page.getByLabel('Name').fill('Alice');
  await page.getByLabel('Email').fill('alice@example.com');
  await page.getByRole('button', { name: 'Create' }).click();
  const request = await requestPromise;

  expect(request.method()).toBe('POST');
  expect(request.postDataJSON()).toMatchObject({
    name: 'Alice',
    email: 'alice@example.com',
  });
});

test('wait for multiple requests in sequence', async ({ page }) => {
  await page.goto('/checkout');

  const [validateResponse, submitResponse] = await Promise.all([
    page.waitForResponse('**/api/cart/validate'),
    page.waitForResponse('**/api/orders'),
    page.getByRole('button', { name: 'Place order' }).click(),
  ]);

  expect(validateResponse.status()).toBe(200);
  expect(submitResponse.status()).toBe(201);
});
```

### Patterns glob et correspondance d'URL

**Utiliser quand** : tu dois faire correspondre des URLs avec des jokers, des chemins partiels ou des regex. Chaque `page.route()`, `waitForRequest()` et `waitForResponse()` accepte des patterns glob, des chaînes ou des regex.
**Éviter quand** : l'URL est connue et statique. Utilise la chaîne exacte.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('glob pattern examples', async ({ page }) => {
  // ** matches any path segments (including nested)
  await page.route('**/api/users', (route) =>
    route.fulfill({ json: [] })
  );
  // Matches: https://example.com/api/users
  // Matches: https://example.com/v2/api/users

  // * matches any single path segment
  await page.route('**/api/users/*/orders', (route) =>
    route.fulfill({ json: [] })
  );
  // Matches: /api/users/123/orders
  // Matches: /api/users/abc/orders
  // Does NOT match: /api/users/123/456/orders

  // Match file extensions
  await page.route('**/*.{png,jpg,svg}', (route) => route.abort());
  // Matches: /images/logo.png, /assets/photo.jpg

  // Match query strings with *
  await page.route('**/api/search?q=*', (route) =>
    route.fulfill({ json: [] })
  );
  // Matches: /api/search?q=anything

  // Use regex for complex patterns
  await page.route(/\/api\/users\/\d+$/, (route) =>
    route.fulfill({ json: { id: 1, name: 'Alice' } })
  );
  // Matches: /api/users/123, /api/users/456
  // Does NOT match: /api/users/abc, /api/users/123/orders

  // Regex with captured groups for dynamic responses
  await page.route(/\/api\/users\/(\d+)/, (route) => {
    const match = route.request().url().match(/\/api\/users\/(\d+)/);
    const userId = match ? match[1] : '0';
    return route.fulfill({
      json: { id: parseInt(userId), name: `User ${userId}` },
    });
  });

  await page.goto('/users');
});

test('match all requests on a domain', async ({ page }) => {
  // Block everything from a specific domain
  await page.route('https://analytics.example.com/**', (route) =>
    route.abort()
  );

  await page.goto('/dashboard');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('glob pattern examples', async ({ page }) => {
  // ** matches any path segments
  await page.route('**/api/users', (route) =>
    route.fulfill({ json: [] })
  );

  // * matches a single path segment
  await page.route('**/api/users/*/orders', (route) =>
    route.fulfill({ json: [] })
  );

  // Match file extensions
  await page.route('**/*.{png,jpg,svg}', (route) => route.abort());

  // Regex for complex patterns
  await page.route(/\/api\/users\/\d+$/, (route) =>
    route.fulfill({ json: { id: 1, name: 'Alice' } })
  );

  // Regex with dynamic responses
  await page.route(/\/api\/users\/(\d+)/, (route) => {
    const match = route.request().url().match(/\/api\/users\/(\d+)/);
    const userId = match ? match[1] : '0';
    return route.fulfill({
      json: { id: parseInt(userId), name: `User ${userId}` },
    });
  });

  await page.goto('/users');
});

test('match all requests on a domain', async ({ page }) => {
  await page.route('https://analytics.example.com/**', (route) =>
    route.abort()
  );

  await page.goto('/dashboard');
});
```

**Référence des patterns** :

| Pattern | Correspond à | Ne correspond pas à |
|---|---|---|
| `**/api/users` | `/api/users`, `/v2/api/users` | `/api/users/1` |
| `**/api/users*` | `/api/users`, `/api/users?page=1` | `/api/users/1` |
| `**/api/users/**` | `/api/users/1`, `/api/users/1/orders` | `/api/users` |
| `**/api/users/*/orders` | `/api/users/1/orders` | `/api/users/1/2/orders` |
| `**/*.{png,jpg}` | `/logo.png`, `/deep/path/img.jpg` | `/file.svg` |
| `/\/api\/users\/\d+$/` (regex) | `/api/users/123` | `/api/users/abc` |

## Guide de décision

| Scénario | Utiliser | Pourquoi |
|---|---|---|
| Le frontend dépend d'une API externe | `route.fulfill()` | Données déterministes, aucune dépendance externe, rapide |
| Tester la vraie API en ajustant un champ | `route.fetch()` + modification + `route.fulfill()` | Utilise les données réelles comme base, ne surcharge que le nécessaire |
| Tester le cas nominal avec le vrai backend | `route.continue()` (ou pas de route) | Couverture d'intégration complète |
| Bloquer le bruit des analytics/pubs/services tiers | `route.abort()` | Tests plus rapides, pas de flakiness liée aux services externes |
| API complexe avec de nombreux endpoints | `page.routeFromHAR()` avec `update: true` | Enregistrer une fois, rejouer indéfiniment ; très peu de code de test |
| Tester la gestion d'erreurs (500, timeout) | `route.fulfill({ status: 500 })` ou `route.abort('timedout')` | Simuler les erreurs de façon déterministe |
| Vérifier le payload envoyé par le frontend | `page.waitForRequest()` + assertions | Confirme que le frontend envoie les bonnes données |
| Vérifier les données de réponse avant le contrôle de l'UI | `page.waitForResponse()` + assertions | Confirme que les données arrivent avant d'asserter sur le DOM |
| Plusieurs tests ont besoin du même mock | `context.route()` ou fixture | Partager les routes entre les tests sans répétition |
| Tester les spinners de chargement / skeletons | `route.fulfill()` avec un délai (via `setTimeout`) | Contrôler précisément le timing de la réponse |
| API paginée ou de recherche | Mock conditionnel (vérifier les query params / le body) | Réponses dynamiques selon le contenu de la requête |

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| Mocker les pages et les assets statiques de ta propre application | Tu finis par tester une fausse application, pas la vraie | Ne mocke que les endpoints d'API/de données, jamais le HTML/JS/CSS servi par ton application |
| Écrire les données de mock en dur dans chaque test | Données dupliquées, difficiles à mettre à jour quand l'API change | Extrais les données de mock dans des fixtures partagées (`tests/data/users.json`) |
| Ne jamais mettre à jour les mocks quand l'API change | Les tests passent sur des données périmées ; la vraie application casse | Utilise l'enregistrement HAR avec des exécutions `update: true` périodiques, ou valide la forme des mocks par rapport aux schémas OpenAPI |
| Mocker dans des tests E2E proches de la production | Tu perds la confiance dans l'intégration | Garde une suite de tests séparée avec de vrais backends pour les tests smoke/d'intégration ; ne mocke que dans les tests de composants et les tests d'UI isolés |
| Oublier d'appeler `route.fulfill()`, `route.continue()` ou `route.abort()` | La requête reste bloquée, le test expire avec une erreur peu claire | Chaque route handler doit appeler exactement une des trois méthodes |
| Configurer les routes après `page.goto()` | Les requêtes partent pendant la navigation avant l'enregistrement de la route | Appelle toujours `page.route()` avant `page.goto()` |
| Utiliser `waitForResponse` après l'action déclenchante | Race condition : la réponse peut arriver avant l'enregistrement de l'attente | Crée toujours la promise avant l'action : `const p = page.waitForResponse(...); await click(); await p;` |
| Mocker avec `route.continue()` en croyant que ça mocke | `route.continue()` transmet la requête au vrai serveur | Utilise `route.fulfill()` pour renvoyer de fausses données |
| Des patterns glob trop larges (`**/*`) sans filtrage | Capture toutes les requêtes, y compris HTML, JS, CSS ; casse l'application | Sois précis : `**/api/**` ou filtre par `resourceType()` |
| Oublier `await` sur la configuration ou la réponse d'une route | La route peut ne pas être active au démarrage de la navigation | Fais toujours `await page.route(...)` et `await route.fulfill(...)` |
| Ne pas appeler `page.unroute()` en changeant de mock en cours de test | L'ancien route handler se déclenche encore, le nouveau est ignoré ou les deux se déclenchent | Appelle `page.unroute()` avant d'enregistrer un nouveau handler pour le même pattern |
| Utiliser `page.on('request')` pour mocker | Les event listeners sont en lecture seule ; ils ne peuvent ni modifier ni satisfaire les requêtes | Utilise `page.route()` pour l'interception ; `page.on('request')` uniquement pour le logging |

## Dépannage

### Le route handler ne se déclenche jamais

**Cause** : le pattern d'URL ne correspond pas à l'URL réelle de la requête. Fréquent quand l'URL de base inclut un numéro de port, un préfixe de chemin, ou quand la requête utilise un autre protocole.

**Solution** :
- Logue toutes les requêtes pour trouver l'URL exacte :
```typescript
page.on('request', (req) => console.log(req.method(), req.url()));
```
- Vérifie que le pattern glob correspond. `**/api/users` ne correspond pas à `http://localhost:3000/api/users?page=1` -- utilise `**/api/users*` pour inclure les query strings.
- Vérifie que `page.route()` est appelé avant `page.goto()`.

### Le route handler se déclenche mais le test expire quand même

**Cause** : le handler lève une erreur ou n'appelle jamais `fulfill`/`continue`/`abort`.

**Solution** :
- Ajoute une gestion d'erreurs dans le route handler.
- Assure-toi que chaque chemin de code du handler se termine par l'une des trois méthodes de résolution.
```typescript
await page.route('**/api/users', async (route) => {
  try {
    const data = getTestData(); // this might throw
    await route.fulfill({ json: data });
  } catch (error) {
    console.error('Route handler error:', error);
    await route.abort();
  }
});
```

### La réponse mockée est ignorée -- l'application affiche les vraies données

**Cause** : la route est enregistrée au niveau de la page mais la requête est émise par un service worker ou par un autre browser context.

**Solution** :
- Utilise `context.route()` plutôt que `page.route()` pour couvrir toutes les pages et les service workers.
- Désactive les service workers dans la configuration s'ils interfèrent :
```typescript
// playwright.config.ts
export default defineConfig({
  use: {
    serviceWorkers: 'block',
  },
});
```

### `route.fetch()` provoque une boucle infinie

**Cause** : `route.fetch()` ré-émet la requête, ce qui peut redéclencher le même route handler si le pattern d'URL correspond.

**Solution** : Playwright gère correctement ce cas pour un même route handler -- `route.fetch()` ne ré-entre pas dans le handler qui l'a appelé. Mais si plusieurs route handlers se chevauchent, ils peuvent interférer. Simplifie avec un seul handler par pattern d'URL, ou utilise `route.fetch({ url: 'different-url' })` pour rediriger.

### Le rejeu HAR renvoie de mauvaises réponses

**Cause** : les fichiers HAR font correspondre les requêtes par URL et parfois par body POST. Si le body de la requête change (par ex. timestamps, tokens CSRF), la correspondance échoue.

**Solution** :
- Ré-enregistre le fichier HAR avec `update: true`.
- Utilise `notFound: 'fallback'` pour laisser les requêtes sans correspondance atteindre le vrai serveur.
- Pour les requêtes POST avec des bodies dynamiques, envisage d'utiliser `page.route()` avec une correspondance manuelle plutôt que HAR.

## Voir aussi

- [core/when-to-mock.md](when-to-mock.md) -- cadre de décision pour choisir entre mocker et utiliser de vrais services
- [core/api-testing.md](api-testing.md) -- tester directement les APIs REST et GraphQL (sans navigateur)
- [core/assertions-and-waiting.md](assertions-and-waiting.md) -- assertions web-first et patterns `waitForResponse`
- [core/authentication.md](authentication.md) -- mocker les tokens d'auth et l'état de session
- [core/error-and-edge-cases.md](error-and-edge-cases.md) -- patterns de test des états d'erreur au-delà des erreurs réseau
- [core/service-workers-and-pwa.md](service-workers-and-pwa.md) -- gérer le cache des service workers qui interfère avec les mocks
