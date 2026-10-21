# Mock de l'horloge et du temps

> **Quand l'utiliser** : tester des features dépendantes du temps -- comptes à rebours, événements planifiés, dates d'expiration, contrôles d'âge, timeouts de session, ou toute UI dont le comportement change selon l'heure courante. L'API `page.clock` de Playwright te permet de contrôler le temps sans attendre en temps réel.
> **Prérequis** : [core/assertions-and-waiting.md](assertions-and-waiting.md), [core/configuration.md](configuration.md)

## Référence rapide

```typescript
// Freeze time at a specific moment
await page.clock.install({ time: new Date('2025-03-15T10:00:00Z') });
await page.goto('/dashboard');

// Advance time by 5 minutes
await page.clock.fastForward('05:00');

// Set time to a specific point (jumps, does not tick through)
await page.clock.setFixedTime(new Date('2025-12-31T23:59:59Z'));

// Let time resume ticking from current mocked point
await page.clock.resume();
```

**Concept clé** : `page.clock.install()` remplace `Date`, `setTimeout`, `setInterval` et `requestAnimationFrame` dans la page. Appelle-le avant `page.goto()` pour que la page se charge avec le temps mocké dès le départ.

## Patterns

### Temps figé avec `install()` et `setFixedTime()`

**À utiliser quand** : ton test a besoin que le temps s'arrête à un moment précis -- vérifier ce que l'UI affiche à une date/heure donnée.
**À éviter quand** : la feature testée dépend de timers qui s'écoulent (utilise plutôt `fastForward`).

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('dashboard shows correct greeting based on time of day', async ({ page }) => {
  // Install clock BEFORE navigating
  await page.clock.install({ time: new Date('2025-06-15T08:30:00') });
  await page.goto('/dashboard');
  await expect(page.getByText('Good morning')).toBeVisible();

  // Jump to afternoon
  await page.clock.setFixedTime(new Date('2025-06-15T14:00:00'));
  await page.reload();
  await expect(page.getByText('Good afternoon')).toBeVisible();

  // Jump to evening
  await page.clock.setFixedTime(new Date('2025-06-15T20:00:00'));
  await page.reload();
  await expect(page.getByText('Good evening')).toBeVisible();
});

test('subscription shows correct expiration status', async ({ page }) => {
  // Freeze time to a date when subscription is active
  await page.clock.install({ time: new Date('2025-06-01T12:00:00Z') });
  await page.goto('/account');

  await expect(page.getByTestId('subscription-status')).toHaveText('Active');
  await expect(page.getByTestId('days-remaining')).toContainText('29');

  // Jump to the expiration date
  await page.clock.setFixedTime(new Date('2025-06-30T12:00:00Z'));
  await page.reload();

  await expect(page.getByTestId('subscription-status')).toHaveText('Expiring today');
});

