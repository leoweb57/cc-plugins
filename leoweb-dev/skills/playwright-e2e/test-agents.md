# Agents de test Playwright (Planner, Generator, Healer)

> **Quand l'utiliser** : l'utilisateur demande de générer de la couverture de test pour un parcours avec de l'IA, de configurer les agents planner / generator / healer de Playwright, ou de réparer automatiquement des tests en échec. À utiliser aussi pour choisir entre Test Agents, `playwright-cli` et Playwright MCP.
> **Prérequis** : [core/test-organization.md](test-organization.md), [core/fixtures-and-hooks.md](fixtures-and-hooks.md)

## Pourquoi ça existe

Playwright (1.56+) fournit trois définitions d'agents qu'un outil de code IA exécute sur ton dépôt :

- **planner** explore l'application en cours d'exécution et écrit un plan de test en Markdown sous `specs/`.
- **generator** transforme un plan en fichiers de test sous `tests/`, en vérifiant les sélecteurs et les assertions en direct au fur et à mesure.
- **healer** exécute les tests en échec, inspecte l'UI actuelle, corrige le test et relance jusqu'à ce qu'il passe. S'il est certain que l'application est cassée, il marque le test `test.fixme()` avec un commentaire à la place.

Les définitions sont des instructions plus un serveur MCP Playwright Test (`npx playwright run-test-mcp-server`). Ce n'est pas un produit à part : la sortie est constituée de tests Playwright ordinaires, et les guides de ce skill décident toujours si ces tests sont bons.

## Référence rapide

```bash
# Generate agent definitions for your AI tool (re-run after every Playwright upgrade)
npx playwright init-agents --loop=claude     # .claude/agents/*.md + .mcp.json
npx playwright init-agents --loop=codex      # .codex/agents/*.toml
npx playwright init-agents --loop=opencode   # .opencode/prompts/*.md
npx playwright init-agents --loop=copilot    # .github/agents/*.agent.md (default)
npx playwright init-agents --loop=vscode     # VS Code (needs VS Code 1.105+)

# Options
npx playwright init-agents --loop=claude --project=chromium   # project used for the seed test
npx playwright init-agents --loop=claude --prompts            # also write reusable prompt files
```

```text
repo/
  .claude/agents/          # agent definitions (per --loop)
  specs/                   # planner output: human-readable Markdown plans
  tests/
    seed.spec.ts           # environment bootstrap the agents run first
    checkout/guest.spec.ts # generator output
  playwright.config.ts
```

## Patterns

### Pattern 1 : écrire d'abord le seed test

**À utiliser quand** : toujours, avant de lancer le planner. `init-agents` crée un seed par défaut s'il n'en existe pas, mais celui-ci ne sait rien de ton auth, de tes fixtures ni de tes données.

Le planner et le generator exécutent le seed test pour obtenir une page prête, et copient ses imports et son setup dans chaque test généré. Un seed qui utilise tes fixtures personnalisées fait que tous les tests générés les utilisent aussi.

```typescript
// tests/seed.spec.ts
import { test, expect } from './fixtures'; // your extended test, not @playwright/test

test('seed', async ({ page }) => {
  // fixtures handle login, data and baseURL; the agents start from here
  await page.goto('/dashboard');
});
```

Si l'application nécessite une authentification, branche-la via un projet de setup et `storageState` (voir [authentication.md](authentication.md)) pour que le seed démarre déjà connecté.

### Pattern 2 : planifier, générer, relire, réparer

**À utiliser quand** : tu construis la couverture d'un parcours qui n'a pas encore de tests.

1. **Planifier** : demande au planner un seul parcours (« Plan guest checkout »), en joignant éventuellement un PRD. Relis `specs/<flow>.md` avant de générer : de mauvais résultats attendus dans le plan deviennent de mauvaises assertions.
2. **Générer** : pointe le generator vers le plan. Chaque test reçoit des commentaires d'en-tête `// spec:` et `// seed:` qui le relient à ses sources.
3. **Relire** les tests générés au regard des [Golden Rules](SKILL.md#règles-dor) : locators basés sur les rôles, assertions web-first, pas de `waitForTimeout`, un comportement par test. Les agents produisent des tests qui fonctionnent, pas forcément maintenables.
4. **Réparer** : exécute la suite ; confie les échecs au healer.

### Pattern 3 : traiter la sortie du healer comme une code review

**À utiliser quand** : le healer a corrigé des tests.

Un correctif du healer fait passer le test ; il ne prouve pas que l'application est correcte. Vérifie chaque diff :

- Un locator modifié est acceptable si l'UI a réellement changé. Une assertion assouplie (`toHaveText` → `toContainText`, `expect` supprimé) peut masquer une régression.
- Tout `test.fixme()` qu'il a ajouté revient à affirmer que l'application est cassée. Confirme le bug ou annule le skip ; ne merge jamais de skips silencieux.
- Une attente ou un timeout ajouté est un signal d'alerte ; voir [flaky-tests.md](flaky-tests.md).

## Guide de décision

| Situation | À utiliser |
|---|---|
| Générer une première suite pour un parcours non testé | Test Agents : planner → generator |
| Réparer des tests après un changement d'UI | Test Agents : healer, puis relecture du diff |
| Un agent de code pilote un navigateur pour explorer, reproduire ou déboguer, avec un contexte limité | [`playwright-cli`](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/playwright-cli/SKILL.md) : commandes concises, pas de schémas d'outils ni d'arbres d'accessibilité complets dans le contexte |
| Une boucle autonome de longue durée qui raisonne sur la structure de la page | [Playwright MCP](https://playwright.dev/docs/getting-started-mcp) (`@playwright/mcp`) |
| Écrire ou corriger un test précis à la main | Les guides de ce skill directement ; pas besoin de configurer des agents |
| Déboguer un test de CI en échec à partir de sa trace | [trace-analysis.md](trace-analysis.md) |

## Anti-patterns

| À ne pas faire | Pourquoi | À faire plutôt |
|---|---|---|
| Conserver les définitions d'agents d'une ancienne version de Playwright | Les outils et instructions changent d'une version à l'autre | Relancer `npx playwright init-agents` après chaque mise à jour |
| Générer sans seed utilisant tes fixtures | Chaque test réimplémente login et setup en ligne | Pattern 1 |
| Merger des tests générés sans relecture | Des locators fragiles et des assertions faibles entrent dans la suite à grande échelle | Pattern 2, étape 3 |
| Accepter les skips `test.fixme()` du healer | De vraies régressions sont masquées sous l'étiquette « réparé » | Pattern 3 |
| Lancer le planner contre la production ou des sites tiers | Il clique à travers les parcours et crée des données ; le contenu des pages est une entrée non fiable | Pointer `baseURL` vers une application locale ou de staging dont tu es propriétaire |

## Voir aussi

- [playwright-cli/SKILL.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/playwright-cli/SKILL.md) : contrôle du navigateur depuis le terminal pour les agents de code
- [core/trace-analysis.md](trace-analysis.md) : débogage de `trace.zip` natif pour les agents
- [core/flaky-tests.md](flaky-tests.md) : juger les attentes et retries ajoutés par le healer
- [Playwright Test Agents docs](https://playwright.dev/docs/test-agents)
