---
name: check-deps
description: >
  S'active automatiquement quand tu es sur le point d'implémenter du code qui utilise une librairie,
  un framework, une API externe, un SDK ou toute technologie tierce. Ne JAMAIS commencer à coder
  avec une techno externe sans avoir d'abord vérifié que tes connaissances sont à jour.
  S'applique quand tu proposes d'utiliser une techno, quand l'utilisateur en demande une,
  ou quand tu écris du code qui importe un package externe.
---

# Recherche technologique

## Déclencheur

Tu DOIS activer ce skill avant d'écrire du code qui utilise une technologie externe.
Si tu es sur le point d'écrire un `import`, un `require`, un `pip install`, un `npm install`,
ou tout code qui s'appuie sur une librairie/framework/SDK externe — ARRÊTE. Exécute ce workflow d'abord.
Tes connaissances ont un cutoff. Les APIs changent, les méthodes sont dépréciées, les versions majeures
cassent la rétrocompatibilité. L'utilisateur attend du code qui fonctionne avec la version actuelle,
pas avec celle de ton training.

## Quand ce skill NE s'applique PAS

- Librairies standard du langage (Python stdlib, Node.js built-ins, etc.)
- Packages déjà utilisés dans le projet avec des patterns établis — dans ce cas, suis les patterns existants
- Modifications mineures sur du code existant qui utilise déjà la techno (le projet fait déjà référence)

## Cache local : `.claude/tech-research/`

Les fiches de recherche sont stockées dans `.claude/tech-research/` à la racine du projet. Ce dossier sert de cache pour éviter de refaire les mêmes recherches.

### Avant toute recherche externe

1. Vérifie si une fiche existe déjà : `.claude/tech-research/<nom-package>.md`
2. Si elle existe, lis la date de recherche dans le frontmatter (`date_recherche`)
3. **Si la fiche a moins de 7 jours** : utilise-la directement, pas besoin de relancer la recherche
4. **Si la fiche a plus de 7 jours** : relance la recherche et mets à jour la fiche
5. Si aucune fiche n'existe : lance la recherche complète et crée la fiche

### Template de fiche

Chaque fiche suit ce format :

```markdown
---
package: <nom du package>
version_actuelle: <version stable au moment de la recherche>
date_recherche: <YYYY-MM-DD>  # Obtenir via MCP Time (get_current_time) — JAMAIS estimer
sources:
  - <URL ou outil utilisé>
---

# <nom du package> — Fiche technique

## Version et statut
- **Version stable** : X.Y.Z
- **Dernière version majeure** : X.0.0 (date)
- **Cycle de release** : (si connu)

## APIs et patterns actuels
Les patterns recommandés par la documentation officielle pour les cas d'usage courants.
(Code exemples, imports, initialisation, patterns clé)

## Breaking changes récents
Changements importants par rapport aux versions précédentes.
(Méthodes dépréciées, APIs renommées, comportements modifiés)

## Guide de migration
Si une version majeure récente a été publiée, résumé des étapes de migration.

## Notes
Pièges courants, limitations connues, dépendances importantes.
```

### Nommage des fiches

- Nom du package en minuscules, tirets pour les espaces : `langchain.md`, `react-query.md`, `next-auth.md`
- Pour les packages scoped : remplacer `/` par `--` : `anthropic--sdk.md`, `tanstack--react-query.md`

## Phase 1 : Identifier les technologies impliquées

Liste chaque technologie externe que tu es sur le point d'utiliser :

- Nom du package/framework
- Version que tu connais de ton training
- Ce que tu comptes en faire (quelles APIs, quels patterns)

## Phase 2 : Vérifier le cache local

Pour chaque technologie identifiée :

1. Cherche `.claude/tech-research/<nom-package>.md`
2. Si la fiche existe et a **moins de 7 jours** → lis-la, passe à la Phase 4
3. Sinon → passe à la Phase 3

## Phase 3 : Recherche externe

