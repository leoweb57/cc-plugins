# Gestion des données de test

> **Quand l'utiliser** : Pour tout test qui manipule des données : comptes utilisateurs, saisies de formulaire, entités, ou tout état qui doit exister avant l'exécution des assertions.

## Référence rapide

| Stratégie | Vitesse | Isolation | Complexité | Idéal pour |
|---|---|---|---|---|
| Données inline | Instantanée | Parfaite | Aucune | Vérifications de valeurs simples, saisies de formulaire |
| Factory functions | Instantanée | Parfaite | Faible | Identifiants uniques, structures cohérentes |
| Faker / données aléatoires | Instantanée | Parfaite | Faible | Champs réalistes, découverte de cas limites |
| Pattern Builder | Instantanée | Parfaite | Moyenne | Objets complexes avec de nombreux champs optionnels |
| Seeding via API | Rapide | Parfaite | Moyenne | Création des entités dont l'application dépend |
| Seeding via base de données | Rapide | Bonne | Élevée | Données relationnelles complexes, mise en place en masse |
| Storage state | Rapide | Bonne | Faible | Réutilisation de sessions authentifiées |
| Setup via fixture | Rapide | Parfaite | Moyenne | Encapsuler le setup + un teardown garanti |

**Principe fondamental** : Chaque test crée ses propres données et nettoie après lui. Aucun test ne doit dépendre de données laissées par un autre test ou préexistantes dans l'environnement.

## Patterns

### Données de test inline

**À utiliser quand** : Les données sont simples, propres à un seul test et essentielles pour comprendre l'assertion.

**À éviter quand** : La même structure de données se répète dans de nombreux tests : extrais plutôt une factory.

Les données inline rendent les tests auto-documentés. Le lecteur voit exactement ce qui compte sans courir après les imports.

**TypeScript**
```typescript
// tests/contact-form.spec.ts
import { test, expect } from '@playwright/test';

test('submits contact form with valid data', async ({ page }) => {
  const name = 'Ada Lovelace';
  const email = `ada-${Date.now()}@example.com`;
  const message = 'Inquiry about analytics engine';

  await page.goto('/contact');
  await page.getByLabel('Name').fill(name);
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Message').fill(message);
  await page.getByRole('button', { name: 'Send' }).click();

  await expect(page.getByText('Thank you, Ada Lovelace')).toBeVisible();
});
```

**JavaScript**
```javascript
// tests/contact-form.spec.js
const { test, expect } = require('@playwright/test');

test('submits contact form with valid data', async ({ page }) => {
  const name = 'Ada Lovelace';
  const email = `ada-${Date.now()}@example.com`;
  const message = 'Inquiry about analytics engine';

  await page.goto('/contact');
  await page.getByLabel('Name').fill(name);
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Message').fill(message);
  await page.getByRole('button', { name: 'Send' }).click();

  await expect(page.getByText('Thank you, Ada Lovelace')).toBeVisible();
});
```

