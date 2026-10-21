# Recettes de flows d'authentification

> **Quand l'utiliser** : tu dois tester le login, l'inscription, la déconnexion, la gestion de session ou tout parcours utilisateur lié à l'authentification.

---

## Recette 1 : Login basique

### Exemple complet

**TypeScript**

```typescript
import { test, expect } from '@playwright/test';

test('logs in with valid credentials', async ({ page }) => {
  await page.goto('/login');

  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('SecurePass123!');
  await page.getByRole('button', { name: 'Sign in' }).click();

  // Wait for navigation to complete after login
  await expect(page).toHaveURL('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  await expect(page.getByText('Welcome, user@example.com')).toBeVisible();
});

test('shows error for invalid credentials', async ({ page }) => {
  await page.goto('/login');

  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('WrongPassword');
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page.getByRole('alert')).toContainText('Invalid email or password');
  // Should remain on login page
  await expect(page).toHaveURL('/login');
});

test('shows validation errors for empty fields', async ({ page }) => {
  await page.goto('/login');

  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page.getByText('Email is required')).toBeVisible();
  await expect(page.getByText('Password is required')).toBeVisible();
});
```

**JavaScript**

```javascript
const { test, expect } = require('@playwright/test');

test('logs in with valid credentials', async ({ page }) => {
  await page.goto('/login');

  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('SecurePass123!');
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page).toHaveURL('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  await expect(page.getByText('Welcome, user@example.com')).toBeVisible();
});

test('shows error for invalid credentials', async ({ page }) => {
  await page.goto('/login');

  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('WrongPassword');
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page.getByRole('alert')).toContainText('Invalid email or password');
  await expect(page).toHaveURL('/login');
});

test('shows validation errors for empty fields', async ({ page }) => {
  await page.goto('/login');

  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page.getByText('Email is required')).toBeVisible();
  await expect(page.getByText('Password is required')).toBeVisible();
});
```

---

## Recette 2 : Login avec « Se souvenir de moi »

### Exemple complet

**TypeScript**

```typescript
import { test, expect, type BrowserContext } from '@playwright/test';

test('remember me persists session across browser restarts', async ({ browser }) => {
  // First session: log in with "remember me" checked
  const context1 = await browser.newContext();
  const page1 = await context1.newPage();

  await page1.goto('/login');
  await page1.getByLabel('Email').fill('user@example.com');
  await page1.getByLabel('Password').fill('SecurePass123!');
  await page1.getByLabel('Remember me').check();
  await page1.getByRole('button', { name: 'Sign in' }).click();

  await expect(page1).toHaveURL('/dashboard');

  // Save storage state (cookies + localStorage)
  const storageState = await context1.storageState();
  await context1.close();

  // Second session: restore state to simulate browser restart
  const context2 = await browser.newContext({ storageState });
  const page2 = await context2.newPage();

  await page2.goto('/dashboard');

  // Should still be logged in without re-authenticating
  await expect(page2).toHaveURL('/dashboard');
  await expect(page2.getByText('Welcome, user@example.com')).toBeVisible();

  await context2.close();
});

test('no remember me does not persist session', async ({ browser }) => {
  const context1 = await browser.newContext();
  const page1 = await context1.newPage();

  await page1.goto('/login');
  await page1.getByLabel('Email').fill('user@example.com');
  await page1.getByLabel('Password').fill('SecurePass123!');
  // Explicitly leave "Remember me" unchecked
  await expect(page1.getByLabel('Remember me')).not.toBeChecked();
  await page1.getByRole('button', { name: 'Sign in' }).click();

  await expect(page1).toHaveURL('/dashboard');

  // Capture only cookies (not sessionStorage) to simulate new tab/window
  const cookies = await context1.cookies();
  await context1.close();

  // New context with only persistent cookies (session cookies are excluded)
  const persistentCookies = cookies.filter(c => c.expires > 0);
  const context2 = await browser.newContext();
  await context2.addCookies(persistentCookies);
  const page2 = await context2.newPage();

  await page2.goto('/dashboard');

  // Should redirect to login since session was not persisted
  await expect(page2).toHaveURL(/\/login/);

  await context2.close();
});
```

**JavaScript**

