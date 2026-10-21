# WebSockets and Real-Time Testing

> **Quand l'utiliser** : quand ton application utilise des WebSockets, des Server-Sent Events (SSE) ou du polling pour des fonctionnalités temps réel -- chat, dashboards live, notifications, édition collaborative, tickers boursiers, scores sportifs en direct.
> **Prérequis** : [core/assertions-and-waiting.md](assertions-and-waiting.md), [core/fixtures-and-hooks.md](fixtures-and-hooks.md)

## Référence rapide

```typescript
// Listen for WebSocket connections
page.on('websocket', (ws) => {
  console.log('WebSocket opened:', ws.url());

  ws.on('framesent', (frame) => console.log('Sent:', frame.payload));
  ws.on('framereceived', (frame) => console.log('Received:', frame.payload));
  ws.on('close', () => console.log('WebSocket closed'));
});

// Mock a WebSocket via route (Playwright 1.48+)
await page.routeWebSocket('**/ws', (ws) => {
  ws.onMessage((message) => {
    ws.send(JSON.stringify({ echo: message }));
  });
});
```

## Patterns

### Observer le trafic WebSocket

**À utiliser quand** : tu dois vérifier que ton app envoie et reçoit les bons messages WebSocket sans les modifier.
**À éviter quand** : tu dois intercepter ou mocker les messages. Utilise `routeWebSocket` à la place.