Utilise `Date.now()` ou `crypto.randomUUID()` pour les champs qui doivent être uniques (emails, noms d'utilisateur). Cela évite les collisions pendant l'exécution en parallèle.

---

### Factory Functions

**À utiliser quand** : Plusieurs tests ont besoin de la même structure de données avec des valeurs différentes, ou tu as besoin d'une unicité garantie.

**À éviter quand** : Les données sont triviales et utilisées une seule fois : mets-les inline.

Les factories centralisent la logique de création des données. Quand la structure change, tu modifies une seule fonction, pas des dizaines de tests.

**TypeScript**
```typescript
// tests/factories/user.factory.ts
export interface UserData {
  firstName: string;
  lastName: string;
  email: string;
  password: string;
}

let counter = 0;

export function createUserData(overrides: Partial<UserData> = {}): UserData {
  counter++;
  const id = `${Date.now()}-${counter}`;
  return {
    firstName: `Test`,
    lastName: `User${id}`,
    email: `testuser-${id}@example.com`,
    password: 'SecureP@ss123!',
    ...overrides,
  };
}
```

```typescript
// tests/registration.spec.ts
import { test, expect } from '@playwright/test';
import { createUserData } from './factories/user.factory';

test('registers a new user', async ({ page }) => {
  const user = createUserData();

  await page.goto('/register');
  await page.getByLabel('First name').fill(user.firstName);
  await page.getByLabel('Last name').fill(user.lastName);
  await page.getByLabel('Email').fill(user.email);
  await page.getByLabel('Password').fill(user.password);
  await page.getByRole('button', { name: 'Create account' }).click();

  await expect(page.getByText(`Welcome, ${user.firstName}`)).toBeVisible();
});

test('rejects duplicate email', async ({ page }) => {
  const user = createUserData({ email: 'duplicate@example.com' });

  await page.goto('/register');
  await page.getByLabel('Email').fill(user.email);
  await page.getByLabel('Password').fill(user.password);
  await page.getByRole('button', { name: 'Create account' }).click();

  await expect(page.getByText('Email already registered')).toBeVisible();
});
```

**JavaScript**
```javascript
// tests/factories/user.factory.js
let counter = 0;

function createUserData(overrides = {}) {
  counter++;
  const id = `${Date.now()}-${counter}`;
  return {
    firstName: 'Test',
    lastName: `User${id}`,
    email: `testuser-${id}@example.com`,
    password: 'SecureP@ss123!',
    ...overrides,
  };
}

module.exports = { createUserData };
```

```javascript
// tests/registration.spec.js
const { test, expect } = require('@playwright/test');
const { createUserData } = require('./factories/user.factory');

test('registers a new user', async ({ page }) => {
  const user = createUserData();

  await page.goto('/register');
  await page.getByLabel('First name').fill(user.firstName);
  await page.getByLabel('Last name').fill(user.lastName);
  await page.getByLabel('Email').fill(user.email);
  await page.getByLabel('Password').fill(user.password);
  await page.getByRole('button', { name: 'Create account' }).click();

  await expect(page.getByText(`Welcome, ${user.firstName}`)).toBeVisible();
});
```

---

### Faker / données aléatoires

**À utiliser quand** : Tu as besoin de données d'apparence réaliste (noms, adresses, numéros de téléphone) ou tu veux découvrir des cas limites grâce à l'aléatoire.

**À éviter quand** : Tu débogues un échec : utilise une seed fixe pour le rendre reproductible.

Initialise toujours faker avec une seed pour que les échecs soient reproductibles. Utilise `testInfo.testId` ou une seed fixe par fichier de test.

**TypeScript**
```typescript
// tests/factories/faker-user.factory.ts
import { faker } from '@faker-js/faker';

export function createFakerUser(seed?: number) {
  if (seed !== undefined) {
    faker.seed(seed);
  }
  return {
    firstName: faker.person.firstName(),
    lastName: faker.person.lastName(),
    email: faker.internet.email({ provider: 'testmail.example.com' }),
    phone: faker.phone.number(),
    address: {
      street: faker.location.streetAddress(),
      city: faker.location.city(),
      state: faker.location.state({ abbreviated: true }),
      zip: faker.location.zipCode(),
    },
  };
}
```

```typescript
// tests/checkout.spec.ts
import { test, expect } from '@playwright/test';
import { createFakerUser } from './factories/faker-user.factory';

test('completes checkout with shipping address', async ({ page }, testInfo) => {
  // Seed with a stable value so re-runs produce the same data
  const user = createFakerUser(testInfo.workerIndex);

  await page.goto('/checkout');
  await page.getByLabel('Street address').fill(user.address.street);
  await page.getByLabel('City').fill(user.address.city);
  await page.getByLabel('State').fill(user.address.state);
  await page.getByLabel('ZIP code').fill(user.address.zip);
  await page.getByRole('button', { name: 'Place order' }).click();

  await expect(page.getByText('Order confirmed')).toBeVisible();
});
```

**JavaScript**
```javascript
// tests/factories/faker-user.factory.js
const { faker } = require('@faker-js/faker');

function createFakerUser(seed) {
  if (seed !== undefined) {
    faker.seed(seed);
  }
  return {
    firstName: faker.person.firstName(),
    lastName: faker.person.lastName(),
    email: faker.internet.email({ provider: 'testmail.example.com' }),
    phone: faker.phone.number(),
    address: {
      street: faker.location.streetAddress(),
      city: faker.location.city(),
      state: faker.location.state({ abbreviated: true }),
      zip: faker.location.zipCode(),
    },
  };
}

module.exports = { createFakerUser };
```

```javascript
// tests/checkout.spec.js
const { test, expect } = require('@playwright/test');
const { createFakerUser } = require('./factories/faker-user.factory');

test('completes checkout with shipping address', async ({ page }, testInfo) => {
  const user = createFakerUser(testInfo.workerIndex);

  await page.goto('/checkout');
  await page.getByLabel('Street address').fill(user.address.street);
  await page.getByLabel('City').fill(user.address.city);
  await page.getByLabel('State').fill(user.address.state);
  await page.getByLabel('ZIP code').fill(user.address.zip);
  await page.getByRole('button', { name: 'Place order' }).click();

  await expect(page.getByText('Order confirmed')).toBeVisible();
});
```

Utilise toujours un domaine d'email dédié aux tests (par ex. `testmail.example.com`) pour que les emails générés par faker n'atteignent jamais de vraies boîtes de réception. Le domaine `example.com` est réservé par la RFC 2606 et peut être utilisé sans risque pour les tests.

---

### Pattern Builder

**À utiliser quand** : Les objets ont de nombreux champs optionnels, de la logique conditionnelle ou plusieurs configurations valides. Courant pour les fiches produit, les profils utilisateur ou les payloads de formulaire avec des données imbriquées.

**À éviter quand** : L'objet a moins de 5 champs : une factory avec des overrides est plus simple.

**TypeScript**
```typescript
// tests/builders/product.builder.ts
export interface Product {
  name: string;
  price: number;
  currency: string;
  category: string;
  description: string;
  inStock: boolean;
  tags: string[];
  variants: { size: string; color: string }[];
}

export class ProductBuilder {
  private product: Product = {
    name: `Product-${Date.now()}`,
    price: 29.99,
    currency: 'USD',
    category: 'Electronics',
    description: 'A test product',
    inStock: true,
    tags: [],
    variants: [],
  };

  withName(name: string): this {
    this.product.name = name;
    return this;
  }

  withPrice(price: number, currency = 'USD'): this {
    this.product.price = price;
    this.product.currency = currency;
    return this;
  }

  withCategory(category: string): this {
    this.product.category = category;
    return this;
  }

  outOfStock(): this {
    this.product.inStock = false;
    return this;
  }

  withTags(...tags: string[]): this {
    this.product.tags = tags;
    return this;
  }

  withVariant(size: string, color: string): this {
    this.product.variants.push({ size, color });
    return this;
  }

  build(): Product {
    return { ...this.product };
  }
}
```

```typescript
// tests/product-catalog.spec.ts
import { test, expect } from '@playwright/test';
import { ProductBuilder } from './builders/product.builder';

test('displays out-of-stock badge for unavailable products', async ({ page, request }) => {
  const product = new ProductBuilder()
    .withName('Wireless Keyboard')
    .withCategory('Accessories')
    .outOfStock()
    .build();

  // Seed via API (see API Seeding pattern below)
  await request.post('/api/products', { data: product });

  await page.goto('/products');
  const card = page.getByRole('listitem').filter({ hasText: product.name });
  await expect(card.getByText('Out of Stock')).toBeVisible();
});
```

**JavaScript**
```javascript
// tests/builders/product.builder.js
class ProductBuilder {
  constructor() {
    this.product = {
      name: `Product-${Date.now()}`,
      price: 29.99,
      currency: 'USD',
      category: 'Electronics',
      description: 'A test product',
      inStock: true,
      tags: [],
      variants: [],
    };
  }

  withName(name) {
    this.product.name = name;
    return this;
  }

  withPrice(price, currency = 'USD') {
    this.product.price = price;
    this.product.currency = currency;
    return this;
  }

  withCategory(category) {
    this.product.category = category;
    return this;
  }

  outOfStock() {
    this.product.inStock = false;
    return this;
  }

  withTags(...tags) {
    this.product.tags = tags;
    return this;
  }

  withVariant(size, color) {
    this.product.variants.push({ size, color });
    return this;
  }

  build() {
    return { ...this.product };
  }
}

module.exports = { ProductBuilder };
```

```javascript
// tests/product-catalog.spec.js
const { test, expect } = require('@playwright/test');
const { ProductBuilder } = require('./builders/product.builder');

test('displays out-of-stock badge for unavailable products', async ({ page, request }) => {
  const product = new ProductBuilder()
    .withName('Wireless Keyboard')
    .withCategory('Accessories')
    .outOfStock()
    .build();

  await request.post('/api/products', { data: product });

  await page.goto('/products');
  const card = page.getByRole('listitem').filter({ hasText: product.name });
  await expect(card.getByText('Out of Stock')).toBeVisible();
});
```

---

### Seeding via API

**À utiliser quand** : Les tests ont besoin que des entités existent déjà (utilisateurs, produits, commandes) et que l'application expose des API pour les créer. C'est la stratégie par défaut pour la mise en place des données de test.

**À éviter quand** : Aucune API n'existe pour l'entité, ou l'API elle-même est ce que tu testes (passe par l'UI ou la base de données).