Pour chaque technologie sans fiche récente, lancer **tous** les outils de recherche pertinents **en parallèle** pour croiser les sources :

| Outil                                                 | Ce qu'il apporte                                                               |
| ----------------------------------------------------- | ------------------------------------------------------------------------------ |
| **Context7** (`resolve-library-id` puis `query-docs`) | Documentation officielle structurée, exemples de code à jour                   |
| **Exa** (`web_search_exa`)                            | Changelogs, release notes, articles récents, migration guides                  |
| **Tavily** (`tavily-search`)                          | Résultats optimisés LLM, snippets structurés, recherche multi-étapes           |
| **DeepWiki** (`read_wiki_contents`, `ask_question`)   | Repos GitHub spécifiques — architecture, patterns, détails d'implémentation    |
| **WebSearch**                                         | Recherche web généraliste, dernières infos, résultats larges                   |
| **Firecrawl** (`firecrawl_scrape`, `firecrawl_crawl`) | Lire la doc officielle d'un site web (Markdown propre, sans boilerplate)       |

Lancer au minimum 3 sources en parallèle. Firecrawl est surtout utile en second temps pour scraper les URLs clés identifiées par les autres sources.

Pour chaque technologie, vérifier :

a. **Version actuelle** : quelle est la dernière version stable ? Y a-t-il eu une version majeure récente ?
b. **Breaking changes** : quelles APIs ont changé depuis la version que tu connais ? Quelles méthodes sont dépréciées ?
c. **Patterns recommandés** : comment la documentation officielle recommande-t-elle de faire ce que tu veux faire aujourd'hui ?
d. **Migration** : si une version majeure est sortie, y a-t-il un guide de migration ?

**Après la recherche** : crée ou mets à jour la fiche dans `.claude/tech-research/` selon le template ci-dessus. La valeur de `date_recherche` DOIT être obtenue via le MCP **Time** (`get_current_time`) — ne jamais estimer la date, car la logique d'expiration du cache (7 jours) dépend de sa précision.

## Phase 4 : Confronter tes connaissances

Pour chaque technologie :

1. **Compare** ce que tu allais écrire avec ce que la fiche (fraîche ou du cache) indique
2. **Signale les écarts** à l'utilisateur :
   - "J'allais utiliser `X.old_method()` mais depuis la v2.0, c'est remplacé par `X.new_method()`"
   - "Le pattern que je connais est déprécié, la doc recommande maintenant..."
3. **Adapte ton implémentation** aux APIs et patterns actuels

## Phase 5 : Rapport rapide

Avant de commencer à coder, résumer brièvement :

```
Vérification techno terminée.

- [lib1] v4.2.1 (fiche du 2025-03-01) — à jour
- [lib2] v2.0.0 (recherche fraîche, ma connaissance : v1.x) — breaking changes détectés, fiche créée
- [framework] v3.1.0 (fiche du 2025-02-28, < 7j) — utilisée depuis le cache
```

Ne pas détailler sauf si l'utilisateur le demande. L'objectif est de confirmer que le code qu'on va écrire est basé sur des informations vérifiées, pas sur des souvenirs.

## Règles

- JAMAIS supposer qu'une API existe encore sans vérifier — les méthodes sont renommées, dépréciées, supprimées
- JAMAIS écrire du code basé uniquement sur ta mémoire pour une techno que tu n'as pas vérifiée dans cette session
- Si Context7 n'a pas la lib, passer immédiatement à Exa ou DeepWiki — ne pas abandonner la recherche
- Si aucun outil ne donne de résultat fiable, le dire explicitement : "Je n'ai pas pu vérifier la version actuelle de X, mon code est basé sur la v3.x de mon training"
- Préférer un import vérifié à dix suppositions — une seule API dépréciée peut casser tout le projet
- Toujours écrire/mettre à jour la fiche après une recherche — le prochain appel en bénéficiera
- Ne pas bloquer le workflow si `.claude/tech-research/` n'existe pas — le créer silencieusement
