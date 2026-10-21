# Intégrations tierces

> **Quand l'utiliser** : Pour tester l'interaction de ton application avec des services externes : fournisseurs OAuth, passerelles de paiement, analytics, widgets de chat, cartes, connexion sociale et CAPTCHAs. Le principe de base : mocke la frontière avec le tiers, pas ton propre code applicatif.
> **Prérequis** : [core/network-mocking.md](network-mocking.md), [core/when-to-mock.md](when-to-mock.md), [core/authentication.md](authentication.md)

## Référence rapide

```typescript
// Mock an OAuth callback to bypass the real provider
await page.route('**/auth/callback*', (route) => {
  route.fulfill({
    status: 302,
    headers: { Location: '/dashboard?token=mock-jwt-token' },
  });
});

// Block analytics scripts from loading
await page.route('**/*.google-analytics.com/**', (route) => route.abort());
await page.route('**/segment.io/**', (route) => route.abort());

// Mock a third-party widget endpoint
await page.route('**/api.stripe.com/**', (route) => {
  route.fulfill({ status: 200, contentType: 'application/json', body: '{"id":"pi_mock"}' });
});
```

**Principe fondamental** : Dans les tests E2E, mocke le service externe, pas ta propre application. Ton code doit s'exécuter tel quel ; seules les réponses du tiers sont simulées.

## Patterns

### Mocker les fournisseurs OAuth (Google, GitHub, etc.)

**À utiliser quand** : Tu testes le parcours de connexion complet sans dépendre de la disponibilité du vrai fournisseur OAuth, de ses rate limits ou de comptes de test.
**À éviter quand** : Tu dois vérifier que l'intégration OAuth réelle fonctionne de bout en bout (utilise pour cela un test d'intégration dédié).

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('Google OAuth login via route mocking', async ({ page }) => {
  // Intercept the redirect to Google and simulate the callback
  await page.route('**/accounts.google.com/**', async (route) => {
    // Extract the redirect_uri from the request URL
    const url = new URL(route.request().url());
    const redirectUri = url.searchParams.get('redirect_uri') || '/auth/callback';

    // Simulate Google redirecting back with an auth code
    await route.fulfill({
      status: 302,
      headers: {
        Location: `${redirectUri}?code=mock-auth-code&state=${url.searchParams.get('state') || ''}`,
      },
    });
  });

  // Mock your own backend's token exchange endpoint
  await page.route('**/api/auth/google/callback*', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        token: 'mock-jwt-token',
        user: {
          id: '1',
          name: 'Test User',
          email: 'testuser@gmail.com',
          avatar: 'https://placehold.co/100x100',
        },
      }),
    });
  });

  await page.goto('/login');
  await page.getByRole('button', { name: 'Sign in with Google' }).click();

  // Should land on dashboard with user info
  await page.waitForURL('/dashboard');
  await expect(page.getByText('Test User')).toBeVisible();
});

