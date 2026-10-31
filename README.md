# leoweb-cc-plugins

Plugin Claude Code personnel consolidant agents, commandes, skills et serveurs MCP pour le développement full-stack.

## Installation

Dans Claude Code, exécuter les commandes slash suivantes :

```
/plugin marketplace add leoweb57/cc-plugins
/plugin install leoweb-dev@leoweb57/cc-plugins
```

## Structure

```
leoweb-dev/
├── CLAUDE.md              # Règles et catalogue des ressources
├── .mcp.json              # Serveurs MCP (Serena, Context7, Exa, Tavily, etc.)
├── hooks/                 # Hooks SessionStart : injection de CLAUDE.md, préparation des worktrees
├── agents/                # Agents spécialisés
│   ├── brainstorm/        # 7 agents d'analyse multi-perspectives
│   ├── business-experts/  # 9 experts business stratégiques
│   ├── react-developer.md
│   ├── mobile-developer.md
│   ├── backend-developer.md
│   ├── devops-engineer.md
│   ├── data-engineer.md
│   ├── deep-research.md
│   ├── refactoring-expert.md
│   ├── root-cause-analyst.md
│   └── quality-engineer.md
├── commands/              # Commandes utilisateur (/command)
│   ├── feature.md
│   ├── deliver.md
│   ├── quality.md
│   ├── merge.md
│   └── resolve.md
├── skills/                # Skills auto-déclenchés ou manuels
│   ├── check-deps/
│   ├── web-research/
│   ├── verify-implementation/
│   ├── tailwind-design-system/
│   ├── nextjs-app-router-patterns/
│   ├── brainstorm/
│   ├── business-experts/
│   ├── karpathy-guidelines/
│   ├── code-quality/                                       # inspiré de unclebob/ub-mode
│   ├── docker-compose-patterns/, docker-build-strategies/   # traduits (docker/skills)
│   ├── postgres-best-practices/                            # traduit (supabase/agent-skills)
│   ├── playwright-e2e/                                     # traduit (testdino-hq/playwright-skill)
│   └── langchain-*, langgraph-*, deep-agents-*, langfuse…  # 24 skills officiels LangChain et Langfuse (en anglais)
└── shared/                # Ressources partagées entre commandes
```

## Commandes

| Commande   | Description                                                                                   |
| ---------- | --------------------------------------------------------------------------------------------- |
| `/feature` | Workflow complet de développement : exploration du code, planification en lots parallèles, implémentation, tests groupés (délégués à la CI si possible, avec commit/push par lot sur la branche) |
| `/deliver` | Génère la documentation de branche avant le push : analyse qualité (`/quality`), changements, synthèse, revue, ADR, cohérence de la doc d'architecture |
| `/quality` | Analyse qualité du code non commité, du dernier commit ou de toute la branche (complexité et CRAP, duplication, principes de conception), puis propose de corriger ou de consigner les constats dans un fichier Markdown. Accepte des points de vigilance en argument |
| `/merge`   | Analyse contextuelle des branches, cartographie des zones de friction, exécution du merge     |
| `/resolve` | Résolution de conflits Git avec classification automatique et agents parallèles               |

## Skills

| Skill                        | Déclencheur                                                 | Description                                                                                                                                             |
| ---------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `check-deps` | lib nouvelle, montée de version majeure ou API incertaine | Vérifie les versions et APIs actuelles en commençant par Context7, puis Exa, Tavily, DeepWiki, WebSearch si besoin. Cache local dans `.claude/tech-research/` |
| `web-research` | recherche d'info sur le web | Mode léger par défaut (une source) ; mode complet multi-sources en parallèle (Exa, Tavily, WebSearch, DeepWiki, WebFetch) pour les sujets complexes, avec synthèse croisée et score de confiance |
| `verify-implementation`      | après implémentation                                        | Vérifie que le code produit correspond au plan et aux exigences                                                                                         |
| `tailwind-design-system`     | travail Tailwind/UI                                         | Patterns CVA (Class Variance Authority), design tokens avec CSS variables, compound components, dark mode, grilles responsives                          |
| `nextjs-app-router-patterns` | travail Next.js                                             | Server Components, streaming Suspense, routes parallèles/interceptées, Server Actions, stratégies de cache                                              |
| `brainstorm`                 | analyse multi-perspectives d'une solution technique         | Lance une équipe de 7 agents en parallèle (architecture, performance, sécurité, UX, qualité, maintenabilité, valeur business)                           |
| `business-experts`           | analyse stratégique/business d'un produit ou d'une décision | Convoque un panel de 9 experts business (Porter, Drucker, Christensen, Godin, Kim & Mauborgne, Collins, Taleb, Meadows, Doumont)                        |
| `karpathy-guidelines`        | écriture, relecture ou refactoring de code                  | 4 règles Karpathy : réfléchir avant de coder, simplicité d'abord, changements chirurgicaux, exécution guidée par des objectifs vérifiables              |
| `code-quality`               | implémentation ou refactoring non trivial, analyse qualité  | Principes inspirés de ub-mode (Uncle Bob) et analyse mesurée : CRAP < 10 et duplication via crapper/dryer (Python, TS/JS), PHPUnit crap4j/PHPMD et jscpd (PHP, Vue), mutation sur demande (mutator, Infection, Stryker) |
| `docker-compose-patterns`    | création ou débogage d'un `compose.yaml`                    | Services, healthchecks, ordre de démarrage, volumes, réseaux, overrides de dev (Docker Inc., traduit) |
| `docker-build-strategies`    | écriture ou optimisation d'un Dockerfile                    | Builds multi-stage, cache de couches, images légères (Docker Inc., traduit) |
| `postgres-best-practices`    | schéma, migrations, index, requêtes, diagnostic PostgreSQL  | Bonnes pratiques PostgreSQL maintenues par Supabase, valables pour tout Postgres (traduit) |
| `playwright-e2e`             | écriture ou débogage de tests Playwright                    | 50 guides : locators, assertions, fixtures, mocks réseau, auth, tests instables, CI, React/Vue (TestDino, traduit) |
| LangChain / LangGraph / Deep Agents | développement d'applications LLM en Python ou TypeScript | 22 skills officiels `langchain-ai/langchain-skills` (fondamentaux, persistance, human-in-the-loop, RAG, middleware, dépendances, évaluation…), en anglais |
| `langfuse`, `migrate-to-langfuse` | instrumentation, prompts, évaluations Langfuse          | Skills officiels `langfuse/skills`, en anglais |

