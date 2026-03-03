# /deliver - Générer la documentation de branche

Commande de documentation à lancer avant de pousser du code. Elle analyse les changements, génère la documentation technique, maintient les ADR et vérifie la cohérence architecturale. Elle ne touche pas à Git (pas de commit, pas de push).

**Prérequis** : l'utilisateur a committé ses changements sur sa branche.

## Étapes

### 1. Identification
- Détecte la branche courante et en extrait le slug
  - Format attendu : `feature/slug`, `fix/slug`, ou `dev/slug`
  - Formats alternatifs acceptés : `username/slug`, `ticket-id-slug`
  - Si le format ne correspond pas : demande le contexte à l'utilisateur
- Retrouve le dossier spec via glob `docs/specs/*-slug/` (le préfixe numérique est variable)
  - Si trouvé : utilise ce dossier
  - Si pas trouvé : crée le dossier avec le prochain index disponible (scanne `docs/specs/` pour le plus grand NNN existant, crée `NNN+1-slug/`, padding sur 3 chiffres)
- Charge `spec.md` et `plan.md`
- Si pas de spec trouvée : avertit et propose de la créer

### 2. Analyse des changements
- `git diff main...HEAD --name-only` pour lister les fichiers modifiés
- `git log main..HEAD --oneline` pour lister les commits de la branche
- Compare avec le périmètre prévu dans la spec
- Signale les fichiers imprévus ou manquants

### 3. changes.md — Registre factuel
Génère ou met à jour `changes.md` dans le dossier spec résolu à l'étape 1 :
- **Commits** : liste des commits de la branche (hash court, message, date)
- **Fichiers impactés** : liste complète avec type de modification (ajout/modif/suppression)
- **Dépendances** : nouvelles libs ajoutées ou mises à jour (si applicable)
- **Écarts** : fichiers modifiés hors périmètre prévu dans la spec

C'est le registre technique. Pour retrouver le diff exact d'un changement, on fait `git diff <hash>` à partir des commits listés ici.

### 4. summary.md — Mémoire technique de la branche
Génère `summary.md` dans le dossier spec résolu à l'étape 1 :
- **Objectif** : ce qu'on a cherché à accomplir, corriger ou améliorer, et pourquoi
- **Cheminement** : le parcours technique — ce qu'on a essayé, les problèmes rencontrés, les choix faits en cours de route et leurs raisons
- **Modifications techniques** : modules touchés, méthodes/classes créées ou modifiées, fonctionnalités impactées, avec explication du sens de chaque changement
- **Ce qu'on a évité** : pièges contournés, approches écartées et pourquoi
- **Mots-clés** : tags de recherche pour retrouver cette branche (ex: `docker, websocket, terminal, xterm`)

C'est la mémoire de la branche. On la lit pour comprendre pourquoi les choses ont été faites de cette manière, quel chemin a été pris, et éviter de reproduire les mêmes erreurs ou de revenir en arrière sur des décisions déjà prises.

### 5. review.md — Bilan de validation
Bilan qualité du travail autonome de Claude Code. Ce fichier documente ce que Claude Code a mis en place de lui-même pour valider que l'implémentation est fonctionnelle et conforme à la demande initiale.

Génère `review.md` dans le dossier spec résolu à l'étape 1 :
- **Critères d'acceptation** : pour chaque critère de la spec, statut (validé / échoué / non testé) et méthode de validation utilisée
- **Tests générés** : tests unitaires, d'intégration ou E2E écrits par Claude Code pendant le développement, avec leurs résultats d'exécution
- **Scénarios de test** : pour chaque scénario du plan, ce qui a été exécuté concrètement (vitest, Playwright MCP, script custom, vérification manuelle par Claude Code) et le résultat
- **Points sensibles** : ce qui n'a pas pu être testé et pourquoi, tests qui échouent avec diagnostic, zones de code non couvertes par les tests, cas limites identifiés mais non validés
- **Erreurs rencontrées** : problèmes détectés pendant la validation, même s'ils ont été corrigés — pour que le reviewer comprenne les zones fragiles