test('GitHub OAuth login with mocked provider', async ({ page }) => {
  await page.route('**/github.com/login/oauth/**', async (route) => {
    const url = new URL(route.request().url());
    const redirectUri = url.searchParams.get('redirect_uri') || '/auth/callback';
    await route.fulfill({
      status: 302,
      headers: {
        Location: `${redirectUri}?code=mock-github-code`,
      },
    });
  });

  await page.route('**/api/auth/github/callback*', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        token: 'mock-jwt-token',
        user: { id: '2', name: 'GitHub User', email: 'user@github.com' },
      }),
    });
  });

  await page.goto('/login');
  await page.getByRole('button', { name: 'Sign in with GitHub' }).click();
  await page.waitForURL('/dashboard');
  await expect(page.getByText('GitHub User')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('Google OAuth login via route mocking', async ({ page }) => {
  await page.route('**/accounts.google.com/**', async (route) => {
    const url = new URL(route.request().url());
    const redirectUri = url.searchParams.get('redirect_uri') || '/auth/callback';
    await route.fulfill({
      status: 302,
      headers: {
        Location: `${redirectUri}?code=mock-auth-code&state=${url.searchParams.get('state') || ''}`,
      },
    });
  });

  await page.route('**/api/auth/google/callback*', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        token: 'mock-jwt-token',
        user: { id: '1', name: 'Test User', email: 'testuser@gmail.com' },
      }),
    });
  });

  await page.goto('/login');
  await page.getByRole('button', { name: 'Sign in with Google' }).click();
  await page.waitForURL('/dashboard');
  await expect(page.getByText('Test User')).toBeVisible();
});
```

### Tester une passerelle de paiement (Stripe Elements)

**À utiliser quand** : Tu testes des parcours de checkout qui utilisent Stripe Elements, des boutons PayPal ou des UI de paiement embarquées similaires.
**À éviter quand** : Stripe fournit un mode test avec des numéros de carte de test et tu veux une couverture d'intégration complète.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('complete Stripe checkout with test card', async ({ page }) => {
  await page.goto('/checkout');

  // Stripe Elements load in an iframe
  const stripeFrame = page.frameLocator('iframe[name*="__privateStripeFrame"]').first();

  // Fill card details inside the Stripe iframe
  await stripeFrame.getByPlaceholder('Card number').fill('4242424242424242');
  await stripeFrame.getByPlaceholder('MM / YY').fill('12/28');
  await stripeFrame.getByPlaceholder('CVC').fill('123');
  await stripeFrame.getByPlaceholder('ZIP').fill('10001');

  await page.getByRole('button', { name: 'Pay' }).click();
  await expect(page.getByText('Payment successful')).toBeVisible({ timeout: 15000 });
});

test('Stripe checkout with mocked API for speed', async ({ page }) => {
  // Mock Stripe API calls for faster, more reliable tests
  await page.route('**/api.stripe.com/v1/payment_intents*', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        id: 'pi_mock_123',
        status: 'succeeded',
        client_secret: 'pi_mock_123_secret_456',
      }),
    });
  });

  await page.route('**/api.stripe.com/v1/payment_methods*', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        id: 'pm_mock_789',
        type: 'card',
        card: { brand: 'visa', last4: '4242' },
      }),
    });
  });

  await page.goto('/checkout');
  // With mocked Stripe, your app-level payment form may work without the iframe
  await page.getByRole('button', { name: 'Pay' }).click();
  await expect(page.getByText('Payment successful')).toBeVisible();
});

test('handles declined card gracefully', async ({ page }) => {
  await page.goto('/checkout');

  const stripeFrame = page.frameLocator('iframe[name*="__privateStripeFrame"]').first();
  // Stripe test card that always declines
  await stripeFrame.getByPlaceholder('Card number').fill('4000000000000002');
  await stripeFrame.getByPlaceholder('MM / YY').fill('12/28');
  await stripeFrame.getByPlaceholder('CVC').fill('123');
  await stripeFrame.getByPlaceholder('ZIP').fill('10001');

  await page.getByRole('button', { name: 'Pay' }).click();
  await expect(page.getByText(/declined|failed/i)).toBeVisible({ timeout: 15000 });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('complete Stripe checkout with test card', async ({ page }) => {
  await page.goto('/checkout');

  const stripeFrame = page.frameLocator('iframe[name*="__privateStripeFrame"]').first();
  await stripeFrame.getByPlaceholder('Card number').fill('4242424242424242');
  await stripeFrame.getByPlaceholder('MM / YY').fill('12/28');
  await stripeFrame.getByPlaceholder('CVC').fill('123');
  await stripeFrame.getByPlaceholder('ZIP').fill('10001');

  await page.getByRole('button', { name: 'Pay' }).click();
  await expect(page.getByText('Payment successful')).toBeVisible({ timeout: 15000 });
});
```

### Blocage des analytics

**À utiliser quand** : Tu veux empêcher les scripts d'analytics de s'exécuter pendant les tests pour gagner en vitesse, éviter de polluer les données d'analytics et éliminer la flakiness due aux échecs de scripts tiers.
**À éviter quand** : Tu dois précisément tester que les événements d'analytics sont déclenchés correctement.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