## Agents

### Agents techniques

| Agent                | Description                                                                                                                                                                                                                            |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `react-developer`    | Développeur React 19+ / Next.js 15+ expert. Composants, state management (Zustand, React Query), Server Components, accessibilité WCAG, Core Web Vitals. Référence les skills `tailwind-design-system` et `nextjs-app-router-patterns` |
| `mobile-developer`   | Développeur mobile expert. React Native (New Architecture, Expo), Flutter, natif iOS/Android. Offline-first, performance 60fps, CI/CD app stores. Référence le skill `tailwind-design-system` (NativeWind)                             |
| `backend-developer`  | Développeur backend expert. APIs REST/GraphQL/gRPC, Node.js/TypeScript, Python, bases de données, authentification, microservices, serverless, sécurité OWASP, observabilité                                                           |
| `devops-engineer`    | Ingénieur DevOps expert. Docker, Kubernetes, CI/CD (GitHub Actions, GitLab CI/CD), Terraform, cloud, monitoring (Prometheus, Grafana), sécurité infra, GitOps                                                                          |
| `data-engineer`      | Ingénieur data expert. Modélisation de données, PostgreSQL, MongoDB, Redis, Prisma, Drizzle, optimisation de requêtes, CQRS, Event Sourcing, migrations, sécurité RGPD                                                                |
| `deep-research`      | Recherche approfondie avec stratégies adaptatives et exploration intelligente multi-sources                                                                                                                                            |
| `refactoring-expert` | Refactoring avec Serena (LSP). Analyse d'impact via `find_referencing_symbols`, restructuration safe via `replace_symbol_body` et `rename_symbol`                                                                                      |
| `root-cause-analyst` | Diagnostic de bugs complexes. Trace les chemins d'exécution avec Serena, identifie les causes racines                                                                                                                                  |
| `quality-engineer`   | Stratégie de tests, analyse de testabilité avec Serena, couverture, qualité du code                                                                                                                                                    |

### Agents brainstorm (7)

Chaque agent évalue une solution technique sous un angle spécifique. Utilisables individuellement ou orchestrés en équipe via le skill `brainstorm`.

| Agent                        | Perspective                                                                   |
| ---------------------------- | ----------------------------------------------------------------------------- |
| `brainstorm/architecture`    | Architecture technique, patterns, scalabilité, séparation des responsabilités |
| `brainstorm/performance`     | Bottlenecks, complexité algorithmique, optimisation mémoire/réseau            |
| `brainstorm/security`        | Vulnérabilités, surface d'attaque, OWASP, authentification, chiffrement       |
| `brainstorm/user-experience` | Ergonomie, accessibilité, parcours utilisateur, feedback loops                |
| `brainstorm/quality-testing` | Stratégie de tests, couverture, edge cases, testabilité                       |
| `brainstorm/maintainability` | Dette technique, lisibilité, couplage, documentation, évolutivité             |
| `brainstorm/business-value`  | ROI, time-to-market, priorisation, alignement business                        |

### Agents business-experts (9)

Chaque agent incarne un penseur business avec son framework intégré. Utilisables individuellement ou orchestrés en équipe via le skill `business-experts`.

