# Sélection dynamique des tests

> **Quand l'utiliser** : tu dois décider *quels* tests s'exécutent, ou *comment* ils sont rejoués, depuis l'extérieur des fichiers de test — pilotés par des signaux de CI, une liste de quarantaine ou des données historiques de flakiness venant d'un service externe. Playwright 1.62+.
> **Prérequis** : [core/flaky-tests.md](flaky-tests.md), [ci/reporting-and-artifacts.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/reporting-and-artifacts.md)

Avant la 1.62, filtrer des tests depuis l'extérieur de la suite passait par `--grep` avec une regex générée, ou par l'édition des fichiers de spec pour y ajouter `test.skip()`. Les deux sont grossiers. `--grep` filtre sur les titres : un renommage fait sortir silencieusement un test du filtre, et les titres contenant des métacaractères de regex doivent être échappés. Éditer les fichiers de spec implique un bot qui écrit des commits.

Playwright 1.62 ajoute `reporter.preprocess()`, un hook qui s'exécute après la collecte et avant l'exécution, avec la possibilité de marquer des tests individuellement. La sélection vit dans un reporter, pas dans les specs.

## Référence rapide

```bash
# Append a reporter instead of replacing the configured one (1.63+)
npx playwright test --add-reporter json

# Still useful: title-based filtering for ad-hoc runs
npx playwright test --grep @smoke
npx playwright test --grep-invert @flaky
```

```ts
// playwright.config.ts
export default defineConfig({
  retries: 2,
  retryStrategy: 'isolated',              // 1.62+
  reporter: [['./reporters/quarantine.ts'], ['html']],
});
```

## Patterns

### Pattern 1 : le hook `preprocess()` (Playwright 1.62+)

`preprocess()` reçoit la suite collectée et un objet `testRun`. Marque les tests avant que quoi que ce soit ne s'exécute.

```js
// reporters/quarantine.ts
class QuarantineReporter {
  async preprocess({ config, suite, testRun }) {
    for (const test of suite.allTests()) {
      if (shouldSkip(test))
        testRun.skip(test);
    }
  }
}

export default QuarantineReporter;
```

`testRun` peut **skip**, **exclude**, **fixme** ou **fail** un test. La distinction compte :

| Marque | Le test s'exécute ? | Apparaît dans le rapport ? | À utiliser pour |
|---|---|---|---|
| `skip` | Non | Oui, comme ignoré | Tests en quarantaine que tu veux quand même comptabiliser |
| `exclude` | Non | Non | Tests sans rapport avec cette exécution (mauvais shard, mauvais tag) |
| `fixme` | Non | Oui, comme ignoré | Tests cassés connus que tu comptes corriger ; rien ne s'exécute |
| `fail` | Oui | Oui | Test cassé connu ; fait échouer l'exécution s'il passe de façon inattendue |

`fail` est celui que l'on oublie. Il exécute le test, s'attend à du rouge, et t'alerte quand il passe au vert — c'est ainsi qu'une liste de quarantaine se réduit d'elle-même au lieu de pourrir.

**Pourquoi c'est mieux que `--grep`** : le hook voit des objets `TestCase`, donc tu peux filtrer sur le chemin du fichier, le chemin de titre, les tags, les annotations ou le projet — pas seulement sur une regex de titre. Rien à échapper, et un test renommé échoue bruyamment à la recherche au lieu de sortir silencieusement d'un motif.

### Pattern 2 : piloter la sélection depuis une liste externe de tests flaky

La version utile d'une quarantaine n'est pas un tableau codé en dur. C'est une liste calculée à partir de l'historique des exécutions, rafraîchie à chaque run de CI.

Cet exemple utilise l'API TestDino, qui renvoie des cas de test avec une flakiness agrégée sur plusieurs exécutions. Tout service exposant une liste similaire fonctionne de la même manière.