// Block analytics in a fixture for all tests
import { test as base } from '@playwright/test';

export const test = base.extend({
  page: async ({ page }, use) => {
    // Block common analytics and tracking scripts
    await page.route(/(google-analytics|googletagmanager|segment\.io|hotjar|mixpanel|amplitude)/, (route) =>
      route.abort()
    );
    await page.route('**/collect?**', (route) => route.abort()); // GA beacon
    await page.route('**/analytics/**', (route) => route.abort());
    await use(page);
  },
});

export { expect };
```

```typescript
// For tests that verify analytics events ARE sent
import { test, expect } from '@playwright/test';

test('purchase event fires on checkout completion', async ({ page }) => {
  const analyticsRequests: { url: string; body: string }[] = [];

  // Intercept analytics calls instead of blocking them
  await page.route('**/collect**', async (route) => {
    analyticsRequests.push({
      url: route.request().url(),
      body: route.request().postData() || '',
    });
    await route.fulfill({ status: 200 }); // Respond but don't send to real analytics
  });

  await page.goto('/checkout');
  await page.getByRole('button', { name: 'Complete order' }).click();
  await page.waitForURL('/order/confirmation');

  // Verify the purchase event was sent
  const purchaseEvent = analyticsRequests.find(
    (r) => r.body.includes('purchase') || r.url.includes('purchase')
  );
  expect(purchaseEvent).toBeDefined();
});
```

**JavaScript**
```javascript
const { test: base, expect } = require('@playwright/test');

const test = base.extend({
  page: async ({ page }, use) => {
    await page.route(/(google-analytics|googletagmanager|segment\.io|hotjar|mixpanel)/, (route) =>
      route.abort()
    );
    await use(page);
  },
});

