# Instructions plugin leoweb-dev

## Catalogue des ressources disponibles

**Skills** : `check-deps` (APIs à jour d'une lib nouvelle ou montée de version majeure), `web-research` (recherche web proportionnée, multi-sources si besoin), `verify-implementation` (vérification avant d'annoncer la fin), `karpathy-guidelines` (règles de code), `tailwind-design-system`, `nextjs-app-router-patterns`, `brainstorm` (7 agents d'analyse multi-perspectives), `business-experts` (panel de 9 experts business), `docker-compose-patterns`, `docker-build-strategies`, `postgres-best-practices`, `playwright-e2e` (écriture de tests E2E), et les skills officiels LangChain/LangGraph/Deep Agents et Langfuse.

**Agents techniques** : `react-developer`, `mobile-developer`, `backend-developer`, `devops-engineer`, `data-engineer`, `deep-research`, `refactoring-expert` (Serena, analyse d'impact), `root-cause-analyst` (bugs complexes), `quality-engineer` (stratégie de tests).

**Agents d'analyse** : `brainstorm/*` (architecture, performance, security, user-experience, quality-testing, maintainability, business-value) et `business-experts/*` (porter, drucker, christensen, godin, kim-mauborgne, collins, taleb, meadows, doumont), invocables seuls ou en équipe via leur skill.

---

## Périmètre et communication

- Fais **uniquement** ce qui est demandé.
- Si tu vois une amélioration, une option ou une suggestion utile, propose-la en une ligne et **attends l'accord de l'utilisateur** avant de l'implémenter.
- Réponses concises : le résultat d'abord, sans récapituler ce que l'utilisateur sait déjà.

## Règles Karpathy — Éviter les erreurs de code typiques des LLM

Règles tirées des [observations d'Andrej Karpathy](https://x.com/karpathy/status/2015883857489522876) (source : [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)). Elles privilégient la prudence plutôt que la vitesse : pour les tâches triviales, fais preuve de jugement. Détail complet dans le skill `karpathy-guidelines`.

### 1. Réfléchir avant de coder

**Ne suppose pas. Ne cache pas ta confusion. Expose les compromis.**

- Énonce tes hypothèses explicitement. En cas de doute, demande.
- S'il existe plusieurs interprétations, présente-les : n'en choisis pas une en silence.
- S'il existe une approche plus simple, dis-le. Conteste quand c'est justifié.
- Si quelque chose n'est pas clair, arrête-toi. Nomme ce qui te bloque. Demande.

### 2. La simplicité d'abord

**Le minimum de code qui résout le problème. Rien de spéculatif.**

- Aucune fonctionnalité au-delà de ce qui est demandé.
- Aucune abstraction pour du code utilisé une seule fois.
- Aucune « flexibilité » ou « configurabilité » non demandée.
- Aucune gestion d'erreur pour des scénarios impossibles.
- Si tu écris 200 lignes et que ça pourrait en faire 50, réécris.

Demande-toi : « Un développeur senior trouverait-il ça trop compliqué ? » Si oui, simplifie.

### 3. Des changements chirurgicaux

**Ne touche qu'à ce qui est nécessaire. Ne nettoie que ton propre désordre.**

- N'« améliore » pas le code, les commentaires ou le formatage adjacents.
- Ne refactore pas ce qui n'est pas cassé.
- Respecte le style existant, même si tu ferais autrement.
- Si tu remarques du code mort sans rapport, signale-le : ne le supprime pas.
- Supprime les imports/variables/fonctions que TES changements ont rendus inutilisés, pas le code mort préexistant.

Le test : chaque ligne modifiée doit se rattacher directement à la demande de l'utilisateur.

### 4. Une exécution guidée par les objectifs

**Définis des critères de réussite. Boucle jusqu'à vérification.**

Transforme les tâches en objectifs vérifiables :

- « Ajouter une validation » → « Écrire des tests pour les entrées invalides, puis les faire passer »
- « Corriger le bug » → « Écrire un test qui le reproduit, puis le faire passer »
- « Refactorer X » → « S'assurer que les tests passent avant et après »

Chaque tâche du plan a sa vérification. Le **moment** où elle s'exécute suit la section « Organisation de l'implémentation » : après l'étape pour des tâches dépendantes, une seule fois pour tout un lot de tâches indépendantes, ou dans la CI.

## Bascule dynamique de modèle

Le modèle de la session (choisi par l'utilisateur) est l'**orchestrateur**. Tu as l'autorisation permanente de déléguer des sous-tâches à des sous-agents tournant sur un autre modèle quand c'est plus rapide ou plus pertinent, sans attendre qu'on te le demande.

- Outil Agent : paramètre `model` (`fable`, `opus`, `sonnet`, `haiku`). Workflow : option `model` de chaque `agent(...)`, fixée **par étape**.
- Utilise toujours les alias de famille, jamais un ID complet : l'alias pointe sur la dernière version.
- Les agents du plugin sont en `model: inherit` ; le paramètre `model` passé à l'appel prend le dessus.

| Modèle | Tâches adaptées |
| --- | --- |
| `fable` | Raisonnement le plus exigeant : architecture, décisions structurantes, bugs complexes multi-modules, revue adversariale, juge final, synthèse |
| `opus` | Implémentation complexe ou multi-fichiers, refactoring avec analyse d'impact, code review approfondie, vérification d'une implémentation |
| `sonnet` | Implémentation bien spécifiée, tâches de dev standard, écriture de tests à partir d'un plan clair, exploration de codebase, recherche web/doc |
| `haiku` | Tâches mécaniques : localiser des fichiers, grep, extraction ou résumé de contenu, renommages, formatage, vérifications simples |

Règle de base : **le modèle le moins coûteux capable de réussir la tâche du premier coup**. En cas de doute entre deux niveaux, prends le plus haut.

- Le thread principal garde le cadrage, le dialogue avec l'utilisateur, les décisions et l'intégration finale.
- Plus le modèle est petit, plus la consigne doit être autonome et précise : contexte, fichiers, contraintes, critère de vérification. Une tâche mal spécifiée ne descend pas sous `opus`.
- Descendre sous le modèle de session est libre. Monter au-dessus n'est justifié que si la tâche l'exige vraiment ; signale-le en une ligne.
- Si un sous-agent échoue ou rend un résultat douteux, relance au niveau supérieur plutôt que de réessayer au même niveau.
- Si l'utilisateur impose un modèle ou interdit la délégation, respecte-le.
- Quand tu lances plusieurs sous-agents, annonce la répartition en une ligne (ex. : « exploration sur Haiku, implémentation sur Sonnet, revue sur Opus »).

## Organisation de l'implémentation : lots, parallélisme et tests groupés

Dès qu'une demande comporte plusieurs tâches, la planification optimise le temps total : ce qui peut être **parallélisé**, ce qui peut être **regroupé**, et dans quel **ordre** enchaîner le tout.

### Deux modes, choisis tâche par tâche

- **Séquentiel** : quand une étape conditionne la suivante (migration BDD puis endpoint qui l'utilise), teste après chaque étape avant de continuer.
- **Par lots** : les tâches indépendantes sont regroupées en un lot. Exemple : modifier le titre, le footer et l'envoi d'email d'une page = un lot, et non trois cycles « modifier → tester ».

### Déroulé d'un lot

1. Un sous-agent par tâche, tous lancés en parallèle (dans un seul message), chacun sur le modèle adapté.
2. Plusieurs agents peuvent travailler sur le même fichier si leurs zones sont distinctes, avec des éditions ciblées (Edit, Serena), jamais une réécriture complète du fichier (Write). Si les zones se chevauchent, regroupe ces tâches dans un même agent.
3. Pendant le dev, seulement des vérifications légères et rapides : typecheck, lint, tests unitaires des fichiers touchés.
4. Une fois **tout** le lot développé, **un seul passage de tests** couvre toutes les tâches du lot.
5. Puis le lot suivant.

### Règles de test

- L'outillage coûteux (navigateur Playwright, serveur, Docker, base de test) est monté **une seule fois par lot** et sert à tester toutes les tâches du lot, jamais pour une seule tâche si d'autres peuvent en profiter.
- Exécute les tests en parallèle quand l'outil le permet (workers Playwright, `vitest`/`pytest -n`, etc.).
- En cas d'échec : corrige, puis relance **uniquement les tests en échec**. La suite complète ne tourne qu'une fois, en fin de feature.

### Format dans le plan

Le plan affiche explicitement la séquence :

```
Lot 1 (parallèle) : titre | footer | envoi d'email → test groupé : 1 session Playwright + test API email
Lot 2 (séquentiel) : migration BDD → test → endpoint → test
```

### Agents indépendants en worktree

Les sous-agents servent aux tâches d'un lot : même session, tests groupés. Quand le travail contient des **features entières et indépendantes**, assez longues pour mériter chacune leur branche, leur CI et leur stack Docker, **propose** à l'utilisateur de les confier à des agents indépendants, chacun dans son worktree, et attends son accord :

- `claude --worktree <nom>` : session interactive dans un nouveau worktree.
- `claude --bg "<consigne>"` : session en arrière-plan, isolée dans son worktree, suivie avec `claude agents`.

Donne pour chaque agent une consigne autonome : périmètre, branche, critères d'acceptation, tests attendus.

Dans un worktree, le plugin (hook `SessionStart`) copie les fichiers `.env*` ignorés du dépôt principal et exporte `COMPOSE_PROJECT_NAME` (unique par worktree), `WORKTREE_NAME` et `WORKTREE_HOST_PREFIX`. Pour que plusieurs stacks tournent en parallèle, le `compose.yaml` ne doit pas fixer de `container_name`, ni de port hôte en dur (utiliser une variable), et les règles Traefik doivent dépendre de ces variables (ex. ``Host(`${WORKTREE_HOST_PREFIX:-}app.localhost`)``, routeur nommé avec `${COMPOSE_PROJECT_NAME}`). Si la stack du projet ne le permet pas, signale-le et propose l'adaptation sans l'appliquer d'office.

## Tests délégués à la CI

Si le projet a une CI qui joue déjà les tests (lint, unitaires, fonctionnels, e2e), ne rejoue pas en local le passage de tests groupé du lot : délègue-le à la CI. Les vérifications légères pendant le dev (typecheck, lint, tests unitaires des fichiers touchés) restent locales.

1. **Détection** (en planification) : repère la CI (`.github/workflows/`, `.gitlab-ci.yml`), les jobs qu'elle exécute, et vérifie ton accès (MCP GitHub/GitLab, `gh` ou `glab`). Si elle ne couvre pas les tests ou si tu n'y as pas accès, reste sur les tests groupés en local et ne commite pas : l'utilisateur gère Git.
2. **Découpage par commit** : le plan prévoit un commit par lot. Une fois le lot développé, commite et pousse sur la branche de la feature (voir les garde-fous ci-dessous).
3. **Pendant que la CI tourne, continue le lot suivant.** Surveille le pipeline en arrière-plan : quelques secondes après le push, récupère l'ID du run (`gh run list --branch <branche> --limit 1 --json databaseId -q '.[0].databaseId'`), puis `gh run watch <id> --exit-status` en commande d'arrière-plan. Côté GitLab : MCP GitLab (`list_pipelines`, `get_pipeline`) ou `glab ci status`.
4. **Si la CI échoue** : corrige dans un nouveau commit qui ne contient que les fichiers du correctif, et repousse. Ne rejoue en local que ce qu'il faut pour diagnostiquer.
5. **Tests non couverts par la CI** (non écrits, vérifications manuelles ou visuelles) : joue-les en local, groupés par lot.
6. **Nouveaux tests** : pour chaque test que tu écris, demande à l'utilisateur s'il doit être **ajouté à la CI** (test durable) ou s'il est **ponctuel** pour ce dev. Ne surcharge jamais la CI sans son accord.

**Garde-fous Git** :

- **Premier push** : avant le tout premier push d'une feature, demande confirmation une fois (`git push -u origin <branche>`). Si l'utilisateur accepte, les pushs suivants sur cette branche sont autorisés sans redemander. S'il refuse, reste sur les tests locaux.
- **Branche** : si la branche courante est `main` ou la branche par défaut du projet, ne commite pas et ne pousse pas : reste sur les tests locaux. Jamais de force-push.
- **Contenu du commit** : stage uniquement les fichiers du lot (`git add <fichiers>`), jamais `git add -A` ni `git add .`. Seul le thread principal commite, jamais les sous-agents. Ne contourne jamais les hooks (`--no-verify`).
- **Déploiement** : vérifie les déclencheurs des jobs de déploiement (`on: push` sans filtre de branche côté GitHub, `rules`/`only` côté GitLab). Si un push sur la branche peut déployer, ou en cas de doute, demande ; sinon tests en local.
- Les commits de travail sont libres : ils pourront être regroupés en squash au merge de la PR/MR.

## Recherche web proportionnée

Active le skill `web-research` pour les recherches d'information sur le web. Par défaut, mode léger : une question simple se règle avec une source bien choisie. Le mode multi-sources en parallèle est réservé aux sujets complexes ou contradictoires, à la veille, à l'investigation, ou quand l'utilisateur demande une recherche approfondie. Pour les versions/APIs d'une lib, utilise `check-deps`.

## Vérification technologique

Active le skill `check-deps` avant d'utiliser une librairie, un framework ou un SDK **nouveau dans le projet**, lors d'une montée de version majeure, ou quand tu n'es pas sûr d'une API. Pas besoin pour les packages déjà utilisés dans le projet avec des patterns établis : suis les patterns existants.

## Dates et timestamps via MCP Time

N'invente jamais une date ou une heure à écrire dans un fichier (noms de migration, logs, specs, identifiants horodatés) : obtiens-la via le MCP Time (`get_current_time`). Pour le reste, la date du contexte système suffit.

## Serena — Navigation et édition sémantique du code

Le MCP Serena comprend la **structure** du code via LSP (classes, fonctions, références). Utilise-le pour travailler sur des symboles ; garde Glob/Grep/Read pour les recherches textuelles simples et les fichiers non-code.

- Comprendre un fichier sans le lire en entier : `get_symbols_overview`, puis `find_symbol` avec `include_body=True` sur ce qui t'intéresse.
- Mesurer l'impact avant de modifier : `find_referencing_symbols`.
- Éditer de façon sûre : `replace_symbol_body`, `insert_after_symbol` / `insert_before_symbol`, `rename_symbol` (renomme toutes les références).

## Playwright — Screenshots et tests visuels

Quand tu utilises `browser_take_screenshot` :

- Ne passe **JAMAIS** un `filename` sans préfixer le chemin par `.playwright-mcp/`. Exemples :
- Correct : `filename: ".playwright-mcp/ma-capture.png"`
- Incorrect : `filename: "ma-capture.png"` (atterrit à la racine du projet)
- Si tu n'as pas besoin d'un nom spécifique, **ne passe pas de `filename`** du tout — le screenshot sera automatiquement sauvé dans
  `.playwright-mcp/` avec un nom horodaté.
- Le viewport est configuré en 1920x1080. Ne pas appeler `browser_resize` sauf demande explicite de l'utilisateur.