> **Playwright 1.61+** : les enregistrements HAR et trace incluent désormais les requêtes WebSocket. Pour le débogage post-mortem, tu n'as souvent pas besoin de code de listener du tout — enregistre une trace et inspecte le trafic WS dans le Trace Viewer ou avec `npx playwright trace requests` (voir [trace-analysis.md](trace-analysis.md)).

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('chat message is sent over WebSocket', async ({ page }) => {
  const messages: { direction: string; payload: string }[] = [];

  page.on('websocket', (ws) => {
    ws.on('framesent', (frame) => {
      messages.push({ direction: 'sent', payload: String(frame.payload) });
    });
    ws.on('framereceived', (frame) => {
      messages.push({ direction: 'received', payload: String(frame.payload) });
    });
  });

  await page.goto('/chat');
  await page.getByRole('textbox', { name: 'Message' }).fill('Hello!');
  await page.getByRole('button', { name: 'Send' }).click();

  // Wait for the message to appear in UI (confirms round-trip)
  await expect(page.getByText('Hello!')).toBeVisible();

  // Verify WebSocket traffic
  const sentMessage = messages.find(
    (m) => m.direction === 'sent' && m.payload.includes('Hello!')
  );
  expect(sentMessage).toBeDefined();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('chat message is sent over WebSocket', async ({ page }) => {
  const messages = [];

  page.on('websocket', (ws) => {
    ws.on('framesent', (frame) => {
      messages.push({ direction: 'sent', payload: String(frame.payload) });
    });
    ws.on('framereceived', (frame) => {
      messages.push({ direction: 'received', payload: String(frame.payload) });
    });
  });

  await page.goto('/chat');
  await page.getByRole('textbox', { name: 'Message' }).fill('Hello!');
  await page.getByRole('button', { name: 'Send' }).click();

  await expect(page.getByText('Hello!')).toBeVisible();

  const sentMessage = messages.find(
    (m) => m.direction === 'sent' && m.payload.includes('Hello!')
  );
  expect(sentMessage).toBeDefined();
});
```

### Attendre un message WebSocket précis

**À utiliser quand** : ton test dépend d'un message précis poussé par le serveur avant de continuer.
**À éviter quand** : l'UI reflète déjà le message. Vérifie plutôt l'UI.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('wait for server acknowledgment over WebSocket', async ({ page }) => {
  // Create a promise that resolves when we get the specific message
  const ackPromise = new Promise<void>((resolve) => {
    page.on('websocket', (ws) => {
      ws.on('framereceived', (frame) => {
        const data = JSON.parse(String(frame.payload));
        if (data.type === 'message_ack') {
          resolve();
        }
      });
    });
  });

  await page.goto('/chat');
  await page.getByRole('textbox', { name: 'Message' }).fill('Important update');
  await page.getByRole('button', { name: 'Send' }).click();

  // Wait for server to acknowledge
  await ackPromise;

  // Now verify the message shows a "delivered" checkmark
  await expect(page.getByTestId('message-status').last()).toHaveText('Delivered');
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('wait for server acknowledgment over WebSocket', async ({ page }) => {
  const ackPromise = new Promise((resolve) => {
    page.on('websocket', (ws) => {
      ws.on('framereceived', (frame) => {
        const data = JSON.parse(String(frame.payload));
        if (data.type === 'message_ack') {
          resolve();
        }
      });
    });
  });

  await page.goto('/chat');
  await page.getByRole('textbox', { name: 'Message' }).fill('Important update');
  await page.getByRole('button', { name: 'Send' }).click();

  await ackPromise;
  await expect(page.getByTestId('message-status').last()).toHaveText('Delivered');
});
```

### Mocker des messages WebSocket avec `routeWebSocket`

**À utiliser quand** : tu veux contrôler ce que le serveur envoie pour tester des états d'UI précis -- messages d'erreur, cas limites, données à fort volume -- sans vrai backend.
**À éviter quand** : tu dois tester le comportement réel du serveur. Utilise un vrai backend.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('display notification when server pushes an alert', async ({ page }) => {
  const wsRoute = await page.routeWebSocket('**/ws/notifications', (ws) => {
    // Let the app send its initial handshake
    ws.onMessage((message) => {
      const data = JSON.parse(message);
      if (data.type === 'subscribe') {
        ws.send(JSON.stringify({ type: 'subscribed', channel: data.channel }));
      }
    });

    // Push a notification after a short delay
    setTimeout(() => {
      ws.send(JSON.stringify({
        type: 'notification',
        title: 'Server Alert',
        body: 'Deployment completed successfully',
        severity: 'info',
      }));
    }, 500);
  });

  await page.goto('/dashboard');

  // Verify the notification appears in the UI
  await expect(page.getByRole('alert')).toContainText('Deployment completed successfully');
});

test('handle WebSocket server error gracefully', async ({ page }) => {
  await page.routeWebSocket('**/ws', (ws) => {
    // Immediately close with an error code
    ws.close({ code: 1011, reason: 'Internal server error' });
  });

  await page.goto('/chat');

  // App should show a reconnection message, not crash
  await expect(page.getByText('Connection lost. Reconnecting...')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('display notification when server pushes an alert', async ({ page }) => {
  await page.routeWebSocket('**/ws/notifications', (ws) => {
    ws.onMessage((message) => {
      const data = JSON.parse(message);
      if (data.type === 'subscribe') {
        ws.send(JSON.stringify({ type: 'subscribed', channel: data.channel }));
      }
    });

    setTimeout(() => {
      ws.send(JSON.stringify({
        type: 'notification',
        title: 'Server Alert',
        body: 'Deployment completed successfully',
        severity: 'info',
      }));
    }, 500);
  });

  await page.goto('/dashboard');
  await expect(page.getByRole('alert')).toContainText('Deployment completed successfully');
});

test('handle WebSocket server error gracefully', async ({ page }) => {
  await page.routeWebSocket('**/ws', (ws) => {
    ws.close({ code: 1011, reason: 'Internal server error' });
  });

  await page.goto('/chat');
  await expect(page.getByText('Connection lost. Reconnecting...')).toBeVisible();
});
```

#### Inspecter les sous-protocoles demandés (`webSocketRoute.protocols()`, Playwright 1.60+)

**À utiliser quand** : ton client négocie un sous-protocole WebSocket (par ex. `graphql-transport-ws`, `wamp`, une chaîne de protocole versionnée) et tu veux vérifier qu'il a envoyé le bon, ou faire varier ton mock en fonction.
**À éviter quand** : ton app n'utilise pas de sous-protocoles — il n'y a rien à inspecter.

Playwright 1.60 ajoute `webSocketRoute.protocols()`, qui renvoie le tableau des sous-protocoles demandés par le client pendant le handshake.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('client requests the graphql-ws subprotocol', async ({ page }) => {
  await page.routeWebSocket('**/graphql', (ws) => {
    // Assert the client negotiated the expected subprotocol
    expect(ws.protocols()).toContain('graphql-transport-ws');

    ws.onMessage((message) => {
      const data = JSON.parse(message);
      if (data.type === 'connection_init') {
        ws.send(JSON.stringify({ type: 'connection_ack' }));
      }
    });
  });

  await page.goto('/explorer');
  await expect(page.getByText('Connected')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('client requests the graphql-ws subprotocol', async ({ page }) => {
  await page.routeWebSocket('**/graphql', (ws) => {
    expect(ws.protocols()).toContain('graphql-transport-ws');
    ws.onMessage((message) => {
      const data = JSON.parse(message);
      if (data.type === 'connection_init') {
        ws.send(JSON.stringify({ type: 'connection_ack' }));
      }
    });
  });

  await page.goto('/explorer');
  await expect(page.getByText('Connected')).toBeVisible();
});
```

### Forwarding avec modification (man-in-the-middle)

**À utiliser quand** : tu veux te connecter au vrai serveur mais intercepter, modifier ou injecter des messages.
**À éviter quand** : un mock complet (`routeWebSocket` sans `connectToServer`) suffit.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('inject a fake high-priority message into real stream', async ({ page }) => {
  await page.routeWebSocket('**/ws/feed', (ws) => {
    const server = ws.connectToServer();

    // Forward all messages from server to client, but inject extras
    server.onMessage((message) => {
      ws.send(message); // Forward the real message
    });

    // Forward all client messages to server
    ws.onMessage((message) => {
      server.send(message);
    });

    // Inject a synthetic message after 1 second
    setTimeout(() => {
      ws.send(JSON.stringify({
        type: 'alert',
        priority: 'high',
        text: 'Injected test alert',
      }));
    }, 1000);
  });

  await page.goto('/live-feed');
  await expect(page.getByText('Injected test alert')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('inject a fake high-priority message into real stream', async ({ page }) => {
  await page.routeWebSocket('**/ws/feed', (ws) => {
    const server = ws.connectToServer();

    server.onMessage((message) => {
      ws.send(message);
    });

    ws.onMessage((message) => {
      server.send(message);
    });

    setTimeout(() => {
      ws.send(JSON.stringify({
        type: 'alert',
        priority: 'high',
        text: 'Injected test alert',
      }));
    }, 1000);
  });

  await page.goto('/live-feed');
  await expect(page.getByText('Injected test alert')).toBeVisible();
});
```

### Tester les Server-Sent Events (SSE)

**À utiliser quand** : ton app utilise `EventSource` pour du streaming serveur-vers-client (logs live, mises à jour de progression, flux d'actualités).
**À éviter quand** : l'app utilise des WebSockets. Le SSE repose sur HTTP et s'intercepte différemment.

Les réponses SSE sont du HTTP standard -- intercepte-les avec `page.route()` et renvoie une réponse en streaming.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('SSE live log stream displays entries', async ({ page }) => {
  // Intercept the SSE endpoint and return controlled events
  await page.route('**/api/logs/stream', async (route) => {
    const events = [
      'data: {"level":"info","message":"Server started"}\n\n',
      'data: {"level":"warn","message":"High memory usage"}\n\n',
      'data: {"level":"error","message":"Connection timeout"}\n\n',
    ];

    await route.fulfill({
      status: 200,
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
      body: events.join(''),
    });
  });

  await page.goto('/admin/logs');

  await expect(page.getByText('Server started')).toBeVisible();
  await expect(page.getByText('High memory usage')).toBeVisible();
  await expect(page.getByText('Connection timeout')).toBeVisible();
});

test('SSE reconnection on connection drop', async ({ page }) => {
  let requestCount = 0;

  await page.route('**/api/events', async (route) => {
    requestCount++;
    if (requestCount === 1) {
      // First request: send one event then close abruptly
      await route.fulfill({
        status: 200,
        headers: { 'Content-Type': 'text/event-stream' },
        body: 'data: {"msg":"first"}\n\n',
      });
    } else {
      // Reconnection: send the next event
      await route.fulfill({
        status: 200,
        headers: { 'Content-Type': 'text/event-stream' },
        body: 'data: {"msg":"reconnected"}\n\n',
      });
    }
  });

  await page.goto('/live');
  await expect(page.getByText('first')).toBeVisible();
  // EventSource auto-reconnects; verify the app handles it
  await expect(page.getByText('reconnected')).toBeVisible({ timeout: 10000 });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('SSE live log stream displays entries', async ({ page }) => {
  await page.route('**/api/logs/stream', async (route) => {
    const events = [
      'data: {"level":"info","message":"Server started"}\n\n',
      'data: {"level":"warn","message":"High memory usage"}\n\n',
      'data: {"level":"error","message":"Connection timeout"}\n\n',
    ];

    await route.fulfill({
      status: 200,
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
      body: events.join(''),
    });
  });

  await page.goto('/admin/logs');

  await expect(page.getByText('Server started')).toBeVisible();
  await expect(page.getByText('High memory usage')).toBeVisible();
  await expect(page.getByText('Connection timeout')).toBeVisible();
});
```

### Tester le temps réel basé sur du polling

**À utiliser quand** : ton app utilise du polling HTTP (setInterval + fetch) au lieu de WebSockets ou de SSE.
**À éviter quand** : l'app utilise des WebSockets ou du SSE -- utilise les patterns ci-dessus.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('polling updates dashboard data every interval', async ({ page }) => {
  let callCount = 0;

  await page.route('**/api/dashboard/stats', async (route) => {
    callCount++;
    const data = callCount === 1
      ? { activeUsers: 100, revenue: 5000 }
      : { activeUsers: 142, revenue: 5250 };

    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(data),
    });
  });

  await page.goto('/dashboard');

  // First poll result
  await expect(page.getByTestId('active-users')).toHaveText('100');

  // Wait for the second poll to update the UI
  await expect(page.getByTestId('active-users')).toHaveText('142', { timeout: 15000 });

  // Verify at least 2 requests were made
  expect(callCount).toBeGreaterThanOrEqual(2);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('polling updates dashboard data every interval', async ({ page }) => {
  let callCount = 0;

  await page.route('**/api/dashboard/stats', async (route) => {
    callCount++;
    const data = callCount === 1
      ? { activeUsers: 100, revenue: 5000 }
      : { activeUsers: 142, revenue: 5250 };

    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(data),
    });
  });

  await page.goto('/dashboard');
  await expect(page.getByTestId('active-users')).toHaveText('100');
  await expect(page.getByTestId('active-users')).toHaveText('142', { timeout: 15000 });
  expect(callCount).toBeGreaterThanOrEqual(2);
});
```

### Cycle de vie d'une connexion WebSocket

**À utiliser quand** : tu dois vérifier que ton app gère correctement la connexion, la déconnexion et la reconnexion.
**À éviter quand** : le cycle de vie de la connexion n'est pas visible par l'utilisateur.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('app reconnects after WebSocket drops', async ({ page }) => {
  let connectionCount = 0;

  await page.routeWebSocket('**/ws', (ws) => {
    connectionCount++;

    if (connectionCount === 1) {
      // First connection: close after a brief moment
      setTimeout(() => ws.close({ code: 1006, reason: 'Abnormal closure' }), 500);
    } else {
      // Second connection (reconnect): stay open and respond
      ws.onMessage((message) => {
        ws.send(JSON.stringify({ type: 'pong' }));
      });
    }
  });

  await page.goto('/app');

  // App detects disconnect and shows status
  await expect(page.getByText('Reconnecting...')).toBeVisible();

  // App reconnects and status returns to normal
  await expect(page.getByText('Connected')).toBeVisible({ timeout: 10000 });

  expect(connectionCount).toBe(2);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('app reconnects after WebSocket drops', async ({ page }) => {
  let connectionCount = 0;

  await page.routeWebSocket('**/ws', (ws) => {
    connectionCount++;

    if (connectionCount === 1) {
      setTimeout(() => ws.close({ code: 1006, reason: 'Abnormal closure' }), 500);
    } else {
      ws.onMessage((message) => {
        ws.send(JSON.stringify({ type: 'pong' }));
      });
    }
  });

  await page.goto('/app');
  await expect(page.getByText('Reconnecting...')).toBeVisible();
  await expect(page.getByText('Connected')).toBeVisible({ timeout: 10000 });
  expect(connectionCount).toBe(2);
});
```

## Guide de décision

| Scénario | Approche | Pourquoi |
|---|---|---|
| Vérifier que l'app envoie le bon message WS | `page.on('websocket')` + `ws.on('framesent')` | Observer sans intercepter |
| Vérifier que l'app gère un push serveur | `page.routeWebSocket()` avec un faux serveur | Contrôle total sur ce que le « serveur » envoie |
| Tester avec un vrai serveur mais injecter des messages | `routeWebSocket` + `connectToServer()` | Man-in-the-middle : transférer le vrai trafic et injecter des extras |
| Tester un endpoint SSE | `page.route()` avec le content type `text/event-stream` | Le SSE est du HTTP -- l'interception de routes standard fonctionne |
| Tester du polling HTTP | `page.route()` avec des réponses variables à chaque appel | Incrémenter un compteur ; renvoyer des données différentes à chaque appel |
| Vérifier la logique de reconnexion | `routeWebSocket` qui ferme la première connexion | Simuler une panne serveur, vérifier que l'app réessaie |
| Tester des données WebSocket binaires | `ws.on('framereceived')`, lire `frame.payload` comme un Buffer | Les frames binaires arrivent en `Buffer` dans Node.js |

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| `page.waitForTimeout(3000)` pour attendre un message WS | Délai arbitraire ; flaky et lent | `await expect(page.getByText('msg')).toBeVisible()` ou attendre une Promise |
| Construire directement un `WebSocket` dans `page.evaluate` | Tu perds les capacités d'observation et de routage de Playwright | Laisser l'app créer son propre WebSocket ; intercepter via `routeWebSocket` |
| Ignorer les codes de fermeture WebSocket dans les mocks | L'app peut se comporter différemment pour 1000 (normal) et 1006 (anormal) | Utiliser le bon code de fermeture : `ws.close({ code: 1000 })` |
| Tester des fonctionnalités temps réel contre des serveurs tiers en production | Flaky, lent et potentiellement coûteux | Mocker l'endpoint WebSocket ou SSE |
| Vérifier le contenu brut des frames WebSocket dans chaque test | Couple les tests au protocole filaire ; casse dès que le format du payload change | Vérifier l'UI -- c'est ce que voient les utilisateurs |
| Oublier de distinguer frames binaires et frames texte | `frame.payload` peut être un `string` ou un `Buffer` | Vérifier le type de la frame ou utiliser `String(frame.payload)` de façon cohérente |

## Dépannage

| Symptôme | Cause | Correctif |
|---|---|---|
| `page.on('websocket')` ne se déclenche jamais | Le WebSocket se connecte avant que le listener soit attaché | Enregistre le listener avant `page.goto()` |
| `routeWebSocket` n'intercepte pas | Le pattern d'URL ne correspond pas à l'URL réelle du WebSocket | Vérifie l'URL dans l'onglet Network des DevTools ; mets à jour le pattern glob |
| Le mock SSE renvoie tous les événements d'un coup | `route.fulfill` envoie le body de façon synchrone | Pour du vrai streaming, utilise le vrai serveur ou découpe la réponse en morceaux avec des pauses via `page.evaluate` |
| Les messages WebSocket arrivent mais l'UI ne se met pas à jour | L'app traite les messages de façon asynchrone ; l'assertion s'exécute trop tôt | Utilise `await expect(...).toBeVisible()` qui réessaie automatiquement |
| Les frames binaires s'affichent comme du texte illisible | `String(frame.payload)` sur des données binaires produit du charabia | Traite `frame.payload` comme un `Buffer` et décode-le correctement |
| Le test de reconnexion est flaky | L'app a un backoff exponentiel ; timeout trop court | Augmente le timeout de l'assertion : `toBeVisible({ timeout: 15000 })` |

## Voir aussi

- [core/multi-user-and-collaboration.md](multi-user-and-collaboration.md) -- tests multi-utilisateurs qui s'appuient sur les WebSockets pour la synchro temps réel
- [core/assertions-and-waiting.md](assertions-and-waiting.md) -- assertions à réessai automatique pour les mises à jour d'UI asynchrones
- [core/when-to-mock.md](when-to-mock.md) -- décider quand mocker un WebSocket ou utiliser un vrai serveur
- [core/debugging.md](debugging.md) -- tracer les frames WebSocket dans les traces Playwright