Le seeding via API est plus rapide qu'un setup via l'UI, plus maintenable que le seeding en base, et exerce la vraie logique applicative. Privilégie-le par rapport à toutes les autres approches quand une API est disponible.

**TypeScript**
```typescript
// tests/fixtures/api-data.fixture.ts
import { test as base, APIRequestContext } from '@playwright/test';
import { createUserData, UserData } from '../factories/user.factory';

type ApiDataFixtures = {
  apiUser: UserData & { id: string };
};

export const test = base.extend<ApiDataFixtures>({
  apiUser: async ({ request }, use) => {
    const userData = createUserData();

    // Create
    const response = await request.post('/api/users', { data: userData });
    const created = await response.json();
    const user = { ...userData, id: created.id };

    // Provide to test
    await use(user);

    // Cleanup — runs even if test fails
    await request.delete(`/api/users/${user.id}`);
  },
});

export { expect } from '@playwright/test';
```

```typescript
// tests/user-profile.spec.ts
import { test, expect } from './fixtures/api-data.fixture';

test('edits user profile name', async ({ page, apiUser }) => {
  await page.goto(`/users/${apiUser.id}/profile`);
  await page.getByLabel('First name').fill('Updated');
  await page.getByRole('button', { name: 'Save' }).click();

  await expect(page.getByText('Profile updated')).toBeVisible();
});
```