```javascript
const { test, expect } = require('@playwright/test');

test('remember me persists session across browser restarts', async ({ browser }) => {
  const context1 = await browser.newContext();
  const page1 = await context1.newPage();

  await page1.goto('/login');
  await page1.getByLabel('Email').fill('user@example.com');
  await page1.getByLabel('Password').fill('SecurePass123!');
  await page1.getByLabel('Remember me').check();
  await page1.getByRole('button', { name: 'Sign in' }).click();

  await expect(page1).toHaveURL('/dashboard');

  const storageState = await context1.storageState();
  await context1.close();

  const context2 = await browser.newContext({ storageState });
  const page2 = await context2.newPage();

  await page2.goto('/dashboard');

  await expect(page2).toHaveURL('/dashboard');
  await expect(page2.getByText('Welcome, user@example.com')).toBeVisible();

  await context2.close();
});
```

---

## Recette 3 : Inscription avec vérification d'email (mockée)

### Exemple complet

**TypeScript**

```typescript
import { test, expect } from '@playwright/test';

test('completes signup flow with mocked email verification', async ({ page }) => {
  // Intercept the verification email API so we can capture the token
  let verificationToken = '';
  await page.route('**/api/auth/send-verification', async (route) => {
    // Let the request go through to the server
    const response = await route.fetch();
    const body = await response.json();

    // Capture the token from the API response (test environments expose this)
    verificationToken = body.verificationToken;

    await route.fulfill({ response });
  });

  // Step 1: Fill out signup form
  await page.goto('/signup');

  await page.getByLabel('Full name').fill('Jane Tester');
  await page.getByLabel('Email').fill('jane@example.com');
  await page.getByLabel('Password', { exact: true }).fill('SecurePass123!');
  await page.getByLabel('Confirm password').fill('SecurePass123!');
  await page.getByLabel('I agree to the Terms of Service').check();
  await page.getByRole('button', { name: 'Create account' }).click();

  // Step 2: Verify "check your email" screen appears
  await expect(page.getByText('Check your email')).toBeVisible();
  await expect(page.getByText('jane@example.com')).toBeVisible();

  // Step 3: Navigate directly to verification URL using captured token
  expect(verificationToken).toBeTruthy();
  await page.goto(`/verify-email?token=${verificationToken}`);

  // Step 4: Verify account is now active
  await expect(page.getByText('Email verified successfully')).toBeVisible();
  await expect(page).toHaveURL('/login');

  // Step 5: Log in with the new account
  await page.getByLabel('Email').fill('jane@example.com');
  await page.getByLabel('Password').fill('SecurePass123!');
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page).toHaveURL('/dashboard');
  await expect(page.getByText('Welcome, Jane Tester')).toBeVisible();
});

test('signup with fully mocked email API (no server dependency)', async ({ page }) => {
  const fakeToken = 'test-verification-token-12345';

  // Mock the signup API endpoint
  await page.route('**/api/auth/signup', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        message: 'Verification email sent',
        verificationToken: fakeToken,
      }),
    });
  });

  // Mock the verification endpoint
  await page.route(`**/api/auth/verify-email?token=${fakeToken}`, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ message: 'Email verified', redirectTo: '/login' }),
    });
  });

  await page.goto('/signup');

  await page.getByLabel('Full name').fill('Jane Tester');
  await page.getByLabel('Email').fill('jane@example.com');
  await page.getByLabel('Password', { exact: true }).fill('SecurePass123!');
  await page.getByLabel('Confirm password').fill('SecurePass123!');
  await page.getByLabel('I agree to the Terms of Service').check();
  await page.getByRole('button', { name: 'Create account' }).click();

  await expect(page.getByText('Check your email')).toBeVisible();

  // Simulate clicking the verification link from the email
  await page.goto(`/verify-email?token=${fakeToken}`);

  await expect(page.getByText('Email verified successfully')).toBeVisible();
});
```

**JavaScript**

