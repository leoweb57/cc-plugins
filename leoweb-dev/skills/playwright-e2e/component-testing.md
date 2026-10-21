# Component Testing

> **Quand l'utiliser** : tester des composants UI de façon isolée (rendu, interactions, états) sans l'application complète. Idéal pour les design systems, les bibliothèques de composants partagées et les widgets interactifs complexes.
> **Prérequis** : [core/configuration.md](configuration.md), [core/fixtures-and-hooks.md](fixtures-and-hooks.md)

## Référence rapide

```tsx
// src/components/Button.story.tsx: one named export per scenario
import { Button } from './Button';

export const Primary = () => <Button title="Submit" />;
export const Disabled = () => <Button title="Submit" disabled />;
```

```typescript
// tests/components/button.spec.ts: plain Playwright test, built-in `mount` fixture (1.62+)
import { test, expect } from '@playwright/test';

test('renders primary button', async ({ mount }) => {
  const component = await mount('components/Button/Primary');
  await expect(component.getByRole('button')).toHaveText('Submit');
});
```

```bash
npx playwright init-skills                       # installs Playwright's own component-testing skill
npx playwright test --project=components
```

## Comment fonctionne le component testing (1.62+)

Un test de composant est un test Playwright ordinaire exécuté contre une petite page **gallery** servie par ton propre serveur de dev. Il n'y a ni package de component testing, ni intégration de bundler, ni config séparée.

- Une **story** est un petit composant wrapper qui place le composant testé dans un scénario précis : props codées en dur, données mockées, providers, callbacks enregistrés. Les stories vivent à côté du composant dans des fichiers `*.story.tsx` (ou `.ts`, `.jsx`, `.js`, `.vue`) ; chaque export nommé est une story.
- La **gallery** est une page unique (`playwright/gallery/index.html`) qui expose `window.mount({ story, props })` et `window.unmount()`, et rend la story dans `#root`. C'est du code applicatif propre à ton framework, que tu maintiens toi-même.
- La **fixture `mount(storyId, props?)`** navigue vers `baseURL` (la gallery), appelle `window.mount`, et renvoie un `Locator` sur `#root` avec `update(props)` et `unmount()`.

Tout ce dont le composant a besoin est mis en place **dans la story** (elle s'exécute dans le navigateur). Tout ce que le test vérifie est observable **via la page** : DOM, URL, réseau.

**Packages historiques** : `@playwright/experimental-ct-react`, `-react17` et `-vue` permettaient d'écrire du JSX directement dans les tests (`mount(<Button />)`). Ils ne sont pas publiés pour Playwright 1.63+ (`-svelte` a été retiré en 1.59) : les suites qui les utilisent doivent rester figées sur la 1.62 jusqu'à leur migration. Les appels `mount()` en JSX ne passent pas le type-check face à `mount(storyId, props?)` de la 1.64. Voir [Migrer depuis les packages expérimentaux](#migrer-depuis-les-packages-expérimentaux).

## Patterns

### 1. Setup : gallery et config

**À utiliser quand** : tu ajoutes des tests de composants à un projet.
**À éviter quand** : tu n'as besoin que de tests E2E sur l'application qui tourne.

Le setup le plus rapide passe par le skill propre à Playwright, qui détecte le framework et le bundler, écrit la gallery, ajoute le projet ainsi qu'une première story et un premier spec :

```bash
npx playwright init-skills
# then ask your coding agent: "Set up component testing using the playwright-component-testing skill."
```

Pour le faire à la main sur une app Vite, ajoute un projet dont le `baseURL` est la gallery :

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  projects: [
    {
      name: 'components',
      testDir: './tests/components',
      use: {
        ...devices['Desktop Chrome'],
        baseURL: 'http://localhost:5173/playwright/gallery/index.html',
        serviceWorkers: 'block', // the app's service worker must not shadow page.route() mocks
        reuseContext: true,      // reuse the browser context per worker: much faster suites
      },
    },
  ],
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173/playwright/gallery/index.html',
    reuseExistingServer: !process.env.CI,
  },
});
```

La gallery pour React + Vite (Vite sert n'importe quel `.html` sous la racine du projet et `vite build` l'ignore) :

```html
<!-- playwright/gallery/index.html -->
<!DOCTYPE html>
<div id="root"></div>
<script type="module" src="./main.tsx"></script>
```

```tsx
// playwright/gallery/main.tsx
import { flushSync } from 'react-dom';
import { createRoot, type Root } from 'react-dom/client';
import '../../src/index.css'; // global CSS, the same way the app entry imports it