**JavaScript**
```javascript
// tests/fixtures/api-data.fixture.js
const { test: base } = require('@playwright/test');
const { createUserData } = require('../factories/user.factory');

const test = base.extend({
  apiUser: async ({ request }, use) => {
    const userData = createUserData();

    const response = await request.post('/api/users', { data: userData });
    const created = await response.json();
    const user = { ...userData, id: created.id };

    await use(user);

    await request.delete(`/api/users/${user.id}`);
  },
});

module.exports = { test, expect: require('@playwright/test').expect };
```

```javascript
// tests/user-profile.spec.js
const { test, expect } = require('./fixtures/api-data.fixture');

test('edits user profile name', async ({ page, apiUser }) => {
  await page.goto(`/users/${apiUser.id}/profile`);
  await page.getByLabel('First name').fill('Updated');
  await page.getByRole('button', { name: 'Save' }).click();

  await expect(page.getByText('Profile updated')).toBeVisible();
});
```

Pour le seeding de plusieurs entités, compose les fixtures :

**TypeScript**
```typescript
// tests/fixtures/order-data.fixture.ts
import { test as base } from './api-data.fixture';

export const test = base.extend({
  apiOrder: async ({ request, apiUser }, use) => {
    const orderResponse = await request.post('/api/orders', {
      data: { userId: apiUser.id, items: [{ sku: 'WIDGET-001', qty: 2 }] },
    });
    const order = await orderResponse.json();

    await use(order);

    await request.delete(`/api/orders/${order.id}`);
  },
});
```

---

### Seeding via base de données

**À utiliser quand** : Aucune API n'existe pour les données dont tu as besoin, tu as besoin de données en masse, ou tu dois mettre en place un état relationnel complexe, pénible à construire via des appels API.

**À éviter quand** : Une API existe : le seeding via API est plus maintenable et exerce la vraie logique applicative. Le seeding en base couple les tests aux détails du schéma.

**TypeScript**
```typescript
// tests/fixtures/db.fixture.ts
import { test as base } from '@playwright/test';
import { Pool } from 'pg';

type DbFixtures = {
  db: Pool;
  seededOrg: { id: string; name: string };
};

export const test = base.extend<DbFixtures>({
  db: async ({}, use) => {
    const pool = new Pool({
      connectionString: process.env.TEST_DATABASE_URL,
    });
    await use(pool);
    await pool.end();
  },

  seededOrg: async ({ db }, use) => {
    const orgName = `TestOrg-${Date.now()}`;
    const result = await db.query(
      'INSERT INTO organizations (name, plan) VALUES ($1, $2) RETURNING id',
      [orgName, 'enterprise']
    );
    const orgId = result.rows[0].id;

    await use({ id: orgId, name: orgName });

    // Cascade delete cleans up related data
    await db.query('DELETE FROM organizations WHERE id = $1', [orgId]);
  },
});

export { expect } from '@playwright/test';
```

**JavaScript**
```javascript
// tests/fixtures/db.fixture.js
const { test: base } = require('@playwright/test');
const { Pool } = require('pg');

const test = base.extend({
  db: async ({}, use) => {
    const pool = new Pool({
      connectionString: process.env.TEST_DATABASE_URL,
    });
    await use(pool);
    await pool.end();
  },

  seededOrg: async ({ db }, use) => {
    const orgName = `TestOrg-${Date.now()}`;
    const result = await db.query(
      'INSERT INTO organizations (name, plan) VALUES ($1, $2) RETURNING id',
      [orgName, 'enterprise']
    );
    const orgId = result.rows[0].id;

    await use({ id: orgId, name: orgName });

    await db.query('DELETE FROM organizations WHERE id = $1', [orgId]);
  },
});

module.exports = { test, expect: require('@playwright/test').expect };
```