```javascript
const { test, expect } = require('@playwright/test');

test('completes signup flow with mocked email verification', async ({ page }) => {
  let verificationToken = '';
  await page.route('**/api/auth/send-verification', async (route) => {
    const response = await route.fetch();
    const body = await response.json();
    verificationToken = body.verificationToken;
    await route.fulfill({ response });
  });

  await page.goto('/signup');

  await page.getByLabel('Full name').fill('Jane Tester');
  await page.getByLabel('Email').fill('jane@example.com');
  await page.getByLabel('Password', { exact: true }).fill('SecurePass123!');
  await page.getByLabel('Confirm password').fill('SecurePass123!');
  await page.getByLabel('I agree to the Terms of Service').check();
  await page.getByRole('button', { name: 'Create account' }).click();

  await expect(page.getByText('Check your email')).toBeVisible();

  expect(verificationToken).toBeTruthy();
  await page.goto(`/verify-email?token=${verificationToken}`);

  await expect(page.getByText('Email verified successfully')).toBeVisible();
  await expect(page).toHaveURL('/login');
});
```

---

## Recette 4 : Flow de réinitialisation du mot de passe

### Exemple complet

**TypeScript**

```typescript
import { test, expect } from '@playwright/test';

test('completes password reset flow', async ({ page }) => {
  let resetToken = '';

  // Intercept the password reset API to capture the reset token
  await page.route('**/api/auth/forgot-password', async (route) => {
    const response = await route.fetch();
    const body = await response.json();
    resetToken = body.resetToken;
    await route.fulfill({ response });
  });

  // Step 1: Request password reset
  await page.goto('/forgot-password');

  await page.getByLabel('Email').fill('user@example.com');
  await page.getByRole('button', { name: 'Send reset link' }).click();

  await expect(page.getByText('Reset link sent')).toBeVisible();
  await expect(page.getByText('user@example.com')).toBeVisible();

  // Step 2: Navigate to the reset page with token
  expect(resetToken).toBeTruthy();
  await page.goto(`/reset-password?token=${resetToken}`);

  // Step 3: Set new password
  await page.getByLabel('New password', { exact: true }).fill('NewSecurePass456!');
  await page.getByLabel('Confirm new password').fill('NewSecurePass456!');
  await page.getByRole('button', { name: 'Reset password' }).click();

  await expect(page.getByText('Password reset successfully')).toBeVisible();

  // Step 4: Log in with new password
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('NewSecurePass456!');
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page).toHaveURL('/dashboard');
});

test('password reset with expired token shows error', async ({ page }) => {
  await page.goto('/reset-password?token=expired-token-123');

  await page.getByLabel('New password', { exact: true }).fill('NewSecurePass456!');
  await page.getByLabel('Confirm new password').fill('NewSecurePass456!');
  await page.getByRole('button', { name: 'Reset password' }).click();

  await expect(page.getByRole('alert')).toContainText(
    /token has expired|link is no longer valid/i
  );
  await expect(page.getByRole('link', { name: 'Request a new reset link' })).toBeVisible();
});

test('password reset enforces password strength requirements', async ({ page }) => {
  await page.goto('/reset-password?token=valid-token');

  // Try a weak password
  await page.getByLabel('New password', { exact: true }).fill('123');
  await page.getByLabel('Confirm new password').fill('123');
  await page.getByRole('button', { name: 'Reset password' }).click();

  await expect(page.getByText(/at least 8 characters/i)).toBeVisible();
});
```

**JavaScript**

```javascript
const { test, expect } = require('@playwright/test');

test('completes password reset flow', async ({ page }) => {
  let resetToken = '';

  await page.route('**/api/auth/forgot-password', async (route) => {
    const response = await route.fetch();
    const body = await response.json();
    resetToken = body.resetToken;
    await route.fulfill({ response });
  });

  await page.goto('/forgot-password');

  await page.getByLabel('Email').fill('user@example.com');
  await page.getByRole('button', { name: 'Send reset link' }).click();

  await expect(page.getByText('Reset link sent')).toBeVisible();

  expect(resetToken).toBeTruthy();
  await page.goto(`/reset-password?token=${resetToken}`);

  await page.getByLabel('New password', { exact: true }).fill('NewSecurePass456!');
  await page.getByLabel('Confirm new password').fill('NewSecurePass456!');
  await page.getByRole('button', { name: 'Reset password' }).click();

  await expect(page.getByText('Password reset successfully')).toBeVisible();

  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('NewSecurePass456!');
  await page.getByRole('button', { name: 'Sign in' }).click();

  await expect(page).toHaveURL('/dashboard');
});
```

