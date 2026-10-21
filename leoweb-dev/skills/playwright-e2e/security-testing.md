# Tests de sécurité

> **Quand l'utiliser** : valider les défenses de ton application contre les vulnérabilités web courantes — XSS, CSRF, cookies non sécurisés, en-têtes manquants, contournement d'authentification et exposition de données sensibles. Playwright ne remplace pas les scanners de sécurité dédiés, mais il détecte les problèmes les plus courants dans le cadre de ta suite E2E.
> **Prérequis** : [core/assertions-and-waiting.md](assertions-and-waiting.md), [core/authentication.md](authentication.md)

## Référence rapide

```typescript
// Check security headers on every navigation
const response = await page.goto('/dashboard');
expect(response.headers()['content-security-policy']).toBeDefined();
expect(response.headers()['x-frame-options']).toBe('DENY');

// Verify cookie security flags
const cookies = await context.cookies();
const sessionCookie = cookies.find(c => c.name === 'session');
expect(sessionCookie.httpOnly).toBe(true);
expect(sessionCookie.secure).toBe(true);
expect(sessionCookie.sameSite).toBe('Strict');
```

## Patterns

### Test d'injection XSS

**À utiliser quand** : tu vérifies que les entrées utilisateur sont correctement assainies et rendues comme du texte, et non comme du HTML.
**À éviter quand** : tu as besoin d'un scan XSS exhaustif — utilise un outil dédié comme OWASP ZAP en complément de Playwright.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

const XSS_PAYLOADS = [
  '<script>alert("xss")</script>',
  '<img src=x onerror=alert("xss")>',
  '"><script>alert("xss")</script>',
  "javascript:alert('xss')",
  '<svg onload=alert("xss")>',
  '{{constructor.constructor("alert(1)")()}}', // Template injection
];

test.describe('XSS protection', () => {
  for (const payload of XSS_PAYLOADS) {
    test(`input sanitizes: ${payload.slice(0, 40)}...`, async ({ page }) => {
      await page.goto('/profile/edit');

      // Inject the payload into a text field
      await page.getByLabel('Display name').fill(payload);
      await page.getByRole('button', { name: 'Save' }).click();

      // Verify the payload is rendered as text, not executed
      await page.goto('/profile');
      const displayName = page.getByTestId('display-name');
      await expect(displayName).toBeVisible();

      // The payload text should appear literally, not as HTML
      const innerHTML = await displayName.innerHTML();
      expect(innerHTML).not.toContain('<script');
      expect(innerHTML).not.toContain('onerror');
      expect(innerHTML).not.toContain('onload');

      // No dialog should have appeared (script execution)
      // If a dialog fires, the test will fail because it's unhandled
    });
  }
});

