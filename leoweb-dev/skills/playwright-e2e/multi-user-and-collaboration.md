# Tests multi-utilisateurs et collaboration

> **Quand l'utiliser** : quand ton application implique de la collaboration en temps réel, des workflows multi-utilisateurs, ou tout scénario où deux utilisateurs ou plus interagissent simultanément avec la même ressource -- applications de chat, documents partagés, fonctionnalités multijoueurs, parcours admin-et-utilisateur.
> **Prérequis** : [core/fixtures-and-hooks.md](fixtures-and-hooks.md), [core/configuration.md](configuration.md)

## Référence rapide

```typescript
// Two independent browser contexts in one test = two users
const alice = await browser.newContext({ storageState: 'auth/alice.json' });
const bob = await browser.newContext({ storageState: 'auth/bob.json' });
const alicePage = await alice.newPage();
const bobPage = await bob.newPage();

// Each operates independently — different cookies, sessions, localStorage
await alicePage.goto('/chat/room-1');
await bobPage.goto('/chat/room-1');
```

## Patterns

### Deux utilisateurs dans un même test via des contextes de navigateur

**À utiliser quand** : tu dois vérifier que les actions d'un utilisateur sont visibles par un autre en temps réel.
**À éviter quand** : tu testes seulement le parcours d'un seul utilisateur. Un contexte par test est le comportement par défaut.

Chaque `browser.newContext()` crée une session totalement isolée -- cookies, localStorage et état réseau séparés. C'est ainsi que tu simules deux utilisateurs connectés dans un seul test sans lancer un second navigateur.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('alice sends a message and bob sees it', async ({ browser }) => {
  // Create two isolated contexts
  const aliceContext = await browser.newContext({ storageState: 'auth/alice.json' });
  const bobContext = await browser.newContext({ storageState: 'auth/bob.json' });

  const alicePage = await aliceContext.newPage();
  const bobPage = await bobContext.newPage();

  // Both navigate to the same chat room
  await alicePage.goto('/chat/general');
  await bobPage.goto('/chat/general');

  // Alice sends a message
  await alicePage.getByRole('textbox', { name: 'Message' }).fill('Hello Bob!');
  await alicePage.getByRole('button', { name: 'Send' }).click();

  // Bob sees it in real time
  await expect(bobPage.getByText('Hello Bob!')).toBeVisible();

  // Alice also sees her own message
  await expect(alicePage.getByText('Hello Bob!')).toBeVisible();

  // Cleanup
  await aliceContext.close();
  await bobContext.close();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('alice sends a message and bob sees it', async ({ browser }) => {
  const aliceContext = await browser.newContext({ storageState: 'auth/alice.json' });
  const bobContext = await browser.newContext({ storageState: 'auth/bob.json' });

  const alicePage = await aliceContext.newPage();
  const bobPage = await bobContext.newPage();

  await alicePage.goto('/chat/general');
  await bobPage.goto('/chat/general');

  await alicePage.getByRole('textbox', { name: 'Message' }).fill('Hello Bob!');
  await alicePage.getByRole('button', { name: 'Send' }).click();

  await expect(bobPage.getByText('Hello Bob!')).toBeVisible();
  await expect(alicePage.getByText('Hello Bob!')).toBeVisible();

  await aliceContext.close();
  await bobContext.close();
});
```

### Fixture multi-utilisateurs réutilisable

**À utiliser quand** : plusieurs tests ont besoin d'un setup à deux utilisateurs. Encapsule la création des contextes dans une fixture pour éviter le code répétitif.
**À éviter quand** : un seul test a besoin de la logique multi-utilisateurs.

**TypeScript**
```typescript
// fixtures.ts
import { test as base, expect, BrowserContext, Page } from '@playwright/test';

type MultiUserFixtures = {
  aliceContext: BrowserContext;
  alicePage: Page;
  bobContext: BrowserContext;
  bobPage: Page;
};