---

## Recette 5 : Login OAuth (callback mocké)

### Exemple complet

**TypeScript**

```typescript
import { test, expect } from '@playwright/test';

test('logs in via mocked Google OAuth callback', async ({ page }) => {
  // Intercept the OAuth redirect to Google and simulate the callback
  await page.route('**/accounts.google.com/**', async (route) => {
    // Instead of actually going to Google, redirect back to our callback URL
    // with a mock authorization code
    const callbackUrl = new URL('/auth/callback/google', 'http://localhost:3000');
    callbackUrl.searchParams.set('code', 'mock-auth-code-12345');
    callbackUrl.searchParams.set('state', route.request().url().match(/state=([^&]+)/)?.[1] || '');

    await route.fulfill({
      status: 302,
      headers: { location: callbackUrl.toString() },
    });
  });

  // Mock the token exchange on our backend
  await page.route('**/api/auth/callback/google**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        user: {
          id: '1',
          email: 'googleuser@gmail.com',
          name: 'Google User',
          avatar: 'https://example.com/avatar.jpg',
        },
        token: 'mock-jwt-token',
      }),
    });
  });

  await page.goto('/login');

  // Click the OAuth button
  await page.getByRole('button', { name: /Sign in with Google/i }).click();

  // After the mocked OAuth flow, we should land on the dashboard
  await expect(page).toHaveURL('/dashboard');
  await expect(page.getByText('Google User')).toBeVisible();
});

test('handles OAuth login failure gracefully', async ({ page }) => {
  // Simulate OAuth provider returning an error
  await page.route('**/accounts.google.com/**', async (route) => {
    const callbackUrl = new URL('/auth/callback/google', 'http://localhost:3000');
    callbackUrl.searchParams.set('error', 'access_denied');
    callbackUrl.searchParams.set('error_description', 'User denied access');

    await route.fulfill({
      status: 302,
      headers: { location: callbackUrl.toString() },
    });
  });

  await page.goto('/login');
  await page.getByRole('button', { name: /Sign in with Google/i }).click();

  await expect(page.getByRole('alert')).toContainText(/authentication failed|access denied/i);
  await expect(page).toHaveURL(/\/login/);
});
```

**JavaScript**

```javascript
const { test, expect } = require('@playwright/test');

test('logs in via mocked Google OAuth callback', async ({ page }) => {
  await page.route('**/accounts.google.com/**', async (route) => {
    const callbackUrl = new URL('/auth/callback/google', 'http://localhost:3000');
    callbackUrl.searchParams.set('code', 'mock-auth-code-12345');
    callbackUrl.searchParams.set('state', route.request().url().match(/state=([^&]+)/)?.[1] || '');

    await route.fulfill({
      status: 302,
      headers: { location: callbackUrl.toString() },
    });
  });

  await page.route('**/api/auth/callback/google**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        user: { id: '1', email: 'googleuser@gmail.com', name: 'Google User' },
        token: 'mock-jwt-token',
      }),
    });
  });

  await page.goto('/login');
  await page.getByRole('button', { name: /Sign in with Google/i }).click();

  await expect(page).toHaveURL('/dashboard');
  await expect(page.getByText('Google User')).toBeVisible();
});
```

---

## Recette 6 : Tests d'accès basés sur les rôles

### Exemple complet

**TypeScript**

