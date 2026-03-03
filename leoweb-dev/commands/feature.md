# /feature - Démarrer un nouveau travail

Commande de cadrage pour démarrer toute feature, bugfix ou modification. Elle structure la demande, analyse l'historique et le code existant, itère avec l'utilisateur en connaissance de cause, puis lance la planification. Elle ne touche pas à Git (pas de création de branche, pas de commit, pas de push).

**Prérequis** : l'utilisateur a déjà créé sa branche et est dessus.

## Phase 1 : Vérification

1. Vérifie qu'on n'est pas sur `main` — sinon avertit :
   > ⚠️ Tu es sur `main`. Crée ta branche d'abord, puis relance `/feature`.
2. Détecte la branche courante et en extrait le slug
   - Format attendu : `feature/slug`, `fix/slug`, ou `dev/slug` (ex: `feature/multi-project-support`)
   - Formats alternatifs acceptés : `username/slug`, `ticket-id-slug`
   - Si le format ne correspond pas : demande le contexte à l'utilisateur
3. Résout le dossier spec pour cette branche :
   - Cherche un dossier existant via glob `docs/specs/*-slug/` (le préfixe numérique est variable)
   - Si trouvé : utilise ce dossier (reprise de travail ou `/deliver` déjà passé)
   - Si pas trouvé : sera créé en Phase 3 avec le prochain index disponible

## Phase 2 : Cadrage

### Étape 2a — Recueil initial

4. Demande à l'utilisateur :
   - **Ce qu'on souhaite implémenter** : description libre de la tâche
   - **Référence de ticket** (optionnel) : si un ticket existe

5. À partir de ces éléments, déduit grosse maille :
   - Le **type** de travail : `feat` (nouvelle fonctionnalité), `fix` (correction de bug), `dev` (refacto, config, docs)
   - Les **modules potentiellement impactés** : frontend, backend, shared, docker, docker-compose, config

### Étape 2b — Analyse historique + codebase (en parallèle)

6. **Analyse historique** — parcourt la documentation existante :
   - `docs/specs/` : lit `summary.md` et `changes.md` des specs qui touchent les mêmes modules/fichiers
   - `docs/adr/` : décisions architecturales en vigueur sur les modules concernés
   - `docs/architecture/overview.md` : contexte global
   - Pour chaque spec pertinente, extrait :
     - Problématiques rencontrées précédemment sur ces zones de code
     - Choix techniques faits et leurs raisons
     - Pièges évités, approches écartées
     - Erreurs et points sensibles signalés dans les `review.md`

7. **Exploration du code actuel** — dans le périmètre identifié :
   - Structure et organisation des modules concernés
   - Patterns en place (conventions, abstractions, interfaces)
   - Dépendances entre composants

### Étape 2c — Brainstorming itératif enrichi

8. Présente à l'utilisateur le **contexte complet** :
   - **Contraintes de l'existant** : code actuel, patterns en place, interfaces à respecter
   - **Historique pertinent** : problèmes passés, choix techniques, pièges évités
   - **ADR en vigueur** qui s'appliquent au périmètre
   - Si rien de pertinent n'a été trouvé, le signale aussi

9. Itère avec l'utilisateur :
   - Questions de précision sur le besoin
   - Définition du **périmètre précis** avec limites et contraintes
   - **Critères d'acceptation** : ce que l'utilisateur devrait observer fonctionnellement pour considérer le travail comme réussi
   - Arbitrages éclairés par le contexte
   - Continue jusqu'à avoir une vision complète : besoin, périmètre, contraintes, critères d'acceptation

10. Résume et demande validation avant de passer à la spec

## Phase 3 : Spec (enrichie)

11. Crée le dossier spec (si pas déjà trouvé à l'étape 3) :
    - Scanne `docs/specs/` pour trouver le plus grand index numérique existant parmi les dossiers `NNN-*` (ignore `_template`)
    - Crée `docs/specs/NNN-slug/` avec NNN = max + 1, padding sur 3 chiffres (ex: `007-multi-project-support`)
    - Si le dossier existait déjà (reprise) : le réutilise tel quel

12. Génère `spec.md` dans ce dossier :
    - Référence du ticket (si fournie)
    - Type (déduit)
    - Titre et description
    - Critères d'acceptation (formulés du point de vue utilisateur)
    - Périmètre (fichiers et modules concernés)
    - **Contraintes identifiées** : ADR en vigueur, patterns à respecter, limitations techniques
    - **Contexte historique pertinent** : choix passés, pièges à éviter, approches écartées
    - **Risques** : zones fragiles, dépendances sensibles
    - Date de création

## Phase 4 : Planification

13. Passe en mode planification natif de Claude Code en lui fournissant comme contexte :
    - La spec enrichie (critères d'acceptation, périmètre, contraintes, risques)
    - Les ADR et contraintes architecturales en vigueur

14. Laisse Claude Code faire son travail de planification : brainstorming technique, découpage en phases, identification des tâches, analyse de la codebase, proposition du plan à l'utilisateur.

15. Quand l'utilisateur valide le plan, **AVANT toute implémentation** :
    - **OBLIGATOIRE** : écrire `plan.md` dans le dossier spec résolu à l'étape 3, en suivant le template `docs/specs/_template/plan.md`
    - Le fichier doit être une transcription fidèle et complète du plan : phases, tâches, contraintes techniques, scénarios de test, risques
    - **POINT DE CONTRÔLE** : vérifier que `plan.md` existe et est complet. Ne JAMAIS passer à l'implémentation sans ce fichier.

## Phase 5 : Implémentation

16. Une fois `plan.md` écrit et vérifié, lance l'implémentation en suivant le plan sauvegardé.