Utilise toujours des requêtes paramétrées (`$1`, `$2`) pour prévenir les injections SQL, même dans les tests. C'est une bonne habitude, et cela évite les ruptures dues aux caractères spéciaux dans les données générées.

---

### Storage State

**À utiliser quand** : Plusieurs tests ont besoin d'une session authentifiée et tu veux éviter de te connecter via l'UI dans chaque test.

**À éviter quand** : Le test vérifie précisément le parcours de connexion lui-même.

Génère le storage state une seule fois dans un projet de setup, puis réutilise-le dans tous les tests qui nécessitent une authentification.

**TypeScript**
```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  projects: [
    {
      name: 'auth-setup',
      testMatch: /auth\.setup\.ts/,
    },
    {
      name: 'authenticated-tests',
      dependencies: ['auth-setup'],
      use: {
        storageState: '.auth/user.json',
      },
    },
  ],
});
```

```typescript
// tests/auth.setup.ts
import { test as setup, expect } from '@playwright/test';
import path from 'node:path';

const authFile = path.join(__dirname, '..', '.auth', 'user.json');

setup('authenticate as standard user', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill(process.env.TEST_USER_EMAIL!);
  await page.getByLabel('Password').fill(process.env.TEST_USER_PASSWORD!);
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  await page.context().storageState({ path: authFile });
});
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  projects: [
    {
      name: 'auth-setup',
      testMatch: /auth\.setup\.js/,
    },
    {
      name: 'authenticated-tests',
      dependencies: ['auth-setup'],
      use: {
        storageState: '.auth/user.json',
      },
    },
  ],
});
```

```javascript
// tests/auth.setup.js
const { test: setup, expect } = require('@playwright/test');
const path = require('node:path');

const authFile = path.join(__dirname, '..', '.auth', 'user.json');

setup('authenticate as standard user', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill(process.env.TEST_USER_EMAIL);
  await page.getByLabel('Password').fill(process.env.TEST_USER_PASSWORD);
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  await page.context().storageState({ path: authFile });
});
```

Pour plusieurs rôles, crée des fichiers de setup et des fichiers de storage state distincts :

```typescript
// tests/admin-auth.setup.ts
import { test as setup } from '@playwright/test';
import path from 'node:path';

const adminAuthFile = path.join(__dirname, '..', '.auth', 'admin.json');

setup('authenticate as admin', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill(process.env.ADMIN_EMAIL!);
  await page.getByLabel('Password').fill(process.env.ADMIN_PASSWORD!);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.context().storageState({ path: adminAuthFile });
});
```

Ajoute `.auth/` au `.gitignore` : les fichiers de storage state contiennent des tokens de session.

---

### Nettoyage des données de test

**À utiliser quand** : Toujours. Chaque test qui crée des données doit les nettoyer.

**À éviter quand** : Jamais. Sauter le nettoyage provoque des échecs en cascade lors des exécutions suivantes.

**Stratégie 1 : Teardown de fixture (recommandée)**

Place le nettoyage dans le bloc de teardown de la fixture. Il s'exécute même si le test lève une exception.

```typescript
// Already shown in API Seeding — the cleanup runs after `use()`
apiUser: async ({ request }, use) => {
  const user = await createViaApi(request);
  await use(user);
  // This ALWAYS runs — even on test failure
  await request.delete(`/api/users/${user.id}`);
},
```

**Stratégie 2 : Nettoyage par lot via un préfixe horodaté**

Marque toutes les données créées par les tests avec un préfixe reconnaissable, puis balaie-les dans le global teardown.

**TypeScript**
```typescript
// global-teardown.ts
import { request } from '@playwright/test';

export default async function globalTeardown() {
  const context = await request.newContext({
    baseURL: process.env.BASE_URL,
  });

  // Delete all test entities created in this run
  // Assumes entities created with the "test-" prefix
  const response = await context.delete('/api/test-data/cleanup', {
    data: { prefix: 'test-', olderThanMinutes: 60 },
  });

  if (!response.ok()) {
    console.warn(`Cleanup returned ${response.status()}`);
  }

  await context.dispose();
}
```