```typescript
import { test, expect, type Page } from '@playwright/test';
import path from 'path';

// Store auth state for each role in separate files
const authDir = path.resolve(__dirname, '../.auth');

// Setup: create auth state files for each role (run in globalSetup or auth.setup)
// This pattern uses Playwright's storage state for efficient role switching
const roles = ['admin', 'editor', 'viewer'] as const;
type Role = typeof roles[number];

function authFile(role: Role): string {
  return path.join(authDir, `${role}.json`);
}

// Auth setup project — runs before all tests
test.describe('auth setup', () => {
  const credentials: Record<Role, { email: string; password: string }> = {
    admin: { email: 'admin@example.com', password: 'AdminPass123!' },
    editor: { email: 'editor@example.com', password: 'EditorPass123!' },
    viewer: { email: 'viewer@example.com', password: 'ViewerPass123!' },
  };

  for (const role of roles) {
    test(`authenticate as ${role}`, async ({ page }) => {
      await page.goto('/login');
      await page.getByLabel('Email').fill(credentials[role].email);
      await page.getByLabel('Password').fill(credentials[role].password);
      await page.getByRole('button', { name: 'Sign in' }).click();
      await expect(page).toHaveURL('/dashboard');

      await page.context().storageState({ path: authFile(role) });
    });
  }
});

// Admin tests
test.describe('admin access', () => {
  test.use({ storageState: authFile('admin') });

  test('admin can access user management', async ({ page }) => {
    await page.goto('/admin/users');
    await expect(page).toHaveURL('/admin/users');
    await expect(page.getByRole('heading', { name: 'User Management' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Add user' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Delete' }).first()).toBeVisible();
  });

  test('admin can access system settings', async ({ page }) => {
    await page.goto('/admin/settings');
    await expect(page).toHaveURL('/admin/settings');
    await expect(page.getByRole('heading', { name: 'System Settings' })).toBeVisible();
  });
});

// Editor tests
test.describe('editor access', () => {
  test.use({ storageState: authFile('editor') });

  test('editor can create and edit content', async ({ page }) => {
    await page.goto('/content');
    await expect(page.getByRole('button', { name: 'New post' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Edit' }).first()).toBeVisible();
  });

  test('editor cannot access admin area', async ({ page }) => {
    await page.goto('/admin/users');
    // Should be redirected or shown forbidden
    await expect(page).toHaveURL(/\/(403|dashboard|login)/);
  });
});

// Viewer tests
test.describe('viewer access', () => {
  test.use({ storageState: authFile('viewer') });

  test('viewer can read content', async ({ page }) => {
    await page.goto('/content');
    await expect(page.getByRole('article').first()).toBeVisible();
  });

  test('viewer cannot create content', async ({ page }) => {
    await page.goto('/content');
    await expect(page.getByRole('button', { name: 'New post' })).not.toBeVisible();
  });

  test('viewer cannot access admin area', async ({ page }) => {
    await page.goto('/admin/users');
    await expect(page).toHaveURL(/\/(403|dashboard|login)/);
  });
});
```

**JavaScript**

```javascript
const { test, expect } = require('@playwright/test');
const path = require('path');

const authDir = path.resolve(__dirname, '../.auth');

function authFile(role) {
  return path.join(authDir, `${role}.json`);
}

// Admin tests
test.describe('admin access', () => {
  test.use({ storageState: authFile('admin') });

  test('admin can access user management', async ({ page }) => {
    await page.goto('/admin/users');
    await expect(page).toHaveURL('/admin/users');
    await expect(page.getByRole('heading', { name: 'User Management' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Add user' })).toBeVisible();
  });

  test('admin can access system settings', async ({ page }) => {
    await page.goto('/admin/settings');
    await expect(page).toHaveURL('/admin/settings');
  });
});

// Viewer tests
test.describe('viewer access', () => {
  test.use({ storageState: authFile('viewer') });

  test('viewer cannot create content', async ({ page }) => {
    await page.goto('/content');
    await expect(page.getByRole('button', { name: 'New post' })).not.toBeVisible();
  });

  test('viewer cannot access admin area', async ({ page }) => {
    await page.goto('/admin/users');
    await expect(page).toHaveURL(/\/(403|dashboard|login)/);
  });
});
```

---

## Recette 7 : Gestion du timeout de session

### Exemple complet

**TypeScript**