```ts
// reporters/quarantine.ts
import type { Reporter, TestCase } from '@playwright/test/reporter';

const API = 'https://api.testdino.com/api/v1/public';

async function fetchFlakyTitles(): Promise<Set<string>> {
  const { TESTDINO_PROJECT_ID, TESTDINO_API_TOKEN } = process.env;
  if (!TESTDINO_PROJECT_ID || !TESTDINO_API_TOKEN) return new Set();

  const params = new URLSearchParams({
    status: 'flaky',
    days: '7',                 // 7, 30, or 90 only
    sortBy: 'flaky_rate',
    order: 'desc',
    limit: '50',               // 10, 25, or 50 only
  });

  try {
    const res = await fetch(`${API}/${TESTDINO_PROJECT_ID}/test-case-explorer?${params}`, {
      headers: { Authorization: `Bearer ${TESTDINO_API_TOKEN}` },
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) return new Set();
    const { success, data } = await res.json();
    if (!success) return new Set();
    return new Set(data.testCases.map((tc) => tc.title));
  } catch {
    return new Set();          // never let telemetry break the test run
  }
}

class QuarantineReporter implements Reporter {
  async preprocess({ suite, testRun }) {
    const flaky = await fetchFlakyTitles();
    if (flaky.size === 0) return;

    for (const test of suite.allTests()) {
      if (flaky.has(test.title))
        testRun.fail(test);   // runs, expected red, alerts if it goes green
    }
  }
}

export default QuarantineReporter;
```

**Le `catch` qui renvoie un ensemble vide est la ligne importante.** Un reporter de quarantaine qui lève une exception sur un simple raté réseau fait tomber toute la pipeline. Dégrade vers « ne rien mettre en quarantaine » et laisse l'exécution continuer.

**Ne te limite pas au titre.** Les titres entrent en collision d'un fichier à l'autre. Si l'API renvoie un chemin de spec, utilise `test.titlePath().join(' > ')` comme clé ou compare aussi `test.location.file` :

```ts
const key = (t: TestCase) => `${t.location.file}::${t.titlePath().join(' > ')}`;
```

### Pattern 3 : retries isolés (Playwright 1.62+)

Le retry par défaut s'exécute immédiatement, dans le même worker, avec tout l'état que ce worker a accumulé. C'est le pire environnement possible pour diagnostiquer un échec flaky, car le retry hérite des conditions qui ont pu le causer.

```ts
// playwright.config.ts
export default defineConfig({
  retries: 2,
  retryStrategy: 'isolated',
});
```

`'isolated'` diffère tous les retries à la fin de l'exécution et les exécute dans un seul worker. Deux conséquences à connaître :

- **Un test qui passe au retry isolé mais avait échoué dans l'exécution parallèle te dit quelque chose de précis** : l'échec est lié à la concurrence, pas inhérent au test. C'est un diagnostic que la stratégie par défaut masque.
- **Le temps total augmente** quand beaucoup de tests sont rejoués, car la phase de retry est mono-worker et en série. Sur une suite avec une poignée de retries, c'est du bruit. Sur une suite où 40 tests sont rejoués, c'est un vrai coût, et les retries ne sont pas le problème à résoudre.

### Pattern 4 : exclusion consciente des shards

`exclude` garde un test totalement hors du rapport, ce que tu veux quand un test n'est simplement pas du ressort de ce shard ou que ses dépendances ne sont pas disponibles dans cet environnement.

```ts
class EnvironmentReporter {
  async preprocess({ suite, testRun }) {
    const hasStripeKey = Boolean(process.env.STRIPE_TEST_KEY);
    for (const test of suite.allTests()) {
      if (!hasStripeKey && test.titlePath().some((t) => t.includes('payment')))
        testRun.exclude(test);
    }
  }
}
```

Préfère les tags et `--grep-invert` quand la condition est statique et connue au moment de la commande. Utilise `exclude` quand la condition n'est connaissable qu'à l'exécution, comme un identifiant manquant ou un feature flag récupéré depuis une API.

### Pattern 5 : combiner avec les tags