| Agent                            | Expert              | Spécialité                                                         |
| -------------------------------- | ------------------- | ------------------------------------------------------------------ |
| `business-experts/porter`        | Michael Porter      | Stratégie concurrentielle, 5 forces, chaîne de valeur              |
| `business-experts/drucker`       | Peter Drucker       | Management par objectifs, efficacité, innovation organisationnelle |
| `business-experts/christensen`   | Clayton Christensen | Innovation disruptive, jobs-to-be-done, dilemme de l'innovateur    |
| `business-experts/godin`         | Seth Godin          | Marketing, tribus, permission marketing, Purple Cow                |
| `business-experts/kim-mauborgne` | Kim & Mauborgne     | Stratégie Océan Bleu, création de nouveaux marchés                 |
| `business-experts/collins`       | Jim Collins         | Excellence durable, Good to Great, Hedgehog Concept                |
| `business-experts/taleb`         | Nassim Taleb        | Antifragilité, cygnes noirs, optionalité, via negativa             |
| `business-experts/meadows`       | Donella Meadows     | Pensée systémique, boucles de rétroaction, points de levier        |
| `business-experts/doumont`       | Jean-Luc Doumont    | Communication efficace, structuration de l'information             |

## Serveurs MCP intégrés

Le plugin déclare les serveurs MCP suivants dans `.mcp.json` :

| MCP                     | Usage                                            |
| ----------------------- | ------------------------------------------------ |
| **Serena**              | Navigation et édition sémantique du code via LSP |
| **Context7**            | Documentation à jour des librairies              |
| **Exa**                 | Recherche web sémantique et code context         |
| **Tavily**              | Recherche web avec extraction de contenu         |
| **DeepWiki**            | Documentation IA pour repos GitHub               |
| **Playwright**          | Automatisation navigateur, tests E2E             |
| **GitHub**              | Gestion repos, PRs, issues GitHub                |
| **GitLab**              | Gestion repos, MRs, pipelines GitLab             |
| **Time**                | Timestamps fiables (pas de dates inventées)      |
| **Sequential Thinking** | Raisonnement étape par étape                     |

## Règles CLAUDE.md

Le fichier `CLAUDE.md` est injecté dans le contexte au début de chaque session par un hook `SessionStart` (`hooks/hooks.json`). Claude Code ne charge pas de lui-même le `CLAUDE.md` d'un plugin, et tronque toute sortie de hook au-delà d'environ 10 000 caractères : le script `hooks/inject-claude-md.sh` découpe donc le fichier entre deux sections `##` et chaque entrée du hook injecte une partie. Le fichier reste la seule source à modifier.

Pour tester en local avant de déployer : `claude --plugin-dir ./leoweb-dev`, puis poser une question dont la réponse est dans `CLAUDE.md`.

Règles injectées :

- **Périmètre** — Ne fait que ce qui est demandé, propose les améliorations et attend l'accord avant de les implémenter
- **Règles Karpathy** — Réfléchir avant de coder, simplicité d'abord, changements chirurgicaux, exécution guidée par des objectifs vérifiables
- **Bascule dynamique de modèle** — Délègue chaque sous-tâche au modèle adapté (`fable`, `opus`, `sonnet`, `haiku`) selon sa complexité, y compris dans les workflows
- **Organisation de l'implémentation** — Tâches indépendantes en lots parallèles suivis d'un test groupé, tâches dépendantes en séquentiel, outillage de test mutualisé ; propose des agents indépendants en worktree (`claude --worktree`, `claude --bg`) pour des features entières indépendantes
- **Tests délégués à la CI** — Si la CI couvre les tests : un commit par lot, push sur la branche courante (y compris `main`), surveillance du pipeline en arrière-plan pendant le lot suivant
- **Recherche web et vérification technologique proportionnées** — `web-research` en mode léger par défaut, `check-deps` seulement pour une lib nouvelle ou une montée de version majeure
- **MCP Time** — Pour toute date ou timestamp écrit dans un fichier
- **Serena** — Navigation et édition sémantique du code

**Worktrees** : dans une session lancée avec `claude --worktree` ou `claude --bg`, le hook `hooks/setup-worktree.sh` copie les fichiers `.env*` ignorés du dépôt principal et exporte `COMPOSE_PROJECT_NAME` (unique par worktree), `WORKTREE_NAME` et `WORKTREE_HOST_PREFIX` pour faire tourner plusieurs stacks Docker/Traefik en parallèle. Il ne fait rien hors worktree.

**Skills tiers** : chaque skill copié contient sa licence d'origine (`LICENSE.txt`) et sa source exacte (`SOURCE.md`, avec le commit). Pour les mettre à jour, recopier depuis le dépôt d'origine.

**GitLab** : le serveur MCP utilise `https://gitlab.com/api/v4` par défaut. Pour une instance auto-hébergée, définir `GITLAB_API_URL` (et `GITLAB_PERSONAL_ACCESS_TOKEN`) dans l'environnement du shell qui lance Claude Code : un fichier `.env` du projet n'est pas lu par Claude Code, sauf s'il est chargé dans le shell (ex. `direnv`).