test('content displays correctly on a specific holiday', async ({ page }) => {
  await page.clock.install({ time: new Date('2025-12-25T10:00:00') });
  await page.goto('/');

  await expect(page.getByText('Happy Holidays')).toBeVisible();
  await expect(page.getByTestId('holiday-banner')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('dashboard shows correct greeting based on time of day', async ({ page }) => {
  await page.clock.install({ time: new Date('2025-06-15T08:30:00') });
  await page.goto('/dashboard');
  await expect(page.getByText('Good morning')).toBeVisible();

  await page.clock.setFixedTime(new Date('2025-06-15T14:00:00'));
  await page.reload();
  await expect(page.getByText('Good afternoon')).toBeVisible();
});

test('subscription shows correct expiration status', async ({ page }) => {
  await page.clock.install({ time: new Date('2025-06-01T12:00:00Z') });
  await page.goto('/account');

  await expect(page.getByTestId('subscription-status')).toHaveText('Active');
});
```

### Avance rapide du temps avec `fastForward()`

**À utiliser quand** : tu testes des timers, des comptes à rebours, des actions avec debounce, ou toute feature qui réagit au temps écoulé. `fastForward` déclenche tous les timers en attente jusqu'à la durée indiquée.
**À éviter quand** : tu dois juste vérifier un affichage statique dépendant du temps -- utilise plutôt `setFixedTime`.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('countdown timer reaches zero', async ({ page }) => {
  await page.clock.install({ time: new Date('2025-03-15T10:00:00Z') });
  await page.goto('/sale');

  // Sale countdown starts at 2 hours
  await expect(page.getByTestId('countdown')).toContainText('2:00:00');

  // Fast-forward 1 hour
  await page.clock.fastForward('01:00:00');
  await expect(page.getByTestId('countdown')).toContainText('1:00:00');

  // Fast-forward remaining time
  await page.clock.fastForward('01:00:00');
  await expect(page.getByTestId('countdown')).toContainText('0:00:00');
  await expect(page.getByText('Sale ended')).toBeVisible();
});

test('auto-save triggers after 30 seconds of inactivity', async ({ page }) => {
  await page.clock.install({ time: new Date('2025-03-15T10:00:00Z') });
  await page.goto('/editor');

  // Type something
  await page.getByRole('textbox', { name: 'Content' }).fill('Draft content');

  // Fast-forward past the auto-save interval
  await page.clock.fastForward('00:30');

  await expect(page.getByText('Saved')).toBeVisible();
});

test('session timeout warning appears after 25 minutes', async ({ page }) => {
  await page.clock.install({ time: new Date('2025-03-15T10:00:00Z') });
  await page.goto('/dashboard');

  // Fast-forward to just before the warning (25 min)
  await page.clock.fastForward('24:59');
  await expect(page.getByRole('dialog', { name: 'Session timeout' })).not.toBeVisible();

  // One more minute triggers the warning
  await page.clock.fastForward('00:01');
  await expect(page.getByRole('dialog', { name: 'Session timeout' })).toBeVisible();
  await expect(page.getByText('Your session will expire in 5 minutes')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('countdown timer reaches zero', async ({ page }) => {
  await page.clock.install({ time: new Date('2025-03-15T10:00:00Z') });
  await page.goto('/sale');

  await expect(page.getByTestId('countdown')).toContainText('2:00:00');

  await page.clock.fastForward('01:00:00');
  await expect(page.getByTestId('countdown')).toContainText('1:00:00');

  await page.clock.fastForward('01:00:00');
  await expect(page.getByText('Sale ended')).toBeVisible();
});

test('auto-save triggers after inactivity', async ({ page }) => {
  await page.clock.install({ time: new Date('2025-03-15T10:00:00Z') });
  await page.goto('/editor');

  await page.getByRole('textbox', { name: 'Content' }).fill('Draft content');
  await page.clock.fastForward('00:30');

  await expect(page.getByText('Saved')).toBeVisible();
});
```

### Reprendre le cours du temps avec `resume()`

**À utiliser quand** : tu dois démarrer avec un temps mocké, puis laisser le temps s'écouler normalement pour un comportement dépendant des interactions.
**À éviter quand** : tout le test doit utiliser le temps mocké.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('notification appears in real-time after scheduled trigger', async ({ page }) => {
  // Start at a known time
  await page.clock.install({ time: new Date('2025-03-15T09:59:55Z') });
  await page.goto('/dashboard');

  // Notification is scheduled for 10:00:00 — advance to 5 seconds before
  await expect(page.getByTestId('notification-bell')).not.toHaveAttribute('data-count');

  // Let real time tick from this point
  await page.clock.resume();

  // The notification should appear within a few seconds
  await expect(page.getByTestId('notification-bell')).toHaveAttribute('data-count', '1', {
    timeout: 10000,
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('notification appears after scheduled trigger', async ({ page }) => {
  await page.clock.install({ time: new Date('2025-03-15T09:59:55Z') });
  await page.goto('/dashboard');

  await page.clock.resume();

  await expect(page.getByTestId('notification-bell')).toHaveAttribute('data-count', '1', {
    timeout: 10000,
  });
});
```

### Tester une UI dépendante de la date

**À utiliser quand** : features qui changent selon la date courante -- vérification d'âge, avertissements d'expiration, contenu saisonnier, date pickers.
**À éviter quand** : la date est transmise par le serveur et ne dépend pas du `Date` côté client.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('age gate blocks users under 18', async ({ page }) => {
  // User born on 2010-01-15 — under 18 as of 2025-06-01
  await page.clock.install({ time: new Date('2025-06-01T12:00:00') });
  await page.goto('/age-restricted');

  await page.getByLabel('Date of birth').fill('2010-01-15');
  await page.getByRole('button', { name: 'Verify age' }).click();

  await expect(page.getByText('You must be 18 or older')).toBeVisible();
});

test('age gate allows users 18 and older', async ({ page }) => {
  await page.clock.install({ time: new Date('2025-06-01T12:00:00') });
  await page.goto('/age-restricted');

  await page.getByLabel('Date of birth').fill('2005-01-15');
  await page.getByRole('button', { name: 'Verify age' }).click();

  await expect(page.getByText('Welcome')).toBeVisible();
});

test('trial expiration banner shows at correct times', async ({ page }) => {
  // Day 1 of 14-day trial
  await page.clock.install({ time: new Date('2025-03-01T12:00:00Z') });
  await page.goto('/dashboard');
  await expect(page.getByTestId('trial-banner')).toContainText('13 days remaining');

  // Day 12 — warning state
  await page.clock.setFixedTime(new Date('2025-03-12T12:00:00Z'));
  await page.reload();
  await expect(page.getByTestId('trial-banner')).toContainText('2 days remaining');
  await expect(page.getByTestId('trial-banner')).toHaveCSS('background-color', /rgb\(255/); // Red/warning

  // Day 15 — expired
  await page.clock.setFixedTime(new Date('2025-03-15T12:00:00Z'));
  await page.reload();
  await expect(page.getByText('Your trial has expired')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Upgrade now' })).toBeVisible();
});

test('date picker defaults to current mocked date', async ({ page }) => {
  await page.clock.install({ time: new Date('2025-07-04T12:00:00') });
  await page.goto('/booking');

  await page.getByLabel('Check-in date').click();

  // Calendar should open to July 2025
  await expect(page.getByText('July 2025')).toBeVisible();

  // Today (July 4) should be highlighted
  const today = page.locator('[aria-current="date"]');
  await expect(today).toHaveText('4');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('age gate blocks users under 18', async ({ page }) => {
  await page.clock.install({ time: new Date('2025-06-01T12:00:00') });
  await page.goto('/age-restricted');

  await page.getByLabel('Date of birth').fill('2010-01-15');
  await page.getByRole('button', { name: 'Verify age' }).click();

  await expect(page.getByText('You must be 18 or older')).toBeVisible();
});

test('trial expiration shows correct days remaining', async ({ page }) => {
  await page.clock.install({ time: new Date('2025-03-01T12:00:00Z') });
  await page.goto('/dashboard');
  await expect(page.getByTestId('trial-banner')).toContainText('13 days remaining');

  await page.clock.setFixedTime(new Date('2025-03-15T12:00:00Z'));
  await page.reload();
  await expect(page.getByText('Your trial has expired')).toBeVisible();
});
```

### Features dépendantes du fuseau horaire

**À utiliser quand** : tu testes des features qui combinent un temps mocké et des fuseaux horaires précis.
**À éviter quand** : la feature n'utilise que l'UTC et n'affiche pas d'heures locales.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('business hours banner shows open/closed status', async ({ browser }) => {
  // Business hours: 9 AM - 5 PM Eastern
  const context = await browser.newContext({ timezoneId: 'America/New_York' });
  const page = await context.newPage();

  // 10 AM Eastern — should show "Open"
  await page.clock.install({ time: new Date('2025-03-15T14:00:00Z') }); // 10 AM ET
  await page.goto('/contact');
  await expect(page.getByTestId('business-hours')).toContainText('Open');

  // 6 PM Eastern — should show "Closed"
  await page.clock.setFixedTime(new Date('2025-03-15T22:00:00Z')); // 6 PM ET
  await page.reload();
  await expect(page.getByTestId('business-hours')).toContainText('Closed');

  await context.close();
});

test('scheduled event shows correct local time', async ({ browser }) => {
  // Event at 2025-03-20T18:00:00Z

  // User in Tokyo (UTC+9)
  const tokyoCtx = await browser.newContext({ timezoneId: 'Asia/Tokyo' });
  const tokyoPage = await tokyoCtx.newPage();
  await tokyoPage.clock.install({ time: new Date('2025-03-20T10:00:00Z') });
  await tokyoPage.goto('/events/upcoming');
  // 18:00 UTC = 03:00 AM next day in Tokyo (UTC+9)
  await expect(tokyoPage.getByTestId('event-time')).toContainText('3:00 AM');
  await tokyoCtx.close();

  // User in London (UTC+0 in March, before DST)
  const londonCtx = await browser.newContext({ timezoneId: 'Europe/London' });
  const londonPage = await londonCtx.newPage();
  await londonPage.clock.install({ time: new Date('2025-03-20T10:00:00Z') });
  await londonPage.goto('/events/upcoming');
  await expect(londonPage.getByTestId('event-time')).toContainText('6:00 PM');
  await londonCtx.close();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('business hours banner shows open/closed status', async ({ browser }) => {
  const context = await browser.newContext({ timezoneId: 'America/New_York' });
  const page = await context.newPage();

  await page.clock.install({ time: new Date('2025-03-15T14:00:00Z') });
  await page.goto('/contact');
  await expect(page.getByTestId('business-hours')).toContainText('Open');

  await page.clock.setFixedTime(new Date('2025-03-15T22:00:00Z'));
  await page.reload();
  await expect(page.getByTestId('business-hours')).toContainText('Closed');

  await context.close();
});
```

## Guide de décision

| Scénario | API | Pourquoi |
|---|---|---|
| Vérifier l'UI à une date/heure précise | `clock.install()` + `clock.setFixedTime()` | Le temps est figé ; aucun timer ne s'écoule |
| Tester un compte à rebours ou un timer | `clock.install()` + `clock.fastForward()` | Déclenche les timers au fil de l'avance du temps sans attente réelle |
| Tester après une longue période d'inactivité | `clock.install()` + `clock.fastForward('30:00')` | Simule 30 minutes sans attendre 30 minutes |
| Démarrer mocké, puis laisser le temps s'écouler normalement | `clock.install()` + `clock.resume()` | Utile quand tu as besoin d'un vrai `requestAnimationFrame` après le setup |
| Affichage selon un autre fuseau horaire | `browser.newContext({ timezoneId })` | Affecte le rendu du fuseau horaire de `Date` |
| Fuseau horaire + temps mocké | `newContext({ timezoneId })` + `clock.install()` | Le fuseau horaire et l'heure absolue sont tous deux contrôlés |
| Tester les valeurs par défaut d'un date picker | `clock.install()` avec la date cible | Le calendrier s'ouvre sur le « aujourd'hui » mocké |
| Tester les transitions d'heure d'été (DST) | Définir `timezoneId` + `install` à la frontière DST | Teste les bugs de fuseau horaire les plus courants |

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| Appeler `clock.install()` après `page.goto()` | La page est déjà chargée avec le vrai `Date` ; les timers ont déjà tiré | Appelle `clock.install()` AVANT `page.goto()` |
| Utiliser `page.waitForTimeout(30000)` pour tester un timer de 30 secondes | Gaspille 30 secondes réelles à chaque exécution du test | `page.clock.fastForward('00:30')` se termine instantanément |
| Tester le temps sans mocker l'horloge | Les résultats dépendent du moment où le test s'exécute (matin vs soir, lundi vs dimanche) | Mocke toujours le temps pour les assertions dépendantes du temps |
| Utiliser `setFixedTime` quand tu as besoin que les timers se déclenchent | `setFixedTime` fige le temps ; `setInterval`/`setTimeout` ne se déclencheront pas | Utilise `fastForward` pour avancer le temps et déclencher les timers en attente |
| Ne mocker que `Date.now()` via `page.evaluate` | N'affecte pas `setTimeout`, `setInterval` ni `requestAnimationFrame` | Utilise `page.clock.install()`, qui mocke toutes les API de temps |
| Oublier le fuseau horaire en testant des dates | Le test passe en local mais échoue en CI (fuseau horaire différent) | Définis toujours `timezoneId` dans le contexte ou utilise des dates UTC |
| Avancer le temps par très petits incréments | Test lent ; beaucoup de déclenchements de timers inutiles | Avance jusqu'à l'instant voulu en un seul appel |
| Ne pas appeler `resume()` avant des assertions dépendant du temps réel | Les timers mockés ne se déclenchent pas naturellement ; les assertions expirent | Appelle `clock.resume()` quand tu as besoin que le temps réel s'écoule |

## Dépannage

| Symptôme | Cause probable | Correctif |
|---|---|---|
| `clock.install()` n'a aucun effet | Appelé après `page.goto()` ; la page a déjà le vrai `Date` | Déplace `clock.install()` avant la navigation |
| Les callbacks de timers ne se déclenchent jamais | Le temps est figé avec `setFixedTime` ; les timers doivent être avancés | Utilise `fastForward()` pour dépasser le délai du timer |
| `fastForward` ne déclenche pas le timer | Le timer a été enregistré avec un délai plus long que la durée de l'avance rapide | Avance d'au moins le délai du timer |
| La date est correcte mais l'affichage du fuseau horaire est faux | `clock.install` définit l'heure en UTC ; `timezoneId` n'est pas défini sur le contexte | Crée le contexte avec `{ timezoneId: 'Your/Timezone' }` |
| Les animations se cassent avec l'horloge mockée | `requestAnimationFrame` est mocké et ne se déclenche pas naturellement | Appelle `clock.resume()` avant les assertions dépendantes d'animations |
| Le test passe en local mais échoue en CI | Le fuseau horaire local diffère de celui de la CI | Définis toujours `timezoneId` explicitement dans le contexte |
| `setFixedTime` lève « clock not installed » | `install()` n'a pas été appelé en premier | Appelle `page.clock.install()` avant toute autre méthode de l'horloge |
| La page fait des requêtes fetch avec de mauvais timestamps | Le serveur voit le `Date.now()` mocké dans les payloads de requête | C'est attendu ; mocke les réponses du serveur si nécessaire |

## Voir aussi

- [core/i18n-and-localization.md](i18n-and-localization.md) -- patterns de test des fuseaux horaires et des locales
- [core/assertions-and-waiting.md](assertions-and-waiting.md) -- auto-waiting vs assertions basées sur le temps
- [core/error-and-edge-cases.md](error-and-edge-cases.md) -- tester les cas limites de timeout et d'expiration
- [core/performance-testing.md](performance-testing.md) -- mesure de performance liée au timing
- [core/websockets-and-realtime.md](websockets-and-realtime.md) -- features temps réel dépendantes du timing