Ce fichier ne juge pas le travail de l'utilisateur et ne décide pas du merge. Il sert de guide pour la code review humaine : le reviewer peut s'appuyer dessus pour identifier les points sensibles, les zones non testées, et concentrer sa relecture là où c'est le plus utile.

### 6. Gestion des ADR
- **Audit** : parcourt les ADR existantes au statut "Accepté" dans `docs/adr/`
  - Vérifie si les modifications de la branche contredisent ou rendent obsolète une ADR existante
  - Si oui : propose de la marquer "Déprécié" ou "Remplacé par ADR-NNN"
- **Détection** : vérifie si les changements nécessitent une nouvelle ADR :
  - Nouveau pattern architectural
  - Nouvelle librairie ajoutée aux dépendances
  - Changement d'architecture significatif
- **Création** : si une ADR est nécessaire :
  - Détermine le prochain numéro séquentiel
  - Rédige l'ADR en mode interactif (contexte, décision, alternatives, conséquences)
  - Génère `docs/adr/NNN-titre-slug.md`
  - Met à jour les anciennes ADR impactées

### 7. Intégrité de l'architecture
- Relit `docs/architecture/overview.md` et vérifie sa cohérence avec l'état actuel du code :
  - Nouveau service ou container ajouté → l'ajouter dans la zone correspondante
  - Module supprimé ou renommé → mettre à jour la structure
  - Flux de données modifié (nouvelle intégration, changement de dépendance entre services) → mettre à jour le schéma
  - Nouvelle zone fonctionnelle → l'ajouter
- Si des incohérences sont détectées : met à jour `overview.md` et montre les modifications à l'utilisateur
- Si l'architecture n'a pas changé : passe silencieusement

### 8. Cohérence README.md et CLAUDE.md
- Relit `README.md` et `CLAUDE.md` à la racine du projet
- Vérifie leur cohérence avec l'état actuel du code et les changements de la branche :
  - **Stack technique** : nouvelle lib majeure ou techno retirée → mettre à jour
  - **Architecture / containers** : nouveau service Docker, container supprimé → mettre à jour
  - **Structure du projet** : nouveau répertoire ou module → mettre à jour l'arbre
  - **Domaines / services** : nouveau sous-domaine Traefik → mettre à jour les tables
  - **Variables d'environnement** : nouveau groupe de variables → mettre à jour
  - **Commandes utiles** : nouveau script ou commande de dev → mettre à jour
  - **Conventions** : nouveau pattern adopté → mettre à jour
  - **API Endpoints** : nouvelle route ou modification → mettre à jour la table
- Si des incohérences sont détectées : met à jour les fichiers et montre les modifications à l'utilisateur
- Si rien n'a changé dans ces domaines : passe silencieusement

### 9. Runbooks
- Vérifie si les changements introduisent une nouvelle procédure opérationnelle (nouveau service à démarrer, nouvelle commande de migration, nouvelle variable d'env requise...)
- Si oui : propose la mise à jour ou la création d'un runbook dans `docs/runbooks/`

### 10. Résumé
- Affiche un résumé complet :
  - Commits de la branche
  - Fichiers modifiés
  - Documentation générée/mise à jour
  - ADR créées ou mises à jour
  - README.md et/ou CLAUDE.md mis à jour (si applicable)
- Indique à l'utilisateur les prochaines étapes : commiter la documentation, puis pousser

## Contenu final du dossier spec

```
docs/specs/NNN-slug/
├── spec.md          # Demande fonctionnelle, critères d'acceptation (/feature)
├── plan.md          # Plan d'implémentation, scénarios de test (/feature)
├── changes.md       # Registre : commits, fichiers, dépendances (/deliver)
├── summary.md       # Mémoire technique : objectif, cheminement, choix, pièges évités (/deliver)
└── review.md        # Bilan de validation : tests, points sensibles, guide pour code review (/deliver)
```

## Résultat
La documentation est générée. L'utilisateur commite et pousse lui-même.
