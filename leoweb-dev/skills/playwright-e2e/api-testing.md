# Tests d'API

> **Quand l'utiliser** : Tester directement des API REST ou GraphQL : valider des endpoints, injecter des données de test ou vérifier le comportement du backend sans le surcoût d'un navigateur.
> **Prérequis** : [core/configuration.md](configuration.md) pour la configuration de `baseURL`, [core/fixtures-and-hooks.md](fixtures-and-hooks.md) pour les patterns de fixtures personnalisés.

## Référence rapide

```typescript
// Standalone API test — no browser launched
import { test, expect } from '@playwright/test';

test('GET /api/users returns user list', async ({ request }) => {
  const response = await request.get('/api/users');
  expect(response.status()).toBe(200);
  expect(response.headers()['content-type']).toContain('application/json');
  const body = await response.json();
  expect(body.users).toHaveLength(3);
  expect(body.users[0]).toMatchObject({ id: expect.any(Number), email: expect.any(String) });
});
```

## Patterns

### Les bases d'APIRequestContext

**Quand l'utiliser** : Faire des requêtes HTTP dans n'importe quel test : GET, POST, PUT, PATCH, DELETE avec en-têtes, paramètres de requête et corps de requête.
**À éviter quand** : Tu dois tester des réponses rendues par le navigateur (redirections, cookies posés via `Set-Cookie` avec `HttpOnly`). Utilise plutôt un test navigateur.

Le fixture `request` fournit un `APIRequestContext` préconfiguré qui hérite de `baseURL` depuis ta config. Aucun navigateur n'est lancé.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('CRUD operations via API', async ({ request }) => {
  // GET with query parameters
  const listResponse = await request.get('/api/users', {
    params: { page: 1, limit: 10, role: 'admin' },
  });
  expect(listResponse.ok()).toBeTruthy();

  // POST with JSON body
  const createResponse = await request.post('/api/users', {
    data: {
      name: 'Jane Doe',
      email: 'jane@example.com',
      role: 'editor',
    },
  });
  expect(createResponse.status()).toBe(201);
  const created = await createResponse.json();

  // PUT — full replacement
  const updateResponse = await request.put(`/api/users/${created.id}`, {
    data: {
      name: 'Jane Smith',
      email: 'jane.smith@example.com',
      role: 'editor',
    },
  });
  expect(updateResponse.ok()).toBeTruthy();

  // PATCH — partial update
  const patchResponse = await request.patch(`/api/users/${created.id}`, {
    data: { role: 'admin' },
  });
  expect(patchResponse.ok()).toBeTruthy();
  const patched = await patchResponse.json();
  expect(patched.role).toBe('admin');

  // DELETE
  const deleteResponse = await request.delete(`/api/users/${created.id}`);
  expect(deleteResponse.status()).toBe(204);

  // Verify deletion
  const getDeleted = await request.get(`/api/users/${created.id}`);
  expect(getDeleted.status()).toBe(404);
});

test('custom headers and auth tokens', async ({ request }) => {
  const response = await request.get('/api/protected/resource', {
    headers: {
      'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIs...',
      'X-Request-ID': 'test-correlation-id-123',
      'Accept': 'application/json',
    },
  });
  expect(response.ok()).toBeTruthy();
});