module.exports = { test, expect };
```

### Tester un widget de chat (Intercom, Drift, etc.)

**À utiliser quand** : Ton application embarque un widget de chat tiers et tu dois tester l'interaction ou vérifier qu'il ne casse pas ton UI.
**À éviter quand** : Le widget de chat est cosmétique et ne fait pas partie des parcours utilisateur critiques.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('Intercom chat widget opens and accepts messages', async ({ page }) => {
  await page.goto('/');

  // Wait for the chat widget to load (often delayed)
  const chatLauncher = page.frameLocator('iframe[name*="intercom"]')
    .getByRole('button', { name: /chat|message/i });
  await expect(chatLauncher).toBeVisible({ timeout: 15000 });

  // Open the chat
  await chatLauncher.click();

  // The chat conversation iframe loads
  const chatFrame = page.frameLocator('iframe[name*="intercom-messenger"]');
  await expect(chatFrame.getByText(/How can we help/i)).toBeVisible();

  // Type a message
  await chatFrame.getByRole('textbox').fill('I need help with my order');
  await chatFrame.getByRole('button', { name: /send/i }).click();

  await expect(chatFrame.getByText('I need help with my order')).toBeVisible();
});

test('chat widget does not overlap critical UI', async ({ page }) => {
  await page.goto('/checkout');

  // Get chat widget position
  const chatWidget = page.locator('iframe[name*="intercom"]').first();
  if (await chatWidget.isVisible()) {
    const chatBox = await chatWidget.boundingBox();
    const payButton = await page.getByRole('button', { name: 'Pay' }).boundingBox();

    // Ensure the pay button is not hidden behind the chat widget
    if (chatBox && payButton) {
      const overlaps =
        payButton.x < chatBox.x + chatBox.width &&
        payButton.x + payButton.width > chatBox.x &&
        payButton.y < chatBox.y + chatBox.height &&
        payButton.y + payButton.height > chatBox.y;
      expect(overlaps).toBe(false);
    }
  }
});

// Block chat widget in most tests for speed
test('block chat widget for non-chat tests', async ({ page }) => {
  await page.route('**/widget.intercom.io/**', (route) => route.abort());
  await page.route('**/js.intercomcdn.com/**', (route) => route.abort());

  await page.goto('/dashboard');
  // Chat widget will not load — test runs faster
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('block chat widget for speed', async ({ page }) => {
  await page.route('**/widget.intercom.io/**', (route) => route.abort());
  await page.route('**/js.intercomcdn.com/**', (route) => route.abort());

  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

### Tester l'intégration d'une carte (Google Maps)

**À utiliser quand** : Ton application embarque Google Maps ou un fournisseur de cartes similaire et tu dois vérifier les interactions liées à la carte.
**À éviter quand** : La carte est décorative et ne fait pas partie d'un parcours utilisateur.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('store locator shows markers on the map', async ({ page }) => {
  await page.goto('/store-locator');

  // Google Maps loads in an iframe or directly on the page
  await page.getByLabel('Search location').fill('New York');
  await page.getByRole('button', { name: 'Search' }).click();

  // Wait for map markers to appear
  await expect(page.locator('[data-testid="map-marker"]')).toHaveCount(5, {
    timeout: 10000,
  });

  // Click a marker to see store details
  await page.locator('[data-testid="map-marker"]').first().click();
  await expect(page.getByTestId('store-info')).toBeVisible();
  await expect(page.getByTestId('store-info')).toContainText('New York');
});

test('mock Google Maps API for offline testing', async ({ page }) => {
  // Block real Google Maps and provide mock responses
  await page.route('**/maps.googleapis.com/**', async (route) => {
    const url = route.request().url();

    if (url.includes('/geocode/')) {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          results: [{
            geometry: { location: { lat: 40.7128, lng: -74.0060 } },
            formatted_address: 'New York, NY, USA',
          }],
          status: 'OK',
        }),
      });
    } else if (url.includes('/places/')) {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          results: [
            { name: 'Store A', geometry: { location: { lat: 40.71, lng: -74.00 } } },
            { name: 'Store B', geometry: { location: { lat: 40.72, lng: -74.01 } } },
          ],
          status: 'OK',
        }),
      });
    } else {
      await route.continue();
    }
  });

  await page.goto('/store-locator');
  await page.getByLabel('Search location').fill('New York');
  await page.getByRole('button', { name: 'Search' }).click();

  await expect(page.getByText('Store A')).toBeVisible();
  await expect(page.getByText('Store B')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('mock Google Maps geocode API', async ({ page }) => {
  await page.route('**/maps.googleapis.com/maps/api/geocode/**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        results: [{
          geometry: { location: { lat: 40.7128, lng: -74.0060 } },
          formatted_address: 'New York, NY, USA',
        }],
        status: 'OK',
      }),
    });
  });

  await page.goto('/store-locator');
  await page.getByLabel('Search location').fill('New York');
  await page.getByRole('button', { name: 'Search' }).click();
  await expect(page.getByText('New York')).toBeVisible();
});
```

### Contourner reCAPTCHA pour les tests