const stories = import.meta.glob('../../src/**/*.story.{tsx,jsx}');
const id = (f: string) => f.replace(/^(\.\.\/)+src\//, '').replace(/\.story\.\w+$/, '');

const find = (path: string) => Object.keys(stories).find(f => id(f) === path || id(f).endsWith('/' + path));

async function resolve(storyId: string) {
  const sep = storyId.lastIndexOf('/');
  const file = find(storyId.slice(0, sep));  // 'components/Button/Primary': file + named export
  if (file)
    return ((await stories[file]()) as Record<string, any>)[storyId.slice(sep + 1)];
  const single = find(storyId);              // 'components/Card.with-actions': one-story .vue file
  return single && ((await stories[single]()) as Record<string, any>).default;
}

const rootEl = document.getElementById('root')!;
let root: Root | undefined;
let renderError: unknown;

(window as any).mount = async ({ story, props }: { story: string, props?: Record<string, any> }) => {
  const Story = await resolve(story);
  if (!Story)
    throw new Error(`Unknown story: ${story}`);
  // React 19 reports render errors instead of throwing; capture them so mount() rejects.
  root ??= createRoot(rootEl, { onUncaughtError: error => { renderError = error; } });
  renderError = undefined;
  flushSync(() => root!.render(<Story {...props} />)); // reuse the root so update() keeps state
  if (renderError)
    throw renderError;
};

(window as any).unmount = async () => {
  root?.unmount();
  root = undefined;
};
```

Pour Vue, monte une seule fois un host réactif et échange ses refs de story et de props, pour que `update()` re-rende sur place :

```typescript
// playwright/gallery/main.ts (resolve() and the glob as above, with '../../src/**/*.story.{ts,js,vue}')
import { createApp, h, shallowRef, type App, type Component } from 'vue';

const story = shallowRef<Component | null>(null);
const props = shallowRef<Record<string, any>>({});
const host = { render: () => (story.value ? h(story.value, props.value) : null) };
let app: App | undefined;

(window as any).mount = async ({ story: id, props: next }: { story: string, props?: Record<string, any> }) => {
  const resolved = await resolve(id);
  if (!resolved)
    throw new Error(`Unknown story: ${id}`);
  story.value = resolved;
  props.value = next ?? {};
  if (!app) {
    app = createApp(host);
    app.mount('#root');
  }
};

(window as any).unmount = async () => {
  app?.unmount();
  app = undefined;
};
```

Tu n'es pas sur Vite (Next.js, webpack) ? Lance un petit serveur Vite autonome pour la gallery et pointe `baseURL` et `webServer` dessus.

### 2. Stories et story IDs

**À utiliser quand** : tu écris n'importe quel test de composant.

- **Story id** = chemin sous `src/` sans `.story.*`, plus le nom de l'export : `src/components/Button.story.tsx` export `Primary` → `components/Button/Primary`. Tout suffixe unique fonctionne : `mount('Button/Primary')`. Un fichier `.story.vue` est une seule story, adressée par son chemin : `components/Card.with-actions`.
- **Un export par scénario.** `Primary`, `Disabled`, `Loading` se lisent comme une spécification du composant. Préfère un nouvel export à la paramétrisation d'un export existant.
- **Les story ids sont des chaînes.** Renommer une story casse les specs à l'exécution, pas à la compilation ; `mount<typeof Story>` (Pattern 4) relie au moins les props à la story.
- Ouvre l'URL de la gallery dans un navigateur et exécute `await window.mount({ story: 'components/Button/Primary' })` dans les DevTools pour voir exactement ce que voit le test.

### 3. Interactions et assertions

**À utiliser quand** : tu vérifies ce qu'un composant affiche et comment il réagit à l'utilisateur.

`mount()` renvoie un locator sur `#root`. Cadre chaque requête à partir de lui et utilise des assertions web-first :

```typescript
import { test, expect } from '@playwright/test';

test('dialog closes on Escape and returns focus', async ({ mount, page }) => {
  const component = await mount('components/Dialog/OpenWithTrigger');

  await expect(component.getByRole('dialog', { name: 'Delete project' })).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(component.getByRole('dialog')).toBeHidden();
  await expect(component.getByRole('button', { name: 'Open dialog' })).toBeFocused();
});
```

Utilise `page` pour tout ce qui est hors de la racine : clavier, souris, viewport et `page.route()`.

### 4. Props : valeurs par test, types et `update()`

**À utiliser quand** : un scénario est réellement paramétrique (balayage de valeurs limites), ou tu testes un changement de prop sur un composant vivant.

Passe des props simples et sérialisables en second argument ; la gallery les transmet à la story. Passe le type de la story à `mount` pour les typer :

```tsx
// src/components/Counter.story.tsx
import { Counter } from './Counter';

export const Default = ({ value = 0 }: { value?: number }) => <Counter value={value} />;
```

```typescript
import { test, expect } from '@playwright/test';
import type { Default } from '../../src/components/Counter.story';

test('re-renders on prop change without remounting', async ({ mount }) => {
  const component = await mount<typeof Default>('components/Counter/Default', { value: 1 });
  await expect(component.getByTestId('value')).toHaveText('1');

  await component.update({ value: 2 }); // same story, new props, state kept
  await expect(component.getByTestId('value')).toHaveText('2');
});
```

Les stories Vue qui reçoivent des props doivent aussi les déclarer à l'exécution, sinon Vue les livre comme attributs :

```typescript
// src/components/Button.story.ts
import { defineComponent, h } from 'vue';
import Button from './Button.vue';

export const WithTitle = defineComponent(
  (props: { title?: string }) => () => h(Button, { title: props.title ?? 'Default' }),
  { props: ['title'] },
);
```

Garde les callbacks hors des props. Le contrat documenté ne couvre que des props simples et sérialisables ; la 1.64 expose par hasard les fonctions passées ainsi, mais l'appel s'exécute alors dans Node.js, hors de la story, et le scénario n'est plus visible dans la gallery. Le Pattern 5 gère les callbacks.

### 5. Événements et callbacks : enregistrer l'état dans la story

**À utiliser quand** : le composant signale quelque chose via un callback ou un événement (`onChange`, `@update:expanded`).

La story possède l'état et les callbacks, et enregistre le résultat dans un input caché. Le test agit puis vérifie cet input avec `toHaveValue()`, qui réessaie jusqu'à ce que l'état arrive :

```tsx
// src/components/Expandable.story.tsx
import { useState } from 'react';
import { Expandable } from './Expandable';

export const Stateful = () => {
  const [expanded, setExpanded] = useState(false);
  return <>
    <Expandable expanded={expanded} setExpanded={setExpanded} title="Details">Hidden text</Expandable>
    <form hidden><input data-testid="expanded" readOnly value={String(expanded)} /></form>
  </>;
};
```

```typescript
test('click toggles expanded', async ({ mount }) => {
  const component = await mount('components/Expandable/Stateful');
  await component.getByRole('button', { name: 'Details' }).click();
  await expect(component.getByTestId('expanded')).toHaveValue('true');
});
```

La même story en Vue :

```typescript
// src/components/Expandable.story.ts
import { defineComponent, h, ref } from 'vue';
import Expandable from './Expandable.vue';

export const Stateful = defineComponent(() => {
  const expanded = ref(false);
  return () => h('div', [
    h(Expandable, {
      'expanded': expanded.value,
      'onUpdate:expanded': (value: boolean) => expanded.value = value,
      'title': 'Details',
    }),
    h('form', { hidden: true }, [
      h('input', { 'data-testid': 'expanded', 'readonly': true, 'value': String(expanded.value) }),
    ]),
  ]);
});
```

- Un input `data-testid` par valeur observée : `String(...)` pour les scalaires, `JSON.stringify(...)` pour les payloads.
- Les vérifications négatives fonctionnent pareil : agis, puis vérifie que la valeur n'a **pas** changé.
- L'enregistrement est visible quand tu ouvres la story dans la gallery, donc la story sert aussi de page de test manuel.

### 6. Children et slots : une story par composition

**À utiliser quand** : le composant rend des children (React) ou des slots (Vue).

Il n'y a pas de JSX par test. Chaque composition à tester devient son propre export :

```tsx
// src/components/Card.story.tsx
import { Card } from './Card';

export const WithActions = () => (
  <Card title="Invoice #42">
    <p>Due in 3 days</p>
    <button>Pay now</button>
  </Card>
);

export const Empty = () => <Card title="Invoice #42" />;
```

```typescript
test('renders children inside the card body', async ({ mount }) => {
  const component = await mount('components/Card/WithActions');
  await expect(component.getByRole('heading', { name: 'Invoice #42' })).toBeVisible();
  await expect(component.getByRole('button', { name: 'Pay now' })).toBeVisible();
});
```

Pour les scénarios Vue riches en slots, une story en fichier unique est plus lisible que des render functions :

```vue
<!-- src/components/Card.with-actions.story.vue: addressed as 'components/Card.with-actions' -->
<script setup lang="ts">
import Card from './Card.vue';
</script>

<template>
  <Card title="Invoice #42">
    <template #default><p>Due in 3 days</p></template>
    <template #actions><button>Pay now</button></template>
  </Card>
</template>
```

### 7. Providers, contexte et plugins

**À utiliser quand** : les composants ont besoin d'un thème, d'un store, d'un router, d'i18n ou d'un query client.

Enveloppe les stories dans un décorateur partagé, placé à côté des stories et non dans la gallery, pour que chaque story montre ses dépendances et puisse s'en passer :

```tsx
// src/stories/decorators.tsx
import type { ReactNode } from 'react';
import { ThemeProvider } from '../theme';

export function AppScaffold({ children, theme = 'light' }: { children: ReactNode, theme?: 'light' | 'dark' }) {
  return <ThemeProvider theme={theme}>{children}</ThemeProvider>;
}
```

```tsx
// src/components/ThemedBadge.story.tsx
import { AppScaffold } from '../stories/decorators';
import { ThemedBadge } from './ThemedBadge';

export const Dark = () => <AppScaffold theme="dark"><ThemedBadge label="New" /></AppScaffold>;
```

- Crée les clients (React Query, Apollo, Pinia) **dans** la story ou le décorateur, pour que chaque `mount()` démarre à neuf.
- Les plugins Vue à installer avec `app.use(...)` vont dans la gallery juste après `createApp(...)`, en miroir du bootstrap de l'app.
- Le corps de `window.mount` remplace les anciens hooks `beforeMount` / `afterMount` pour le setup global à l'app.

### 8. Réseau et dépendances

**À utiliser quand** : le composant récupère des données ou dépend d'un module que tu veux remplacer.

Enregistre `page.route()` **avant** `mount()`, car le mount navigue :

```typescript
test('shows an error when items fail to load', async ({ mount, page }) => {
  await page.route('**/api/items', route => route.fulfill({ status: 500 }));
  const component = await mount('components/ItemList/Default');
  await expect(component.getByRole('alert')).toContainText('Something went wrong');
});

test('renders items from the API', async ({ mount, page }) => {
  await page.route('**/api/items', route => route.fulfill({ json: [{ id: 1, name: 'Blue Mug' }] }));
  const component = await mount('components/ItemList/Default');
  await expect(component.getByRole('listitem')).toHaveText(['Blue Mug']);
});
```

Il n'existe pas de mock de module côté test : le composant s'exécute dans le navigateur, construit par ton serveur de dev. Pour remplacer une dépendance, passe-la par la story (une prop ou un provider avec une implémentation factice), utilise les alias de ton bundler pour la gallery, ou démarre un worker MSW dans une story ou un décorateur.

### 9. Comparaison visuelle

**À utiliser quand** : tu veux verrouiller l'apparence des composants et des états d'un design system.

Fais la capture du locator racine renvoyé, pas de la page, et monte plusieurs stories par test à moindre coût :

```typescript
test('button states', async ({ mount }) => {
  await expect(await mount('components/Button/Primary')).toHaveScreenshot('primary.png');
  await expect(await mount('components/Button/Disabled')).toHaveScreenshot('disabled.png');
});
```

Garde le formulaire d'enregistrement en `hidden` pour qu'il reste hors des baselines. Les règles de baseline (OS, polices, Docker) sont dans [visual-regression.md](visual-regression.md).

### 10. Test de composant vs test E2E

**À utiliser quand** : tu décides où tester un comportement d'UI.

Les tests de composants vérifient **comment un composant se comporte isolément** ; les tests E2E vérifient **comment le système fonctionne ensemble**. L'état désactivé et le spinner d'un bouton de chargement relèvent d'un test de composant ; « enregistrer le formulaire persiste l'enregistrement et affiche un toast » relève de l'E2E. Voir [test-architecture.md](test-architecture.md).

## Guide de décision

| Élément d'UI | Test de composant | Test E2E | Test unitaire |
|---|---|---|---|
| **Button** (variantes, états, chargement) | Oui : chaque variante, désactivé, chargement, enregistrement du clic | Seulement dans un flux plus large | Non : il faut un vrai DOM pour le style et l'accessibilité |
| **Champ de formulaire** (validation, masquage) | Oui : messages, masquage, états d'erreur | Oui : soumission complète avec le backend | Logique de validation seule (regex, formatters) |
| **Modal / dialog** | Oui : ouverture/fermeture, focus trap, Escape | Oui : le flux qui l'ouvre | Non |
| **Table de données** (tri, filtre, pagination) | Oui : avec des données mockées via route | Oui : données réelles de l'API et synchro d'URL | Fonctions pures de tri/filtre |
| **Navigation / menu** | Partiellement : comportement du dropdown, états actifs | Oui : vrais changements de route | Non |
| **Page complète** (dashboard, settings) | Non : trop de contexte ; ça annule l'isolation | Oui | Non |
| **Graphique** | Oui : régression visuelle du rendu | Seulement dans les flux critiques | Transformation de données uniquement |
| **Primitives de design system** | Oui : le cas d'usage principal | Non | Non |

**Règle générale** : tests de composants pour le comportement et l'apparence isolés, E2E pour les parcours utilisateur à travers composants et pages, tests unitaires pour la logique pure sans DOM.

## Migrer depuis les packages expérimentaux

| `@playwright/experimental-ct-*` | Story gallery (1.62+) |
|---|---|
| `mount(<Button onClick={spy} />)` | Une story avec état enregistre l'effet dans un input caché ; le test vérifie `toHaveValue()` (Pattern 5) |
| Props de données simples depuis le test | `mount(id, props)` (Pattern 4) |
| Children / slots JSX dans le test | Un export de story par composition (Pattern 6) |
| `component.update(<Button count={2} />)` | `component.update({ count: 2 })` |
| Hooks `beforeMount` / `afterMount` | Corps du `window.mount` de la gallery, ou décorateurs de stories |
| `hooksConfig` | Props interprétées par la story |
| Fixture `router` / MSW dans Node.js | `page.route()` dans le test, ou MSW dans une story |
| `playwright/index.html` + `index.ts` | L'`index.html` de la gallery et son module d'entrée |
| `ctViteConfig`, `ctPort`, `ctTemplateDir`, `playwright-ct.config.ts` | Disparus : ton serveur de dev, `webServer` et `baseURL` |
| `import { test } from '@playwright/experimental-ct-react'` | `import { test } from '@playwright/test'` |

Migre progressivement tout en restant figé sur la 1.62 : ajoute la gallery et le projet `components` à côté de l'ancien projet CT, porte les specs un par un, puis retire la dépendance expérimentale, `playwright/index.*` et `playwright/.cache`, et mets à jour. Guide complet : [section de migration upstream](https://playwright.dev/docs/test-components#migration-from-the-experimental-packages).

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| `mount(<Component />)` avec du JSX en 1.63+ | Les packages expérimentaux n'existent plus ; ça ne type-check pas et ne s'exécute pas | Une story plus `mount('path/Story')` |
| Passer des callbacks ou des instances de classe en props | Hors du contrat documenté de props sérialisables ; le comportement vit dans Node.js au lieu de la story | Pattern 5 : la story possède les callbacks et enregistre l'état |
| `component.click()` sur le locator renvoyé | C'est le conteneur `#root`, pas ton composant | `component.getByRole('button').click()` |
| `page.route()` après `mount()` | Le mount navigue ; les premières requêtes sont déjà parties | Router d'abord, monter ensuite |
| Intégrer les providers dans la gallery | Cache les dépendances ; les stories ne peuvent pas s'en passer | Décorateurs dans les fichiers de stories (Pattern 7) |
| Monter une page entière | Trop de contexte ; lent ; annule l'isolation | E2E pour les pages ; tests de composants pour les widgets |
| Vérifier l'état interne ou les méthodes d'instance | Couple les tests à l'implémentation | Vérifier le DOM, ou enregistrer les effets dans la story |
| Capturer la page | Capture tout le reste de la gallery | Capturer le locator racine renvoyé |

## Dépannage

| Symptôme | Cause | Correctif |
|---|---|---|
| `mount()` lève `Unknown story: ...` | L'id ne correspond pas au chemin du fichier + export, ou le glob ne couvre pas le fichier | Vérifie la grammaire des ids (Pattern 2) et le `import.meta.glob` de la gallery |
| `The gallery page does not define window.mount().` | `baseURL` pointe sur une page qui n'est pas la gallery, ou le script de la gallery n'a pas chargé | Mets `baseURL` et `webServer.url` sur `.../playwright/gallery/index.html` ; regarde les erreurs console de la gallery |
| ``mount() requires `baseURL` to point at the component gallery.`` | Pas de `baseURL` dans le `use` du projet | Ajoute `baseURL` pour le projet components (Pattern 1) |
| `mount()` réussit mais `#root` est vide, puis un locator expire | Une erreur de rendu avalée par la gallery (React 19 la signale au lieu de la lever) | Capture-la avec `onUncaughtError` et relance-la, comme la gallery du Pattern 1 |
| Le composant s'affiche sans style | CSS global non importé dans l'entrée de la gallery | Importe-le dans `playwright/gallery/main.*` comme le fait l'entrée de l'app |
| `update()` réinitialise l'état du composant | La gallery recrée la racine ou l'app à chaque appel | Réutilise la racine (React) ou monte un host réactif une seule fois (Vue) |
| La story Vue ignore les props passées par le test | Props non déclarées à l'exécution | Ajoute `{ props: [...] }` à `defineComponent` (Pattern 4) |
| Le mock `page.route()` est ignoré | Le service worker de l'app sert une réponse en cache, ou la route a été ajoutée après `mount()` | `serviceWorkers: 'block'` ; router avant de monter |
| `Cannot find module '@playwright/experimental-ct-react'` en 1.63+ | Package non publié pour la 1.63+ | Migre vers les stories, ou fige la suite sur Playwright 1.62 |
| useContext / inject renvoie undefined | La story n'enveloppe pas le composant dans son provider | Utilise le décorateur partagé (Pattern 7) |

## Voir aussi

- [core/visual-regression.md](visual-regression.md) : baselines de captures pour les états de composants
- [core/network-mocking.md](network-mocking.md) : patterns `page.route()`
- [core/test-architecture.md](test-architecture.md) : composant vs E2E vs API
- [core/react.md](react.md), [core/vue.md](vue.md) : recettes par framework
- [Documentation Playwright sur le component testing](https://playwright.dev/docs/test-components)