test('form-urlencoded body', async ({ request }) => {
  const response = await request.post('/api/oauth/token', {
    form: {
      grant_type: 'client_credentials',
      client_id: 'my-app',
      client_secret: 'secret-value',
    },
  });
  expect(response.ok()).toBeTruthy();
  const token = await response.json();
  expect(token).toHaveProperty('access_token');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('CRUD operations via API', async ({ request }) => {
  const listResponse = await request.get('/api/users', {
    params: { page: 1, limit: 10, role: 'admin' },
  });
  expect(listResponse.ok()).toBeTruthy();

  const createResponse = await request.post('/api/users', {
    data: {
      name: 'Jane Doe',
      email: 'jane@example.com',
      role: 'editor',
    },
  });
  expect(createResponse.status()).toBe(201);
  const created = await createResponse.json();

  const updateResponse = await request.put(`/api/users/${created.id}`, {
    data: {
      name: 'Jane Smith',
      email: 'jane.smith@example.com',
      role: 'editor',
    },
  });
  expect(updateResponse.ok()).toBeTruthy();

  const patchResponse = await request.patch(`/api/users/${created.id}`, {
    data: { role: 'admin' },
  });
  expect(patchResponse.ok()).toBeTruthy();

  const deleteResponse = await request.delete(`/api/users/${created.id}`);
  expect(deleteResponse.status()).toBe(204);
});

test('form-urlencoded body', async ({ request }) => {
  const response = await request.post('/api/oauth/token', {
    form: {
      grant_type: 'client_credentials',
      client_id: 'my-app',
      client_secret: 'secret-value',
    },
  });
  expect(response.ok()).toBeTruthy();
  const token = await response.json();
  expect(token).toHaveProperty('access_token');
});
```

### Réponses typées et timing des requêtes (Playwright 1.62 à 1.63)

**Réponses typées (1.63+)** — passe un argument de type pour que le corps parsé soit typé au point d'appel plutôt que casté après coup :

```typescript
const response = await request.get<User>('/api/users/42');
const user = await response.json(); // typed as User
```

C'est uniquement un confort à la compilation. L'argument de type ne valide **pas** le payload à l'exécution : une réponse qui ne correspond pas à `User` est parsée sans broncher et échoue plus tard, à un endroit moins évident. Pour faire respecter un contrat, garde une vérification de schéma à l'exécution ; voir [Validation de schéma](#validation-de-schéma) plus bas.

**Timing des ressources (1.62+)** — `apiResponse.timing()` renvoie les informations de timing de la requête :

```javascript
const response = await request.get('/api/orders');
const timing = response.timing();
```

Utile pour repérer une régression de latence dans un test d'API existant plutôt que de monter une suite de performance séparée. Considère les chiffres d'une seule requête comme bruités et assert sur des plafonds généreux, pas sur des fourchettes serrées, sinon tu as simplement troqué un test d'UI flaky contre un test de timing flaky. Voir [core/performance-testing.md](performance-testing.md).

### Gérer les cookies de requête (Playwright 1.64+)

**Avant la 1.64**, les cookies d'un `APIRequestContext` ne pouvaient être injectés que via `storageState` à la création ou en construisant à la main les en-têtes `Cookie`. La **1.64** ajoute `addCookies()`, `cookies()` et `clearCookies()`, qui reflètent les méthodes de `BrowserContext` :

```javascript
await request.addCookies([{ name: 'session-id', value: '42', url: 'https://example.com' }]);
console.log(await request.cookies('https://example.com'));
await request.clearCookies({ name: 'session-id' });
```

Usages pratiques : vérifier qu'un endpoint de login a bien posé le cookie de session, tester le cas d'une session expirée en supprimant un cookie en cours de test, ou basculer des cookies de feature flag entre deux appels sans créer de nouveau contexte.

### Structure des tests d'API

**Quand l'utiliser** : Écrire des suites de tests d'API dédiées qui n'ont pas besoin de navigateur.
**À éviter quand** : Tu dois vérifier l'état de l'UI après un appel d'API : utilise un test combiné avec les fixtures `page` et `request`.

Structure les tests d'API dans leur propre répertoire, avec des blocs `describe` explicites par ressource ou par domaine.

**TypeScript**
```typescript
// tests/api/users.spec.ts
import { test, expect } from '@playwright/test';

// No browser is launched — these tests use only the request fixture
test.describe('Users API', () => {
  test.describe('GET /api/users', () => {
    test('returns paginated user list', async ({ request }) => {
      const response = await request.get('/api/users', {
        params: { page: 1, limit: 5 },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      expect(body.users.length).toBeLessThanOrEqual(5);
      expect(body.pagination).toMatchObject({
        page: 1,
        limit: 5,
        total: expect.any(Number),
      });
    });

    test('filters by role', async ({ request }) => {
      const response = await request.get('/api/users', {
        params: { role: 'admin' },
      });
      const body = await response.json();
      for (const user of body.users) {
        expect(user.role).toBe('admin');
      }
    });
  });

  test.describe('POST /api/users', () => {
    test('creates a new user with valid data', async ({ request }) => {
      const response = await request.post('/api/users', {
        data: { name: 'Test User', email: `test-${Date.now()}@example.com` },
      });
      expect(response.status()).toBe(201);
      const user = await response.json();
      expect(user).toMatchObject({
        id: expect.any(Number),
        name: 'Test User',
      });
    });

    test('rejects duplicate email', async ({ request }) => {
      const email = `dupe-${Date.now()}@example.com`;
      await request.post('/api/users', { data: { name: 'First', email } });

      const response = await request.post('/api/users', {
        data: { name: 'Second', email },
      });
      expect(response.status()).toBe(409);
      const body = await response.json();
      expect(body.error).toContain('already exists');
    });
  });
});
```

**JavaScript**
```javascript
// tests/api/users.spec.js
const { test, expect } = require('@playwright/test');

test.describe('Users API', () => {
  test.describe('GET /api/users', () => {
    test('returns paginated user list', async ({ request }) => {
      const response = await request.get('/api/users', {
        params: { page: 1, limit: 5 },
      });
      expect(response.status()).toBe(200);
      const body = await response.json();
      expect(body.users.length).toBeLessThanOrEqual(5);
      expect(body.pagination).toMatchObject({
        page: 1,
        limit: 5,
        total: expect.any(Number),
      });
    });
  });

  test.describe('POST /api/users', () => {
    test('creates a new user with valid data', async ({ request }) => {
      const response = await request.post('/api/users', {
        data: { name: 'Test User', email: `test-${Date.now()}@example.com` },
      });
      expect(response.status()).toBe(201);
      const user = await response.json();
      expect(user).toMatchObject({
        id: expect.any(Number),
        name: 'Test User',
      });
    });
  });
});
```

**Astuce de config** : utilise un projet dédié aux tests d'API pour éviter de lancer des navigateurs.

```typescript
// playwright.config.ts — API project runs without a browser
import { defineConfig } from '@playwright/test';

export default defineConfig({
  projects: [
    {
      name: 'api',
      testDir: './tests/api',
      use: {
        baseURL: 'https://api.example.com',
        extraHTTPHeaders: {
          'Accept': 'application/json',
        },
      },
    },
    {
      name: 'e2e',
      testDir: './tests/e2e',
      use: {
        baseURL: 'https://app.example.com',
        browserName: 'chromium',
      },
    },
  ],
});
```

### Fixtures de requête

**Quand l'utiliser** : Plusieurs tests ont besoin d'un client d'API authentifié, ou tu veux partager la configuration des requêtes (en-têtes, URL de base, tokens d'authentification) dans une suite de tests.
**À éviter quand** : Un seul test fait des appels d'API ponctuels. Utilise directement le fixture `request` intégré.

**TypeScript**
```typescript
// fixtures/api-fixtures.ts
import { test as base, expect, APIRequestContext } from '@playwright/test';

type ApiFixtures = {
  authenticatedRequest: APIRequestContext;
  adminRequest: APIRequestContext;
};

export const test = base.extend<ApiFixtures>({
  authenticatedRequest: async ({ playwright }, use) => {
    // Create a fresh context with auth headers
    const context = await playwright.request.newContext({
      baseURL: 'https://api.example.com',
      extraHTTPHeaders: {
        'Authorization': `Bearer ${process.env.API_TOKEN}`,
        'Accept': 'application/json',
      },
    });
    await use(context);
    await context.dispose();
  },

  adminRequest: async ({ playwright }, use) => {
    // Login via API to get a token, then create authenticated context
    const loginContext = await playwright.request.newContext({
      baseURL: 'https://api.example.com',
    });
    const loginResponse = await loginContext.post('/api/auth/login', {
      data: {
        email: process.env.ADMIN_EMAIL,
        password: process.env.ADMIN_PASSWORD,
      },
    });
    expect(loginResponse.ok()).toBeTruthy();
    const { token } = await loginResponse.json();
    await loginContext.dispose();

    const context = await playwright.request.newContext({
      baseURL: 'https://api.example.com',
      extraHTTPHeaders: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/json',
      },
    });
    await use(context);
    await context.dispose();
  },
});

export { expect };
```

```typescript
// tests/api/admin.spec.ts
import { test, expect } from '../../fixtures/api-fixtures';

test('admin can list all users', async ({ adminRequest }) => {
  const response = await adminRequest.get('/api/admin/users');
  expect(response.status()).toBe(200);
  const body = await response.json();
  expect(body.users.length).toBeGreaterThan(0);
});

test('admin can delete a user', async ({ adminRequest }) => {
  // Create then delete
  const createResp = await adminRequest.post('/api/users', {
    data: { name: 'To Delete', email: `del-${Date.now()}@example.com` },
  });
  const { id } = await createResp.json();

  const deleteResp = await adminRequest.delete(`/api/users/${id}`);
  expect(deleteResp.status()).toBe(204);
});
```

**JavaScript**
```javascript
// fixtures/api-fixtures.js
const { test: base, expect } = require('@playwright/test');

const test = base.extend({
  authenticatedRequest: async ({ playwright }, use) => {
    const context = await playwright.request.newContext({
      baseURL: 'https://api.example.com',
      extraHTTPHeaders: {
        'Authorization': `Bearer ${process.env.API_TOKEN}`,
        'Accept': 'application/json',
      },
    });
    await use(context);
    await context.dispose();
  },

  adminRequest: async ({ playwright }, use) => {
    const loginContext = await playwright.request.newContext({
      baseURL: 'https://api.example.com',
    });
    const loginResponse = await loginContext.post('/api/auth/login', {
      data: {
        email: process.env.ADMIN_EMAIL,
        password: process.env.ADMIN_PASSWORD,
      },
    });
    expect(loginResponse.ok()).toBeTruthy();
    const { token } = await loginResponse.json();
    await loginContext.dispose();

    const context = await playwright.request.newContext({
      baseURL: 'https://api.example.com',
      extraHTTPHeaders: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/json',
      },
    });
    await use(context);
    await context.dispose();
  },
});

module.exports = { test, expect };
```

```javascript
// tests/api/admin.spec.js
const { test, expect } = require('../../fixtures/api-fixtures');

test('admin can list all users', async ({ adminRequest }) => {
  const response = await adminRequest.get('/api/admin/users');
  expect(response.status()).toBe(200);
  const body = await response.json();
  expect(body.users.length).toBeGreaterThan(0);
});
```

### Assertions sur les réponses JSON

**Quand l'utiliser** : Valider le statut, les en-têtes et la structure du corps après chaque appel d'API.
**À éviter quand** : Ne jamais s'en passer. Chaque test d'API doit asserter sur le statut et sur le corps.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('thorough response validation', async ({ request }) => {
  const response = await request.get('/api/users/42');

  // Status code — always check first
  expect(response.status()).toBe(200);

  // Status category — ok() checks 200-299 range
  expect(response.ok()).toBeTruthy();

  // Response headers
  expect(response.headers()['content-type']).toContain('application/json');
  expect(response.headers()['x-request-id']).toBeDefined();
  expect(response.headers()['cache-control']).toMatch(/max-age=\d+/);

  // TLS and connection details (Playwright 1.61+ — mirrors the browser-side APIs)
  const security = await response.securityDetails();  // protocol, issuer, validity
  expect(security?.protocol).toBe('TLS 1.3');
  const addr = await response.serverAddr();           // { ipAddress, port } actually hit
  expect(addr?.port).toBe(443);

  // Full body parse and deep assertion
  const user = await response.json();

  // Exact match on known fields
  expect(user.id).toBe(42);
  expect(user.name).toBe('Jane Doe');
  expect(user.email).toBe('jane@example.com');

  // Partial match — ignore fields you don't care about
  expect(user).toMatchObject({
    id: 42,
    name: 'Jane Doe',
    role: expect.stringMatching(/^(admin|editor|viewer)$/),
  });

  // Type checks with expect.any()
  expect(user).toMatchObject({
    id: expect.any(Number),
    name: expect.any(String),
    createdAt: expect.any(String),
    permissions: expect.any(Array),
  });

  // Array content
  expect(user.permissions).toEqual(
    expect.arrayContaining(['read', 'write'])
  );
  expect(user.permissions).not.toContain('delete');

  // Nested object assertions
  expect(user.profile).toMatchObject({
    avatar: expect.stringMatching(/^https:\/\//),
    bio: expect.any(String),
  });

  // Date format validation
  expect(new Date(user.createdAt).toISOString()).toBe(user.createdAt);
});

test('list response structure', async ({ request }) => {
  const response = await request.get('/api/users');
  const body = await response.json();

  // Array length
  expect(body.users).toHaveLength(10);

  // Every item in array matches shape
  for (const user of body.users) {
    expect(user).toMatchObject({
      id: expect.any(Number),
      name: expect.any(String),
      email: expect.stringContaining('@'),
    });
  }

  // Pagination metadata
  expect(body.pagination).toEqual({
    page: 1,
    limit: 10,
    total: expect.any(Number),
    totalPages: expect.any(Number),
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('thorough response validation', async ({ request }) => {
  const response = await request.get('/api/users/42');

  expect(response.status()).toBe(200);
  expect(response.ok()).toBeTruthy();
  expect(response.headers()['content-type']).toContain('application/json');

  const user = await response.json();

  expect(user).toMatchObject({
    id: 42,
    name: 'Jane Doe',
    role: expect.stringMatching(/^(admin|editor|viewer)$/),
  });

  expect(user).toMatchObject({
    id: expect.any(Number),
    name: expect.any(String),
    createdAt: expect.any(String),
    permissions: expect.any(Array),
  });

  expect(user.permissions).toEqual(
    expect.arrayContaining(['read', 'write'])
  );
});

test('list response structure', async ({ request }) => {
  const response = await request.get('/api/users');
  const body = await response.json();

  expect(body.users).toHaveLength(10);
  for (const user of body.users) {
    expect(user).toMatchObject({
      id: expect.any(Number),
      name: expect.any(String),
      email: expect.stringContaining('@'),
    });
  }
});
```

### Tests GraphQL

**Quand l'utiliser** : Ton backend expose une API GraphQL et tu veux tester les queries, les mutations, les variables et la gestion des erreurs.
**À éviter quand** : Ton API est purement REST. Utilise plutôt les méthodes HTTP standard.

Toutes les requêtes GraphQL passent par `POST` vers un endpoint unique. Envoie `query`, `variables` et éventuellement `operationName` dans le corps JSON.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

const GRAPHQL_ENDPOINT = '/graphql';

test.describe('GraphQL API', () => {
  test('query with variables', async ({ request }) => {
    const response = await request.post(GRAPHQL_ENDPOINT, {
      data: {
        query: `
          query GetUser($id: ID!) {
            user(id: $id) {
              id
              name
              email
              posts {
                id
                title
              }
            }
          }
        `,
        variables: { id: '42' },
      },
    });

    expect(response.ok()).toBeTruthy();
    const { data, errors } = await response.json();

    // GraphQL returns 200 even on errors — always check both
    expect(errors).toBeUndefined();
    expect(data.user).toMatchObject({
      id: '42',
      name: expect.any(String),
      email: expect.stringContaining('@'),
    });
    expect(data.user.posts).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: expect.any(String), title: expect.any(String) }),
      ])
    );
  });

  test('mutation creates a resource', async ({ request }) => {
    const response = await request.post(GRAPHQL_ENDPOINT, {
      data: {
        query: `
          mutation CreatePost($input: CreatePostInput!) {
            createPost(input: $input) {
              id
              title
              status
              author {
                id
              }
            }
          }
        `,
        variables: {
          input: {
            title: 'API Testing with Playwright',
            body: 'A comprehensive guide...',
            status: 'DRAFT',
          },
        },
      },
    });

    const { data, errors } = await response.json();
    expect(errors).toBeUndefined();
    expect(data.createPost).toMatchObject({
      id: expect.any(String),
      title: 'API Testing with Playwright',
      status: 'DRAFT',
    });
  });

  test('handles GraphQL validation errors', async ({ request }) => {
    const response = await request.post(GRAPHQL_ENDPOINT, {
      data: {
        query: `
          mutation CreatePost($input: CreatePostInput!) {
            createPost(input: $input) {
              id
            }
          }
        `,
        variables: {
          input: { title: '' }, // invalid: empty title
        },
      },
    });

    // GraphQL often returns 200 even for validation errors
    const { data, errors } = await response.json();
    expect(errors).toBeDefined();
    expect(errors.length).toBeGreaterThan(0);
    expect(errors[0].message).toContain('title');
    expect(errors[0].extensions?.code).toBe('BAD_USER_INPUT');
  });

  test('handles authorization errors', async ({ request }) => {
    const response = await request.post(GRAPHQL_ENDPOINT, {
      data: {
        query: `
          query AdminDashboard {
            adminStats {
              totalRevenue
              activeUsers
            }
          }
        `,
      },
      // No auth header
    });

    const { data, errors } = await response.json();
    expect(errors).toBeDefined();
    expect(errors[0].extensions?.code).toBe('UNAUTHORIZED');
    expect(data?.adminStats).toBeNull();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

const GRAPHQL_ENDPOINT = '/graphql';

test.describe('GraphQL API', () => {
  test('query with variables', async ({ request }) => {
    const response = await request.post(GRAPHQL_ENDPOINT, {
      data: {
        query: `
          query GetUser($id: ID!) {
            user(id: $id) {
              id
              name
              email
            }
          }
        `,
        variables: { id: '42' },
      },
    });

    const { data, errors } = await response.json();
    expect(errors).toBeUndefined();
    expect(data.user).toMatchObject({
      id: '42',
      name: expect.any(String),
      email: expect.stringContaining('@'),
    });
  });

  test('mutation creates a resource', async ({ request }) => {
    const response = await request.post(GRAPHQL_ENDPOINT, {
      data: {
        query: `
          mutation CreatePost($input: CreatePostInput!) {
            createPost(input: $input) {
              id
              title
              status
            }
          }
        `,
        variables: {
          input: {
            title: 'API Testing with Playwright',
            body: 'A comprehensive guide...',
            status: 'DRAFT',
          },
        },
      },
    });

    const { data, errors } = await response.json();
    expect(errors).toBeUndefined();
    expect(data.createPost).toMatchObject({
      id: expect.any(String),
      title: 'API Testing with Playwright',
      status: 'DRAFT',
    });
  });

  test('handles GraphQL validation errors', async ({ request }) => {
    const response = await request.post(GRAPHQL_ENDPOINT, {
      data: {
        query: `
          mutation CreatePost($input: CreatePostInput!) {
            createPost(input: $input) { id }
          }
        `,
        variables: { input: { title: '' } },
      },
    });

    const { data, errors } = await response.json();
    expect(errors).toBeDefined();
    expect(errors.length).toBeGreaterThan(0);
    expect(errors[0].message).toContain('title');
  });
});
```

### Injection de données via l'API

**Quand l'utiliser** : Les tests E2E ont besoin que des données précises existent avant de s'exécuter. L'injection via l'API est 10 à 100 fois plus rapide qu'une préparation via l'UI.
**À éviter quand** : Le test valide précisément le parcours de création via l'UI. Injecte tout *sauf* ce que tu testes.

**TypeScript**
```typescript
import { test as base, expect, APIRequestContext } from '@playwright/test';

// Fixture that seeds data via API before each test
type SeedFixtures = {
  seedUser: { id: number; email: string; password: string };
  seedProject: { id: number; name: string };
};

export const test = base.extend<SeedFixtures>({
  seedUser: async ({ request }, use) => {
    const email = `user-${Date.now()}@example.com`;
    const password = 'TestPass123!';

    // Create via API
    const response = await request.post('/api/users', {
      data: { name: 'Test User', email, password },
    });
    expect(response.ok()).toBeTruthy();
    const user = await response.json();

    // Pass to test
    await use({ id: user.id, email, password });

    // Cleanup after test — always delete what you created
    await request.delete(`/api/users/${user.id}`);
  },

  seedProject: async ({ request, seedUser }, use) => {
    const response = await request.post('/api/projects', {
      data: { name: `Test Project ${Date.now()}`, ownerId: seedUser.id },
    });
    expect(response.ok()).toBeTruthy();
    const project = await response.json();

    await use({ id: project.id, name: project.name });

    await request.delete(`/api/projects/${project.id}`);
  },
});

export { expect };
```

```typescript
// tests/e2e/project-dashboard.spec.ts
import { test, expect } from '../../fixtures/seed-fixtures';

test('user sees their project on dashboard', async ({ page, seedUser, seedProject }) => {
  // Login via UI (or use storageState for speed)
  await page.goto('/login');
  await page.getByLabel('Email').fill(seedUser.email);
  await page.getByLabel('Password').fill(seedUser.password);
  await page.getByRole('button', { name: 'Sign in' }).click();

  // Data already exists — go straight to assertion
  await page.waitForURL('/dashboard');
  await expect(page.getByRole('heading', { name: seedProject.name })).toBeVisible();
});
```

**JavaScript**
```javascript
// fixtures/seed-fixtures.js
const { test: base, expect } = require('@playwright/test');

const test = base.extend({
  seedUser: async ({ request }, use) => {
    const email = `user-${Date.now()}@example.com`;
    const password = 'TestPass123!';

    const response = await request.post('/api/users', {
      data: { name: 'Test User', email, password },
    });
    expect(response.ok()).toBeTruthy();
    const user = await response.json();

    await use({ id: user.id, email, password });

    await request.delete(`/api/users/${user.id}`);
  },

  seedProject: async ({ request, seedUser }, use) => {
    const response = await request.post('/api/projects', {
      data: { name: `Test Project ${Date.now()}`, ownerId: seedUser.id },
    });
    expect(response.ok()).toBeTruthy();
    const project = await response.json();

    await use({ id: project.id, name: project.name });

    await request.delete(`/api/projects/${project.id}`);
  },
});

module.exports = { test, expect };
```

```javascript
// tests/e2e/project-dashboard.spec.js
const { test, expect } = require('../../fixtures/seed-fixtures');

test('user sees their project on dashboard', async ({ page, seedUser, seedProject }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill(seedUser.email);
  await page.getByLabel('Password').fill(seedUser.password);
  await page.getByRole('button', { name: 'Sign in' }).click();

  await page.waitForURL('/dashboard');
  await expect(page.getByRole('heading', { name: seedProject.name })).toBeVisible();
});
```

### Validation de schéma

**Quand l'utiliser** : Vérifier que les réponses de l'API respectent un contrat : types des champs, champs obligatoires, contraintes sur les valeurs. Détecte tôt les régressions du backend.
**À éviter quand** : Tu n'as qu'un ou deux champs précis à vérifier. Utilise plutôt `toMatchObject`.

#### Option A : Zod (recommandé pour les projets TypeScript)

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';
import { z } from 'zod';

// Define schemas once, reuse across tests
const UserSchema = z.object({
  id: z.number().positive(),
  name: z.string().min(1),
  email: z.string().email(),
  role: z.enum(['admin', 'editor', 'viewer']),
  createdAt: z.string().datetime(),
  profile: z.object({
    avatar: z.string().url().nullable(),
    bio: z.string().max(500),
  }),
});

const PaginatedUsersSchema = z.object({
  users: z.array(UserSchema),
  pagination: z.object({
    page: z.number().int().positive(),
    limit: z.number().int().positive(),
    total: z.number().int().nonnegative(),
  }),
});

test('GET /api/users matches schema', async ({ request }) => {
  const response = await request.get('/api/users');
  expect(response.ok()).toBeTruthy();

  const body = await response.json();
  const result = PaginatedUsersSchema.safeParse(body);

  if (!result.success) {
    // Detailed error output showing exactly which fields failed
    throw new Error(
      `Schema validation failed:\n${result.error.issues
        .map((i) => `  ${i.path.join('.')}: ${i.message}`)
        .join('\n')}`
    );
  }
});

test('POST /api/users returns valid user', async ({ request }) => {
  const response = await request.post('/api/users', {
    data: { name: 'Schema Test', email: `schema-${Date.now()}@example.com` },
  });

  const body = await response.json();
  // Throws with detailed path info if validation fails
  UserSchema.parse(body);
});
```

#### Option B : vérifications de type manuelles (sans dépendance)

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

function assertUserShape(user: unknown): void {
  expect(user).toBeDefined();
  expect(user).toMatchObject({
    id: expect.any(Number),
    name: expect.any(String),
    email: expect.any(String),
    role: expect.any(String),
    createdAt: expect.any(String),
  });

  const u = user as Record<string, unknown>;
  // Value constraints
  expect(['admin', 'editor', 'viewer']).toContain(u.role);
  expect(typeof u.email === 'string' && u.email.includes('@')).toBe(true);
  expect(new Date(u.createdAt as string).toString()).not.toBe('Invalid Date');
}

test('response matches expected shape', async ({ request }) => {
  const response = await request.get('/api/users/1');
  expect(response.ok()).toBeTruthy();

  const body = await response.json();
  assertUserShape(body);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

function assertUserShape(user) {
  expect(user).toBeDefined();
  expect(user).toMatchObject({
    id: expect.any(Number),
    name: expect.any(String),
    email: expect.any(String),
    role: expect.any(String),
    createdAt: expect.any(String),
  });
  expect(['admin', 'editor', 'viewer']).toContain(user.role);
  expect(user.email).toContain('@');
  expect(new Date(user.createdAt).toString()).not.toBe('Invalid Date');
}

test('response matches expected shape', async ({ request }) => {
  const response = await request.get('/api/users/1');
  expect(response.ok()).toBeTruthy();

  const body = await response.json();
  assertUserShape(body);
});
```

### Tests des réponses d'erreur

**Quand l'utiliser** : Toute API a des chemins d'erreur. Teste-les. Un test 401 manquant aujourd'hui est une faille de sécurité demain.
**À éviter quand** : Ne jamais faire l'impasse sur les tests d'erreur.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('Error responses', () => {
  test('400 — validation error with details', async ({ request }) => {
    const response = await request.post('/api/users', {
      data: { name: '', email: 'not-an-email' }, // invalid
    });
    expect(response.status()).toBe(400);

    const body = await response.json();
    expect(body).toMatchObject({
      error: 'Validation Error',
      details: expect.any(Array),
    });
    // Check individual field errors
    expect(body.details).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ field: 'name', message: expect.any(String) }),
        expect.objectContaining({ field: 'email', message: expect.any(String) }),
      ])
    );
  });

  test('401 — missing authentication', async ({ request }) => {
    // Create a fresh context with NO auth headers
    const response = await request.get('/api/protected/resource', {
      headers: { 'Authorization': '' }, // explicitly clear
    });
    expect(response.status()).toBe(401);

    const body = await response.json();
    expect(body.error).toMatch(/unauthorized|unauthenticated/i);
  });

  test('403 — insufficient permissions', async ({ request }) => {
    // Assuming `request` is authenticated as a viewer
    const response = await request.delete('/api/admin/users/1');
    expect(response.status()).toBe(403);

    const body = await response.json();
    expect(body.error).toMatch(/forbidden|insufficient permissions/i);
  });

  test('404 — resource not found', async ({ request }) => {
    const response = await request.get('/api/users/999999');
    expect(response.status()).toBe(404);

    const body = await response.json();
    expect(body).toMatchObject({
      error: expect.stringMatching(/not found/i),
    });
  });

  test('409 — conflict on duplicate resource', async ({ request }) => {
    const email = `conflict-${Date.now()}@example.com`;
    await request.post('/api/users', {
      data: { name: 'First', email },
    });

    const response = await request.post('/api/users', {
      data: { name: 'Duplicate', email },
    });
    expect(response.status()).toBe(409);
  });

  test('422 — unprocessable entity', async ({ request }) => {
    const response = await request.post('/api/orders', {
      data: { items: [] }, // empty cart
    });
    expect(response.status()).toBe(422);
    const body = await response.json();
    expect(body.error).toContain('at least one item');
  });

  test('429 — rate limiting', async ({ request }) => {
    // Send rapid requests to trigger rate limit
    const responses = await Promise.all(
      Array.from({ length: 50 }, () =>
        request.get('/api/search', { params: { q: 'test' } })
      )
    );
    const rateLimited = responses.filter((r) => r.status() === 429);
    expect(rateLimited.length).toBeGreaterThan(0);

    // Verify rate limit headers
    const limited = rateLimited[0];
    expect(limited.headers()['retry-after']).toBeDefined();
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('Error responses', () => {
  test('400 — validation error with details', async ({ request }) => {
    const response = await request.post('/api/users', {
      data: { name: '', email: 'not-an-email' },
    });
    expect(response.status()).toBe(400);

    const body = await response.json();
    expect(body).toMatchObject({
      error: 'Validation Error',
      details: expect.any(Array),
    });
    expect(body.details).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ field: 'name', message: expect.any(String) }),
        expect.objectContaining({ field: 'email', message: expect.any(String) }),
      ])
    );
  });

  test('401 — missing authentication', async ({ request }) => {
    const response = await request.get('/api/protected/resource', {
      headers: { 'Authorization': '' },
    });
    expect(response.status()).toBe(401);
  });

  test('404 — resource not found', async ({ request }) => {
    const response = await request.get('/api/users/999999');
    expect(response.status()).toBe(404);
  });

  test('409 — conflict on duplicate resource', async ({ request }) => {
    const email = `conflict-${Date.now()}@example.com`;
    await request.post('/api/users', { data: { name: 'First', email } });

    const response = await request.post('/api/users', {
      data: { name: 'Duplicate', email },
    });
    expect(response.status()).toBe(409);
  });
});
```

### Upload de fichier via l'API

**Quand l'utiliser** : Tester des endpoints d'upload de fichiers avec des données multipart : upload de documents, traitement d'images, imports CSV.
**À éviter quand** : Tu dois tester la boîte de dialogue du sélecteur de fichiers du navigateur. Utilise `page.setInputFiles()` dans un test E2E à la place.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';
import path from 'path';
import fs from 'fs';

test('upload a file via multipart form data', async ({ request }) => {
  const filePath = path.resolve('tests/fixtures/test-document.pdf');

  const response = await request.post('/api/documents/upload', {
    multipart: {
      file: {
        name: 'test-document.pdf',
        mimeType: 'application/pdf',
        buffer: fs.readFileSync(filePath),
      },
      description: 'Quarterly report',
      category: 'reports',
    },
  });

  expect(response.status()).toBe(201);
  const body = await response.json();
  expect(body).toMatchObject({
    id: expect.any(String),
    filename: 'test-document.pdf',
    mimeType: 'application/pdf',
    size: expect.any(Number),
    url: expect.stringMatching(/^https:\/\//),
  });
});

test('upload an image with metadata', async ({ request }) => {
  const imagePath = path.resolve('tests/fixtures/avatar.png');

  const response = await request.post('/api/users/42/avatar', {
    multipart: {
      image: {
        name: 'avatar.png',
        mimeType: 'image/png',
        buffer: fs.readFileSync(imagePath),
      },
      crop: JSON.stringify({ x: 0, y: 0, width: 200, height: 200 }),
    },
  });

  expect(response.ok()).toBeTruthy();
  const body = await response.json();
  expect(body.avatarUrl).toMatch(/\.png$/);
});

test('upload multiple files', async ({ request }) => {
  const files = ['report-q1.csv', 'report-q2.csv'].map((name) => ({
    name,
    mimeType: 'text/csv',
    buffer: fs.readFileSync(path.resolve(`tests/fixtures/${name}`)),
  }));

  // Send sequential uploads when the API does not support batch
  const results = [];
  for (const file of files) {
    const response = await request.post('/api/imports/csv', {
      multipart: { file },
    });
    expect(response.ok()).toBeTruthy();
    results.push(await response.json());
  }
  expect(results).toHaveLength(2);
});

test('rejects oversized files', async ({ request }) => {
  // Create a buffer that exceeds the server limit
  const largeBuffer = Buffer.alloc(11 * 1024 * 1024); // 11MB

  const response = await request.post('/api/documents/upload', {
    multipart: {
      file: {
        name: 'large-file.bin',
        mimeType: 'application/octet-stream',
        buffer: largeBuffer,
      },
    },
  });

  expect(response.status()).toBe(413); // Payload Too Large
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');
const path = require('path');
const fs = require('fs');

test('upload a file via multipart form data', async ({ request }) => {
  const filePath = path.resolve('tests/fixtures/test-document.pdf');

  const response = await request.post('/api/documents/upload', {
    multipart: {
      file: {
        name: 'test-document.pdf',
        mimeType: 'application/pdf',
        buffer: fs.readFileSync(filePath),
      },
      description: 'Quarterly report',
      category: 'reports',
    },
  });

  expect(response.status()).toBe(201);
  const body = await response.json();
  expect(body).toMatchObject({
    id: expect.any(String),
    filename: 'test-document.pdf',
    mimeType: 'application/pdf',
    size: expect.any(Number),
  });
});

test('rejects oversized files', async ({ request }) => {
  const largeBuffer = Buffer.alloc(11 * 1024 * 1024);

  const response = await request.post('/api/documents/upload', {
    multipart: {
      file: {
        name: 'large-file.bin',
        mimeType: 'application/octet-stream',
        buffer: largeBuffer,
      },
    },
  });

  expect(response.status()).toBe(413);
});
```

### Appels d'API enchaînés

**Quand l'utiliser** : Tester des workflows en plusieurs étapes : séquences création, lecture, mise à jour, suppression ; parcours de commande ; transitions de machine à états. Cela vérifie le comportement de l'API comme un système intégré, pas seulement des endpoints isolés.
**À éviter quand** : Tu peux tester chaque endpoint isolément et que les interactions sont triviales.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('complete order workflow', async ({ request }) => {
  // Step 1: Create a product
  const productResp = await request.post('/api/products', {
    data: { name: 'Widget', price: 29.99, stock: 100 },
  });
  expect(productResp.status()).toBe(201);
  const product = await productResp.json();

  // Step 2: Create a cart
  const cartResp = await request.post('/api/carts', {
    data: { items: [{ productId: product.id, quantity: 2 }] },
  });
  expect(cartResp.status()).toBe(201);
  const cart = await cartResp.json();
  expect(cart.total).toBe(59.98);

  // Step 3: Checkout — create an order from the cart
  const orderResp = await request.post('/api/orders', {
    data: {
      cartId: cart.id,
      shippingAddress: {
        street: '123 Test St',
        city: 'Testville',
        zip: '12345',
      },
    },
  });
  expect(orderResp.status()).toBe(201);
  const order = await orderResp.json();
  expect(order.status).toBe('pending');
  expect(order.items).toHaveLength(1);
  expect(order.total).toBe(59.98);

  // Step 4: Verify order appears in user's order list
  const ordersResp = await request.get('/api/orders');
  const orders = await ordersResp.json();
  expect(orders.items.map((o: any) => o.id)).toContain(order.id);

  // Step 5: Verify product stock decreased
  const updatedProduct = await (await request.get(`/api/products/${product.id}`)).json();
  expect(updatedProduct.stock).toBe(98); // 100 - 2

  // Cleanup
  await request.delete(`/api/orders/${order.id}`);
  await request.delete(`/api/products/${product.id}`);
});

test('state machine transitions — publish workflow', async ({ request }) => {
  // Create a draft post
  const createResp = await request.post('/api/posts', {
    data: { title: 'Draft Post', body: 'Content here.' },
  });
  const post = await createResp.json();
  expect(post.status).toBe('draft');

  // Submit for review
  const reviewResp = await request.patch(`/api/posts/${post.id}/status`, {
    data: { status: 'in_review' },
  });
  expect(reviewResp.ok()).toBeTruthy();
  expect((await reviewResp.json()).status).toBe('in_review');

  // Approve (requires admin — use appropriate fixture in real tests)
  const approveResp = await request.patch(`/api/posts/${post.id}/status`, {
    data: { status: 'published' },
  });
  expect(approveResp.ok()).toBeTruthy();
  expect((await approveResp.json()).status).toBe('published');

  // Verify: cannot go back to draft from published
  const revertResp = await request.patch(`/api/posts/${post.id}/status`, {
    data: { status: 'draft' },
  });
  expect(revertResp.status()).toBe(422);

  // Cleanup
  await request.delete(`/api/posts/${post.id}`);
});

test('API + E2E hybrid — seed via API, verify in browser', async ({ request, page }) => {
  // Seed test data via API
  const resp = await request.post('/api/products', {
    data: {
      name: `Hybrid Test Product ${Date.now()}`,
      price: 42.00,
      published: true,
    },
  });
  const product = await resp.json();

  // Verify via browser
  await page.goto('/products');
  await expect(
    page.getByRole('heading', { name: product.name })
  ).toBeVisible();
  await expect(page.getByText('$42.00')).toBeVisible();

  // Cleanup via API
  await request.delete(`/api/products/${product.id}`);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('complete order workflow', async ({ request }) => {
  const productResp = await request.post('/api/products', {
    data: { name: 'Widget', price: 29.99, stock: 100 },
  });
  expect(productResp.status()).toBe(201);
  const product = await productResp.json();

  const cartResp = await request.post('/api/carts', {
    data: { items: [{ productId: product.id, quantity: 2 }] },
  });
  expect(cartResp.status()).toBe(201);
  const cart = await cartResp.json();
  expect(cart.total).toBe(59.98);

  const orderResp = await request.post('/api/orders', {
    data: {
      cartId: cart.id,
      shippingAddress: {
        street: '123 Test St',
        city: 'Testville',
        zip: '12345',
      },
    },
  });
  expect(orderResp.status()).toBe(201);
  const order = await orderResp.json();
  expect(order.status).toBe('pending');

  const ordersResp = await request.get('/api/orders');
  const orders = await ordersResp.json();
  expect(orders.items.map((o) => o.id)).toContain(order.id);

  await request.delete(`/api/orders/${order.id}`);
  await request.delete(`/api/products/${product.id}`);
});

test('API + E2E hybrid — seed via API, verify in browser', async ({ request, page }) => {
  const resp = await request.post('/api/products', {
    data: {
      name: `Hybrid Test Product ${Date.now()}`,
      price: 42.00,
      published: true,
    },
  });
  const product = await resp.json();

  await page.goto('/products');
  await expect(
    page.getByRole('heading', { name: product.name })
  ).toBeVisible();

  await request.delete(`/api/products/${product.id}`);
});
```

## Guide de décision

| Scénario | Tests d'API | Tests E2E | Pourquoi |
|---|---|---|---|
| Valider statut/corps/en-têtes d'une réponse | Oui | Non | Pas de navigateur nécessaire ; 10 à 100 fois plus rapide |
| Tester la logique métier (calculs, règles) | Oui | Non | Les tests d'API isolent la logique backend de l'UI |
| Vérifier qu'une soumission de formulaire crée les bonnes données | Injection via l'API, soumission via l'UI | Oui | Le test d'UI valide le formulaire ; la vérification via l'API confirme la persistance |
| Tester les messages d'erreur affichés à l'utilisateur | Non | Oui | L'affichage des erreurs relève de l'UI |
| Valider pagination, filtrage, tri | Oui | Peut-être les deux | Test d'API pour la justesse ; test E2E seulement si la logique côté UI est complexe |
| Injecter des données de test pour les tests E2E | Oui (fixture) | Non | L'injection via l'API est rapide et fiable |
| Tester les parcours d'authentification (login/logout/RBAC) | Oui pour la logique de token/session | Oui pour le parcours UI | Les deux comptent : l'API protège les ressources, l'UI guide les utilisateurs |
| Vérifier le traitement d'un upload de fichier | Oui | Seulement si on teste l'UI du sélecteur de fichiers | Le test d'API valide le traitement côté backend |
| Tests de régression de contrat/schéma | Oui | Non | Les tests de schéma s'exécutent en quelques millisecondes |
| Tester la gestion d'un webhook tiers | Oui | Non | Les webhooks sont d'API à API ; aucune UI impliquée |
| Vérifier le comportement de redirection après une action | Non | Oui | Les redirections relèvent du navigateur et de la navigation |
| Tester les mises à jour en temps réel (WebSocket + déclenchement via l'API) | L'API déclenche | L'E2E vérifie | Injecte via l'API, observe dans le navigateur |

## Anti-patterns

| À ne pas faire | Problème | À faire plutôt |
|---|---|---|
| Utiliser des tests E2E pour valider de simples réponses d'API | Lent, flaky, lance un navigateur pour rien | Utilise le fixture `request` : pas de navigateur, HTTP direct |
| Ignorer `response.status()` | Un 500 avec un corps de repli peut passer toutes les assertions sur le corps | Asserte toujours le statut d'abord : `expect(response.status()).toBe(200)` |
| Sauter la vérification des en-têtes de réponse | L'absence de `Content-Type`, `Cache-Control` ou des en-têtes CORS provoque des bugs en production | Asserte les en-têtes critiques : `expect(response.headers()['content-type']).toContain('application/json')` |
| Ne tester que le cas nominal | De vrais utilisateurs déclenchent des 400, 401, 403, 404, 409, 422 : chacun mérite un test | Dédie un bloc `describe` aux réponses d'erreur |
| Coder des IDs en dur dans les tests d'API | Les tests cassent quand la base est réinitialisée ou que les IDs sont réattribués | Crée les ressources dans le test et utilise les IDs retournés |
| Partager un état mutable entre les tests | Les tests qui dépendent de l'ordre d'exécution sont flaky et ne peuvent pas tourner en parallèle | Chaque test crée et nettoie ses propres données |
| Parser `response.text()` puis `JSON.parse()` à la main | `response.json()` de Playwright s'en charge et lève des erreurs claires si le corps n'est pas du JSON | Utilise `await response.json()` |
| Oublier le nettoyage après la création de ressources | Pollution entre tests : les tests suivants peuvent voir des données périmées ou heurter des contraintes d'unicité | Utilise des fixtures avec teardown ou des appels `delete` explicites |
| Tester GraphQL en ne vérifiant que `response.ok()` | GraphQL renvoie 200 même en cas d'erreur : le tableau `errors` est le vrai signal | Vérifie toujours à la fois `data` et `errors` dans le corps de la réponse |
| Utiliser `page.request` quand tu n'as pas besoin de page | `page.request` partage les cookies avec le contexte du navigateur, ce qui peut créer de la confusion d'authentification | Utilise le fixture `request` autonome pour les tests d'API purs |

## Dépannage

### "Request failed: connect ECONNREFUSED 127.0.0.1:3000"

**Cause** : Le serveur d'API n'est pas démarré, ou `baseURL` pointe vers le mauvais hôte/port.

**Solution** :
- Vérifie que le serveur tourne avant les tests : utilise `webServer` dans `playwright.config.ts` pour le démarrer automatiquement.
- Vérifie que `baseURL` dans ta config correspond à l'adresse réelle du serveur.

```typescript
// playwright.config.ts
export default defineConfig({
  webServer: {
    command: 'npm run start:api',
    url: 'http://localhost:3000/api/health',
    reuseExistingServer: !process.env.CI,
  },
  use: {
    baseURL: 'http://localhost:3000',
  },
});
```

### "response.json() failed — body is not valid JSON"

**Cause** : L'endpoint a renvoyé du HTML (page d'erreur), du texte brut ou un corps vide au lieu de JSON.

**Solution** :
- Vérifie d'abord `response.status()` : un 500 ou un 302 renvoie souvent du HTML.
- Logue `await response.text()` pour voir le corps réel.
- Vérifie que l'en-tête `Accept: application/json` est bien défini.

```typescript
const response = await request.get('/api/endpoint');
if (!response.ok()) {
  console.error(`Status: ${response.status()}, Body: ${await response.text()}`);
}
const body = await response.json(); // now you know what failed
```

### "401 Unauthorized" avec le fixture `request`

**Cause** : Le fixture `request` intégré ne transporte pas automatiquement les cookies ni les tokens d'authentification du navigateur. Il part d'une table rase.

**Solution** :
- Définis `extraHTTPHeaders` dans ta config ou crée un fixture authentifié personnalisé.
- Si tu as besoin des cookies d'un login navigateur, utilise `page.request` (qui partage les cookies du contexte du navigateur) plutôt que le fixture `request` autonome.

```typescript
// Option A: config-level headers
export default defineConfig({
  use: {
    extraHTTPHeaders: {
      'Authorization': `Bearer ${process.env.API_TOKEN}`,
    },
  },
});

// Option B: per-request headers
const response = await request.get('/api/resource', {
  headers: { 'Authorization': `Bearer ${token}` },
});

// Option C: use page.request to inherit browser cookies
test('API call with browser auth', async ({ page }) => {
  await page.goto('/login');
  // ... login via UI ...
  const response = await page.request.get('/api/profile');
  expect(response.ok()).toBeTruthy();
});
```

### GraphQL renvoie 200 mais data est null

**Cause** : Les serveurs GraphQL renvoient un HTTP 200 même quand la query contient des erreurs. L'erreur réelle se trouve dans le tableau `errors`.

**Solution** : Déstructure toujours et vérifie à la fois `data` et `errors`.

```typescript
const { data, errors } = await response.json();
if (errors) {
  console.error('GraphQL errors:', JSON.stringify(errors, null, 2));
}
expect(errors).toBeUndefined();
expect(data.user).toBeDefined();
```

### Les tests passent en local mais échouent en CI

**Cause** : Environnements différents, état de la base de données différent ou variables d'environnement manquantes.

**Solution** :
- Utilise `process.env` pour les secrets et les URL de base : ne les code jamais en dur.
- Exécute les seeds ou migrations de base de données dans `globalSetup`.
- Utilise des identifiants uniques (timestamps, UUID) pour les données de test afin d'éviter les collisions lors des exécutions en parallèle.
- Vérifie que le `baseURL` de la CI correspond au service déployé ou conteneurisé.

## Voir aussi

- [core/configuration.md](configuration.md) — configuration de `baseURL`, `extraHTTPHeaders` et `webServer`
- [core/fixtures-and-hooks.md](fixtures-and-hooks.md) — patterns de fixtures personnalisés pour des clients d'API réutilisables
- [core/authentication.md](authentication.md) — patterns d'authentification, y compris l'auth d'API par token
- [core/network-mocking.md](network-mocking.md) — mocker des réponses d'API dans les tests E2E (l'inverse de ce guide)
- [core/test-architecture.md](test-architecture.md) — quand utiliser des tests d'API, E2E ou de composants
- [core/when-to-mock.md](when-to-mock.md) — quand appeler les vraies API et quand les mocker
