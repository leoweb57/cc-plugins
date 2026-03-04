# Format du rapport de résolution

Ressource partagée utilisée par les commandes `/resolve-conflicts` et `/merge`.
Structure du rapport de résolution, organisé par domaine fonctionnel.

Pour chaque conflit (réel ou anticipé) :

a. **Contexte** : dans quel domaine fonctionnel, quel fichier, quel hunk ou zone de friction
b. **Classification** : type assigné selon la table de classification (`shared/conflict-classification.md`)
c. **Analyse** : ce que chaque branche a voulu faire (sources : Agent A docs, Agent B historique, Agent C dépendances)
d. **Résolution proposée** : le code résultant
e. **Justification** : pourquoi cette résolution, avec sources citées (commit hash, ADR, spec, fichier de doc)
f. **Impact** : fichiers dépendants identifiés par l'Agent C qui pourraient être affectés

Pour les conflits classifiés **DÉCISION REQUISE** :
- Présente 2 options avec les arguments pour et contre chacune
- L'utilisateur tranche
