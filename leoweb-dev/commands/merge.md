# /merge - Préparer et exécuter un merge entre deux branches

Commande proactive de merge. Elle analyse les divergences entre deux branches **avant** le merge, anticipe les zones de friction, propose une stratégie de résolution, exécute le merge, puis résout les conflits éventuels avec le contexte déjà acquis. Contrairement à `/resolve` (réactif — on est déjà en état de conflit), `/merge` est proactif : on comprend d'abord, on merge ensuite.

Ce que cette commande fait :
- Analyse les modifications de chaque branche par rapport à l'ancêtre commun
- Anticipe et classifie les zones de friction (fichiers modifiés par les deux branches)
- Propose une stratégie de résolution validée par l'utilisateur avant d'agir
- Exécute le `git merge`
- Si conflits : enchaîne sur la résolution avec le contexte intentionnel déjà acquis
- Vérifie l'intégrité du résultat (syntaxe, imports, types, tests)

Ce que cette commande ne fait PAS :
- Elle ne crée pas de commit manuellement (le merge commit est automatique si pas de conflits)
- Elle ne pousse rien
- Elle ne prend pas de décision ambiguë sans validation de l'utilisateur
- Elle ne force pas le merge si les branches ne sont pas propres

**Prérequis** : les deux branches existent et sont propres (pas de changements non commités).

## Phase 1 : Cadrage

1. L'utilisateur précise :
   - **Branche source** : la branche à merger
   - **Branche destination** : la branche qui reçoit le merge (branche courante)
   - **Contexte intentionnel** : ce que chaque branche fait, quel problème elle résout
2. Vérifie que les deux branches existent et qu'il n'y a pas de changements non commités (`git status`)
3. Calcule l'ancêtre commun via `git merge-base <destination> <source>`
4. Dimensionne les modifications :
   - `git diff --stat <ancêtre>..<source>` — changements de la branche source
   - `git diff --stat <ancêtre>..<destination>` — changements de la branche destination
5. Affiche le tableau de bord :
   - Fichiers modifiés par la branche source uniquement
   - Fichiers modifiés par la branche destination uniquement
   - Fichiers modifiés par les deux branches (zones de friction potentielles)
   - Ancêtre commun (hash et date)

**CHECKPOINT : L'UTILISATEUR VALIDE LE CADRAGE ET LES ZONES DE FRICTION IDENTIFIÉES AVANT DE CONTINUER.**

## Phase 2 : Analyse contextuelle

Lance 3 analyses en parallèle via une équipe d'agents spécialisés, selon le protocole décrit dans `shared/conflict-analysis-agents.md`.

Créer une équipe via `TeamCreate`, créer une tâche par agent via `TaskCreate`, puis lancer les 3 agents **en parallèle dans un seul message** via l'outil `Agent` avec le paramètre `team_name`. Attendre que les 3 agents renvoient leurs résultats. Fermer l'équipe via `TeamDelete` après la synthèse.

Les agents travaillent sur les diffs virtuels des deux branches vs ancêtre commun (pas sur des hunks de conflit réels). La source de données pour chaque agent :
- **Agent A** : recherche la documentation relative aux fichiers modifiés par les deux branches
- **Agent B** : analyse l'historique git des deux branches (`git log/diff <ancêtre>..<source>` et `<ancêtre>..<destination>`). Dispose en plus du **contexte intentionnel** fourni par l'utilisateur en Phase 1
- **Agent C** : analyse les imports, exports et signatures qui changent dans les fichiers touchés par les deux branches (pas seulement ceux en commun — inclut les dépendances indirectes). Utilise **Serena** (`find_referencing_symbols`, `get_symbols_overview`) pour détecter les impacts indirects via les liens sémantiques du code

**CHECKPOINT : LES 3 ANALYSES SONT TERMINÉES. RÉSUMÉ DES DÉCOUVERTES CLÉ PRÉSENTÉ À L'UTILISATEUR.**

## Phase 3 : Cartographie des zones de friction

Pour chaque fichier modifié par les deux branches, croise les résultats des 3 agents :

a. Compare les modifications de chaque branche sur ce fichier
b. Prédit le type de conflit probable selon la table définie dans `shared/conflict-classification.md`
c. Classe la zone par niveau de risque :
   - **Faible** : ADDITIF ou STRUCTUREL — résolution mécanique prévisible
   - **Moyen** : SUPERSÉDANT — un côté remplace l'autre, nécessite validation
   - **Élevé** : CONTRADICTOIRE ou DÉCISION REQUISE — nécessite arbitrage
d. Identifie les conflits indirects : fichiers modifiés par une seule branche mais qui dépendent de code modifié par l'autre (résultats de l'Agent C)

## Phase 4 : Stratégie de merge

Génère un rapport structuré par domaine fonctionnel, selon le format décrit dans `shared/conflict-resolution-format.md`.

En complément du format standard :
- **Pré-résolutions** : pour les zones à risque faible (ADDITIF, STRUCTUREL), propose le code résultant qui sera appliqué automatiquement si des conflits surviennent
- **Points de décision** : pour les zones à risque élevé (CONTRADICTOIRE, DÉCISION REQUISE), présente les options et demande la décision de l'utilisateur **avant** le merge

**CHECKPOINT : L'UTILISATEUR VALIDE LA STRATÉGIE COMPLÈTE AVANT L'EXÉCUTION DU MERGE. AUCUN MERGE N'EST LANCÉ SANS ACCORD EXPLICITE.**

## Phase 5 : Exécution du merge

a. Exécute `git merge <source>` depuis la branche destination
b. Si le merge est propre (pas de conflits) : passe directement à la Phase 7
c. Si des conflits surviennent : passe à la Phase 6

## Phase 6 : Résolution des conflits (si nécessaire)

Enchaîne sur le workflow de `/resolve` à partir de sa Phase 1, avec les avantages suivants :
- L'analyse contextuelle des Phases 2-3 est déjà disponible — pas besoin de relancer les agents
- Le contexte intentionnel de l'utilisateur est connu
- Les pré-résolutions validées en Phase 4 sont appliquées automatiquement sur les hunks correspondants
- Seuls les conflits non anticipés ou classifiés DÉCISION REQUISE nécessitent une intervention de l'utilisateur

## Phase 7 : Vérification

a. Active le skill `verify-implementation` pour valider le résultat du merge
b. Lance les tests existants du projet (si disponibles)
c. Affiche le rapport final :
   - Zones de friction anticipées vs conflits réels (prédiction correcte ou non)
   - Résolutions appliquées avec rappel des justifications
   - Pré-résolutions appliquées automatiquement
   - Points de décision tranchés par l'utilisateur
   - Résultat des tests
   - Éventuels points d'attention restants

## Résultat

Le merge est effectué. Si des conflits sont survenus, ils sont résolus dans les fichiers. L'utilisateur vérifie le résultat, commite si nécessaire (en cas de conflits résolus) et pousse lui-même.
