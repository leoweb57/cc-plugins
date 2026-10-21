# États d'erreur et cas limites

> **Quand l'utiliser** : Tester la façon dont ton application gère les erreurs, les échecs, les conditions aux limites et les comportements inhabituels de l'utilisateur. Ces tests détectent des bugs que les tests du chemin nominal manquent.
> **Prérequis** : [core/assertions-and-waiting.md](assertions-and-waiting.md), [core/network-mocking.md](network-mocking.md) pour l'interception de routes

## Référence rapide

```typescript
// Mock a 500 server error
await page.route('**/api/data', (route) => route.fulfill({ status: 500 }));

// Simulate offline mode
await page.context().setOffline(true);

// Test empty state
await page.route('**/api/items', (route) =>
  route.fulfill({ status: 200, json: [] })
);

// Browser back/forward
await page.goBack();
await page.goForward();

// Abort a network request (simulate network failure)
await page.route('**/api/save', (route) => route.abort('connectionfailed'));
```

## Patterns

### Codes de statut d'erreur HTTP

**Utilise quand** : Tu testes que ton application affiche des pages ou messages d'erreur appropriés pour les réponses 4xx et 5xx.
**Évite quand** : L'erreur est gérée silencieusement (aucun retour visible pour l'utilisateur). Teste plutôt via l'API ou les logs.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('displays 404 page for missing resources', async ({ page }) => {
  // Navigate directly to a non-existent URL
  await page.goto('/this-page-does-not-exist');

  await expect(page.getByRole('heading', { name: /not found/i })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Go home' })).toBeVisible();
});

