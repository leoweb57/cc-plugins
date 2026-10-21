# Tests WebMCP

> **Quand l'utiliser** : ton application web enregistre des outils pour des agents IA via l'API navigateur expérimentale [WebMCP](https://webmachinelearning.github.io/webmcp/), et tu dois vérifier que ces outils sont listés, décrits et se comportent correctement, comme pour n'importe quelle autre partie de l'application.
> **Prérequis** : [core/api-testing.md](api-testing.md), [core/fixtures-and-hooks.md](fixtures-and-hooks.md)

## Pourquoi ça existe

WebMCP permet à une page d'exposer des fonctions JavaScript comme outils d'agents (`search_catalog`, `add_to_cart`, `book_slot`) directement depuis le navigateur, avec un nom, une description et un schéma d'entrée. Ces outils constituent une interface publique. Un agent choisit un outil d'après sa description et l'appelle avec des arguments qu'il déduit du schéma : un outil renommé, une description vague ou un schéma qui dérive de l'implémentation cassent donc les agents en silence, sans changement d'UI, sans erreur console, sans rien qu'un test E2E basé sur des clics puisse détecter.

**Avant la 1.64**, le seul moyen d'atteindre ces outils était `page.evaluate()` contre l'API en page, en réimplémentant à la main la découverte et l'invocation des outils dans chaque test.

**Playwright 1.64** ajoute `page.webmcp` et `frame.webmcp`, un accès de première classe aux outils qu'une page enregistre. Liste-les, inspecte leurs métadonnées et appelle-les avec des arguments, Playwright se chargeant de la plomberie.

## Référence rapide

```typescript
// WebMCP is experimental: enable it at launch (Chromium flag shown; Firefox uses prefs, see Pattern 1)
const browser = await chromium.launch({ args: ['--enable-features=WebMCP'] });
const page = await browser.newPage();
await page.goto('/');

// Discover tools the page registered
const tools = await page.webmcp.tools();          // [{ name, description, ... }]

// Call one, exactly as an agent would
const result = await page.webmcp.callTool('add', { a: 2, b: 40 });
result.content[0].text;                           // "42"

// Tools registered inside an iframe
const frame = page.frame({ name: 'checkout' });
await frame!.webmcp.tools();
```

```bash
# playwright-cli exposes the same surface
playwright-cli webmcp-list
playwright-cli webmcp-call search_catalog --params '{"query":"cats"}'
```

## Patterns

### Pattern 1 : activer WebMCP une seule fois, dans la config

**À utiliser quand** : plus d'une spec touche aux outils WebMCP.
**À éviter quand** : tu n'as qu'un seul test exploratoire ; lancer avec `args` en ligne convient très bien dans ce cas.

WebMCP est derrière un flag du navigateur. Mets le flag sur un projet dédié pour que le reste de la suite tourne sur des navigateurs standard et que les specs WebMCP soient clairement délimitées.

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    {
      name: 'webmcp',
      testMatch: /.*\.webmcp\.spec\.ts/,
      use: {
        ...devices['Desktop Chrome'],
        launchOptions: { args: ['--enable-features=WebMCP'] },
      },
    },
    {
      name: 'webmcp-firefox',
      testMatch: /.*\.webmcp\.spec\.ts/,
      use: {
        ...devices['Desktop Firefox'],
        launchOptions: {
          firefoxUserPrefs: {
            'dom.modelcontext.enabled': true,
            'dom.modelcontext.testing.enabled': true,
          },
        },
      },
    },
  ],
});
```

Chromium active WebMCP avec `--enable-features=WebMCP` et Firefox avec les prefs `dom.modelcontext.enabled` et `dom.modelcontext.testing.enabled`. WebKit ne l'implémente pas : n'ajoute donc pas de variante WebKit de ce projet.

### Pattern 2 : verrouiller le contrat des outils

**À utiliser quand** : des agents (les tiens ou ceux de tiers) dépendent des outils que ta page expose.
**À éviter quand** : les outils sont encore en prototypage et renommés tous les jours ; ajoute le test de contrat une fois les noms stabilisés.

Traite la liste des outils comme une API publique : asserte explicitement les noms et les descriptions pour que tout changement apparaisse en revue.

```typescript
import { test, expect } from '@playwright/test';