**À utiliser quand** : Ton application utilise reCAPTCHA ou hCaptcha et tes tests doivent avancer sans résoudre de défis.
**À éviter quand** : Tu peux désactiver le CAPTCHA dans ton environnement de test via un flag côté serveur (approche à privilégier).

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test.describe('reCAPTCHA handling', () => {
  // Best approach: Use test keys provided by Google
  // Site key: 6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI (always passes)
  // Secret key: 6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe

  test('form submission with reCAPTCHA bypassed via test keys', async ({ page }) => {
    // Your test environment should be configured with Google's test keys
    await page.goto('/contact');

    await page.getByLabel('Name').fill('Test User');
    await page.getByLabel('Email').fill('test@example.com');
    await page.getByLabel('Message').fill('Test message');

    // With test keys, reCAPTCHA auto-passes — just click submit
    await page.getByRole('button', { name: 'Send' }).click();
    await expect(page.getByText('Message sent')).toBeVisible();
  });

  test('mock reCAPTCHA verification endpoint', async ({ page }) => {
    // Mock Google's reCAPTCHA verification API
    await page.route('**/recaptcha/api/siteverify**', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ success: true, score: 0.9 }),
      });
    });

    // Mock the reCAPTCHA script to provide a fake token
    await page.addInitScript(() => {
      (window as any).grecaptcha = {
        ready: (cb: () => void) => cb(),
        execute: () => Promise.resolve('mock-recaptcha-token'),
        render: () => 'mock-widget-id',
        getResponse: () => 'mock-recaptcha-token',
        reset: () => {},
      };
    });

    await page.goto('/contact');
    await page.getByLabel('Name').fill('Test User');
    await page.getByLabel('Email').fill('test@example.com');
    await page.getByLabel('Message').fill('Test message');
    await page.getByRole('button', { name: 'Send' }).click();

    await expect(page.getByText('Message sent')).toBeVisible();
  });

  test('invisible reCAPTCHA v3 bypass', async ({ page }) => {
    // For reCAPTCHA v3, mock the enterprise API
    await page.route('**/recaptcha/**', async (route) => {
      if (route.request().url().includes('api.js')) {
        // Serve a mock script that provides the grecaptcha object
        await route.fulfill({
          status: 200,
          contentType: 'application/javascript',
          body: `
            window.grecaptcha = {
              ready: function(cb) { cb(); },
              execute: function() { return Promise.resolve('mock-token'); },
              enterprise: {
                ready: function(cb) { cb(); },
                execute: function() { return Promise.resolve('mock-token'); },
              }
            };
          `,
        });
      } else {
        await route.abort();
      }
    });

    await page.goto('/login');
    await page.getByLabel('Email').fill('user@example.com');
    await page.getByLabel('Password').fill('password123');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await page.waitForURL('/dashboard');
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('mock reCAPTCHA for form submission', async ({ page }) => {
  await page.route('**/recaptcha/api/siteverify**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ success: true, score: 0.9 }),
    });
  });

  await page.addInitScript(() => {
    window.grecaptcha = {
      ready: (cb) => cb(),
      execute: () => Promise.resolve('mock-recaptcha-token'),
      render: () => 'mock-widget-id',
      getResponse: () => 'mock-recaptcha-token',
      reset: () => {},
    };
  });

  await page.goto('/contact');
  await page.getByLabel('Name').fill('Test User');
  await page.getByLabel('Email').fill('test@example.com');
  await page.getByLabel('Message').fill('Test message');
  await page.getByRole('button', { name: 'Send' }).click();
  await expect(page.getByText('Message sent')).toBeVisible();
});
```

### Mocker la connexion sociale

**À utiliser quand** : Ton application propose plusieurs options de connexion sociale et tu dois tester le parcours de connexion sans comptes réels chez les fournisseurs.
**À éviter quand** : Tu disposes d'un bypass côté backend qui positionne directement l'état d'authentification.

**TypeScript**
```typescript
import { test as base, expect } from '@playwright/test';

// Reusable fixture that mocks any OAuth provider
type OAuthFixtures = {
  mockOAuth: (provider: string, userData: Record<string, string>) => Promise<void>;
};

export const test = base.extend<OAuthFixtures>({
  mockOAuth: async ({ page }, use) => {
    const mock = async (provider: string, userData: Record<string, string>) => {
      const providerPatterns: Record<string, string> = {
        google: '**/accounts.google.com/**',
        github: '**/github.com/login/oauth/**',
        facebook: '**/facebook.com/v*/dialog/oauth**',
        apple: '**/appleid.apple.com/**',
        microsoft: '**/login.microsoftonline.com/**',
      };

      const pattern = providerPatterns[provider];
      if (!pattern) throw new Error(`Unknown provider: ${provider}`);

      // Intercept the OAuth redirect
      await page.route(pattern, async (route) => {
        const url = new URL(route.request().url());
        const redirectUri = url.searchParams.get('redirect_uri') || '/auth/callback';
        await route.fulfill({
          status: 302,
          headers: { Location: `${redirectUri}?code=mock-${provider}-code` },
        });
      });

      // Mock the token exchange
      await page.route(`**/api/auth/${provider}/callback*`, async (route) => {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ token: `mock-${provider}-jwt`, user: userData }),
        });
      });
    };

    await use(mock);
  },
});