**JavaScript**
```javascript
// global-teardown.js
const { request } = require('@playwright/test');

module.exports = async function globalTeardown() {
  const context = await request.newContext({
    baseURL: process.env.BASE_URL,
  });

  const response = await context.delete('/api/test-data/cleanup', {
    data: { prefix: 'test-', olderThanMinutes: 60 },
  });

  if (!response.ok()) {
    console.warn(`Cleanup returned ${response.status()}`);
  }

  await context.dispose();
};
```

**Stratégie 3 : Tenant isolé par worker**

Chaque worker Playwright obtient son propre tenant/organisation. Toutes les données sont rattachées à ce tenant. Le teardown supprime le tenant entier.

```typescript
// tests/fixtures/tenant.fixture.ts
import { test as base } from '@playwright/test';

export const test = base.extend<{}, { workerTenant: { id: string; apiKey: string } }>({
  workerTenant: [async ({ request }, use) => {
    const res = await request.post('/api/tenants', {
      data: { name: `test-worker-${Date.now()}` },
    });
    const tenant = await res.json();

    await use(tenant);

    await request.delete(`/api/tenants/${tenant.id}`);
  }, { scope: 'worker' }],
});
```

---

### Données spécifiques à l'environnement

**À utiliser quand** : Les tests s'exécutent sur plusieurs environnements (dev, staging, miroir de production) avec des URL de base, des identifiants ou des contraintes de données différents.

**À éviter quand** : Tu n'as qu'un seul environnement de test.

Ne mets jamais en dur des valeurs propres à un environnement dans les fichiers de test. Utilise des fichiers `.env` et `playwright.config` pour les injecter.

**TypeScript**
```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';
import dotenv from 'dotenv';
import path from 'node:path';

// Load environment-specific .env file
const envFile = process.env.TEST_ENV || 'local';
dotenv.config({ path: path.resolve(__dirname, `.env.${envFile}`) });

export default defineConfig({
  use: {
    baseURL: process.env.BASE_URL,
  },
});
```

```
# .env.local
BASE_URL=http://localhost:3000
TEST_USER_EMAIL=testuser@localhost.test
TEST_USER_PASSWORD=localpassword123

# .env.staging
BASE_URL=https://staging.example.com
TEST_USER_EMAIL=e2e-bot@staging.example.com
TEST_USER_PASSWORD=staging-secret-from-vault
```

```typescript
// tests/fixtures/env-data.fixture.ts
import { test as base } from '@playwright/test';

type EnvConfig = {
  testCredentials: { email: string; password: string };
};

export const test = base.extend<EnvConfig>({
  testCredentials: async ({}, use) => {
    const email = process.env.TEST_USER_EMAIL;
    const password = process.env.TEST_USER_PASSWORD;
    if (!email || !password) {
      throw new Error('TEST_USER_EMAIL and TEST_USER_PASSWORD must be set');
    }
    await use({ email, password });
  },
});

export { expect } from '@playwright/test';
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');
const dotenv = require('dotenv');
const path = require('node:path');

const envFile = process.env.TEST_ENV || 'local';
dotenv.config({ path: path.resolve(__dirname, `.env.${envFile}`) });

module.exports = defineConfig({
  use: {
    baseURL: process.env.BASE_URL,
  },
});
```

Exécuter sur un environnement précis :

```bash
TEST_ENV=staging npx playwright test
```

---

### Fixtures pour les données de test

**À utiliser quand** : Le setup et le teardown des données doivent être encapsulés, réutilisables et garantir le nettoyage. C'est le pattern recommandé pour toutes les données de test non triviales.

**À éviter quand** : La donnée est une simple valeur inline qui ne nécessite aucun nettoyage.

Les fixtures sont l'ossature d'une gestion fiable des données de test dans Playwright. Elles se composent, elles garantissent le teardown, et elles rendent les tests déclaratifs.

**TypeScript**
```typescript
// tests/fixtures/index.ts
import { test as base, expect } from '@playwright/test';
import { createUserData, UserData } from '../factories/user.factory';

type TestFixtures = {
  seedUser: UserData & { id: string };
  seedProduct: { id: string; name: string; price: number };
};

export const test = base.extend<TestFixtures>({
  seedUser: async ({ request }, use) => {
    const data = createUserData();
    const res = await request.post('/api/users', { data });
    expect(res.ok()).toBeTruthy();
    const user = { ...data, id: (await res.json()).id };

    await use(user);

    await request.delete(`/api/users/${user.id}`);
  },

  seedProduct: async ({ request }, use) => {
    const data = {
      name: `Product-${Date.now()}`,
      price: 49.99,
      category: 'Testing',
    };
    const res = await request.post('/api/products', { data });
    expect(res.ok()).toBeTruthy();
    const product = { ...data, id: (await res.json()).id };

    await use(product);

    await request.delete(`/api/products/${product.id}`);
  },
});

export { expect };
```