export const test = base.extend<MultiUserFixtures>({
  aliceContext: async ({ browser }, use) => {
    const context = await browser.newContext({ storageState: 'auth/alice.json' });
    await use(context);
    await context.close();
  },
  alicePage: async ({ aliceContext }, use) => {
    const page = await aliceContext.newPage();
    await use(page);
  },
  bobContext: async ({ browser }, use) => {
    const context = await browser.newContext({ storageState: 'auth/bob.json' });
    await use(context);
    await context.close();
  },
  bobPage: async ({ bobContext }, use) => {
    const page = await bobContext.newPage();
    await use(page);
  },
});

export { expect };
```

```typescript
// collaboration.spec.ts
import { test, expect } from './fixtures';

test('both users see shared document title', async ({ alicePage, bobPage }) => {
  await alicePage.goto('/docs/shared-doc');
  await bobPage.goto('/docs/shared-doc');

  await alicePage.getByRole('textbox', { name: 'Title' }).fill('Project Plan');

  await expect(bobPage.getByRole('textbox', { name: 'Title' })).toHaveValue('Project Plan');
});
```

**JavaScript**
```javascript
// fixtures.js
const { test: base, expect } = require('@playwright/test');

const test = base.extend({
  aliceContext: async ({ browser }, use) => {
    const context = await browser.newContext({ storageState: 'auth/alice.json' });
    await use(context);
    await context.close();
  },
  alicePage: async ({ aliceContext }, use) => {
    const page = await aliceContext.newPage();
    await use(page);
  },
  bobContext: async ({ browser }, use) => {
    const context = await browser.newContext({ storageState: 'auth/bob.json' });
    await use(context);
    await context.close();
  },
  bobPage: async ({ bobContext }, use) => {
    const page = await bobContext.newPage();
    await use(page);
  },
});

module.exports = { test, expect };
```

### Édition collaborative avec détection de conflits

**À utiliser quand** : tu testes des éditeurs collaboratifs temps réel (style Google Docs) où les deux utilisateurs modifient le même contenu.
**À éviter quand** : ton application ne gère pas l'édition concurrente.

**TypeScript**
```typescript
import { test, expect } from './fixtures';

test('concurrent edits merge without data loss', async ({ alicePage, bobPage }) => {
  await alicePage.goto('/docs/shared-doc');
  await bobPage.goto('/docs/shared-doc');

  // Wait for both to be connected
  await expect(alicePage.getByTestId('connection-status')).toHaveText('Connected');
  await expect(bobPage.getByTestId('connection-status')).toHaveText('Connected');

  // Alice types at the beginning
  const aliceEditor = alicePage.getByRole('textbox', { name: 'Editor' });
  await aliceEditor.pressSequentially('Alice was here. ');

  // Bob types at the end (simultaneously)
  const bobEditor = bobPage.getByRole('textbox', { name: 'Editor' });
  await bobEditor.press('End');
  await bobEditor.pressSequentially('Bob was here.');

  // Both edits should be visible to both users
  await expect(aliceEditor).toContainText('Alice was here.');
  await expect(aliceEditor).toContainText('Bob was here.');
  await expect(bobEditor).toContainText('Alice was here.');
  await expect(bobEditor).toContainText('Bob was here.');
});
```

**JavaScript**
```javascript
const { test, expect } = require('./fixtures');

test('concurrent edits merge without data loss', async ({ alicePage, bobPage }) => {
  await alicePage.goto('/docs/shared-doc');
  await bobPage.goto('/docs/shared-doc');

  await expect(alicePage.getByTestId('connection-status')).toHaveText('Connected');
  await expect(bobPage.getByTestId('connection-status')).toHaveText('Connected');

  const aliceEditor = alicePage.getByRole('textbox', { name: 'Editor' });
  await aliceEditor.pressSequentially('Alice was here. ');

  const bobEditor = bobPage.getByRole('textbox', { name: 'Editor' });
  await bobEditor.press('End');
  await bobEditor.pressSequentially('Bob was here.');

  await expect(aliceEditor).toContainText('Alice was here.');
  await expect(aliceEditor).toContainText('Bob was here.');
  await expect(bobEditor).toContainText('Alice was here.');
  await expect(bobEditor).toContainText('Bob was here.');
});
```

### Vérification de l'état partagé (présence, curseurs, indicateurs)

**À utiliser quand** : tu vérifies que la présence ou l'activité d'un utilisateur se reflète dans l'UI d'un autre -- indicateurs en ligne, indicateurs de saisie, positions de curseur.
**À éviter quand** : la présence n'est pas une fonctionnalité de ton application.

**TypeScript**
```typescript
import { test, expect } from './fixtures';