// Usage in tests
test('login with multiple social providers', async ({ page, mockOAuth }) => {
  // Test Google login
  await mockOAuth('google', { name: 'Google User', email: 'user@gmail.com' });
  await page.goto('/login');
  await page.getByRole('button', { name: 'Sign in with Google' }).click();
  await page.waitForURL('/dashboard');
  await expect(page.getByText('Google User')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test: base, expect } = require('@playwright/test');

const test = base.extend({
  mockOAuth: async ({ page }, use) => {
    const mock = async (provider, userData) => {
      const patterns = {
        google: '**/accounts.google.com/**',
        github: '**/github.com/login/oauth/**',
        facebook: '**/facebook.com/v*/dialog/oauth**',
      };

      await page.route(patterns[provider], async (route) => {
        const url = new URL(route.request().url());
        const redirectUri = url.searchParams.get('redirect_uri') || '/auth/callback';
        await route.fulfill({
          status: 302,
          headers: { Location: `${redirectUri}?code=mock-${provider}-code` },
        });
      });

      await page.route(`**/api/auth/${provider}/callback*`, async (route) => {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ token: `mock-${provider}-jwt`, user: userData }),
        });
      });
    };
    await use(mock);
  },
});

test('login with Google', async ({ page, mockOAuth }) => {
  await mockOAuth('google', { name: 'Google User', email: 'user@gmail.com' });
  await page.goto('/login');
  await page.getByRole('button', { name: 'Sign in with Google' }).click();
  await page.waitForURL('/dashboard');
  await expect(page.getByText('Google User')).toBeVisible();
});