test('XSS via URL parameters is prevented', async ({ page }) => {
  const xssUrl = '/search?q=<script>alert("xss")</script>';
  await page.goto(xssUrl);

  // The search term should be displayed as text
  const searchInput = page.getByRole('textbox', { name: 'Search' });
  const value = await searchInput.inputValue();
  expect(value).not.toContain('<script');

  // Page should not have injected script tags
  const scriptCount = await page.locator('script:not([src])').count();
  const pageContent = await page.content();
  expect(pageContent).not.toContain('alert("xss")');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

const XSS_PAYLOADS = [
  '<script>alert("xss")</script>',
  '<img src=x onerror=alert("xss")>',
  '"><script>alert("xss")</script>',
  '<svg onload=alert("xss")>',
];

test.describe('XSS protection', () => {
  for (const payload of XSS_PAYLOADS) {
    test(`input sanitizes: ${payload.slice(0, 40)}...`, async ({ page }) => {
      await page.goto('/profile/edit');
      await page.getByLabel('Display name').fill(payload);
      await page.getByRole('button', { name: 'Save' }).click();

      await page.goto('/profile');
      const innerHTML = await page.getByTestId('display-name').innerHTML();
      expect(innerHTML).not.toContain('<script');
      expect(innerHTML).not.toContain('onerror');
    });
  }
});
```

### Vérification du token CSRF

**À utiliser quand** : tu t'assures que les requêtes qui modifient l'état incluent des tokens CSRF valides et que le serveur rejette les requêtes qui n'en ont pas.
**À éviter quand** : ton API utilise une authentification par token (JWT) sans sessions par cookie — le CSRF n'est pas applicable.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('form submissions include CSRF token', async ({ page }) => {
  await page.goto('/settings');

  // Verify the CSRF token is present in the form
  const csrfInput = page.locator('input[name="_csrf"], input[name="csrf_token"]');
  await expect(csrfInput).toBeAttached();
  const tokenValue = await csrfInput.inputValue();
  expect(tokenValue).toBeTruthy();
  expect(tokenValue.length).toBeGreaterThan(16);
});

test('server rejects requests without CSRF token', async ({ page, request }) => {
  // First, get a valid session by logging in through the UI
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');

  // Attempt a state-changing request without the CSRF token
  const cookies = await page.context().cookies();
  const response = await request.post('/api/settings', {
    headers: {
      Cookie: cookies.map(c => `${c.name}=${c.value}`).join('; '),
    },
    data: { theme: 'dark' }, // No CSRF token
  });

  // Server should reject it
  expect(response.status()).toBe(403);
});

test('CSRF token rotates per session', async ({ browser }) => {
  const context1 = await browser.newContext();
  const context2 = await browser.newContext();

  const page1 = await context1.newPage();
  const page2 = await context2.newPage();

  await page1.goto('/login');
  await page2.goto('/login');

  const token1 = await page1.locator('input[name="_csrf"]').inputValue();
  const token2 = await page2.locator('input[name="_csrf"]').inputValue();

  // Tokens should differ between sessions
  expect(token1).not.toBe(token2);

  await context1.close();
  await context2.close();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('form submissions include CSRF token', async ({ page }) => {
  await page.goto('/settings');

  const csrfInput = page.locator('input[name="_csrf"], input[name="csrf_token"]');
  await expect(csrfInput).toBeAttached();
  const tokenValue = await csrfInput.inputValue();
  expect(tokenValue).toBeTruthy();
  expect(tokenValue.length).toBeGreaterThan(16);
});

test('server rejects requests without CSRF token', async ({ page, request }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');

  const cookies = await page.context().cookies();
  const response = await request.post('/api/settings', {
    headers: {
      Cookie: cookies.map(c => `${c.name}=${c.value}`).join('; '),
    },
    data: { theme: 'dark' },
  });

  expect(response.status()).toBe(403);
});
```

### Validation des en-têtes CSP

**À utiliser quand** : tu vérifies que les en-têtes Content Security Policy sont présents et correctement configurés.
**À éviter quand** : la CSP est gérée par l'infrastructure (CDN/WAF) et testée séparément.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('CSP headers are properly configured', async ({ page }) => {
  const response = await page.goto('/');
  const csp = response!.headers()['content-security-policy'];

  expect(csp).toBeDefined();
  expect(csp).toContain("default-src 'self'");
  expect(csp).not.toContain("'unsafe-inline'"); // Disallow inline scripts
  expect(csp).not.toContain("'unsafe-eval'");   // Disallow eval()
  expect(csp).toContain('script-src');
});

