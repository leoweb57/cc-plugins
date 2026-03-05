---
name: web-research
description: >
  S'active automatiquement quand tu as besoin d'aller chercher de l'information sur le web :
  recherche technique, mise à jour sur un sujet, veille, analyse d'un produit/service/technologie,
  investigation sur un problème, ou toute question qui nécessite des données récentes et fiables.
  Ne JAMAIS faire une recherche web avec un seul outil quand on peut croiser les sources.
---

# Recherche web multi-sources

## Déclencheur

Tu DOIS activer ce skill chaque fois que tu as besoin de chercher de l'information sur le web.
Que ce soit pour répondre à une question de l'utilisateur, investiguer un problème, se renseigner
sur un produit, une technologie, un concurrent, ou toute autre recherche nécessitant des données
externes. Une seule source ne suffit pas — on croise toujours.

## Quand ce skill NE s'applique PAS

- Recherche de documentation d'une lib/framework spécifique pour coder → utilise le skill `check-deps` à la place
- Lecture d'une URL précise que l'utilisateur t'a donnée → utilise directement Firecrawl ou WebFetch
- Recherche dans la codebase locale → utilise Serena ou les outils natifs

## Les 5 sources disponibles

| Source | MCP / Outil | Force | Faiblesse |
|---|---|---|---|
| **Exa** | `web_search_exa` | Recherche sémantique, comprend le sens, pas juste les mots-clés. Recherche de code, personnes, entreprises | Moins bon sur l'actualité brûlante |
| **Tavily** | `tavily-search` | Résultats optimisés pour LLM, snippets structurés, endpoint `/research` multi-étapes | Moins profond sémantiquement qu'Exa |
| **WebSearch** | `WebSearch` (natif) | Rapide, pas de clé API, toujours disponible | Pas de contenu complet, juste des snippets |
| **DeepWiki** | `ask_question`, `read_wiki_contents` | Documentation IA de repos GitHub, architecture et patterns | Limité aux repos GitHub indexés |
| **Firecrawl** | `firecrawl_scrape`, `firecrawl_crawl` | Scraping propre (Markdown sans boilerplate), crawl de sites entiers | Consomme des crédits, pas un moteur de recherche |

## Phase 1 : Qualifier la recherche

Avant de lancer les agents, déterminer :

1. **Le sujet** : qu'est-ce qu'on cherche exactement ?
2. **Le type** : technique (lib, API, architecture) / business (marché, produit, concurrent) / factuel (événement, date, chiffre) / investigation (problème, bug, comportement)
3. **La profondeur** : rapide (une réponse suffit) / approfondie (synthèse multi-sources nécessaire)
4. **Les sources pertinentes** : pas toujours besoin des 5 — adapter selon le type

### Sélection des sources par type

| Type de recherche | Sources prioritaires |
|---|---|
| Technique (lib, framework, API) | Exa + DeepWiki + Tavily |
| Business (marché, concurrent, produit) | Exa + Tavily + WebSearch |
| Factuel (événement, date, chiffre) | WebSearch + Tavily |
| Investigation (problème, debug, comportement) | Exa + Tavily + DeepWiki |
| Documentation d'un site web | Firecrawl (`firecrawl_crawl`) |

## Phase 2 : Recherche parallèle

### Mise en place de l'équipe

Créer une équipe via `TeamCreate` pour orchestrer la recherche. Puis lancer les agents en parallèle via l'outil `Agent` avec le paramètre `team_name` :

1. **`TeamCreate`** : créer une équipe `web-research-<sujet-court>`
2. **`TaskCreate`** : créer une tâche par source sélectionnée
3. **`Agent`** : lancer un agent `general-purpose` par source, **en parallèle** (tous les appels `Agent` dans un seul message), chacun avec sa tâche assignée
4. Attendre que tous les agents renvoient leurs résultats
5. Synthétiser (Phase 3)

Chaque agent reçoit :
- La question formulée de manière adaptée à sa source
- L'instruction de renvoyer ses résultats avec les URLs des sources
- Si une source ne renvoie rien de pertinent, ce n'est pas un échec — les autres compensent

### Consignes par agent

- **Agent Exa** : formuler la requête de manière sémantique (pas de mots-clés, une phrase naturelle). Utiliser les filtres disponibles (date, domaine) si pertinent
- **Agent Tavily** : formuler la requête de manière directe. Utiliser le mode `research` pour les recherches approfondies
- **Agent WebSearch** : formuler avec des mots-clés précis, ajouter l'année courante pour les sujets évolutifs
- **Agent DeepWiki** : utiliser `ask_question` avec le repo GitHub si connu, sinon `read_wiki_structure` pour explorer
- **Agent Firecrawl** : scraper les URLs clés identifiées par les autres agents pour récupérer le contenu complet

### Workflow en 2 vagues

**Vague 1** — Recherche : lancer les agents Exa + Tavily + WebSearch (+ DeepWiki si pertinent) **en parallèle dans un seul message** via `Agent`

**Vague 2** — Approfondissement : si les résultats de la Vague 1 identifient des URLs importantes mais dont le contenu n'est que partiellement disponible, lancer un agent Firecrawl pour scraper ces pages et récupérer le contenu complet en Markdown propre

Une fois la synthèse terminée, fermer l'équipe via `TeamDelete`.

## Phase 3 : Synthèse

Une fois tous les résultats collectés, le synthétiseur (toi) :

1. **Déduplique** : supprime les informations redondantes entre les sources
2. **Croise** : identifie les informations confirmées par plusieurs sources (haute confiance) vs celles présentes dans une seule source (confiance moyenne)
3. **Résout les contradictions** : si deux sources disent des choses différentes, le signale avec les arguments de chaque côté
4. **Structure** : organise la synthèse par thème, pas par source
5. **Source** : chaque affirmation importante est attribuée à sa source (URL)

### Format de la synthèse

```
## [Sujet de la recherche]

### Points clés
- [Affirmation 1] (confirmé par Exa + Tavily)
- [Affirmation 2] (source unique : DeepWiki — confiance moyenne)
- [Affirmation 3] (contradiction : Exa dit X, Tavily dit Y — à vérifier)

### Détails
[Synthèse structurée par thème]

### Sources
- [URL 1] — via Exa
- [URL 2] — via Tavily
- [URL 3] — via Firecrawl (contenu complet)
```

## Phase 4 : Évaluation de confiance

Attribuer un niveau de confiance global à la synthèse :

- **Haute** : informations confirmées par 2+ sources indépendantes, sources fiables (docs officielles, repos GitHub)
- **Moyenne** : informations provenant d'une seule source fiable, ou de 2+ sources de fiabilité variable
- **Faible** : informations non vérifiées, source unique de fiabilité incertaine, ou contradictions non résolues

Si la confiance est faible, le dire explicitement à l'utilisateur et suggérer des pistes pour confirmer.

## Règles

- JAMAIS se contenter d'une seule source quand le sujet est important — croiser systématiquement
- JAMAIS présenter les résultats d'un seul MCP comme une vérité absolue
- TOUJOURS citer les sources avec leurs URLs
- Adapter le nombre de sources à l'importance de la question — pas besoin de 5 agents pour "quelle heure est-il à Tokyo"
- Firecrawl est un outil de **récupération de contenu**, pas de recherche — l'utiliser en Vague 2 pour approfondir, pas en Vague 1 pour chercher
- Si aucune source ne donne de résultat fiable, le dire explicitement plutôt que de broder
