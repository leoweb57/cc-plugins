# Instructions plugin leoweb-dev

## Catalogue des ressources disponibles

Ce plugin fournit des agents, skills et commandes spécialisés. Consulte cette liste pour identifier l'outil adapté à chaque situation.

### Skills (déclenchés automatiquement ou manuellement)

| Skill                        | Déclencheur automatique                                             | Description                                                                                                        |
| ---------------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `check-deps`                 | Avant d'implémenter du code utilisant une lib/framework externe     | Vérifie les versions et APIs actuelles via Context7, Exa, Tavily, DeepWiki, WebSearch, Firecrawl                   |
| `web-research`               | Recherche d'information sur le web (veille, investigation, analyse) | Orchestration multi-sources en parallèle avec synthèse croisée                                                     |
| `verify-implementation`      | Après implémentation d'une feature                                  | Vérifie que le code produit correspond au plan et aux exigences                                                    |
| `tailwind-design-system`     | Travail sur du styling Tailwind, design tokens, composants UI       | Patterns CVA, compound components, dark mode, design tokens                                                        |
| `nextjs-app-router-patterns` | Travail avec Next.js App Router                                     | Server Components, streaming, routes parallèles, Server Actions, cache                                             |
| `brainstorm`                 | Analyse multi-perspectives d'une solution technique                 | Équipe de 7 agents spécialisés (architecture, performance, sécurité, UX, qualité, maintenabilité, valeur business) |
| `business-experts`           | Analyse stratégique/business d'un produit ou d'une décision         | Panel de 9 experts business (Porter, Drucker, Christensen, Godin, Taleb, etc.)                                     |
| `karpathy-guidelines`        | Écriture, relecture ou refactoring de code                          | 4 règles Karpathy : réfléchir avant de coder, simplicité, changements chirurgicaux, objectifs vérifiables          |

### Agents (utilisables individuellement via l'outil Agent)

| Agent                            | Quand l'utiliser                                                                                                                         |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `react-developer`                | Composants React, Next.js, state management, styling, accessibilité, performance frontend                                                |
| `mobile-developer`               | React Native, Flutter, Expo, intégrations natives, offline-first, déploiement app stores                                                 |
| `backend-developer`              | APIs REST/GraphQL/gRPC, Node.js, TypeScript, Python, bases de données, authentification, architecture serveur, microservices, serverless |
| `devops-engineer`                | Docker, Kubernetes, CI/CD, Terraform, cloud, monitoring, sécurité infra, GitOps                                                          |
| `data-engineer`                  | Modélisation de données, PostgreSQL, MongoDB, Redis, Prisma, migrations, optimisation requêtes, CQRS                                     |
| `deep-research`                  | Recherche approfondie avec stratégies adaptatives et exploration multi-sources                                                           |
| `refactoring-expert`             | Refactoring de code avec Serena, analyse d'impact, restructuration safe                                                                  |
| `root-cause-analyst`             | Diagnostic de bugs complexes, analyse de traces d'exécution, identification de causes racines                                            |
| `quality-engineer`               | Stratégie de tests, analyse de testabilité, couverture, qualité du code                                                                  |
| `brainstorm/architecture`        | Évaluation de l'architecture technique, patterns, scalabilité                                                                            |
| `brainstorm/performance`         | Analyse de performance, bottlenecks, optimisation                                                                                        |
| `brainstorm/security`            | Audit de sécurité, vulnérabilités, OWASP                                                                                                 |
| `brainstorm/user-experience`     | UX, ergonomie, accessibilité, parcours utilisateur                                                                                       |
| `brainstorm/quality-testing`     | Stratégie de tests, couverture, edge cases                                                                                               |
| `brainstorm/maintainability`     | Maintenabilité, dette technique, lisibilité du code                                                                                      |
| `brainstorm/business-value`      | Valeur business, ROI, priorisation                                                                                                       |
| `business-experts/porter`        | Stratégie concurrentielle, 5 forces, chaîne de valeur                                                                                    |
| `business-experts/drucker`       | Management, efficacité, innovation organisationnelle                                                                                     |
| `business-experts/christensen`   | Innovation disruptive, jobs-to-be-done                                                                                                   |
| `business-experts/godin`         | Marketing, tribus, permission marketing, Purple Cow                                                                                      |
| `business-experts/kim-mauborgne` | Océan bleu, création de nouveaux marchés                                                                                                 |
| `business-experts/collins`       | Excellence durable, Good to Great, Hedgehog Concept                                                                                      |
| `business-experts/taleb`         | Antifragilité, risques, cygnes noirs, optionalité                                                                                        |
| `business-experts/meadows`       | Pensée systémique, boucles de rétroaction, leviers                                                                                       |
| `business-experts/doumont`       | Communication efficace, structuration de l'information                                                                                   |