test('security headers are present on all pages', async ({ page }) => {
  const pagesToCheck = ['/', '/login', '/dashboard', '/api/health'];

  for (const url of pagesToCheck) {
    const response = await page.goto(url);
    const headers = response!.headers();

    expect(headers['x-content-type-options']).toBe('nosniff');
    expect(headers['x-frame-options']).toMatch(/DENY|SAMEORIGIN/);
    expect(headers['strict-transport-security']).toBeDefined();
    expect(headers['referrer-policy']).toBeDefined();
    expect(headers['x-xss-protection']).toBeUndefined(); // Deprecated, should not be set
  }
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('CSP headers are properly configured', async ({ page }) => {
  const response = await page.goto('/');
  const csp = response.headers()['content-security-policy'];

  expect(csp).toBeDefined();
  expect(csp).toContain("default-src 'self'");
  expect(csp).not.toContain("'unsafe-inline'");
  expect(csp).not.toContain("'unsafe-eval'");
});

test('security headers are present on all pages', async ({ page }) => {
  const pagesToCheck = ['/', '/login', '/dashboard'];

  for (const url of pagesToCheck) {
    const response = await page.goto(url);
    const headers = response.headers();

    expect(headers['x-content-type-options']).toBe('nosniff');
    expect(headers['x-frame-options']).toMatch(/DENY|SAMEORIGIN/);
    expect(headers['strict-transport-security']).toBeDefined();
  }
});
```

### Flags de sécurité des cookies

**À utiliser quand** : tu vérifies que les cookies de session et d'authentification ont les bons attributs de sécurité.
**À éviter quand** : ton application est entièrement stateless et n'utilise aucun cookie.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('session cookie has correct security flags', async ({ page, context }) => {
  // Log in to create a session cookie
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');

  const cookies = await context.cookies();

  // Check session cookie
  const session = cookies.find(c => c.name === 'session' || c.name === 'sid');
  expect(session).toBeDefined();
  expect(session!.httpOnly).toBe(true);   // Not accessible via JavaScript
  expect(session!.secure).toBe(true);     // Only sent over HTTPS
  expect(session!.sameSite).toBe('Strict'); // Or 'Lax' at minimum

  // Session cookie should not have an excessive expiry
  if (session!.expires !== -1) {
    const maxAge = session!.expires - Date.now() / 1000;
    expect(maxAge).toBeLessThan(86400 * 30); // No more than 30 days
  }
});

test('sensitive cookies are not exposed to JavaScript', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');

  // document.cookie should NOT contain HttpOnly cookies
  const jsCookies = await page.evaluate(() => document.cookie);
  expect(jsCookies).not.toContain('session');
  expect(jsCookies).not.toContain('sid');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('session cookie has correct security flags', async ({ page, context }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');

  const cookies = await context.cookies();
  const session = cookies.find(c => c.name === 'session' || c.name === 'sid');

  expect(session).toBeDefined();
  expect(session.httpOnly).toBe(true);
  expect(session.secure).toBe(true);
  expect(session.sameSite).toBe('Strict');
});
```

### Test de contournement d'authentification

**À utiliser quand** : tu t'assures que les routes protégées redirigent les utilisateurs non authentifiés et que l'invalidation de session fonctionne.
**À éviter quand** : l'authentification est testée par des tests API dédiés qui couvrent déjà ces cas.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('unauthenticated user cannot access protected routes', async ({ page }) => {
  const protectedRoutes = ['/dashboard', '/settings', '/admin', '/api/users'];

  for (const route of protectedRoutes) {
    const response = await page.goto(route);

    // Should redirect to login or return 401/403
    const isRedirected = page.url().includes('/login');
    const isBlocked = response!.status() === 401 || response!.status() === 403;
    expect(isRedirected || isBlocked).toBe(true);
  }
});

test('session is invalidated after logout', async ({ page, context }) => {
  // Log in
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');

  // Capture session cookie
  const cookiesBefore = await context.cookies();
  const sessionBefore = cookiesBefore.find(c => c.name === 'session');

  // Log out
  await page.getByRole('button', { name: 'Log out' }).click();
  await page.waitForURL('/login');

  // Verify session cookie is cleared
  const cookiesAfter = await context.cookies();
  const sessionAfter = cookiesAfter.find(c => c.name === 'session');
  expect(sessionAfter).toBeUndefined();

  // Attempting to access protected route should fail
  await page.goto('/dashboard');
  expect(page.url()).toContain('/login');
});