test('catalog page exposes the expected agent tools', async ({ page }) => {
  await page.goto('/catalog');

  const tools = await page.webmcp.tools();
  const byName = Object.fromEntries(tools.map(t => [t.name, t]));

  expect(Object.keys(byName).sort()).toEqual(['add_to_cart', 'search_catalog']);

  // Agents choose tools by description; an empty or vague one is a bug
  for (const tool of tools)
    expect(tool.description?.length, `${tool.name} needs a description`).toBeGreaterThan(20);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('catalog page exposes the expected agent tools', async ({ page }) => {
  await page.goto('/catalog');
  const names = (await page.webmcp.tools()).map(t => t.name).sort();
  expect(names).toEqual(['add_to_cart', 'search_catalog']);
});
```

### Pattern 3 : appeler un outil, puis asserter sur l'UI

**À utiliser quand** : un outil modifie l'état de l'application (ajout au panier, réservation d'un créneau) et que l'utilisateur doit en voir le résultat.
**À éviter quand** : l'outil est en lecture seule ; asserter sur sa valeur de retour suffit.

Le test WebMCP le plus solide exerce l'outil exactement comme le ferait un agent, puis vérifie que la page le reflète, ce qui prouve que l'outil est branché sur un vrai état applicatif et non sur un stub.

```typescript
test('add_to_cart tool updates the visible cart', async ({ page }) => {
  await page.goto('/catalog');

  const result = await page.webmcp.callTool('add_to_cart', { sku: 'CAT-001', quantity: 2 });
  expect(result.content[0].text).toContain('Added');

  // Web-first assertion on the UI the user sees
  await expect(page.getByRole('status', { name: 'Cart' })).toHaveText('2 items');
});
```

### Pattern 4 : entrées négatives

**À utiliser quand** : toujours, pour tout outil qui accepte des arguments. Les agents envoient des entrées mal formées bien plus souvent que les humains.

```typescript
test('search_catalog rejects an empty query with a useful message', async ({ page }) => {
  await page.goto('/catalog');

  const result = await page.webmcp.callTool('search_catalog', { query: '' });
  expect(result.isError).toBe(true);
  expect(result.content[0].text).toMatch(/query.*required/i);
});
```

Un message d'erreur fait partie du contrat : un agent le lit pour décider comment réessayer. Asserte qu'il indique ce qui n'allait pas.

`callTool()` renvoie tel quel un résultat `isError: true`, mais **lève une exception** quand l'outil n'est pas enregistré ou que sa fonction `execute` lève une exception. Asserte sur le rejet pour les outils qui lèvent une exception sur une mauvaise entrée :

```typescript
await expect(page.webmcp.callTool('search_catalog', { query: 42 })).rejects.toThrow(/query/i);
```

### Pattern 5 : outils enregistrés par des pages authentifiées

**À utiliser quand** : les outils n'apparaissent qu'après le login (actions de compte, historique de commandes).

Combine avec un état d'authentification stocké pour que la liste des outils reflète un utilisateur connecté. Voir [authentication.md](authentication.md).

```typescript
test.use({ storageState: 'playwright/.auth/user.json' });

test('signed-in users get order tools', async ({ page }) => {
  await page.goto('/account');
  const names = (await page.webmcp.tools()).map(t => t.name);
  expect(names).toContain('list_orders');
});

test.describe('anonymous', () => {
  test.use({ storageState: { cookies: [], origins: [] } });

  test('anonymous users do not get order tools', async ({ page }) => {
    await page.goto('/account');
    const names = (await page.webmcp.tools()).map(t => t.name);
    expect(names).not.toContain('list_orders');
  });
});
```

Exposer des outils de compte à une session anonyme est un bug d'autorisation : le cas négatif compte donc autant que le cas positif.

### Pattern 6 : explorer depuis la CLI et depuis Playwright MCP

**À utiliser quand** : tu écris le premier test d'une page que tu n'as jamais vue, ou tu débogues un outil en échec.

```bash
playwright-cli open https://localhost:3000/catalog
playwright-cli webmcp-list
playwright-cli webmcp-call search_catalog --params '{"query":"cats"}'
```

[Playwright MCP](https://playwright.dev/docs/getting-started-mcp) propose automatiquement à l'agent les outils définis par la page sous la forme `webmcp_<tool>`. Passe `--no-webmcp` pour t'en désinscrire, par exemple quand tu veux qu'un agent pilote l'UI comme le ferait un humain plutôt que de prendre le raccourci.

Les noms d'outils, descriptions, schémas d'entrée et résultats viennent de la page : traite-les donc comme des entrées non fiables, surtout quand un agent explore une page que tu ne contrôles pas. Voir la Security Trust Boundary dans [SKILL.md](SKILL.md).

## Guide de décision

| Situation | Approche |
|---|---|
| Vérifier quels outils une page expose | `page.webmcp.tools()` plus une assertion sur une liste explicite de noms |
| Vérifier qu'un outil fonctionne de bout en bout | `page.webmcp.callTool()` puis une assertion UI web-first |
| Les outils vivent dans une iframe | `frame.webmcp` sur le bon `Frame` |
| Exploration manuelle rapide | `playwright-cli webmcp-list` / `webmcp-call` |
| L'agent doit utiliser l'UI, pas les outils | Playwright MCP avec `--no-webmcp` |
| Couverture Firefox | `firefoxUserPrefs` avec `dom.modelcontext.enabled` et `dom.modelcontext.testing.enabled` |
| Couverture WebKit | Indisponible : WebKit n'implémente pas WebMCP |

## Anti-patterns

| À ne pas faire | Pourquoi | À faire à la place |
|---|---|---|
| `page.evaluate()` dans l'API WebMCP | Réimplémente la découverte et l'invocation ; casse quand la spec évolue | `page.webmcp.tools()` / `callTool()` |
| Asserter uniquement sur le texte renvoyé par `callTool()` | Un outil peut renvoyer « ok » sans rien changer | Asserte aussi sur l'UI ou sur l'état du backend |
| Snapshotter le JSON complet des outils | Fragile à chaque ajustement de schéma ; les reviewers arrêtent de lire le diff | Asserte les noms, les descriptions et les champs du schéma dont les agents dépendent |
| Activer `--enable-features=WebMCP` pour toute la suite | Masque quels tests dépendent d'un flag expérimental | Un projet `webmcp` dédié |

## Dépannage

| Symptôme | Cause | Correctif |
|---|---|---|
| `tools()` lève une exception | Navigateur lancé sans prise en charge de WebMCP | Chromium : `--enable-features=WebMCP` ; Firefox : les prefs `dom.modelcontext.*` (Pattern 1) |
| `tools()` renvoie `[]` | La page enregistre les outils après le chargement, ou dans une frame enfant | Attends le signal de disponibilité de l'application avant de lister ; utilise `frame.webmcp` pour les iframes |
| `tools()` lève une exception uniquement en CI | Le projet CI ou le canal du navigateur se lance sans le flag | Utilise le navigateur fourni et passe le flag ou les prefs dans le projet CI |
| Outil trouvé dans la page, pas dans la frame | Outil enregistré dans une iframe | Utilise `frame.webmcp` sur cette frame |

## Voir aussi

- [core/api-testing.md](api-testing.md) : patterns de test de contrat qui s'appliquent aussi aux schémas d'outils
- [core/authentication.md](authentication.md) : état de stockage pour les jeux d'outils d'un utilisateur connecté
- [playwright-cli/core-commands.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/playwright-cli/core-commands.md) : `webmcp-list` et `webmcp-call`
- [Playwright 1.64 release notes](https://playwright.dev/docs/release-notes#version-164)