Les agents `brainstorm/*` et `business-experts/*` peuvent être invoqués individuellement ou orchestrés en équipe via leurs skills respectifs (`brainstorm` et `business-experts`).

---

## Règles Karpathy — Éviter les erreurs de code typiques des LLM

Règles tirées des [observations d'Andrej Karpathy](https://x.com/karpathy/status/2015883857489522876) (source : [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills)). Elles privilégient la prudence plutôt que la vitesse : pour les tâches triviales, fais preuve de jugement. Détail complet dans le skill `karpathy-guidelines`.

### 1. Réfléchir avant de coder

**Ne suppose pas. Ne cache pas ta confusion. Expose les compromis.**

Avant d'implémenter :

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

Quand tu modifies du code existant :

- N'« améliore » pas le code, les commentaires ou le formatage adjacents.
- Ne refactore pas ce qui n'est pas cassé.
- Respecte le style existant, même si tu ferais autrement.
- Si tu remarques du code mort sans rapport, signale-le : ne le supprime pas.

Quand tes changements créent des orphelins :

- Supprime les imports/variables/fonctions que TES changements ont rendus inutilisés.
- Ne supprime pas le code mort préexistant sauf si on te le demande.

Le test : chaque ligne modifiée doit se rattacher directement à la demande de l'utilisateur.

### 4. Une exécution guidée par les objectifs

**Définis des critères de réussite. Boucle jusqu'à vérification.**

Transforme les tâches en objectifs vérifiables :

- « Ajouter une validation » → « Écrire des tests pour les entrées invalides, puis les faire passer »
- « Corriger le bug » → « Écrire un test qui le reproduit, puis le faire passer »
- « Refactorer X » → « S'assurer que les tests passent avant et après »

Pour les tâches en plusieurs étapes, énonce un plan bref :

```
1. [Étape] → vérification : [contrôle]
2. [Étape] → vérification : [contrôle]
3. [Étape] → vérification : [contrôle]
```

Des critères de réussite solides te permettent de boucler en autonomie. Des critères faibles (« fais que ça marche ») exigent des clarifications constantes.

## Bascule dynamique de modèle

Le modèle de la session (choisi par l'utilisateur) est l'**orchestrateur**. Tu as l'autorisation permanente de déléguer des sous-tâches à des sous-agents tournant sur un autre modèle quand c'est plus rapide ou plus pertinent, sans attendre qu'on te le demande.

### Comment choisir le modèle

- Outil Agent : paramètre `model` (`fable`, `opus`, `sonnet`, `haiku`).
- Workflow : option `model` de chaque `agent(...)`, à fixer **par étape**, éventuellement avec `effort`.
- Utilise toujours les alias de famille, jamais un ID complet : l'alias pointe sur la dernière version disponible.
- Les agents du plugin sont en `model: inherit` ; le paramètre `model` passé à l'appel prend le dessus.

| Modèle   | Tâches adaptées                                                                                                                              |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `fable`  | Raisonnement le plus exigeant : architecture, décisions structurantes, bugs complexes multi-modules, revue adversariale, juge final, synthèse |
| `opus`   | Implémentation complexe ou multi-fichiers, refactoring avec analyse d'impact, code review approfondie, vérification d'une implémentation     |
| `sonnet` | Implémentation bien spécifiée, tâches de dev standard, écriture de tests à partir d'un plan clair, exploration de codebase, recherche web/doc |
| `haiku`  | Tâches mécaniques : localiser des fichiers, grep, extraction ou résumé de contenu, renommages, formatage, vérifications simples              |

Règle de base : **le modèle le moins coûteux capable de réussir la tâche du premier coup**. En cas de doute entre deux niveaux, prends le plus haut.

### Découpage des tâches par complexité

1. Le thread principal garde le cadrage, le dialogue avec l'utilisateur, les décisions et l'intégration finale.
2. Décompose le travail en sous-tâches et attribue à chacune un niveau de complexité, donc un modèle.
3. Plus le modèle est petit, plus la consigne doit être autonome et précise : contexte, fichiers concernés, contraintes, et critère de vérification (cf. règle Karpathy n°4). Une tâche mal spécifiée ne descend pas sous `opus`.
4. Dans un workflow, enchaîne typiquement : exploration (`haiku`/`sonnet`) → implémentation (`sonnet`/`opus`) → vérification ou jugement (`opus`/`fable`).

### Garde-fous

- Descendre sous le modèle de session est libre. Monter au-dessus n'est justifié que si la tâche l'exige vraiment ; signale-le en une ligne.
- Si un sous-agent échoue ou rend un résultat douteux, relance au niveau supérieur plutôt que de réessayer au même niveau.
- Si l'utilisateur impose un modèle pour une tâche ou interdit la délégation, respecte-le.
- Quand tu lances plusieurs sous-agents, annonce la répartition en une ligne (ex. : « exploration sur Haiku, implémentation sur Sonnet, revue sur Opus »).

## Recherche web multi-sources obligatoire

Pour toute recherche d'information sur le web (veille, investigation, analyse, mise à jour), active le skill `web-research` qui orchestre Exa, Tavily, WebSearch, DeepWiki et Firecrawl en parallèle et croise les résultats. Ne jamais se fier à une seule source — croiser systématiquement. Exception : pour la vérification de versions/APIs d'une lib spécifique, utilise `check-deps` à la place.

## Vérification technologique obligatoire

Avant d'implémenter du code qui utilise une librairie, framework, SDK ou technologie externe, active le skill `check-deps` pour vérifier que tes connaissances sont à jour. Tes données de training ont un cutoff — les APIs changent, les versions majeures cassent la rétrocompatibilité. Ne fais jamais confiance à ta mémoire sur les APIs externes sans vérification.

## Dates et timestamps obligatoires via MCP Time

Ne JAMAIS inventer, deviner ou estimer une date, une heure ou un timestamp. Utilise systématiquement le MCP Time (`get_current_time`) chaque fois que tu as besoin de :

- Générer un timestamp (noms de fichiers de migration, logs, identifiants horodatés)
- Écrire une date dans du code, un fichier ou un document
- Savoir quel jour ou quelle heure il est
- Comparer des dates ou calculer des durées par rapport à maintenant

Tu n'as PAS de notion fiable du temps. Le contexte système peut contenir une date approximative mais elle ne suffit pas pour des timestamps précis. Le MCP Time est ta seule source de vérité temporelle.

## Serena — Navigation et édition sémantique du code

Le MCP Serena apporte une couche d'intelligence sémantique sur la codebase via le Language Server Protocol (LSP). Contrairement aux outils natifs (Grep, Glob, Read) qui travaillent sur du texte brut, Serena comprend la **structure** du code : classes, méthodes, fonctions, imports, dépendances symboliques.

### Outils clés

**Navigation sémantique** — explorer le code par sa structure, pas par du texte :

- `get_symbols_overview` : vue d'ensemble des symboles d'un fichier (classes, fonctions, méthodes) sans lire tout le code
- `find_symbol` : trouver un symbole par son nom (avec `include_body=True` pour lire son contenu, `depth=1` pour ses enfants)
- `find_referencing_symbols` : trouver tous les endroits qui utilisent un symbole (appelants, importeurs, implémentations)

**Édition symbolique** — modifier le code par sa structure, pas par recherche-remplacement textuel :

- `replace_symbol_body` : remplacer le corps d'une fonction/méthode/classe entière
- `insert_after_symbol` / `insert_before_symbol` : insérer du code à une position précise dans la structure
- `rename_symbol` : renommer un symbole et toutes ses références automatiquement

**Recherche et fichiers** :

- `search_for_pattern` : recherche rapide par regex dans la codebase
- `find_file` : trouver un fichier par son nom
- `list_dir` : lister un répertoire

### Quand utiliser Serena plutôt que les outils natifs

| Besoin                                 | Outil natif                   | Serena                                 | Préférer                                    |
| -------------------------------------- | ----------------------------- | -------------------------------------- | ------------------------------------------- |
| Trouver un fichier par nom             | Glob                          | `find_file`                            | Glob (plus rapide)                          |
| Chercher du texte dans le code         | Grep                          | `search_for_pattern`                   | Grep (plus rapide)                          |
| Comprendre la structure d'un fichier   | Read (tout le fichier)        | `get_symbols_overview`                 | **Serena** (économise des tokens)           |
| Lire une seule méthode                 | Read + chercher manuellement  | `find_symbol` avec `include_body=True` | **Serena** (précis)                         |
| Trouver qui appelle une fonction       | Grep sur le nom               | `find_referencing_symbols`             | **Serena** (sémantique, pas textuel)        |
| Analyser les dépendances d'un module   | Grep sur les imports          | `find_referencing_symbols`             | **Serena** (suit les vrais liens)           |
| Renommer une variable/fonction partout | Edit avec `replace_all`       | `rename_symbol`                        | **Serena** (safe, pas de faux positifs)     |
| Remplacer le corps d'une fonction      | Edit (match textuel)          | `replace_symbol_body`                  | **Serena** (pas de risque de match partiel) |
| Ajouter une méthode à une classe       | Edit (trouver le bon endroit) | `insert_after_symbol`                  | **Serena** (positionnement exact)           |

**Règle générale** : utilise Serena dès que tu travailles sur la **structure** du code (symboles, dépendances, refactoring). Utilise les outils natifs pour les recherches textuelles simples et la lecture de fichiers non-code.

### Workflow recommandé avec Serena

1. `get_symbols_overview` pour comprendre la structure d'un fichier sans le lire en entier
2. `find_symbol` avec `include_body=True` pour lire seulement les symboles qui t'intéressent
3. `find_referencing_symbols` pour comprendre l'impact d'une modification avant de la faire
4. Éditer via `replace_symbol_body` / `insert_after_symbol` / `rename_symbol` pour des modifications sûres

Cela économise des tokens (pas besoin de lire des fichiers entiers) et réduit les erreurs (pas de match textuel ambigu).

## Firecrawl — Scraping web propre pour l'IA

Le MCP Firecrawl transforme n'importe quelle page web en Markdown propre, débarrassé du boilerplate (navigation, pubs, footers, scripts). C'est nettement supérieur au `fetch` natif ou à `WebFetch` pour extraire du contenu web exploitable.

### Outils clés

- `firecrawl_scrape` : scraper une URL précise → Markdown propre
- `firecrawl_search` : recherche web + scraping optionnel des résultats (contenu réel, pas juste des snippets)
- `firecrawl_crawl` : crawler un site entier (avec limite de profondeur) → toutes les pages en Markdown
- `firecrawl_batch_scrape` : scraper une liste d'URLs en parallèle
- `firecrawl_extract` : extraction structurée de données spécifiques

### Quand utiliser Firecrawl

| Besoin                                     | Outil alternatif            | Firecrawl                | Préférer                                                 |
| ------------------------------------------ | --------------------------- | ------------------------ | -------------------------------------------------------- |
| Lire le contenu d'une page web             | `WebFetch`                  | `firecrawl_scrape`       | **Firecrawl** (Markdown propre, sans boilerplate)        |
| Rechercher sur le web + lire les résultats | `WebSearch` puis `WebFetch` | `firecrawl_search`       | **Firecrawl** (une seule étape, contenu complet)         |
| Lire la doc complète d'un projet           | `WebFetch` page par page    | `firecrawl_crawl`        | **Firecrawl** (crawl automatique de tout le site)        |
| Scraper plusieurs pages                    | `WebFetch` en boucle        | `firecrawl_batch_scrape` | **Firecrawl** (parallèle, plus fiable)                   |
| Recherche technique (docs, APIs)           | Context7, Exa               | Context7, Exa            | Context7/Exa (plus spécialisés pour les docs techniques) |

**Règle générale** : utilise Firecrawl dès que tu as besoin de **lire le contenu réel** d'une page web. Utilise Context7/Exa pour la recherche de documentation technique. Utilise `WebSearch` pour les recherches rapides où tu n'as pas besoin du contenu complet.

## Playwright — Screenshots et tests visuels

Quand tu utilises `browser_take_screenshot` :

- Ne passe **JAMAIS** un `filename` sans préfixer le chemin par `.playwright-mcp/`. Exemples :
- Correct : `filename: ".playwright-mcp/ma-capture.png"`
- Incorrect : `filename: "ma-capture.png"` (atterrit à la racine du projet)
- Si tu n'as pas besoin d'un nom spécifique, **ne passe pas de `filename`** du tout — le screenshot sera automatiquement sauvé dans
  `.playwright-mcp/` avec un nom horodaté.
- Le viewport est configuré en 1920x1080. Ne pas appeler `browser_resize` sauf demande explicite de l'utilisateur.
