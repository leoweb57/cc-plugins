# /resolve - Résoudre les conflits de merge avec compréhension contextuelle

Commande de résolution de conflits de merge git. Elle analyse l'intention derrière chaque branche en s'appuyant sur la documentation du projet et l'historique git, puis propose des résolutions argumentées par domaine fonctionnel. Elle ne touche pas à Git (pas de commit, pas de push).

Ce que cette commande fait :
- Analyse les conflits avec compréhension du contexte (docs, historique, dépendances)
- Classifie chaque hunk selon sa nature (additif, contradictoire, supersédant, structurel)
- Propose des résolutions argumentées avec sources citées
- Applique les résolutions après validation explicite de l'utilisateur
- Vérifie l'intégrité du résultat (syntaxe, imports, types, tests)

Ce que cette commande ne fait PAS :
- Elle ne crée pas de commit et ne pousse rien
- Elle ne résout pas les conflits mécaniquement (pas de "ours/theirs" aveugle)
- Elle ne prend pas de décision ambiguë sans validation de l'utilisateur

**Prérequis** : l'utilisateur est en cours de merge ou rebase avec des conflits non résolus (`git status` montre des fichiers "both modified" ou "Unmerged paths").

## Phase 1 : Inventaire des conflits

1. `git status` pour détecter les fichiers en conflit (Unmerged paths)
2. Identifie les branches impliquées :
   - Branche courante (HEAD)
   - Branche entrante (MERGE_HEAD ou branche de rebase)
   - Ancêtre commun via `git merge-base`
3. Lit chaque fichier en conflit et extrait les hunks (marqueurs `<<<<<<<`, `=======`, `>>>>>>>`)
4. Regroupe les conflits par domaine fonctionnel (pas par fichier) :
   - Un domaine = un ensemble cohérent de modifications liées à la même fonctionnalité ou au même module
   - Exemples : "authentification", "API projets", "configuration Docker"
5. Affiche le tableau de bord :
   - Nombre de fichiers en conflit
   - Nombre total de hunks
   - Branches impliquées et ancêtre commun
   - Domaines fonctionnels identifiés

**CHECKPOINT : L'UTILISATEUR VALIDE L'INVENTAIRE ET LE REGROUPEMENT PAR DOMAINE AVANT DE CONTINUER.**

## Phase 2 : Analyse contextuelle

Lance 3 analyses en parallèle via une équipe d'agents spécialisés, selon le protocole décrit dans `shared/conflict-analysis-agents.md`.

Créer une équipe via `TeamCreate`, créer une tâche par agent via `TaskCreate`, puis lancer les 3 agents **en parallèle dans un seul message** via l'outil `Agent` avec le paramètre `team_name`. Attendre que les 3 agents renvoient leurs résultats. Fermer l'équipe via `TeamDelete` après la synthèse.

Les agents travaillent sur les hunks de conflit réels (marqueurs `<<<<<<<` / `=======` / `>>>>>>>`). La source de données pour chaque agent :
- **Agent A** : recherche la documentation relative aux fichiers en conflit
- **Agent B** : analyse l'historique git sur les fichiers en conflit (`git log/diff <ancêtre>..HEAD` et `<ancêtre>..<branche-entrante>`)
- **Agent C** : analyse les imports, exports et signatures qui changent dans les hunks en conflit

**CHECKPOINT : LES 3 ANALYSES SONT TERMINÉES. RÉSUMÉ DES DÉCOUVERTES CLÉ PRÉSENTÉ À L'UTILISATEUR.**

## Phase 3 : Classification des hunks

Pour chaque hunk, croise les résultats des 3 agents et assigne une classification selon la table définie dans `shared/conflict-classification.md`.

## Phase 4 : Proposition des résolutions

Génère un rapport structuré par domaine fonctionnel, selon le format décrit dans `shared/conflict-resolution-format.md`.

**CHECKPOINT : L'UTILISATEUR VALIDE CHAQUE RÉSOLUTION PROPOSÉE AVANT TOUTE APPLICATION. AUCUNE MODIFICATION N'EST FAITE SANS ACCORD EXPLICITE.**

## Phase 5 : Application des résolutions

a. Applique les résolutions séquentiellement, fichier par fichier
b. Pour chaque fichier résolu :
   - Vérifie qu'il ne reste plus de marqueurs de conflit (`<<<<<<<`, `=======`, `>>>>>>>`)
   - Vérifie la syntaxe (pas d'erreur de parsing évidente)
c. Vérifie l'intégrité globale à partir des résultats de l'Agent C :
   - Tous les imports référencent des modules existants
   - Les signatures correspondent entre définitions et appelants
   - Les types sont cohérents

## Phase 6 : Vérification

a. Active le skill `verify-implementation` pour valider le résultat
b. Lance les tests existants du projet (si disponibles)
c. Affiche le rapport final :
   - Nombre de conflits résolus par classification
   - Fichiers modifiés
   - Résolutions appliquées avec rappel des justifications
   - Résultat des tests
   - Éventuels points d'attention restants

## Résultat

Les conflits sont résolus dans les fichiers. L'utilisateur vérifie, commite et pousse lui-même.