module.exports = { test, expect };
```

## Guide de décision

| Intégration | Stratégie de mock | Quand utiliser le réel | Quand mocker |
|---|---|---|---|
| OAuth (Google, GitHub, etc.) | Interception de route sur l'URL du fournisseur + callback mocké | Test d'intégration dédié avec des comptes de test | Tous les tests E2E de fonctionnalités qui nécessitent une connexion |
| Stripe / passerelle de paiement | Utiliser le mode test de Stripe avec des cartes de test OU mocker l'API | Tests d'intégration du parcours de checkout | Tous les tests E2E hors paiement |
| Google Analytics / Segment | `route.abort()` pour bloquer entièrement | Tests dédiés à la vérification des analytics | Tous les autres tests (bloquer pour la vitesse) |
| Widgets de chat (Intercom, Drift) | `route.abort()` pour bloquer, ou interagir via l'iframe | Tests portant spécifiquement sur la fonctionnalité de chat | Tous les autres tests (bloquer pour la vitesse/stabilité) |
| Google Maps | Mocker les réponses des API de géocodage/places | Tests vérifiant le vrai rendu de la carte | Tests qui n'ont besoin que de données de localisation |
| reCAPTCHA | Clés de test Google (à privilégier) ou mock de `grecaptcha` | Jamais dans les tests automatisés | Toujours -- un CAPTCHA ne peut pas être résolu par l'automatisation |
| Connexion sociale | Fixture de mock OAuth réutilisable par fournisseur | Vérification d'intégration périodique | Tous les tests E2E nécessitant une authentification |
| Services d'email (SendGrid, SES) | Mocker les endpoints d'API, vérifier que les appels ont eu lieu | Tests de livraison d'email de bout en bout (suite séparée) | Tous les tests qui déclenchent des emails |

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| Utiliser de vrais comptes de fournisseurs OAuth dans les tests | Rate limits, exigences de 2FA, verrouillages de compte, flakiness des tests | Mocker le parcours OAuth ou utiliser les modes test des fournisseurs |
| Laisser les scripts d'analytics s'exécuter dans tous les tests | Tests plus lents, pollution des vraies données d'analytics, flakiness réseau supplémentaire | Bloquer les analytics avec `route.abort()` dans une fixture partagée |
| Résoudre reCAPTCHA par reconnaissance d'images | Fragile, lent, viole les conditions d'utilisation du CAPTCHA | Utiliser les clés de test de Google ou mocker l'objet `grecaptcha` |
| Mocker son propre code applicatif au lieu du tiers | Ne teste pas ta logique d'intégration | Ne mocker que la frontière externe (endpoints d'API, scripts) |
| Coder en dur des réponses mockées dans chaque test | Setup de mock dupliqué, difficile à maintenir | Construire des fixtures de mock réutilisables (voir le pattern Connexion sociale) |
| Ne pas tester les chemins d'erreur des tiers | Passe à côté de la façon dont ton application gère les échecs OAuth et les paiements refusés | Mocker les réponses d'erreur : `{ error: 'access_denied' }`, cartes refusées |
| Charger le vrai Stripe.js dans chaque test | Chargement initial lent, échecs occasionnels du CDN | Mocker Stripe pour les tests hors paiement ; n'utiliser le vrai Stripe que pour les tests de checkout |
| Se fier à `networkidle` pour les scripts tiers | Les scripts tiers peuvent faire du polling indéfiniment | Attendre des indicateurs précis au niveau de l'application, pas `networkidle` |

## Dépannage

| Symptôme | Cause probable | Correction |
|---|---|---|
| La route de mock OAuth ne se déclenche jamais | L'application utilise une chaîne de redirections qui contourne ton pattern de route | Utiliser un pattern plus large comme `**accounts.google.com**` ou journaliser toutes les requêtes pour voir l'URL réelle |
| iframe Stripe introuvable | Stripe.js se charge en async ; le nom de l'iframe varie selon la version | Utiliser un sélecteur flexible : `iframe[name*="__privateStripeFrame"]` avec un timeout long |
| Le mock reCAPTCHA ne fonctionne pas | Le script se charge avant l'exécution de `addInitScript` | Utiliser `route` pour intercepter le script reCAPTCHA et servir une version mockée |
| Le blocage des analytics casse l'application | Le code de l'application dépend de la présence de la bibliothèque d'analytics (par ex. `window.gtag`) | Au lieu de bloquer, répondre avec un stub : `route.fulfill({ body: 'window.gtag=function(){}' })` |
| L'iframe du widget de chat n'est pas accessible | Restrictions des iframes cross-origin | Utiliser `frameLocator` avec le bon nom/sélecteur d'iframe |
| Le mock OAuth renvoie une mauvaise redirect URI | Le paramètre `redirect_uri` est encodé en URL ou différent en test | Journaliser l'URL réelle de la requête avec `page.on('request')` et faire correspondre en conséquence |
| Le test de paiement passe en local mais échoue en CI | Le mode test de Stripe a des rate limits ; l'IP de la CI peut être bloquée | Mocker l'API Stripe en CI, n'utiliser le vrai Stripe que dans une pipeline d'intégration séparée |
| Le mock de connexion sociale ne redirige pas | Ton application ouvre OAuth dans une popup, pas via une redirection | Gérer la popup : `page.waitForEvent('popup')` et mocker les routes sur la page de la popup |

## Voir aussi

- [core/network-mocking.md](network-mocking.md) -- patterns fondamentaux d'interception de routes
- [core/authentication.md](authentication.md) -- gestion de l'état d'authentification et bypass de connexion
- [core/when-to-mock.md](when-to-mock.md) -- cadre de décision entre mock et vrais services
- [core/multi-context-and-popups.md](multi-context-and-popups.md) -- gestion des fenêtres popup OAuth
- [core/security-testing.md](security-testing.md) -- tester les aspects de sécurité de l'authentification
- [core/iframes-and-shadow-dom.md](iframes-and-shadow-dom.md) -- interagir avec les iframes des widgets de paiement