```typescript
import { test, expect } from '@playwright/test';

test('redirects to login after session timeout', async ({ page, context }) => {
  // Log in first
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('SecurePass123!');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page).toHaveURL('/dashboard');

  // Simulate session expiration by clearing the session cookie
  const cookies = await context.cookies();
  const sessionCookie = cookies.find(
    (c) => c.name === 'session' || c.name === 'sid' || c.name === 'connect.sid'
  );

  if (sessionCookie) {
    await context.clearCookies({ name: sessionCookie.name });
  }

  // Try to navigate to a protected page
  await page.goto('/settings');

  // Should redirect to login with a return URL
  await expect(page).toHaveURL(/\/login/);
  await expect(page.getByText(/session.*expired|please.*log in again/i)).toBeVisible();
});

test('shows session expiry warning before timeout', async ({ page }) => {
  // Mock the session check endpoint to return "expiring soon"
  await page.route('**/api/auth/session', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        valid: true,
        expiresIn: 120, // 2 minutes remaining
      }),
    });
  });

  await page.goto('/dashboard');

  // The app should show a warning when session is about to expire
  await expect(page.getByText(/session.*expir/i)).toBeVisible({ timeout: 10000 });
  await expect(page.getByRole('button', { name: /extend|stay logged in/i })).toBeVisible();
});

test('extends session when user clicks extend', async ({ page }) => {
  let sessionExtended = false;

  await page.route('**/api/auth/session', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ valid: true, expiresIn: 120 }),
    });
  });

  await page.route('**/api/auth/refresh', async (route) => {
    sessionExtended = true;
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ valid: true, expiresIn: 3600 }),
    });
  });

  await page.goto('/dashboard');

  await expect(page.getByRole('button', { name: /extend|stay logged in/i })).toBeVisible({
    timeout: 10000,
  });
  await page.getByRole('button', { name: /extend|stay logged in/i }).click();

  expect(sessionExtended).toBe(true);
  await expect(page.getByText(/session.*expir/i)).not.toBeVisible();
});
```

**JavaScript**

```javascript
const { test, expect } = require('@playwright/test');

test('redirects to login after session timeout', async ({ page, context }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('SecurePass123!');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page).toHaveURL('/dashboard');

  const cookies = await context.cookies();
  const sessionCookie = cookies.find(
    (c) => c.name === 'session' || c.name === 'sid' || c.name === 'connect.sid'
  );

  if (sessionCookie) {
    await context.clearCookies({ name: sessionCookie.name });
  }

  await page.goto('/settings');

  await expect(page).toHaveURL(/\/login/);
  await expect(page.getByText(/session.*expired|please.*log in again/i)).toBeVisible();
});
```

---

## Recette 8 : Déconnexion

### Exemple complet

**TypeScript**

```typescript
import { test, expect } from '@playwright/test';

// Use a logged-in state
test.use({ storageState: '.auth/user.json' });

test('logs out and redirects to login page', async ({ page }) => {
  await page.goto('/dashboard');
  await expect(page.getByText('Welcome')).toBeVisible();

  // Open user menu and click logout
  await page.getByRole('button', { name: /user menu|account|profile/i }).click();
  await page.getByRole('menuitem', { name: 'Log out' }).click();

  // Should redirect to login
  await expect(page).toHaveURL('/login');

  // Verify we can no longer access protected pages
  await page.goto('/dashboard');
  await expect(page).toHaveURL(/\/login/);
});

test('logout clears all session data', async ({ page, context }) => {
  await page.goto('/dashboard');

  await page.getByRole('button', { name: /user menu|account|profile/i }).click();
  await page.getByRole('menuitem', { name: 'Log out' }).click();

  await expect(page).toHaveURL('/login');

  // Verify cookies are cleared
  const cookies = await context.cookies();
  const sessionCookies = cookies.filter(
    (c) => c.name === 'session' || c.name === 'sid' || c.name === 'token'
  );
  expect(sessionCookies).toHaveLength(0);

  // Verify localStorage is cleared
  const token = await page.evaluate(() => localStorage.getItem('authToken'));
  expect(token).toBeNull();
});

test('logout from all devices', async ({ page }) => {
  let logoutAllCalled = false;

  await page.route('**/api/auth/logout-all', async (route) => {
    logoutAllCalled = true;
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ message: 'Logged out from all devices' }),
    });
  });

  await page.goto('/settings/security');

  await page.getByRole('button', { name: 'Log out of all devices' }).click();

  // Confirm the action in the dialog
  await page.getByRole('dialog').getByRole('button', { name: 'Confirm' }).click();

  expect(logoutAllCalled).toBe(true);
  await expect(page).toHaveURL(/\/login/);
});
```

**JavaScript**