`preprocess()` ne remplace pas les tags. Utilise les tags pour l'intention déclarée par l'auteur, et `preprocess()` pour les faits découverts par l'exécution.

```ts
test('checkout completes', { tag: '@critical' }, async ({ page }) => { /* ... */ });
```

```ts
// Never quarantine a test the author marked critical, however flaky it looks
for (const test of suite.allTests()) {
  if (flaky.has(test.title) && !test.tags.includes('@critical'))
    testRun.fail(test);
}
```

Cette garde est importante. Une auto-quarantaine sans liste d'exemptions finira par réduire au silence ton test le plus important, car le test le plus important est souvent celui qui touche le plus d'infrastructure, donc celui qui est flaky.

## Guide de décision

| Situation | Approche |
|---|---|
| Sous-ensemble statique, connu avant l'exécution | `--grep` / `--grep-invert` avec des tags |
| Sous-ensemble dépendant de l'historique des exécutions ou d'un service externe | `reporter.preprocess()` |
| Un test est cassé et tu veux qu'il cesse de bloquer les merges | `testRun.fail()` — l'exécute, alerte quand il se rétablit |
| Un test ne peut pas du tout s'exécuter dans cet environnement | `testRun.exclude()` |
| Diagnostiquer si la flakiness est liée à la concurrence | `retryStrategy: 'isolated'` |
| Des tests se disputent une ressource partagée | `lock` — voir [ci/parallel-and-sharding.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/parallel-and-sharding.md) |

## Anti-patterns

**Auto-quarantaine sans issue de sortie.** Une liste qui ne fait que grossir est une liste que personne ne lit. Utilise `fail` plutôt que `skip` pour qu'un test rétabli se signale lui-même, et déclenche une alerte quand la liste ne diminue pas d'un mois sur l'autre.

**Laisser l'appel réseau du reporter faire échouer l'exécution.** Encadre le fetch, définis un timeout, et par défaut ne sélectionne rien.

**Construire une regex `--grep` à partir de titres fournis par une API sans les échapper.** Un titre contenant `(`, `?` ou `[` produit soit un motif invalide, soit une correspondance silencieusement fausse. Si tu dois utiliser `--grep`, échappe avec `s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')`. `preprocess()` évite complètement le problème.

**Utiliser `retryStrategy: 'isolated'` pour passer une suite rouge au vert.** Cela change le moment où les retries s'exécutent, pas la solidité du test. Si les retries isolés passent systématiquement, corrige le problème d'isolation — voir [core/flaky-tests.md](flaky-tests.md).

## Dépannage

### `preprocess()` ne s'exécute jamais

Le hook n'est appelé que sur les reporters listés dans la config `reporter`. Un reporter passé via `--reporter` en CLI **remplace** la liste configurée ; utilise `--add-reporter` (1.63+) pour en ajouter un à la place.

### Les marques sont appliquées mais les tests s'exécutent normalement

Vérifie que tu fais bien un `await` sur le travail asynchrone dans `preprocess()`. Le hook est `async` ; retourner avant que le fetch ne soit résolu laisse la boucle sans marquage.

### Les titres de l'API ne correspondent jamais

Le `test.title` de Playwright est uniquement le titre le plus interne. Un test dans `test.describe('Checkout')` a pour titre `'completes'`, pas `'Checkout > completes'`. Utilise `test.titlePath()` quand le système externe stocke le chemin complet.

## Voir aussi

- [core/flaky-tests.md](flaky-tests.md) — diagnostiquer et corriger la flakiness sous-jacente
- [ci/parallel-and-sharding.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/parallel-and-sharding.md) — workers, shards et `lock`
- [ci/reporting-and-artifacts.md](https://github.com/testdino-hq/playwright-skill/blob/178d1cb537604279d7b54500c4823a6db42b9de6/ci/reporting-and-artifacts.md) — configuration des reporters et `--add-reporter`
- [core/test-organization.md](test-organization.md) — tags et structure des suites