test('handles 500 server error gracefully', async ({ page }) => {
  // Intercept the API call and return a 500
  await page.route('**/api/dashboard', (route) =>
    route.fulfill({
      status: 500,
      contentType: 'application/json',
      body: JSON.stringify({ error: 'Internal server error' }),
    })
  );

  await page.goto('/dashboard');

  await expect(page.getByText('Something went wrong')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Try again' })).toBeVisible();
});

test('handles 403 forbidden with redirect to login', async ({ page }) => {
  await page.route('**/api/admin/**', (route) =>
    route.fulfill({ status: 403 })
  );

  await page.goto('/admin/settings');

  // Should redirect to login or show access denied
  await expect(page.getByText(/access denied|not authorized/i)).toBeVisible();
});

test('handles 429 rate limiting', async ({ page }) => {
  await page.route('**/api/search*', (route) =>
    route.fulfill({
      status: 429,
      headers: { 'Retry-After': '30' },
      body: JSON.stringify({ error: 'Too many requests' }),
    })
  );

  await page.goto('/search');
  await page.getByLabel('Search').fill('test');
  await page.getByRole('button', { name: 'Search' }).click();

  await expect(page.getByText(/too many requests|try again later/i)).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('displays 404 page for missing resources', async ({ page }) => {
  await page.goto('/this-page-does-not-exist');

  await expect(page.getByRole('heading', { name: /not found/i })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Go home' })).toBeVisible();
});

test('handles 500 server error gracefully', async ({ page }) => {
  await page.route('**/api/dashboard', (route) =>
    route.fulfill({
      status: 500,
      contentType: 'application/json',
      body: JSON.stringify({ error: 'Internal server error' }),
    })
  );

  await page.goto('/dashboard');

  await expect(page.getByText('Something went wrong')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Try again' })).toBeVisible();
});

test('handles 403 forbidden with redirect to login', async ({ page }) => {
  await page.route('**/api/admin/**', (route) =>
    route.fulfill({ status: 403 })
  );

  await page.goto('/admin/settings');
  await expect(page.getByText(/access denied|not authorized/i)).toBeVisible();
});

test('handles 429 rate limiting', async ({ page }) => {
  await page.route('**/api/search*', (route) =>
    route.fulfill({
      status: 429,
      headers: { 'Retry-After': '30' },
      body: JSON.stringify({ error: 'Too many requests' }),
    })
  );

  await page.goto('/search');
  await page.getByLabel('Search').fill('test');
  await page.getByRole('button', { name: 'Search' }).click();

  await expect(page.getByText(/too many requests|try again later/i)).toBeVisible();
});
```

### Défaillance réseau et mode hors ligne

**Utilise quand** : Tu testes le comportement de l'application quand le réseau est coupé, que des requêtes échouent ou que la connexion est intermittente.
**Évite quand** : L'application n'a aucun comportement hors ligne ni de gestion d'erreur à tester.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('offline mode shows offline banner', async ({ page }) => {
  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  // Go offline
  await page.context().setOffline(true);

  // Trigger a network-dependent action
  await page.getByRole('button', { name: 'Refresh' }).click();

  await expect(page.getByText(/offline|no connection/i)).toBeVisible();

  // Go back online
  await page.context().setOffline(false);

  await page.getByRole('button', { name: 'Refresh' }).click();
  await expect(page.getByText(/offline|no connection/i)).not.toBeVisible();
});

test('network request failure shows error state', async ({ page }) => {
  // Abort specific requests to simulate network failure
  await page.route('**/api/user/profile', (route) =>
    route.abort('connectionfailed')
  );

  await page.goto('/profile');

  await expect(page.getByText('Failed to load profile')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Retry' })).toBeVisible();
});

test('request timeout shows timeout message', async ({ page }) => {
  // Delay the response beyond the app's timeout threshold
  await page.route('**/api/reports', async (route) => {
    await new Promise((resolve) => setTimeout(resolve, 30_000));
    await route.fulfill({ status: 200, json: { data: [] } });
  });

  await page.goto('/reports');

  // App should show timeout message before Playwright's own timeout
  await expect(page.getByText(/timed out|taking too long/i)).toBeVisible({
    timeout: 20_000,
  });
});

test('intermittent connectivity — request fails then succeeds', async ({ page }) => {
  let requestCount = 0;

  await page.route('**/api/data', (route) => {
    requestCount++;
    if (requestCount <= 2) {
      return route.abort('connectionfailed');
    }
    return route.fulfill({ status: 200, json: { items: ['a', 'b', 'c'] } });
  });

  await page.goto('/data');

  // First load fails
  await expect(page.getByText(/failed|error/i)).toBeVisible();

  // User retries — still fails
  await page.getByRole('button', { name: 'Retry' }).click();
  await expect(page.getByText(/failed|error/i)).toBeVisible();

  // Third attempt succeeds
  await page.getByRole('button', { name: 'Retry' }).click();
  await expect(page.getByRole('listitem')).toHaveCount(3);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('offline mode shows offline banner', async ({ page }) => {
  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  await page.context().setOffline(true);

  await page.getByRole('button', { name: 'Refresh' }).click();
  await expect(page.getByText(/offline|no connection/i)).toBeVisible();

  await page.context().setOffline(false);

  await page.getByRole('button', { name: 'Refresh' }).click();
  await expect(page.getByText(/offline|no connection/i)).not.toBeVisible();
});

test('network request failure shows error state', async ({ page }) => {
  await page.route('**/api/user/profile', (route) =>
    route.abort('connectionfailed')
  );

  await page.goto('/profile');

  await expect(page.getByText('Failed to load profile')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Retry' })).toBeVisible();
});

test('intermittent connectivity — request fails then succeeds', async ({ page }) => {
  let requestCount = 0;

  await page.route('**/api/data', (route) => {
    requestCount++;
    if (requestCount <= 2) {
      return route.abort('connectionfailed');
    }
    return route.fulfill({ status: 200, json: { items: ['a', 'b', 'c'] } });
  });

  await page.goto('/data');

  await expect(page.getByText(/failed|error/i)).toBeVisible();

  await page.getByRole('button', { name: 'Retry' }).click();
  await expect(page.getByText(/failed|error/i)).toBeVisible();

  await page.getByRole('button', { name: 'Retry' }).click();
  await expect(page.getByRole('listitem')).toHaveCount(3);
});
```

### Abandonner sur des requêtes inattendues (`test.abort()`, Playwright 1.60+)

**Utilise quand** : Un route handler voit passer une requête qui ne devrait *jamais* arriver (appel à un endpoint interdit, requête tierce qui fuite, mock manquant), et tu préfères échouer bruyamment à la source plutôt que de traquer une assertion en aval déroutante.
**Évite quand** : Tu peux asserter la condition dans le corps du test -- utilise `expect()` là-bas. `test.abort()` est utile dans les route handlers et les fixtures, qui s'exécutent hors du corps du test.

Playwright 1.60 ajoute `test.abort(message?)` pour arrêter immédiatement le test en cours avec un message clair, depuis un route handler ou une fixture.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('fails fast if the app calls a forbidden endpoint', async ({ page }) => {
  await page.route('**/api/**', (route) => {
    const url = route.request().url();
    if (url.includes('/api/admin/delete-all')) {
      // Stop now with a precise message instead of letting the page error out
      test.abort(`Blocked dangerous request: ${url}`);
    }
    return route.continue();
  });

  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('fails fast if the app calls a forbidden endpoint', async ({ page }) => {
  await page.route('**/api/**', (route) => {
    if (route.request().url().includes('/api/admin/delete-all')) {
      test.abort('Blocked dangerous request');
    }
    return route.continue();
  });

  await page.goto('/dashboard');
});
```

Voir [core/fixtures-and-hooks.md](fixtures-and-hooks.md) pour l'abandon depuis le setup d'une fixture.

### États vides et tests aux limites

**Utilise quand** : Tu testes ce que l'UI affiche quand il n'y a aucune donnée, quand les entrées sont à leur valeur minimale ou maximale, ou quand elles contiennent des caractères spéciaux.
**Évite quand** : Jamais. Chaque fonctionnalité devrait avoir des tests d'état vide et de limites.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('empty state is shown when no items exist', async ({ page }) => {
  // Mock an empty response
  await page.route('**/api/tasks', (route) =>
    route.fulfill({ status: 200, json: [] })
  );

  await page.goto('/tasks');

  await expect(page.getByText('No tasks yet')).toBeVisible();
  await expect(page.getByRole('link', { name: 'Create your first task' })).toBeVisible();

  // List elements should not be present
  await expect(page.getByRole('listitem')).toHaveCount(0);
});

test('handles maximum length input', async ({ page }) => {
  await page.goto('/profile');

  // Fill with max-length string
  const maxLengthName = 'A'.repeat(255);
  await page.getByLabel('Display name').fill(maxLengthName);
  await page.getByRole('button', { name: 'Save' }).click();

  // Verify the name was saved (or truncated, depending on app behavior)
  await expect(page.getByText('Profile updated')).toBeVisible();
});

test('handles special characters in input', async ({ page }) => {
  await page.goto('/search');

  const specialInputs = [
    '<script>alert("xss")</script>',
    '"; DROP TABLE users; --',
    'unicode: \u00e9\u00e0\u00fc\u00f1 \u4f60\u597d \ud83d\ude80',
    'null bytes: \x00\x01\x02',
    'path traversal: ../../etc/passwd',
  ];

  for (const input of specialInputs) {
    await page.getByLabel('Search').fill(input);
    await page.getByRole('button', { name: 'Search' }).click();

    // App should not crash — either show results or "no results"
    await expect(
      page.getByText(/results|no results|no matches/i)
    ).toBeVisible();
  }
});

test('handles zero, one, and many items (0-1-N pattern)', async ({ page }) => {
  // Zero items
  await page.route('**/api/notifications', (route) =>
    route.fulfill({ status: 200, json: [] })
  );
  await page.goto('/notifications');
  await expect(page.getByText('No notifications')).toBeVisible();

  // One item
  await page.route('**/api/notifications', (route) =>
    route.fulfill({
      status: 200,
      json: [{ id: 1, message: 'Welcome!' }],
    })
  );
  await page.reload();
  await expect(page.getByRole('listitem')).toHaveCount(1);
  await expect(page.getByText('No notifications')).not.toBeVisible();

  // Many items — verify pagination or "load more"
  await page.route('**/api/notifications', (route) =>
    route.fulfill({
      status: 200,
      json: Array.from({ length: 50 }, (_, i) => ({
        id: i + 1,
        message: `Notification ${i + 1}`,
      })),
    })
  );
  await page.reload();
  await expect(page.getByRole('listitem').first()).toBeVisible();
  await expect(page.getByRole('button', { name: /load more|show all/i })).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('empty state is shown when no items exist', async ({ page }) => {
  await page.route('**/api/tasks', (route) =>
    route.fulfill({ status: 200, json: [] })
  );

  await page.goto('/tasks');

  await expect(page.getByText('No tasks yet')).toBeVisible();
  await expect(page.getByRole('link', { name: 'Create your first task' })).toBeVisible();
  await expect(page.getByRole('listitem')).toHaveCount(0);
});

test('handles maximum length input', async ({ page }) => {
  await page.goto('/profile');

  const maxLengthName = 'A'.repeat(255);
  await page.getByLabel('Display name').fill(maxLengthName);
  await page.getByRole('button', { name: 'Save' }).click();

  await expect(page.getByText('Profile updated')).toBeVisible();
});

test('handles special characters in input', async ({ page }) => {
  await page.goto('/search');

  const specialInputs = [
    '<script>alert("xss")</script>',
    '"; DROP TABLE users; --',
    'unicode: \u00e9\u00e0\u00fc\u00f1 \u4f60\u597d \ud83d\ude80',
    'path traversal: ../../etc/passwd',
  ];

  for (const input of specialInputs) {
    await page.getByLabel('Search').fill(input);
    await page.getByRole('button', { name: 'Search' }).click();

    await expect(
      page.getByText(/results|no results|no matches/i)
    ).toBeVisible();
  }
});

test('handles zero, one, and many items (0-1-N pattern)', async ({ page }) => {
  await page.route('**/api/notifications', (route) =>
    route.fulfill({ status: 200, json: [] })
  );
  await page.goto('/notifications');
  await expect(page.getByText('No notifications')).toBeVisible();

  await page.route('**/api/notifications', (route) =>
    route.fulfill({
      status: 200,
      json: [{ id: 1, message: 'Welcome!' }],
    })
  );
  await page.reload();
  await expect(page.getByRole('listitem')).toHaveCount(1);

  await page.route('**/api/notifications', (route) =>
    route.fulfill({
      status: 200,
      json: Array.from({ length: 50 }, (_, i) => ({
        id: i + 1,
        message: `Notification ${i + 1}`,
      })),
    })
  );
  await page.reload();
  await expect(page.getByRole('listitem').first()).toBeVisible();
  await expect(page.getByRole('button', { name: /load more|show all/i })).toBeVisible();
});
```

### États de chargement et skeletons

**Utilise quand** : Tu vérifies que les indicateurs de chargement, les skeleton screens ou les spinners apparaissent pendant la récupération des données et disparaissent à leur arrivée.
**Évite quand** : L'application s'affiche de façon synchrone sans indicateur de chargement (SSR sans fetching côté client).

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('loading skeleton appears and resolves', async ({ page }) => {
  // Delay the API response to observe the loading state
  let resolveResponse: () => void;
  const responseReady = new Promise<void>((resolve) => {
    resolveResponse = resolve;
  });

  await page.route('**/api/dashboard', async (route) => {
    await responseReady;
    await route.fulfill({
      status: 200,
      json: { revenue: 12400, users: 350 },
    });
  });

  await page.goto('/dashboard');

  // Skeleton should be visible while loading
  await expect(page.getByTestId('skeleton-revenue')).toBeVisible();
  await expect(page.getByTestId('skeleton-users')).toBeVisible();

  // Real content should not be visible yet
  await expect(page.getByText('$12,400')).not.toBeVisible();

  // Release the response
  resolveResponse!();

  // Skeleton disappears, real content appears
  await expect(page.getByTestId('skeleton-revenue')).not.toBeVisible();
  await expect(page.getByText('$12,400')).toBeVisible();
  await expect(page.getByText('350')).toBeVisible();
});

test('spinner shown during form submission', async ({ page }) => {
  let resolveSubmit: () => void;
  const submitReady = new Promise<void>((resolve) => {
    resolveSubmit = resolve;
  });

  await page.route('**/api/contact', async (route) => {
    await submitReady;
    await route.fulfill({ status: 200, json: { success: true } });
  });

  await page.goto('/contact');
  await page.getByLabel('Name').fill('Jane');
  await page.getByLabel('Email').fill('jane@example.com');
  await page.getByLabel('Message').fill('Test');

  await page.getByRole('button', { name: 'Send' }).click();

  // Loading spinner/state during submission
  await expect(page.getByRole('button', { name: /sending/i })).toBeVisible();
  await expect(page.getByRole('button', { name: /sending/i })).toBeDisabled();

  // Complete the submission
  resolveSubmit!();

  await expect(page.getByText('Message sent')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('loading skeleton appears and resolves', async ({ page }) => {
  let resolveResponse;
  const responseReady = new Promise((resolve) => {
    resolveResponse = resolve;
  });

  await page.route('**/api/dashboard', async (route) => {
    await responseReady;
    await route.fulfill({
      status: 200,
      json: { revenue: 12400, users: 350 },
    });
  });

  await page.goto('/dashboard');

  await expect(page.getByTestId('skeleton-revenue')).toBeVisible();
  await expect(page.getByTestId('skeleton-users')).toBeVisible();
  await expect(page.getByText('$12,400')).not.toBeVisible();

  resolveResponse();

  await expect(page.getByTestId('skeleton-revenue')).not.toBeVisible();
  await expect(page.getByText('$12,400')).toBeVisible();
  await expect(page.getByText('350')).toBeVisible();
});

test('spinner shown during form submission', async ({ page }) => {
  let resolveSubmit;
  const submitReady = new Promise((resolve) => {
    resolveSubmit = resolve;
  });

  await page.route('**/api/contact', async (route) => {
    await submitReady;
    await route.fulfill({ status: 200, json: { success: true } });
  });

  await page.goto('/contact');
  await page.getByLabel('Name').fill('Jane');
  await page.getByLabel('Email').fill('jane@example.com');
  await page.getByLabel('Message').fill('Test');

  await page.getByRole('button', { name: 'Send' }).click();

  await expect(page.getByRole('button', { name: /sending/i })).toBeVisible();
  await expect(page.getByRole('button', { name: /sending/i })).toBeDisabled();

  resolveSubmit();

  await expect(page.getByText('Message sent')).toBeVisible();
});
```

### Tester le comportement de retry

**Utilise quand** : Tu testes que l'application réessaie automatiquement les requêtes échouées, ou via un bouton « réessayer » déclenché par l'utilisateur.
**Évite quand** : L'application n'a aucun mécanisme de retry.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('retry button recovers from a failed API call', async ({ page }) => {
  let callCount = 0;

  await page.route('**/api/feed', (route) => {
    callCount++;
    if (callCount === 1) {
      return route.fulfill({ status: 500 });
    }
    return route.fulfill({
      status: 200,
      json: { posts: [{ id: 1, title: 'Hello World' }] },
    });
  });

  await page.goto('/feed');

  // First load fails
  await expect(page.getByText(/something went wrong/i)).toBeVisible();

  // Click retry — second call succeeds
  await page.getByRole('button', { name: 'Try again' }).click();

  await expect(page.getByText('Hello World')).toBeVisible();
  expect(callCount).toBe(2);
});

test('automatic retry with exponential backoff', async ({ page }) => {
  const callTimestamps: number[] = [];

  await page.route('**/api/status', (route) => {
    callTimestamps.push(Date.now());
    if (callTimestamps.length <= 3) {
      return route.fulfill({ status: 503 });
    }
    return route.fulfill({ status: 200, json: { status: 'ok' } });
  });

  await page.goto('/status');

  // Wait for the auto-retry to eventually succeed
  await expect(page.getByText('System operational')).toBeVisible({
    timeout: 30_000,
  });

  // Verify multiple retry attempts were made
  expect(callTimestamps.length).toBeGreaterThanOrEqual(4);

  // Verify backoff: gaps between retries should increase
  if (callTimestamps.length >= 3) {
    const gap1 = callTimestamps[1] - callTimestamps[0];
    const gap2 = callTimestamps[2] - callTimestamps[1];
    expect(gap2).toBeGreaterThanOrEqual(gap1);
  }
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('retry button recovers from a failed API call', async ({ page }) => {
  let callCount = 0;

  await page.route('**/api/feed', (route) => {
    callCount++;
    if (callCount === 1) {
      return route.fulfill({ status: 500 });
    }
    return route.fulfill({
      status: 200,
      json: { posts: [{ id: 1, title: 'Hello World' }] },
    });
  });

  await page.goto('/feed');

  await expect(page.getByText(/something went wrong/i)).toBeVisible();

  await page.getByRole('button', { name: 'Try again' }).click();

  await expect(page.getByText('Hello World')).toBeVisible();
  expect(callCount).toBe(2);
});

test('automatic retry with exponential backoff', async ({ page }) => {
  const callTimestamps = [];

  await page.route('**/api/status', (route) => {
    callTimestamps.push(Date.now());
    if (callTimestamps.length <= 3) {
      return route.fulfill({ status: 503 });
    }
    return route.fulfill({ status: 200, json: { status: 'ok' } });
  });

  await page.goto('/status');

  await expect(page.getByText('System operational')).toBeVisible({
    timeout: 30_000,
  });

  expect(callTimestamps.length).toBeGreaterThanOrEqual(4);
});
```

### Navigation précédent/suivant du navigateur

**Utilise quand** : Tu testes que l'application gère correctement la navigation dans l'historique du navigateur -- conservation de l'état, mise à jour de l'URL et du contenu après un retour ou une avance.
**Évite quand** : L'application est une single-page application qui n'utilise pas l'API History du navigateur. Concentre-toi plutôt sur des tests de routage côté client.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('browser back preserves navigation context', async ({ page }) => {
  await page.goto('/products');
  await page.getByRole('link', { name: 'Running Shoes' }).click();
  await page.waitForURL('**/products/running-shoes');

  // Go back
  await page.goBack();

  await expect(page).toHaveURL(/\/products$/);
  await expect(page.getByRole('heading', { name: 'Products' })).toBeVisible();
});

test('browser forward returns to previous page', async ({ page }) => {
  await page.goto('/products');
  await page.getByRole('link', { name: 'Running Shoes' }).click();
  await page.waitForURL('**/products/running-shoes');

  await page.goBack();
  await page.goForward();

  await expect(page).toHaveURL(/\/products\/running-shoes/);
  await expect(page.getByRole('heading', { name: 'Running Shoes' })).toBeVisible();
});

test('form state after browser back', async ({ page }) => {
  await page.goto('/checkout');

  // Fill form on step 1
  await page.getByLabel('Address').fill('123 Main St');
  await page.getByRole('button', { name: 'Continue' }).click();

  // Arrived at step 2
  await expect(page.getByRole('heading', { name: 'Payment' })).toBeVisible();

  // Go back to step 1
  await page.goBack();

  // Data should be preserved (depends on app implementation)
  await expect(page.getByLabel('Address')).toHaveValue('123 Main St');
});

test('back button after form submission does not re-submit', async ({ page }) => {
  await page.goto('/contact');

  await page.getByLabel('Name').fill('Jane');
  await page.getByLabel('Email').fill('jane@example.com');
  await page.getByLabel('Message').fill('Test');
  await page.getByRole('button', { name: 'Send' }).click();

  await expect(page.getByText('Message sent')).toBeVisible();

  // Going back should show the form, not re-submit
  await page.goBack();
  await expect(page.getByLabel('Name')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('browser back preserves navigation context', async ({ page }) => {
  await page.goto('/products');
  await page.getByRole('link', { name: 'Running Shoes' }).click();
  await page.waitForURL('**/products/running-shoes');

  await page.goBack();

  await expect(page).toHaveURL(/\/products$/);
  await expect(page.getByRole('heading', { name: 'Products' })).toBeVisible();
});

test('browser forward returns to previous page', async ({ page }) => {
  await page.goto('/products');
  await page.getByRole('link', { name: 'Running Shoes' }).click();
  await page.waitForURL('**/products/running-shoes');

  await page.goBack();
  await page.goForward();

  await expect(page).toHaveURL(/\/products\/running-shoes/);
  await expect(page.getByRole('heading', { name: 'Running Shoes' })).toBeVisible();
});

test('form state after browser back', async ({ page }) => {
  await page.goto('/checkout');

  await page.getByLabel('Address').fill('123 Main St');
  await page.getByRole('button', { name: 'Continue' }).click();

  await expect(page.getByRole('heading', { name: 'Payment' })).toBeVisible();

  await page.goBack();
  await expect(page.getByLabel('Address')).toHaveValue('123 Main St');
});

test('back button after form submission does not re-submit', async ({ page }) => {
  await page.goto('/contact');

  await page.getByLabel('Name').fill('Jane');
  await page.getByLabel('Email').fill('jane@example.com');
  await page.getByLabel('Message').fill('Test');
  await page.getByRole('button', { name: 'Send' }).click();

  await expect(page.getByText('Message sent')).toBeVisible();

  await page.goBack();
  await expect(page.getByLabel('Name')).toBeVisible();
});
```

### Actions utilisateur concurrentes

**Utilise quand** : Tu testes que des interactions rapides de l'utilisateur ne provoquent pas de race conditions -- double-clic sur l'envoi, saisie pendant le chargement des données, navigation pendant une opération asynchrone.
**Évite quand** : L'UI n'a aucune opération asynchrone susceptible d'entrer en conflit avec les actions de l'utilisateur.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('double-click submit does not create duplicate entries', async ({ page }) => {
  const requests: string[] = [];

  await page.route('**/api/orders', (route) => {
    requests.push(route.request().method());
    return route.fulfill({
      status: 201,
      json: { id: 1, status: 'created' },
    });
  });

  await page.goto('/checkout');
  await page.getByLabel('Item').fill('Widget');

  const submitButton = page.getByRole('button', { name: 'Place order' });

  // Rapid double-click
  await submitButton.dblclick();

  // Wait for the result
  await expect(page.getByText('Order confirmed')).toBeVisible();

  // The app should prevent duplicate submissions
  // (button disabled after first click, or server deduplication)
  expect(requests.filter((m) => m === 'POST').length).toBeLessThanOrEqual(1);
});

test('typing during navigation does not crash', async ({ page }) => {
  await page.goto('/search');

  // Start typing and immediately navigate
  await page.getByLabel('Search').pressSequentially('test query', { delay: 30 });
  await page.getByRole('link', { name: 'Home' }).click();

  // Should arrive at home page without errors
  await page.waitForURL('**/');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
});

test('rapid filter changes use latest value', async ({ page }) => {
  const requestUrls: string[] = [];

  await page.route('**/api/products*', (route) => {
    requestUrls.push(route.request().url());
    return route.fulfill({
      status: 200,
      json: { products: [{ name: 'Latest result' }] },
    });
  });

  await page.goto('/products');

  // Rapidly change the filter
  await page.getByLabel('Category').selectOption('electronics');
  await page.getByLabel('Category').selectOption('clothing');
  await page.getByLabel('Category').selectOption('books');

  // Wait for the final result
  await expect(page.getByText('Latest result')).toBeVisible();

  // The UI should show results for "books", not an earlier selection
  // Some apps debounce; some cancel in-flight requests
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('double-click submit does not create duplicate entries', async ({ page }) => {
  const requests = [];

  await page.route('**/api/orders', (route) => {
    requests.push(route.request().method());
    return route.fulfill({
      status: 201,
      json: { id: 1, status: 'created' },
    });
  });

  await page.goto('/checkout');
  await page.getByLabel('Item').fill('Widget');

  const submitButton = page.getByRole('button', { name: 'Place order' });
  await submitButton.dblclick();

  await expect(page.getByText('Order confirmed')).toBeVisible();

  expect(requests.filter((m) => m === 'POST').length).toBeLessThanOrEqual(1);
});

test('typing during navigation does not crash', async ({ page }) => {
  await page.goto('/search');

  await page.getByLabel('Search').pressSequentially('test query', { delay: 30 });
  await page.getByRole('link', { name: 'Home' }).click();

  await page.waitForURL('**/');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
});

test('rapid filter changes use latest value', async ({ page }) => {
  const requestUrls = [];

  await page.route('**/api/products*', (route) => {
    requestUrls.push(route.request().url());
    return route.fulfill({
      status: 200,
      json: { products: [{ name: 'Latest result' }] },
    });
  });

  await page.goto('/products');

  await page.getByLabel('Category').selectOption('electronics');
  await page.getByLabel('Category').selectOption('clothing');
  await page.getByLabel('Category').selectOption('books');

  await expect(page.getByText('Latest result')).toBeVisible();
});
```

### Dégradation gracieuse

**Utilise quand** : Tu testes que l'application continue de fonctionner quand des services non critiques tombent (analytics, widget de chat, recommandations).
**Évite quand** : Le service défaillant est critique pour le parcours principal.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('page works when analytics service fails', async ({ page }) => {
  // Block analytics and tracking scripts
  await page.route('**/analytics/**', (route) => route.abort());
  await page.route('**/tracking/**', (route) => route.abort());

  await page.goto('/products');

  // Core functionality still works
  await expect(page.getByRole('heading', { name: 'Products' })).toBeVisible();
  await page.getByRole('link', { name: 'Running Shoes' }).click();
  await expect(page.getByRole('button', { name: 'Add to cart' })).toBeEnabled();
});

test('page works when recommendation engine fails', async ({ page }) => {
  await page.route('**/api/recommendations', (route) =>
    route.fulfill({ status: 500 })
  );

  await page.goto('/products/running-shoes');

  // Main product content loads
  await expect(page.getByRole('heading', { name: 'Running Shoes' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Add to cart' })).toBeEnabled();

  // Recommendations section shows fallback
  await expect(
    page.getByText(/recommendations unavailable|you may also like/i)
  ).toBeVisible();
});

test('page works when third-party chat widget fails to load', async ({ page }) => {
  // Block the chat widget script
  await page.route('**/chat-widget.js', (route) => route.abort());

  await page.goto('/support');

  // Core support page loads
  await expect(page.getByRole('heading', { name: 'Help Center' })).toBeVisible();

  // No console errors from the blocked widget should crash the page
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));

  // Navigate around to ensure no cascade failures
  await page.getByRole('link', { name: 'FAQ' }).click();
  await expect(page.getByRole('heading', { name: 'FAQ' })).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('page works when analytics service fails', async ({ page }) => {
  await page.route('**/analytics/**', (route) => route.abort());
  await page.route('**/tracking/**', (route) => route.abort());

  await page.goto('/products');

  await expect(page.getByRole('heading', { name: 'Products' })).toBeVisible();
  await page.getByRole('link', { name: 'Running Shoes' }).click();
  await expect(page.getByRole('button', { name: 'Add to cart' })).toBeEnabled();
});

test('page works when recommendation engine fails', async ({ page }) => {
  await page.route('**/api/recommendations', (route) =>
    route.fulfill({ status: 500 })
  );

  await page.goto('/products/running-shoes');

  await expect(page.getByRole('heading', { name: 'Running Shoes' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Add to cart' })).toBeEnabled();
});

test('page works when third-party chat widget fails to load', async ({ page }) => {
  await page.route('**/chat-widget.js', (route) => route.abort());

  await page.goto('/support');

  await expect(page.getByRole('heading', { name: 'Help Center' })).toBeVisible();

  await page.getByRole('link', { name: 'FAQ' }).click();
  await expect(page.getByRole('heading', { name: 'FAQ' })).toBeVisible();
});
```

## Guide de décision

| Scénario | Approche | API clé |
|---|---|---|
| Page 404 | Naviguer vers une URL inexistante, asserter la page d'erreur | `page.goto('/nonexistent')` |
| Erreur serveur 500 | Mocker la route avec `status: 500` | `page.route(url, route => route.fulfill({ status: 500 }))` |
| Défaillance réseau | Abandonner la route | `route.abort('connectionfailed')` |
| Mode hors ligne | Basculer en hors ligne sur le contexte du navigateur | `page.context().setOffline(true)` |
| Réponse lente | Retarder la réponse de la route avec une Promise | `await new Promise(r => setTimeout(r, delay))` dans le route handler |
| État vide | Mocker l'API pour retourner un tableau vide | `route.fulfill({ json: [] })` |
| Valeurs limites | Remplir les inputs avec des valeurs min/max/spéciales | `locator.fill('A'.repeat(255))` |
| Skeleton de chargement | Retarder la route, asserter le skeleton visible, libérer, asserter le contenu | Route handler basé sur une Promise |
| Comportement de retry | Compter les appels de la route, échouer les N premiers, réussir ensuite | Compteur dans le route handler |
| Historique du navigateur | Utiliser `page.goBack()` et `page.goForward()` | Asserter l'URL et le contenu après la navigation |
| Double envoi | `dblclick()` sur le bouton d'envoi, vérifier un seul POST | Suivre les requêtes dans le route handler |
| Défaillance d'un service tiers | Abandonner les routes non critiques, vérifier que le cœur fonctionne | `route.abort()` sur les services optionnels |
| Surveillance des erreurs console | Écouter l'événement `pageerror` | `page.on('pageerror', handler)` |

## Anti-patterns

| À ne pas faire | Problème | À faire plutôt |
|---|---|---|
| Ne tester que le chemin nominal | Les vrais utilisateurs rencontrent des erreurs. Les erreurs en production coûtent plus cher que le temps de test. | Ajouter des tests d'erreurs et de cas limites pour chaque fonctionnalité |
| `page.route('**/*', route => route.abort())` | Bloque TOUTES les requêtes, y compris celle de la page elle-même | Cibler des URLs précises : `page.route('**/api/specific', ...)` |
| Utiliser `page.waitForTimeout()` pour simuler un chargement lent | Arbitraire, flaky, ralentit les tests | Utiliser des route handlers basés sur des promesses pour contrôler précisément le timing |
| Coder en dur les messages d'erreur dans les assertions | Les messages changent. Les tests cassent à chaque retouche de texte. | Utiliser des regex ou des correspondances partielles : `getByText(/error/i)` |
| Tester tous les codes d'erreur dans un seul méga-test | Difficile à déboguer, lent, le premier échec masque les autres | Un test par scénario d'erreur, ou utiliser des groupes `test.describe` |
| Sauter les tests d'état vide | Les états vides sont la première chose que voient les nouveaux utilisateurs ; souvent cassés | Toujours tester l'état à 0 élément en plus de ceux à 1 et N éléments |
| Tester le hors ligne en coupant le vrai réseau | Flaky, affecte les tests parallèles, la CI peut ne pas le supporter | Utiliser `context.setOffline(true)` -- déterministe et scopé |
| Ne pas nettoyer les mocks de routes entre les tests | Les routes persistent sur la page. Le test B hérite des mocks du test A. | Chaque test définit ses propres routes ; Playwright réinitialise entre les tests par défaut |
| Asserter sur les chaînes d'erreur exactes du serveur | Couple les tests aux détails d'implémentation du backend | Asserter le message de l'UI, pas le corps brut de la réponse de l'API |
| Utiliser `try/catch` pour « gérer » des erreurs attendues | Avale de vrais bugs ; le test passe alors qu'il ne devrait pas | Laisser les erreurs se propager ; utiliser le mocking de routes pour contrôler la réponse |

## Dépannage

### Le route handler n'intercepte pas les requêtes

**Cause** : Le pattern d'URL ne correspond pas, ou la route a été enregistrée après la navigation qui déclenche la requête.

```typescript
// Always register routes BEFORE navigating
await page.route('**/api/data', (route) => route.fulfill({ status: 500 }));
await page.goto('/dashboard'); // route is active before the page loads

// Debug: log all requests to find the actual URL pattern
page.on('request', (req) => console.log(req.url()));
```

### `context.setOffline(true)` n'affecte pas le Service Worker

**Cause** : Les Service Workers gèrent le réseau à leur façon. `setOffline` simule le hors ligne au niveau du navigateur, mais un Service Worker peut servir des réponses en cache.

```typescript
// Unregister service workers first
await page.evaluate(async () => {
  const registrations = await navigator.serviceWorker.getRegistrations();
  for (const registration of registrations) {
    await registration.unregister();
  }
});
await page.context().setOffline(true);
```

### Un route handler retardé provoque un timeout du test

**Cause** : La promesse du route handler ne se résout jamais, ou le délai dépasse le timeout du test.

```typescript
// Always ensure the delay is less than the assertion timeout
await page.route('**/api/slow', async (route) => {
  await new Promise((resolve) => setTimeout(resolve, 5_000)); // 5s delay
  await route.fulfill({ status: 200, json: {} });
});

// Increase assertion timeout to account for the artificial delay
await expect(page.getByText('Data loaded')).toBeVisible({ timeout: 10_000 });
```

### `goBack()` ne navigue pas

**Cause** : Il n'y a aucune entrée d'historique vers laquelle revenir. `goBack()` nécessite au moins une navigation précédente.

```typescript
// Ensure there is history before calling goBack
await page.goto('/page-a');
await page.goto('/page-b');
await page.goBack(); // goes to /page-a

// If using SPA client-side routing, goBack may not work if the router
// does not push to browser history. Use the app's own back button instead.
await page.getByRole('button', { name: 'Back' }).click();
```

## Voir aussi

- [core/assertions-and-waiting.md](assertions-and-waiting.md) -- stratégies d'assertion pour les états d'erreur
- [core/network-mocking.md](network-mocking.md) -- patterns détaillés d'interception et de mocking réseau
- [core/forms-and-validation.md](forms-and-validation.md) -- tester les erreurs de validation de formulaire
- [core/flaky-tests.md](flaky-tests.md) -- corriger les problèmes de timing dans les tests d'erreurs et de cas limites
- [core/service-workers-and-pwa.md](service-workers-and-pwa.md) -- patterns de test offline-first et PWA
- [core/multi-context-and-popups.md](multi-context-and-popups.md) -- tester des contextes de navigateur concurrents
