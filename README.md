# leoweb-cc-plugins

Plugin Claude Code personnel consolidant agents, commandes, skills et serveurs MCP pour le développement full-stack.

## Installation

```bash
claude plugin add leoweb-cc-plugins/leoweb-dev
```

## Structure

```
leoweb-dev/
├── CLAUDE.md              # Règles et catalogue des ressources
├── .mcp.json              # Serveurs MCP (Serena, Context7, Exa, Tavily, etc.)
├── agents/                # Agents spécialisés
│   ├── brainstorm/        # 7 agents d'analyse multi-perspectives
│   ├── business-experts/  # 9 experts business stratégiques
│   ├── react-developer.md
│   ├── mobile-developer.md
│   ├── deep-research.md
│   ├── refactoring-expert.md
│   ├── root-cause-analyst.md
│   └── quality-engineer.md
├── commands/              # Commandes utilisateur (/command)
│   ├── feature.md
│   ├── deliver.md
│   ├── merge.md
│   └── resolve.md
├── skills/                # Skills auto-déclenchés ou manuels
│   ├── check-deps/
│   ├── web-research/
│   ├── verify-implementation/
│   ├── tailwind-design-system/
│   ├── nextjs-app-router-patterns/
│   ├── brainstorm/
│   └── business-experts/
└── shared/                # Ressources partagées entre commandes
```

## Commandes

| Commande   | Description                                                                                   |
| ---------- | --------------------------------------------------------------------------------------------- |
| `/feature` | Workflow complet de développement : exploration du code, planification, implémentation, tests |
| `/deliver` | Vérification qualité, tests finaux, commit structuré — prépare une feature pour la livraison  |
| `/merge`   | Analyse contextuelle des branches, cartographie des zones de friction, exécution du merge     |
| `/resolve` | Résolution de conflits Git avec classification automatique et agents parallèles               |

## Skills

| Skill                        | Déclencheur                                                 | Description                                                                                                                                             |
| ---------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `check-deps`                 | avant d'utiliser une lib externe                            | Vérifie les versions et APIs actuelles via 6 sources (Context7, Exa, Tavily, DeepWiki, WebSearch, Firecrawl). Cache local dans `.claude/tech-research/` |
| `web-research`               | recherche d'info sur le web                                 | Orchestration multi-sources en parallèle (Exa, Tavily, WebSearch, DeepWiki) + approfondissement Firecrawl, avec synthèse croisée et score de confiance  |
| `verify-implementation`      | après implémentation                                        | Vérifie que le code produit correspond au plan et aux exigences                                                                                         |
| `tailwind-design-system`     | travail Tailwind/UI                                         | Patterns CVA (Class Variance Authority), design tokens avec CSS variables, compound components, dark mode, grilles responsives                          |
| `nextjs-app-router-patterns` | travail Next.js                                             | Server Components, streaming Suspense, routes parallèles/interceptées, Server Actions, stratégies de cache                                              |
| `brainstorm`                 | analyse multi-perspectives d'une solution technique         | Lance une équipe de 7 agents en parallèle (architecture, performance, sécurité, UX, qualité, maintenabilité, valeur business)                           |
| `business-experts`           | analyse stratégique/business d'un produit ou d'une décision | Convoque un panel de 9 experts business (Porter, Drucker, Christensen, Godin, Kim & Mauborgne, Collins, Taleb, Meadows, Doumont)                        |

## Agents

### Agents techniques

| Agent                | Description                                                                                                                                                                                                                            |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `react-developer`    | Développeur React 19+ / Next.js 15+ expert. Composants, state management (Zustand, React Query), Server Components, accessibilité WCAG, Core Web Vitals. Référence les skills `tailwind-design-system` et `nextjs-app-router-patterns` |
| `mobile-developer`   | Développeur mobile expert. React Native (New Architecture, Expo), Flutter, natif iOS/Android. Offline-first, performance 60fps, CI/CD app stores. Référence le skill `tailwind-design-system` (NativeWind)                             |
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
| **Firecrawl**           | Scraping web → Markdown propre                   |
| **Playwright**          | Automatisation navigateur, tests E2E             |
| **GitHub**              | Gestion repos, PRs, issues GitHub                |
| **GitLab**              | Gestion repos, MRs, pipelines GitLab             |
| **Time**                | Timestamps fiables (pas de dates inventées)      |
| **Sequential Thinking** | Raisonnement étape par étape                     |

## Règles CLAUDE.md

Le fichier `CLAUDE.md` injecte des règles automatiques dans chaque conversation :

- **Vérification technologique obligatoire** — Déclenche `check-deps` avant d'utiliser une lib externe
- **Recherche web multi-sources** — Déclenche `web-research` pour toute investigation web
- **MCP Time obligatoire** — Interdit d'inventer des dates, impose `get_current_time`
- **Serena prioritaire** — Guide d'utilisation détaillé avec tableau comparatif vs outils natifs
- **Firecrawl prioritaire** — Guide d'utilisation avec tableau comparatif vs WebFetch/WebSearch