test('expired session redirects to login', async ({ page, context }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');

  // Manually expire the session cookie
  await context.clearCookies();

  // Next navigation should redirect to login
  await page.goto('/dashboard');
  expect(page.url()).toContain('/login');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('unauthenticated user cannot access protected routes', async ({ page }) => {
  const protectedRoutes = ['/dashboard', '/settings', '/admin'];

  for (const route of protectedRoutes) {
    await page.goto(route);
    expect(page.url()).toContain('/login');
  }
});

test('session is invalidated after logout', async ({ page, context }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');

  await page.getByRole('button', { name: 'Log out' }).click();
  await page.waitForURL('/login');

  const cookies = await context.cookies();
  const session = cookies.find(c => c.name === 'session');
  expect(session).toBeUndefined();
});
```

### Redirection HTTPS et exposition de données sensibles

**À utiliser quand** : tu vérifies que les requêtes HTTP sont redirigées vers HTTPS et que les données sensibles ne fuitent pas dans les URL, les en-têtes ou le stockage côté client.
**À éviter quand** : tu testes contre `localhost` où HTTPS n'est pas configuré.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('HTTP redirects to HTTPS', async ({ request }) => {
  // Use the API request context to follow redirects
  const response = await request.get('http://your-app.com/', {
    maxRedirects: 0, // Don't follow — inspect the redirect
  });
  expect(response.status()).toBe(301);
  expect(response.headers()['location']).toMatch(/^https:\/\//);
});

test('HSTS header is set', async ({ page }) => {
  const response = await page.goto('/');
  const hsts = response!.headers()['strict-transport-security'];
  expect(hsts).toBeDefined();
  expect(hsts).toContain('max-age=');

  // Extract max-age value and verify it's at least 1 year
  const maxAge = parseInt(hsts!.match(/max-age=(\d+)/)?.[1] || '0');
  expect(maxAge).toBeGreaterThanOrEqual(31536000);
});

test('sensitive data is not in URL parameters', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');

  // Password should never appear in URL
  expect(page.url()).not.toContain('password');
  expect(page.url()).not.toContain('token');
  expect(page.url()).not.toContain('secret');
});

test('sensitive data is not in localStorage', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');

  const storageData = await page.evaluate(() => {
    const data: Record<string, string> = {};
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i)!;
      data[key] = localStorage.getItem(key)!;
    }
    return JSON.stringify(data);
  });

  expect(storageData).not.toContain('password');
  expect(storageData.toLowerCase()).not.toContain('secret');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('sensitive data is not in localStorage', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');

  const storageData = await page.evaluate(() => {
    const data = {};
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      data[key] = localStorage.getItem(key);
    }
    return JSON.stringify(data);
  });

  expect(storageData).not.toContain('password');
  expect(storageData.toLowerCase()).not.toContain('secret');
});
```

### Prévention de la fixation de session

**À utiliser quand** : tu t'assures que l'ID de session change après l'authentification pour prévenir les attaques de fixation de session.
**À éviter quand** : tu utilises une authentification par token stateless (JWT) sans sessions côté serveur.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('session ID changes after login', async ({ page, context }) => {
  await page.goto('/login');

  // Capture pre-login session identifier
  const cookiesBefore = await context.cookies();
  const preLoginSession = cookiesBefore.find(c => c.name === 'session');
  const preLoginValue = preLoginSession?.value;

  // Log in
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');

  // Session ID must change after authentication
  const cookiesAfter = await context.cookies();
  const postLoginSession = cookiesAfter.find(c => c.name === 'session');
  expect(postLoginSession).toBeDefined();

  if (preLoginValue) {
    expect(postLoginSession!.value).not.toBe(preLoginValue);
  }
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('session ID changes after login', async ({ page, context }) => {
  await page.goto('/login');

  const cookiesBefore = await context.cookies();
  const preLoginSession = cookiesBefore.find(c => c.name === 'session');
  const preLoginValue = preLoginSession?.value;

  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password123');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');

  const cookiesAfter = await context.cookies();
  const postLoginSession = cookiesAfter.find(c => c.name === 'session');
  expect(postLoginSession).toBeDefined();

  if (preLoginValue) {
    expect(postLoginSession.value).not.toBe(preLoginValue);
  }
});
```

## Guide de décision

| Vulnérabilité | Approche de test Playwright | Niveau de confiance |
|---|---|---|
| XSS réfléchi | Injecter des payloads dans les champs et les paramètres d'URL, vérifier qu'aucun script ne s'exécute | Moyen -- couvre les cas courants, pas exhaustif |
| XSS stocké | Injecter un payload, recharger la page, vérifier que la sortie est assainie | Moyen -- détecte les problèmes au niveau du rendu |
| CSRF | Vérifier la présence du token, tester le rejet sans token | Élevé -- teste directement le mécanisme |
| Cookies non sécurisés | Vérifier les flags `httpOnly`, `secure`, `sameSite` | Élevé -- vérification déterministe |
| En-têtes de sécurité manquants | Vérifier la présence et les valeurs des en-têtes | Élevé -- vérification déterministe |
| Contournement d'authentification | Naviguer vers les routes protégées sans authentification | Élevé -- teste le mécanisme de redirection/blocage |
| Fixation de session | Comparer les IDs de session avant et après le login | Élevé -- directement vérifiable |
| Exposition de données sensibles | Inspecter les URL, le localStorage, les corps de réponse à la recherche de secrets | Moyen -- détecte les fuites évidentes |
| Application de HTTPS | Vérifier la redirection et l'en-tête HSTS | Élevé -- vérification déterministe |

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| Ne tester que le login « happy path » | Passe à côté des vecteurs de contournement | Teste l'accès non authentifié, les sessions expirées, les tokens falsifiés |
| Vérifier `SameSite` sur un seul cookie | D'autres cookies peuvent laisser fuiter des informations de session | Vérifie tous les cookies qui contiennent des données de session |
| Ignorer la CSP sur les endpoints d'API | Les API peuvent servir du HTML sur les pages d'erreur | Vérifie aussi les en-têtes sur les routes d'API |
| Ne tester la sécurité qu'en développement | Les serveurs de dev ont souvent une sécurité allégée | Lance les tests de sécurité contre le staging avec une configuration proche de la production |
| Utiliser `page.waitForTimeout` après le login | Masque les problèmes d'authentification liés au timing | Utilise `page.waitForURL` ou une attente basée sur des assertions |
| Coder en dur des identifiants de test dans les fichiers de test | Les identifiants fuitent dans le contrôle de version | Utilise des variables d'environnement ou un gestionnaire de secrets |
| Sauter les tests HTTPS parce que « ça marche en local » | Un dev local en HTTP seul masque les problèmes HTTPS | Teste la redirection HTTPS contre le staging ou utilise `--ignore-https-errors` avec précaution |
| Traiter Playwright comme un scanner de sécurité complet | Les tests Playwright ne sont pas des tests d'intrusion | Utilise Playwright pour les vérifications de non-régression ; associe-le à OWASP ZAP, Burp Suite ou Snyk pour un scan approfondi |

## Dépannage

| Symptôme | Cause probable | Correctif |
|---|---|---|
| En-tête CSP absent dans le test mais présent en production | Le serveur de dev ne définit pas de CSP | Lance les tests de sécurité contre le staging avec la configuration de production |
| Le flag `secure` du cookie vaut `false` | Test en HTTP (localhost) | Teste contre un staging HTTPS, ou vérifie que le flag est défini conditionnellement en production |
| Le test CSRF passe sans token | La protection CSRF est désactivée dans l'environnement de test | Active le CSRF dans l'environnement de test ou lance contre le staging |
| Le payload XSS ne s'exécute pas mais le test passe | Le framework échappe automatiquement par défaut | Teste quand même -- le test confirme que la protection fonctionne ; ajoute des cas limites pour le rendu de HTML brut |
| `context.cookies()` renvoie un tableau vide | Cookies définis sur un autre domaine ou chemin | Passe l'URL précise à `context.cookies('https://your-app.com')` |
| La vérification de l'en-tête HSTS échoue sur localhost | HSTS exige HTTPS avec des certificats valides | Saute les tests HSTS pour localhost, lance-les contre le staging |
| Cookie de session introuvable par son nom | Le nom du cookie diffère selon les environnements | Cherche par motif : `cookies.find(c => c.name.includes('sess'))` |

## Voir aussi

- [core/authentication.md](authentication.md) -- flux de login et gestion de l'état d'authentification
- [core/network-mocking.md](network-mocking.md) -- interception de requêtes pour les tests de sécurité
- [core/configuration.md](configuration.md) -- `ignoreHTTPSErrors` et configuration de l'URL de base
- [core/third-party-integrations.md](third-party-integrations.md) -- test d'OAuth et des fournisseurs d'authentification tiers
- [ci/ci-github-actions.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/ci-github-actions.md) -- exécution des tests de sécurité dans les pipelines de CI