```javascript
const { test, expect } = require('@playwright/test');

test.use({ storageState: '.auth/user.json' });

test('logs out and redirects to login page', async ({ page }) => {
  await page.goto('/dashboard');

  await page.getByRole('button', { name: /user menu|account|profile/i }).click();
  await page.getByRole('menuitem', { name: 'Log out' }).click();

  await expect(page).toHaveURL('/login');

  await page.goto('/dashboard');
  await expect(page).toHaveURL(/\/login/);
});

test('logout clears all session data', async ({ page, context }) => {
  await page.goto('/dashboard');

  await page.getByRole('button', { name: /user menu|account|profile/i }).click();
  await page.getByRole('menuitem', { name: 'Log out' }).click();

  await expect(page).toHaveURL('/login');

  const cookies = await context.cookies();
  const sessionCookies = cookies.filter(
    (c) => c.name === 'session' || c.name === 'sid' || c.name === 'token'
  );
  expect(sessionCookies).toHaveLength(0);
});
```

---

## Variantes

### Login via l'API pour gagner en vitesse

Évite l'UI de login quand tu testes des fonctionnalités sans rapport avec l'auth. Utilise le context `request` pour obtenir les tokens plus vite.

**TypeScript**

```typescript
import { test as setup } from '@playwright/test';

setup('authenticate via API', async ({ request }) => {
  const response = await request.post('/api/auth/login', {
    data: {
      email: 'user@example.com',
      password: 'SecurePass123!',
    },
  });

  expect(response.ok()).toBeTruthy();

  // Save the auth state
  await request.storageState({ path: '.auth/user.json' });
});
```

### Authentification multi-facteurs

```typescript
test('logs in with MFA (TOTP)', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('mfa-user@example.com');
  await page.getByLabel('Password').fill('SecurePass123!');
  await page.getByRole('button', { name: 'Sign in' }).click();

  // MFA challenge screen appears
  await expect(page.getByText('Enter verification code')).toBeVisible();

  // In test environments, use a predictable TOTP code or mock the verification
  await page.route('**/api/auth/verify-mfa', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ success: true, token: 'jwt-token' }),
    });
  });

  await page.getByLabel('Verification code').fill('123456');
  await page.getByRole('button', { name: 'Verify' }).click();

  await expect(page).toHaveURL('/dashboard');
});
```

### Passkeys / WebAuthn (Playwright 1.61+)

Playwright 1.61 fournit un authenticator WebAuthn virtuel limité au browser context : `context.credentials`. Les tests peuvent enregistrer des passkeys et répondre aux cérémonies `navigator.credentials.create()` / `navigator.credentials.get()` sans clé de sécurité physique. Appelle `credentials.install()` avant qu'une page du context ne démarre une cérémonie WebAuthn.

**Pattern A : laisser l'application enregistrer une passkey, puis s'en servir pour se connecter**

```typescript
test('registers a passkey and signs in with it', async ({ browser }) => {
  const context = await browser.newContext();
  await context.credentials.install(); // override navigator.credentials in this context

  const page = await context.newPage();

  // Register: the app's "Create a passkey" flow now talks to the virtual authenticator
  await page.goto('/settings/security');
  await page.getByRole('button', { name: 'Create a passkey' }).click();
  await expect(page.getByText('Passkey added')).toBeVisible();

  // Sign out, then sign back in with the passkey
  await page.goto('/logout');
  await page.goto('/login');
  await page.getByRole('button', { name: 'Sign in with a passkey' }).click();
  // navigator.credentials.get() is answered with the registered passkey
  await expect(page).toHaveURL('/dashboard');

  await context.close();
});
```

**Pattern B : capturer une fois, injecter partout (le pattern storageState pour les passkeys)**

```typescript
// setup project: register a passkey once and save it (it includes the private key)
const [credential] = await context.credentials.get({ rpId: 'example.com' });
fs.writeFileSync('playwright/.auth/passkey.json', JSON.stringify(credential));

// later tests: seed the captured passkey so the user is already enrolled
const credential = JSON.parse(fs.readFileSync('playwright/.auth/passkey.json', 'utf8'));
const context = await browser.newContext();
await context.credentials.create(credential.rpId, credential);
await context.credentials.install();
// navigator.credentials.get() now resolves the seeded passkey — no registration UI needed
```