```typescript
// tests/shopping-cart.spec.ts
import { test, expect } from './fixtures';

test('adds product to cart', async ({ page, seedUser, seedProduct }) => {
  // seedUser and seedProduct are already created and will be cleaned up automatically
  await page.goto(`/products/${seedProduct.id}`);
  await page.getByRole('button', { name: 'Add to cart' }).click();

  await page.goto('/cart');
  await expect(page.getByText(seedProduct.name)).toBeVisible();
  await expect(page.getByText('$49.99')).toBeVisible();
});
```

**JavaScript**
```javascript
// tests/fixtures/index.js
const { test: base, expect } = require('@playwright/test');
const { createUserData } = require('../factories/user.factory');

const test = base.extend({
  seedUser: async ({ request }, use) => {
    const data = createUserData();
    const res = await request.post('/api/users', { data });
    expect(res.ok()).toBeTruthy();
    const user = { ...data, id: (await res.json()).id };

    await use(user);

    await request.delete(`/api/users/${user.id}`);
  },

  seedProduct: async ({ request }, use) => {
    const data = {
      name: `Product-${Date.now()}`,
      price: 49.99,
      category: 'Testing',
    };
    const res = await request.post('/api/products', { data });
    expect(res.ok()).toBeTruthy();
    const product = { ...data, id: (await res.json()).id };

    await use(product);

    await request.delete(`/api/products/${product.id}`);
  },
});

module.exports = { test, expect };
```

```javascript
// tests/shopping-cart.spec.js
const { test, expect } = require('./fixtures');

test('adds product to cart', async ({ page, seedUser, seedProduct }) => {
  await page.goto(`/products/${seedProduct.id}`);
  await page.getByRole('button', { name: 'Add to cart' }).click();

  await page.goto('/cart');
  await expect(page.getByText(seedProduct.name)).toBeVisible();
  await expect(page.getByText('$49.99')).toBeVisible();
});
```

Les fixtures ne s'exécutent que lorsqu'un test les demande par leur nom. Si un test n'utilise pas `seedProduct`, le produit n'est jamais créé : pas de setup inutile, pas de nettoyage superflu.

## Guide de décision

```
What data does your test need?
│
├── Simple values (strings, numbers for form fields)?
│   └── Use INLINE DATA — keep it in the test
│
├── Same shape used across many tests?
│   ├── < 5 fields? → Use a FACTORY FUNCTION
│   └── >= 5 fields with optional/conditional fields? → Use a BUILDER
│
├── Need realistic-looking data (names, addresses)?
│   └── Use FAKER with a fixed seed
│
├── Entities that must exist before the test starts?
│   ├── App has an API for this entity?
│   │   └── Use API SEEDING in a fixture (preferred)
│   ├── No API, but have database access?
│   │   └── Use DATABASE SEEDING in a fixture
│   └── No API, no DB access?
│       └── Use UI setup in a beforeEach (slowest — avoid if possible)
│
├── Need an authenticated session?
│   └── Use STORAGE STATE via setup project
│
└── Need data isolated per worker?
    └── Use WORKER-SCOPED FIXTURES with tenant isolation
```

### Classement par vitesse (du plus rapide au plus lent)

1. Données inline / factories / faker : aucune I/O, instantané
2. Seeding via API : un appel HTTP par entité
3. Seeding via base de données : appel direct à la BDD, contourne la logique applicative
4. Storage state : connexion unique, réutilisée entre les tests
5. Setup via l'UI : interaction complète avec le navigateur à chaque test (à éviter)

### Classement par isolation (du plus au moins isolé)

1. Fixtures à portée test avec teardown via API : chaque test reçoit des données fraîches, nettoyées ensuite
2. Isolation par tenant à portée worker : les tests d'un worker partagent un tenant, nettoyé à la sortie du worker
3. Nettoyage par lot via préfixe horodaté : rattrape les données orphelines, s'exécute dans le global teardown
4. État de base de données partagé : fragile, sujet aux bugs d'ordre d'exécution (à éviter)

## Anti-patterns

### Données mutables partagées entre les tests

```typescript
// BAD — tests share the same user object and depend on execution order
let sharedUser: UserData;

test.beforeAll(async ({ request }) => {
  sharedUser = await createUser(request);
});

test('updates user name', async ({ page }) => {
  // Mutates sharedUser — other tests see the changed state
});

test('checks original name', async ({ page }) => {
  // Fails because the previous test changed the name
});
```

