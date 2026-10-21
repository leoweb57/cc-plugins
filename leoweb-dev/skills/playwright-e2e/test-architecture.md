# Architecture des tests : E2E vs composant vs API

> **Quand l'utiliser** : pour décider quel type de test écrire pour une fonctionnalité. Avant d'écrire le moindre test, demande-toi : « Quel est le test le moins cher qui me donne confiance dans le fait que ça fonctionne ? »

## Réponse rapide

La plupart des équipes écrivent trop de tests E2E. Adopte par défaut l'approche du **testing trophy** :

1. **Tests API** pour la logique métier, la validation des données et les permissions (les plus rapides, les plus stables)
2. **Tests de composants** pour le comportement isolé de l'UI, la validation de formulaires et les widgets interactifs (rapides, ciblés)
3. **Tests E2E uniquement pour les parcours utilisateur critiques** -- login, checkout, onboarding (lents, confiance maximale)

Si tu n'as le temps que pour une seule couche, commence par les tests API. Ils couvrent le plus de terrain pour le coût de maintenance le plus faible.

## Le testing trophy

Le testing trophy (théorisé par Kent C. Dodds) remplace la pyramide des tests traditionnelle pour les applications web modernes :

```
        ╱ ╲
       ╱ E2E ╲           Thin layer -- critical paths only
      ╱─────────╲
     ╱           ╲
    ╱ Integration  ╲      Thickest layer -- component + API tests
   ╱                 ╲
  ╱───────────────────╲
 ╱        Unit         ╲   Utility functions, pure logic
╱───────────────────────╲
     Static Analysis       TypeScript, ESLint, Prettier
```

**Où se place Playwright** :
- **Couche E2E** : `@playwright/test` avec un navigateur -- test de parcours utilisateur complets
- **Couche intégration / composant** : la fixture `mount` intégrée de `@playwright/test` (modèle stories et galleries, 1.62+) -- rend des composants dans un vrai navigateur sans application complète. Voir [component-testing.md](component-testing.md)
- **Couche intégration / API** : `@playwright/test` avec le contexte `request` -- tests HTTP sans navigateur
- **Couche statique** : ce n'est pas le rôle de Playwright. Utilise TypeScript et ESLint.

La forme du trophée signifie que les tests d'intégration (composant + API) doivent être ton **plus gros** investissement. Ils offrent le meilleur rapport confiance/coût.

## Matrice de décision

| Ce que tu testes | Type de test | Pourquoi | Exemple Playwright |
|---|---|---|---|
| Login / flux d'authentification | E2E | Multi-pages, cookies, redirections, état de session | Parcours complet dans le navigateur avec `storageState` |
| Soumission de formulaire | Composant | Logique de validation isolée, états d'erreur, UX | Monter le composant de formulaire, tester les états |
| Opérations CRUD | API | L'intégrité des données compte plus que l'UI pour créer/modifier/supprimer | `request.post()`, `request.put()`, `request.delete()` |
| Recherche avec UI de résultats | Composant + API | Test API pour la logique de requête ; test de composant pour le rendu des résultats | Séparer : API pour les données, composant pour l'affichage |
| Navigation entre pages | E2E | Le routage, l'historique et les deep links relèvent du navigateur | `page.goto()`, `page.waitForURL()` |
| Gestion d'erreurs (erreurs API) | API | Valider les codes de statut, la forme des erreurs et les cas limites sans UI | `expect(response.status()).toBe(422)` |
| Gestion d'erreurs (retour UI) | Composant | Rendu des toasts, bannières, erreurs inline | Monter le composant, mocker la réponse d'erreur |
| Accessibilité | Composant | Tester les rôles ARIA et la navigation clavier par composant ; plus rapide que de l'E2E complet | `expect(locator).toHaveAttribute('aria-expanded')` |
| Layout responsive | Composant | Rendu spécifique à un viewport sans la lourdeur d'une application complète | `mount()` avec configuration du viewport |
| Intégration d'API (contrat) | API | Valider indépendamment les formes de réponse, les en-têtes et l'authentification | `request.get()` avec validation de schéma |
| Fonctionnalités temps réel (WebSocket) | E2E | Nécessite un environnement de navigateur complet pour les connexions WebSocket | `page.evaluate()` avec des listeners WebSocket |
| Paiement / checkout | E2E | Multi-étapes, iframes tierces, fiabilité en conditions réelles | Parcours complet dans le navigateur, `frameLocator()` |
| Onboarding / wizard | E2E | Multi-étapes, l'état persiste d'une page à l'autre | `test.step()` pour chaque étape du wizard |
| Comportement d'un widget individuel | Composant | Toggle, accordéon, date picker, modale -- interactions isolées | Monter le composant, tester ouverture/fermeture/sélection |
| Permissions / autorisation | API | L'accès par rôle est de la logique backend ; à tester sans la lourdeur de l'UI | Requêtes avec différents tokens d'authentification |