Tu peux aussi injecter un credential que ton backend a déjà provisionné pour un utilisateur de test, en passant `id`, `userHandle`, `privateKey` (base64url PKCS#8) et `publicKey` (base64url SPKI) à `credentials.create(rpId, …)`, et en supprimer un avec `credentials.delete(id)`.

**Compteur de signature (1.64+)** : `credentials.create()` accepte `signCount` pour définir le compteur initial de l'authenticator, et `create()` / `get()` renvoient la valeur courante. Le compteur est sauvegardé et restauré avec les credentials dans le storage state. Utilise-le pour vérifier que ton serveur rejette un authenticator rejoué ou cloné dont le compteur régresse :

```typescript
await context.credentials.create(credential.rpId, { ...credential, signCount: 100 });
```

**Astuces :**
- Alternative au pattern B : `context.storageState({ path, credentials: true })` sauvegarde les passkeys avec les cookies ; restaurer cet état installe automatiquement l'authenticator virtuel.
- Traite le JSON de passkey sauvegardé comme un `storageState` sauvegardé : il contient une clé privée, donc garde-le hors du contrôle de version (ajoute le répertoire `.auth/` au `.gitignore`).
- Combine-le avec un setup project (voir la recette 1) pour que l'enrôlement de la passkey ait lieu une fois par exécution, et non à chaque test.
- Teste aussi le chemin de repli : que se passe-t-il quand l'utilisateur annule la cérémonie ou n'a pas de passkey.

### Tester l'auth avec différents browser contexts

```typescript
test('two users interact simultaneously', async ({ browser }) => {
  const adminContext = await browser.newContext({
    storageState: '.auth/admin.json',
  });
  const userContext = await browser.newContext({
    storageState: '.auth/viewer.json',
  });

  const adminPage = await adminContext.newPage();
  const userPage = await userContext.newPage();

  // Admin bans a user
  await adminPage.goto('/admin/users');
  await adminPage.getByRole('row', { name: 'viewer@example.com' })
    .getByRole('button', { name: 'Ban' }).click();
  await adminPage.getByRole('dialog').getByRole('button', { name: 'Confirm' }).click();

  // User tries to navigate and should be blocked
  await userPage.goto('/dashboard');
  await expect(userPage.getByText(/account.*banned|access.*revoked/i)).toBeVisible();

  await adminContext.close();
  await userContext.close();
});
```

---

## Astuces

1. **Utilise `storageState` pour une auth réutilisable**. Exécute le login une seule fois dans un setup project, sauvegarde l'état dans un fichier JSON et réutilise-le dans tous les tests. Cela accélère considérablement ta suite de tests, puisque tu ne te connectes qu'une fois par rôle.

2. **N'écris jamais les identifiants en dur dans les fichiers de test**. Utilise des variables d'environnement ou un fichier `.env` chargé via `dotenv`. Dans `playwright.config.ts`, définis des valeurs `process.env` ou utilise l'option `env` dans `use`.

3. **Privilégie le login via l'API pour les tests hors auth**. Ne teste l'UI de login que dans tes tests spécifiques à l'auth. Pour tout le reste, authentifie-toi via l'API ou en restaurant `storageState`. Les tests sont ainsi plus rapides et moins fragiles.

4. **Teste aussi les cas négatifs**. Identifiants invalides, tokens expirés, comptes verrouillés, rate limiting. Ce sont les scénarios que les utilisateurs rencontrent réellement en production, et ils sont souvent sous-testés.

5. **Réduis le timeout de session dans ton environnement de test**. Si ton application a un timeout de session de 30 minutes, configure-le à 30 secondes dans l'environnement de test pour pouvoir tester le comportement du timeout sans tests lents.

---

## Voir aussi

- [Documentation Playwright sur l'authentification](https://playwright.dev/docs/auth)
- `patterns/page-objects.md` -- Encapsuler les flows de login dans des page objects
- `foundations/assertions.md` -- Patterns d'assertions pour les états d'auth
- `recipes/crud-testing.md` -- Tester les opérations CRUD une fois authentifié