test('bob sees alice typing indicator', async ({ alicePage, bobPage }) => {
  await alicePage.goto('/chat/general');
  await bobPage.goto('/chat/general');

  // Alice starts typing
  await alicePage.getByRole('textbox', { name: 'Message' }).pressSequentially('Hel', { delay: 100 });

  // Bob sees the typing indicator
  await expect(bobPage.getByText('Alice is typing...')).toBeVisible();

  // Alice stops typing — indicator disappears after debounce
  await expect(bobPage.getByText('Alice is typing...')).toBeHidden({ timeout: 5000 });
});

test('online users list updates when user joins', async ({ alicePage, bobPage }) => {
  await alicePage.goto('/chat/general');

  // Alice sees only herself
  await expect(alicePage.getByTestId('online-users').getByText('Alice')).toBeVisible();
  await expect(alicePage.getByTestId('online-users').getByText('Bob')).toBeHidden();

  // Bob joins
  await bobPage.goto('/chat/general');

  // Alice now sees Bob in the online list
  await expect(alicePage.getByTestId('online-users').getByText('Bob')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('./fixtures');

test('bob sees alice typing indicator', async ({ alicePage, bobPage }) => {
  await alicePage.goto('/chat/general');
  await bobPage.goto('/chat/general');

  await alicePage.getByRole('textbox', { name: 'Message' }).pressSequentially('Hel', { delay: 100 });
  await expect(bobPage.getByText('Alice is typing...')).toBeVisible();
  await expect(bobPage.getByText('Alice is typing...')).toBeHidden({ timeout: 5000 });
});

test('online users list updates when user joins', async ({ alicePage, bobPage }) => {
  await alicePage.goto('/chat/general');
  await expect(alicePage.getByTestId('online-users').getByText('Alice')).toBeVisible();

  await bobPage.goto('/chat/general');
  await expect(alicePage.getByTestId('online-users').getByText('Bob')).toBeVisible();
});
```

### Tests de race conditions entre utilisateurs

**À utiliser quand** : tu dois vérifier que des actions simultanées (deux utilisateurs cliquant sur « acheter » pour le dernier article, ou deux utilisateurs modifiant le même champ) sont gérées correctement.
**À éviter quand** : ton application n'a pas de ressources modifiables partagées.

**TypeScript**
```typescript
import { test, expect } from './fixtures';

test('only one user can claim the last item', async ({ alicePage, bobPage }) => {
  await alicePage.goto('/store/limited-item');
  await bobPage.goto('/store/limited-item');

  // Both see the item is available
  await expect(alicePage.getByText('1 remaining')).toBeVisible();
  await expect(bobPage.getByText('1 remaining')).toBeVisible();

  // Both click buy at approximately the same time
  const aliceBuy = alicePage.getByRole('button', { name: 'Buy now' }).click();
  const bobBuy = bobPage.getByRole('button', { name: 'Buy now' }).click();
  await Promise.all([aliceBuy, bobBuy]);

  // One succeeds, one fails — verify the app handles the race
  const aliceResult = await alicePage.getByTestId('purchase-result').textContent();
  const bobResult = await bobPage.getByTestId('purchase-result').textContent();

  const results = [aliceResult, bobResult];
  expect(results).toContain('Purchase successful');
  expect(results).toContain('Item no longer available');
});

test('simultaneous form submissions do not create duplicates', async ({ alicePage, bobPage }) => {
  await alicePage.goto('/admin/settings');
  await bobPage.goto('/admin/settings');

  // Both change the same setting
  await alicePage.getByLabel('Company name').fill('Alice Corp');
  await bobPage.getByLabel('Company name').fill('Bob Inc');

  // Submit simultaneously
  await Promise.all([
    alicePage.getByRole('button', { name: 'Save' }).click(),
    bobPage.getByRole('button', { name: 'Save' }).click(),
  ]);

  // Reload both pages — one value should win, no corruption
  await alicePage.reload();
  const finalValue = await alicePage.getByLabel('Company name').inputValue();
  expect(['Alice Corp', 'Bob Inc']).toContain(finalValue);

  // The "loser" should see a conflict notification or the updated value
  await bobPage.reload();
  await expect(bobPage.getByLabel('Company name')).toHaveValue(finalValue);
});
```

**JavaScript**
```javascript
const { test, expect } = require('./fixtures');

test('only one user can claim the last item', async ({ alicePage, bobPage }) => {
  await alicePage.goto('/store/limited-item');
  await bobPage.goto('/store/limited-item');

  await expect(alicePage.getByText('1 remaining')).toBeVisible();
  await expect(bobPage.getByText('1 remaining')).toBeVisible();

  const aliceBuy = alicePage.getByRole('button', { name: 'Buy now' }).click();
  const bobBuy = bobPage.getByRole('button', { name: 'Buy now' }).click();
  await Promise.all([aliceBuy, bobBuy]);

  const aliceResult = await alicePage.getByTestId('purchase-result').textContent();
  const bobResult = await bobPage.getByTestId('purchase-result').textContent();

  const results = [aliceResult, bobResult];
  expect(results).toContain('Purchase successful');
  expect(results).toContain('Item no longer available');
});
```

### N utilisateurs avec création dynamique de contextes

**À utiliser quand** : tu as besoin de plus de deux utilisateurs, ou que le nombre d'utilisateurs est variable (tests de collaboration de type charge).
**À éviter quand** : deux utilisateurs suffisent. Reste simple.

**TypeScript**
```typescript
import { test, expect, Browser, Page } from '@playwright/test';

async function createUser(browser: Browser, name: string, room: string): Promise<Page> {
  const context = await browser.newContext({ storageState: `auth/${name}.json` });
  const page = await context.newPage();
  await page.goto(`/chat/${room}`);
  return page;
}

test('five users in a chat room all see each other', async ({ browser }) => {
  const names = ['alice', 'bob', 'charlie', 'diana', 'eve'];
  const pages = await Promise.all(
    names.map((name) => createUser(browser, name, 'team-room'))
  );

  // First user sends a message
  await pages[0].getByRole('textbox', { name: 'Message' }).fill('Hello everyone!');
  await pages[0].getByRole('button', { name: 'Send' }).click();

  // All users see the message
  for (const page of pages) {
    await expect(page.getByText('Hello everyone!')).toBeVisible();
  }

  // Cleanup
  for (const page of pages) {
    await page.context().close();
  }
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

async function createUser(browser, name, room) {
  const context = await browser.newContext({ storageState: `auth/${name}.json` });
  const page = await context.newPage();
  await page.goto(`/chat/${room}`);
  return page;
}

test('five users in a chat room all see each other', async ({ browser }) => {
  const names = ['alice', 'bob', 'charlie', 'diana', 'eve'];
  const pages = await Promise.all(
    names.map((name) => createUser(browser, name, 'team-room'))
  );

  await pages[0].getByRole('textbox', { name: 'Message' }).fill('Hello everyone!');
  await pages[0].getByRole('button', { name: 'Send' }).click();

  for (const page of pages) {
    await expect(page.getByText('Hello everyone!')).toBeVisible();
  }

  for (const page of pages) {
    await page.context().close();
  }
});
```

## Guide de décision

| Scénario | Approche | Pourquoi |
|---|---|---|
| Deux utilisateurs interagissent en temps réel | Deux `browser.newContext()` dans un seul test | Sessions totalement isolées, même chronologie de test |
| Même setup multi-utilisateurs dans de nombreux tests | Fixture personnalisée par contexte utilisateur | Élimine le code répétitif, garantit le nettoyage |
| Tester la présence / les indicateurs de saisie | Actions séquentielles, assertion sur l'autre page | L'ordre compte -- agir sur l'une, asserter sur l'autre |
| Race condition (clics simultanés) | `Promise.all([action1, action2])` | Déclenche les deux aussi simultanément que possible |
| Un admin effectue une action, l'utilisateur voit le résultat | Deux contextes avec des `storageState` différents | Rôles d'authentification différents, même instance de navigateur |
| 3 utilisateurs ou plus dans un test | Boucle avec un `browser.newContext()` par utilisateur | Chaque contexte est léger ; le navigateur est partagé |
| Multi-utilisateurs cross-browser (Chrome + Firefox) | Lancements de navigateurs séparés dans `beforeAll` | Rarement nécessaire ; des contextes au sein d'un même navigateur suffisent |

## Anti-patterns

| À ne pas faire | Problème | À faire plutôt |
|---|---|---|
| Utiliser un contexte avec deux pages pour deux utilisateurs | Les pages d'un même contexte partagent cookies et localStorage | Utiliser `browser.newContext()` par utilisateur |
| Ouvrir un second navigateur pour le second utilisateur | Gaspille de la mémoire et du temps de démarrage | Utiliser un second `browser.newContext()` -- les contextes sont légers |
| `await page.waitForTimeout(2000)` pour la synchro temps réel | Délai arbitraire ; flaky en CI, lent en dev | `await expect(bobPage.getByText('msg')).toBeVisible()` |
| Partager un état mutable via des variables `let` entre contextes | L'ordre et le timing des tests deviennent des dépendances implicites | Chaque contexte est indépendant ; asserter via l'UI |
| Mettre le setup multi-utilisateurs dans `beforeAll` | `beforeAll` n'a pas accès à `page` ni à `context` | Utiliser des fixtures à portée test ou un `browser.newContext()` inline |
| Oublier de fermer les contextes supplémentaires | Fuite de mémoire et risque d'épuisement des ports | Toujours fermer les contextes dans le teardown de la fixture ou dans un `finally` |
| Asserter sur les deux pages sans attendre | La seconde page n'a peut-être pas encore reçu la mise à jour | Utiliser `expect` avec retry automatique sur la page qui reçoit |

## Dépannage

| Symptôme | Cause | Correction |
|---|---|---|
| Le second utilisateur voit des données obsolètes | Contexte créé avant que l'état du serveur soit prêt | Naviguer avec la seconde page après la fin de l'action du premier utilisateur |
| Fichier `storageState` introuvable | Le projet de setup d'authentification n'a pas tourné, ou le chemin est faux | Lancer d'abord le setup d'auth via `dependencies` dans `playwright.config` |
| Les deux utilisateurs ont la même session | Réutilisation du même fichier `storageState` pour les deux | Créer des fichiers d'état d'authentification distincts par rôle d'utilisateur |
| Les mises à jour temps réel n'arrivent jamais sur la seconde page | Connexion WebSocket/SSE non établie avant l'assertion | Attendre un indicateur de connexion avant d'asserter : `await expect(page.getByTestId('connected')).toBeVisible()` |
| Le test est lent avec de nombreux contextes | Trop de contextes dans un seul test (10 ou plus) | Limiter à 3-5 contextes par test ; utiliser un setup par API pour réduire les interactions avec les pages |
| Le test de race avec `Promise.all` a toujours le même gagnant | Le réseau / l'event loop rend l'un toujours plus rapide | C'est attendu en test -- asserter que l'application gère les deux issues, pas quel utilisateur gagne |

## Voir aussi

- [core/fixtures-and-hooks.md](fixtures-and-hooks.md) -- encapsuler les contextes multi-utilisateurs dans des fixtures
- [core/websockets-and-realtime.md](websockets-and-realtime.md) -- tester la couche de transport sous les fonctionnalités de collaboration
- [core/test-data-management.md](test-data-management.md) -- préparer les ressources partagées (salons, documents) avant les tests multi-utilisateurs
- [core/configuration.md](configuration.md) -- configurer `storageState` par projet pour différents rôles d'utilisateurs