Correction : Utilise des fixtures à portée test. Chaque test obtient sa propre instance.

### IDs en dur

```typescript
// BAD — this ID only exists in your local database
test('edits product', async ({ page }) => {
  await page.goto('/products/507f1f77bcf86cd799439011/edit');
});
```

Correction : Crée le produit dans une fixture et utilise l'ID retourné.

### Pas de nettoyage

```typescript
// BAD — creates data but never deletes it
test.beforeEach(async ({ request }) => {
  await request.post('/api/products', { data: { name: 'Leaked Product' } });
});
// Over time, the database fills with test debris causing slowdowns and false positives
```

Correction : Associe toujours la création à une suppression dans le teardown d'une fixture.

### S'appuyer sur un état de base de données préexistant

```typescript
// BAD — assumes "Premium Plan" already exists in the database
test('subscribes to premium', async ({ page }) => {
  await page.goto('/pricing');
  await page.getByRole('button', { name: 'Premium Plan' }).click();
  // Breaks on a fresh database or different environment
});
```

Correction : Crée le plan via une fixture API ou base de données avant le test.

### Utiliser des données de production dans les tests

```typescript
// BAD — tests against real customer data
test('views customer orders', async ({ page }) => {
  await page.goto('/admin/customers/real-customer-id/orders');
});
```

Correction : Crée des données de test synthétiques. Ne pointe jamais une suite de tests vers des bases de production et n'utilise jamais de vrais identifiants clients.

### Sur-ingénierie de la mise en place des données

```typescript
// BAD — abstraction for its own sake
const data = new TestDataOrchestrator()
  .withStrategy('api')
  .withRetry(3)
  .withCleanupPolicy('deferred')
  .withEnvironment('staging')
  .build();
```

Correction : Une factory function et une fixture couvrent 95 % des cas. N'ajoute de la complexité que si le besoin est avéré.

## Dépannage

| Problème | Cause | Correction |
|---|---|---|
| Les tests échouent avec des erreurs « duplicate key » | Les données des exécutions précédentes n'ont pas été nettoyées | Ajoute un teardown de fixture ; exécute un nettoyage par lot dans `globalTeardown` |
| Les tests passent seuls mais échouent en parallèle | Les tests partagent un état mutable ou entrent en collision sur des champs uniques | Utilise `Date.now()` ou `crypto.randomUUID()` dans la sortie des factories ; utilise des fixtures à portée test |
| Faker produit des données différentes lors d'un retry | Faker n'a pas été initialisé avec une seed, ou la seed change d'une exécution à l'autre | Initialise avec `testInfo.workerIndex` ou une valeur fixe |
| Storage state expiré / session invalide | Les tokens d'authentification ont un TTL court | Relance le setup d'authentification avant chaque suite ; mets `fullyParallel: false` sur le projet dépendant de l'auth si nécessaire |
| Le nettoyage échoue et bloque d'autres tests | Le teardown fait des appels réseau susceptibles d'expirer | Entoure le nettoyage d'un `try/catch` ; journalise les échecs sans lever d'exception ; compte sur le nettoyage par lot comme filet de sécurité |
| Le seeding en base est lent | Trop d'instructions INSERT individuelles | Regroupe les insertions ; utilise des transactions ; envisage plutôt le seeding via API |
| Les tests cassent sur staging | Valeurs en dur qui n'existent qu'en local | Utilise des variables d'environnement pour toutes les données propres à un environnement ; valide dans la fixture avec des messages d'erreur clairs |

### Rendre le nettoyage résilient

```typescript
// Wrap fixture teardown in try/catch so a cleanup failure does not mask the real test failure
seedUser: async ({ request }, use) => {
  const user = await createViaApi(request);
  await use(user);

  try {
    await request.delete(`/api/users/${user.id}`);
  } catch (error) {
    console.warn(`Failed to clean up user ${user.id}:`, error);
  }
},
```

## Voir aussi

- [core/fixtures-and-hooks.md](fixtures-and-hooks.md) — mécanique des fixtures, portées, composition
- [core/authentication.md](authentication.md) — setup du storage state, patterns d'authentification multi-rôles
- [core/api-testing.md](api-testing.md) — contexte de requête API, validation des réponses
- [ci/global-setup-teardown.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/global-setup-teardown.md) — global setup/teardown pour les opérations par lot
- [pom/pom-vs-fixtures-vs-helpers.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/pom/pom-vs-fixtures-vs-helpers.md) — quand utiliser des fixtures, des page objects ou des helpers