## Quand utiliser des tests E2E

**Idéal pour** :
- Les parcours utilisateur critiques qui génèrent du revenu (checkout, inscription, abonnement)
- Les flux d'authentification et d'autorisation (login, SSO, MFA, réinitialisation de mot de passe)
- Les workflows multi-pages où l'état se propage d'une navigation à l'autre (wizards, onboarding)
- Les flux impliquant des iframes tierces (widgets de paiement, formulaires embarqués)
- Les smoke tests qui valident que toute la stack est correctement câblée
- Les fonctionnalités de collaboration en temps réel nécessitant plusieurs contextes de navigateur

**À éviter pour** :
- Tester chaque permutation de validation de formulaire (utilise des tests de composants)
- Les opérations CRUD où l'UI n'est qu'une fine couche (utilise des tests API)
- Vérifier les états individuels d'un composant (utilise des tests de composants)
- Tester la forme des réponses API ou les codes d'erreur (utilise des tests API)
- Le layout responsive à chaque breakpoint (utilise des tests de composants)
- Les cas limites qui n'affectent que le backend (utilise des tests API)

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// E2E: critical checkout flow -- this justifies the cost of a full browser
test.describe('checkout flow', () => {
  test.beforeEach(async ({ page }) => {
    // Seed data via API to keep E2E tests focused on the flow, not setup
    await page.request.post('/api/test/seed-cart', {
      data: { items: [{ sku: 'SHOE-001', qty: 1 }] },
    });
    await page.goto('/cart');
  });

  test('completes purchase with valid payment', async ({ page }) => {
    await test.step('review cart', async () => {
      await expect(page.getByRole('heading', { name: 'Your Cart' })).toBeVisible();
      await expect(page.getByText('Running Shoes')).toBeVisible();
      await page.getByRole('button', { name: 'Proceed to checkout' }).click();
    });

    await test.step('fill shipping details', async () => {
      await page.getByLabel('Full name').fill('Jane Doe');
      await page.getByLabel('Address').fill('123 Main St');
      await page.getByLabel('City').fill('Portland');
      await page.getByRole('combobox', { name: 'State' }).selectOption('OR');
      await page.getByLabel('ZIP code').fill('97201');
      await page.getByRole('button', { name: 'Continue to payment' }).click();
    });

    await test.step('enter payment', async () => {
      const paymentFrame = page.frameLocator('iframe[title="Payment"]');
      await paymentFrame.getByLabel('Card number').fill('4242424242424242');
      await paymentFrame.getByLabel('Expiration').fill('12/28');
      await paymentFrame.getByLabel('CVC').fill('123');
      await page.getByRole('button', { name: 'Place order' }).click();
    });

    await test.step('verify confirmation', async () => {
      await page.waitForURL('**/order/confirmation/**');
      await expect(page.getByRole('heading', { name: 'Order Confirmed' })).toBeVisible();
      await expect(page.getByText(/Order #\d+/)).toBeVisible();
    });
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('checkout flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.request.post('/api/test/seed-cart', {
      data: { items: [{ sku: 'SHOE-001', qty: 1 }] },
    });
    await page.goto('/cart');
  });

  test('completes purchase with valid payment', async ({ page }) => {
    await test.step('review cart', async () => {
      await expect(page.getByRole('heading', { name: 'Your Cart' })).toBeVisible();
      await expect(page.getByText('Running Shoes')).toBeVisible();
      await page.getByRole('button', { name: 'Proceed to checkout' }).click();
    });

    await test.step('fill shipping details', async () => {
      await page.getByLabel('Full name').fill('Jane Doe');
      await page.getByLabel('Address').fill('123 Main St');
      await page.getByLabel('City').fill('Portland');
      await page.getByRole('combobox', { name: 'State' }).selectOption('OR');
      await page.getByLabel('ZIP code').fill('97201');
      await page.getByRole('button', { name: 'Continue to payment' }).click();
    });

    await test.step('enter payment', async () => {
      const paymentFrame = page.frameLocator('iframe[title="Payment"]');
      await paymentFrame.getByLabel('Card number').fill('4242424242424242');
      await paymentFrame.getByLabel('Expiration').fill('12/28');
      await paymentFrame.getByLabel('CVC').fill('123');
      await page.getByRole('button', { name: 'Place order' }).click();
    });

    await test.step('verify confirmation', async () => {
      await page.waitForURL('**/order/confirmation/**');
      await expect(page.getByRole('heading', { name: 'Order Confirmed' })).toBeVisible();
      await expect(page.getByText(/Order #\d+/)).toBeVisible();
    });
  });
});
```

## Quand utiliser des tests de composants

**Idéal pour** :
- La validation de formulaires (champs obligatoires, règles de format, messages d'erreur, interactions entre champs)
- Les widgets interactifs (modales, dropdowns, accordéons, date pickers, onglets)
- Le rendu conditionnel (logique afficher/masquer, états de chargement, états vides, états d'erreur)
- L'accessibilité par composant (attributs ARIA, navigation clavier, gestion du focus)
- Le layout responsive à différents viewports sans la lourdeur d'une application complète
- Les états visuels (hover, focus, disabled, selected) des composants d'un design system

**À éviter pour** :
- Tester le routage ou la navigation entre pages (utilise de l'E2E)
- Les flux nécessitant de vrais cookies, sessions ou un état côté serveur (utilise de l'E2E)
- La persistance des données ou la validation de contrat d'API (utilise des tests API)
- Les interactions avec des iframes tierces (utilise de l'E2E)
- Tout ce qui nécessite plusieurs pages ou contextes de navigateur (utilise de l'E2E)

> **Package historique** : les exemples ci-dessous utilisent `@playwright/experimental-ct-react`, qui n'est plus mis à jour depuis Playwright 1.63. Les nouvelles suites devraient utiliser le modèle stories, où `mount('components/LoginForm/Default')` prend un id de story au lieu de JSX. Voir [component-testing.md](component-testing.md). Les conseils au niveau des tests (quoi couvrir, comment asserter) restent inchangés.

**TypeScript** (exemple React avec `@playwright/experimental-ct-react`)
```typescript
import { test, expect } from '@playwright/experimental-ct-react';
import { LoginForm } from '../src/components/LoginForm';

test.describe('LoginForm component', () => {
  test('shows validation errors for empty submission', async ({ mount }) => {
    const component = await mount(<LoginForm onSubmit={() => {}} />);

    await component.getByRole('button', { name: 'Sign in' }).click();

    await expect(component.getByText('Email is required')).toBeVisible();
    await expect(component.getByText('Password is required')).toBeVisible();
  });

  test('shows error for invalid email format', async ({ mount }) => {
    const component = await mount(<LoginForm onSubmit={() => {}} />);

    await component.getByLabel('Email').fill('not-an-email');
    await component.getByLabel('Password').fill('password123');
    await component.getByRole('button', { name: 'Sign in' }).click();

    await expect(component.getByText('Enter a valid email address')).toBeVisible();
  });

  test('calls onSubmit with credentials for valid input', async ({ mount }) => {
    const submitted: Array<{ email: string; password: string }> = [];
    const component = await mount(
      <LoginForm onSubmit={(data) => submitted.push(data)} />
    );

    await component.getByLabel('Email').fill('jane@example.com');
    await component.getByLabel('Password').fill('s3cure!Pass');
    await component.getByRole('button', { name: 'Sign in' }).click();

    expect(submitted).toHaveLength(1);
    expect(submitted[0]).toEqual({
      email: 'jane@example.com',
      password: 's3cure!Pass',
    });
  });

  test('disables submit button while loading', async ({ mount }) => {
    const component = await mount(<LoginForm onSubmit={() => {}} loading={true} />);

    await expect(component.getByRole('button', { name: 'Signing in...' })).toBeDisabled();
  });

  test('meets accessibility requirements', async ({ mount }) => {
    const component = await mount(<LoginForm onSubmit={() => {}} />);

    // Labels are associated with inputs
    await expect(component.getByRole('textbox', { name: 'Email' })).toBeVisible();

    // Error messages are announced via aria-live
    await component.getByRole('button', { name: 'Sign in' }).click();
    await expect(component.getByRole('alert')).toContainText('Email is required');
  });
});
```

**JavaScript** (exemple React avec `@playwright/experimental-ct-react`)
```javascript
const { test, expect } = require('@playwright/experimental-ct-react');
const { LoginForm } = require('../src/components/LoginForm');

test.describe('LoginForm component', () => {
  test('shows validation errors for empty submission', async ({ mount }) => {
    const component = await mount(<LoginForm onSubmit={() => {}} />);

    await component.getByRole('button', { name: 'Sign in' }).click();

    await expect(component.getByText('Email is required')).toBeVisible();
    await expect(component.getByText('Password is required')).toBeVisible();
  });

  test('calls onSubmit with credentials for valid input', async ({ mount }) => {
    const submitted = [];
    const component = await mount(
      <LoginForm onSubmit={(data) => submitted.push(data)} />
    );

    await component.getByLabel('Email').fill('jane@example.com');
    await component.getByLabel('Password').fill('s3cure!Pass');
    await component.getByRole('button', { name: 'Sign in' }).click();

    expect(submitted).toHaveLength(1);
    expect(submitted[0]).toEqual({
      email: 'jane@example.com',
      password: 's3cure!Pass',
    });
  });

  test('disables submit button while loading', async ({ mount }) => {
    const component = await mount(<LoginForm onSubmit={() => {}} loading={true} />);

    await expect(component.getByRole('button', { name: 'Signing in...' })).toBeDisabled();
  });
});
```

## Quand utiliser des tests API

**Idéal pour** :
- Les opérations CRUD (créer, lire, modifier, supprimer des ressources)
- La validation des entrées et les réponses d'erreur (400, 422 avec des corps d'erreur structurés)
- Les contrôles de permissions et d'autorisation (accès par rôle, portée des tokens)
- L'intégrité des données et les règles métier (unicité, intégrité référentielle, calculs)
- La vérification du contrat d'API (formes de réponse, en-têtes, pagination)
- Les cas limites coûteux à reproduire via l'UI (rate limiting, mises à jour concurrentes)
- La mise en place et le nettoyage des données de test pour les tests E2E (seed via l'API, vérification via l'API)

**À éviter pour** :
- Tester la manière dont les erreurs sont affichées à l'utilisateur (utilise des tests de composants)
- Tester un comportement propre au navigateur (cookies, redirections, navigation)
- Vérifier le layout visuel ou le design responsive (utilise des tests de composants)
- Les flux nécessitant l'exécution de JavaScript ou une interaction avec le DOM (utilise de l'E2E ou des tests de composants)
- Les interactions avec des iframes tierces (utilise de l'E2E)

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('Users API', () => {
  let authToken: string;

  test.beforeAll(async ({ request }) => {
    const response = await request.post('/api/auth/login', {
      data: { email: 'admin@example.com', password: 'admin-pass' },
    });
    const body = await response.json();
    authToken = body.token;
  });

  test('creates a user with valid data', async ({ request }) => {
    const response = await request.post('/api/users', {
      headers: { Authorization: `Bearer ${authToken}` },
      data: {
        email: 'newuser@example.com',
        name: 'Jane Doe',
        role: 'editor',
      },
    });

    expect(response.status()).toBe(201);

    const user = await response.json();
    expect(user).toMatchObject({
      email: 'newuser@example.com',
      name: 'Jane Doe',
      role: 'editor',
    });
    expect(user).toHaveProperty('id');
    expect(user).toHaveProperty('createdAt');
  });

  test('rejects duplicate email with 409', async ({ request }) => {
    const response = await request.post('/api/users', {
      headers: { Authorization: `Bearer ${authToken}` },
      data: {
        email: 'admin@example.com', // already exists
        name: 'Duplicate',
        role: 'viewer',
      },
    });

    expect(response.status()).toBe(409);

    const error = await response.json();
    expect(error.message).toContain('already exists');
  });

  test('returns 422 for invalid email format', async ({ request }) => {
    const response = await request.post('/api/users', {
      headers: { Authorization: `Bearer ${authToken}` },
      data: {
        email: 'not-valid',
        name: 'Bad Email',
        role: 'viewer',
      },
    });

    expect(response.status()).toBe(422);

    const error = await response.json();
    expect(error.errors).toContainEqual(
      expect.objectContaining({ field: 'email' })
    );
  });

  test('non-admin cannot create users', async ({ request }) => {
    // Login as a non-admin user
    const loginResponse = await request.post('/api/auth/login', {
      data: { email: 'viewer@example.com', password: 'viewer-pass' },
    });
    const { token: viewerToken } = await loginResponse.json();

    const response = await request.post('/api/users', {
      headers: { Authorization: `Bearer ${viewerToken}` },
      data: {
        email: 'another@example.com',
        name: 'Unauthorized',
        role: 'editor',
      },
    });

    expect(response.status()).toBe(403);
  });

  test('lists users with pagination', async ({ request }) => {
    const response = await request.get('/api/users', {
      headers: { Authorization: `Bearer ${authToken}` },
      params: { page: '1', limit: '10' },
    });

    expect(response.status()).toBe(200);

    const body = await response.json();
    expect(body.data).toBeInstanceOf(Array);
    expect(body.data.length).toBeLessThanOrEqual(10);
    expect(body).toHaveProperty('total');
    expect(body).toHaveProperty('page', 1);
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test.describe('Users API', () => {
  let authToken;

  test.beforeAll(async ({ request }) => {
    const response = await request.post('/api/auth/login', {
      data: { email: 'admin@example.com', password: 'admin-pass' },
    });
    const body = await response.json();
    authToken = body.token;
  });

  test('creates a user with valid data', async ({ request }) => {
    const response = await request.post('/api/users', {
      headers: { Authorization: `Bearer ${authToken}` },
      data: {
        email: 'newuser@example.com',
        name: 'Jane Doe',
        role: 'editor',
      },
    });

    expect(response.status()).toBe(201);

    const user = await response.json();
    expect(user).toMatchObject({
      email: 'newuser@example.com',
      name: 'Jane Doe',
      role: 'editor',
    });
    expect(user).toHaveProperty('id');
    expect(user).toHaveProperty('createdAt');
  });

  test('rejects duplicate email with 409', async ({ request }) => {
    const response = await request.post('/api/users', {
      headers: { Authorization: `Bearer ${authToken}` },
      data: {
        email: 'admin@example.com',
        name: 'Duplicate',
        role: 'viewer',
      },
    });

    expect(response.status()).toBe(409);

    const error = await response.json();
    expect(error.message).toContain('already exists');
  });

  test('non-admin cannot create users', async ({ request }) => {
    const loginResponse = await request.post('/api/auth/login', {
      data: { email: 'viewer@example.com', password: 'viewer-pass' },
    });
    const { token: viewerToken } = await loginResponse.json();

    const response = await request.post('/api/users', {
      headers: { Authorization: `Bearer ${viewerToken}` },
      data: {
        email: 'another@example.com',
        name: 'Unauthorized',
        role: 'editor',
      },
    });

    expect(response.status()).toBe(403);
  });
});
```

## Combiner les types de tests

Les suites de tests les plus efficaces superposent les trois types. Voici comment ils fonctionnent ensemble pour une fonctionnalité de « gestion des utilisateurs » :

### Couche 1 : tests API (60 % du nombre de tests)

Couvrent chaque permutation de la logique backend. Ils sont peu coûteux à exécuter et à maintenir.

```
tests/api/users.spec.ts
  - creates user with valid data (201)
  - rejects duplicate email (409)
  - rejects invalid email format (422)
  - rejects missing required fields (422)
  - non-admin cannot create users (403)
  - unauthenticated request returns 401
  - lists users with pagination
  - filters users by role
  - updates user profile
  - soft-deletes a user
  - prevents deleting last admin
```

### Couche 2 : tests de composants (30 % du nombre de tests)

Couvrent chaque état visuel et chaque interaction des composants d'UI.

```
tests/components/UserForm.spec.tsx
  - shows validation errors on empty submit
  - shows inline error for invalid email
  - disables submit while loading
  - calls onSubmit with form data
  - resets form after successful submit

tests/components/UserTable.spec.tsx
  - renders user rows from props
  - shows empty state when no users
  - handles delete confirmation modal
  - sorts by column header click
  - shows role badges with correct colors
```

### Couche 3 : tests E2E (10 % du nombre de tests)

Ne couvrent que le parcours critique qui prouve que toute la stack fonctionne ensemble.

```
tests/e2e/user-management.spec.ts
  - admin creates a user and sees them in the list
  - admin edits a user's role
  - viewer cannot access user management page
```

### Le calcul

Pour cette seule fonctionnalité, tu pourrais avoir :
- **11 tests API** -- environ 2 secondes au total, aucun navigateur nécessaire
- **10 tests de composants** -- environ 5 secondes au total, vrai navigateur mais sans serveur
- **3 tests E2E** -- environ 15 secondes au total, stack complète

Total : 24 tests, ~22 secondes. Les 11 tests API détectent la plupart des régressions. Les 10 tests de composants détectent les bugs d'UI. Les 3 tests E2E prouvent que le câblage fonctionne. Si les tests E2E échouent alors que les tests API et de composants passent, tu sais que le problème se situe dans la couche d'intégration (routage, gestion d'état, client API) -- pas dans la logique métier ni dans les composants d'UI.

## Anti-patterns

| Anti-pattern | Problème | Meilleure approche |
|---|---|---|
| Un test E2E pour chaque règle de validation de formulaire | Test navigateur de 30 secondes pour ce qu'un test API couvre en 200 ms | Test API pour la logique de validation, un test de composant pour l'affichage des erreurs |
| Aucun test API -- tout en E2E | Suite lente, flaky à cause du timing de l'UI, échecs difficiles à diagnostiquer | Tests API pour les données/la logique, E2E uniquement pour les parcours critiques |
| Tests de composants qui mockent tout | Les tests passent mais l'application est cassée car les mocks dérivent de la réalité | Mocke uniquement les frontières externes ; utilise des tests API pour vérifier les vrais contrats |
| Dupliquer les assertions entre les couches | Même vérification dans le test API, le test de composant ET le test E2E -- triple coût de maintenance | Chaque couche teste ce qu'elle est la seule à pouvoir vérifier |
| Test E2E qui crée ses propres données de test via l'UI | Test de 2 minutes dont 90 secondes de mise en place ; casse quand une partie non liée de l'UI change | Seed les données via des appels API dans `beforeEach`, puis teste le vrai parcours |
| Tester le comportement d'un tiers | Tester que Stripe valide les numéros de carte (c'est le travail de Stripe) | Mocke Stripe dans les tests de composants/E2E ; fais confiance à leur contrat d'API |
| Sauter complètement la couche API | Les tests d'UI détectent le bug mais tu ne peux pas dire s'il vient du frontend ou du backend | Les tests API isolent les bugs backend ; les tests de composants isolent les bugs frontend |
| Un seul gigantesque test E2E pour toute la fonctionnalité | Test de 5 minutes qui échoue quelque part au milieu sans cause claire | Découpe en tests E2E ciblés par parcours critique ; utilise `test.step()` pour la clarté |

## Voir aussi

- [core/test-organization.md](test-organization.md) -- structure des fichiers et conventions de nommage pour chaque type de test
- [core/api-testing.md](api-testing.md) -- approfondissement de l'API `request` de Playwright pour les tests HTTP
- [core/component-testing.md](component-testing.md) -- mise en place et écriture de tests de composants avec Playwright CT
- [core/authentication.md](authentication.md) -- patterns de test des flux d'authentification (E2E + réutilisation de `storageState`)
- [core/when-to-mock.md](when-to-mock.md) -- quand mocker les requêtes réseau et quand appeler les vrais services
- [pom/pom-vs-fixtures-vs-helpers.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/pom/pom-vs-fixtures-vs-helpers.md) -- organisation de la logique de test partagée entre les couches
