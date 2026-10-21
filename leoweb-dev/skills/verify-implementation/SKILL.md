---
name: verify-implementation
description: >
  S'active automatiquement quand l'implémentation est terminée — quand tu es sur le point de dire
  à l'utilisateur "ça devrait marcher", "c'est fait", "tu devrais avoir le résultat attendu",
  ou toute conclusion similaire. Ne JAMAIS annoncer la fin du travail sans avoir d'abord exécuté
  ce workflow de vérification. S'exécute une fois à la fin d'un lot de tâches ou de la feature
  (pas après chaque petite modification), après l'implémentation d'un plan, la correction d'un bug
  ou l'ajout d'une fonctionnalité qui produit un comportement observable.
---

# Vérification d'implémentation

## Déclencheur

Tu DOIS activer ce skill avant d'annoncer à l'utilisateur que le travail est terminé.
Si tu es sur le point d'écrire "ça devrait marcher", "c'est bon normalement",
"les modifications sont en place" — ARRÊTE. Exécute ce workflow d'abord.
L'utilisateur attend des résultats vérifiés, pas des suppositions optimistes.

**Moment d'exécution** : une fois par lot de tâches indépendantes, ou une fois en fin de feature, jamais après chaque modification d'un lot. Pour des étapes dépendantes (l'une conditionne la suivante), une vérification ciblée après chaque étape suffit, et ce workflow complet s'exécute à la fin. Voir la section « Organisation de l'implémentation » du CLAUDE.md du plugin.

## Phase 1 : Identifier ce qui a changé

Utiliser **Serena** (`get_symbols_overview`) pour lister les symboles modifiés ou ajoutés sans relire tous les fichiers, et `find_referencing_symbols` pour vérifier que les appelants existants ne sont pas cassés par les changements.

Liste concrètement ce qui a été modifié :

- Fichiers modifiés (et ce qui a changé dans chacun)
- Nouveaux endpoints, routes, composants, méthodes, migrations de base de données
- Changements de configuration
- Dépendances ajoutées ou modifiées

## Phase 2 : Déterminer les critères d'acceptation

**Si un plan ou une spec existe** (ex: `spec.md`, `plan.md`, ou instructions de l'utilisateur) :

- Extraire chaque critère d'acceptation
- Chaque critère devient un scénario de test

**Si aucun critère explicite n'existe** (demande ad-hoc, bugfix, modification rapide) :

- Formuler toi-même les critères d'acceptation à partir de ce que l'utilisateur a demandé
- Les présenter brièvement : "Je vais vérifier : 1) ... 2) ... 3) ..."
- Inclure l'inverse : vérifier que rien n'a été cassé (régression)

## Phase 3 : Choisir les outils de vérification

**Si une CI couvre les tests concernés** (lint, unitaires, fonctionnels, e2e) : ne les rejoue pas en local. Pousse sur la branche de la feature si les garde-fous Git de la section « Tests délégués à la CI » du CLAUDE.md du plugin le permettent (branche de feature, confirmation du premier push, pas de déploiement), sinon vérifie en local. Attends le statut final du pipeline et utilise-le comme preuve (MCP GitHub/GitLab, `gh`, `glab`) avant le rapport. Seuls les critères que la CI ne couvre pas sont vérifiés en local avec le tableau ci-dessous.

Pour chaque critère, choisir la méthode de vérification la plus adaptée :

| Ce qui a changé                         | Comment vérifier                                                                                                                                         |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| UI / visuel / composant frontend        | **Playwright MCP** : naviguer, interagir, prendre des captures d'écran                                                                                   |
| Endpoint API                            | **curl / httpie** via Bash : appeler l'endpoint, vérifier la réponse                                                                                     |
| Schéma ou données en base               | **Requête SQL** via Bash : vérifier la structure des tables, l'intégrité des données                                                                     |
| Méthode / logique backend               | **Lancer les tests existants** (vitest, pytest, etc.) ou écrire un script rapide                                                                         |
| Configuration / environnement           | **Vérifier le service en cours** : redémarrer si nécessaire, vérifier le comportement                                                                    |
| Docker / infrastructure                 | **Commandes docker compose** : vérifier que les services sont up et healthy                                                                              |
| Pipeline CI/CD                          | **MCP GitHub** (`get_pull_request_status`, `list_commits`) ou **MCP GitLab** (`get_pipeline`, `get_pipeline_job_output`) : vérifier que les jobs passent |
| Dépendances ajoutées ou modifiées       | Skill `check-deps` : vérifier que les versions sont correctes et que les APIs utilisées correspondent à la version installée                             |
| Imports, signatures, appels             | **Serena** (`find_referencing_symbols`) : vérifier que tous les appelants existants sont compatibles avec les changements de signatures ou de modules     |
| Génération / transformation de fichiers | **Lire le fichier de sortie** et vérifier son contenu                                                                                                    |

Utiliser plusieurs outils si un critère couvre plusieurs couches (ex: "la soumission du formulaire sauvegarde en BDD" = Playwright + SQL).

**Mutualiser l'outillage** : monte une seule fois ce qui est coûteux (navigateur Playwright, serveur, Docker, base de test) et vérifie tous les critères du lot dans cette même session. Lance les tests en parallèle quand l'outil le permet.

## Phase 4 : Exécuter les scénarios de test

Pour chaque critère d'acceptation :

1. **Énoncer le critère** qu'on teste
2. **Exécuter le test** avec l'outil choisi
3. **Capturer la preuve** : capture d'écran, sortie de commande, résultat de requête
4. **Verdict** : PASS ou FAIL avec explication

Si un test ÉCHOUE :

- Corriger le problème immédiatement
- Relancer le test en échec
- Répéter jusqu'à ce qu'il passe
- Puis continuer avec les scénarios restants

Après une correction, relancer uniquement les scénarios en échec, plus ceux qui touchent le code modifié par la correction. La suite complète ne tourne qu'une fois, en fin de feature (ou via la CI).

## Phase 5 : Rapport à l'utilisateur

Uniquement quand TOUS les scénarios passent, rapporter à l'utilisateur :

```
Vérification terminée — tous les tests passent.

Testé :
- [critère 1] : PASS (méthode utilisée)
- [critère 2] : PASS (méthode utilisée)
- ...

[Inclure les captures d'écran ou extraits de sortie comme preuve]
```

Si certains scénarios n'ont pas pu être testés (ex: nécessite l'environnement de production, un service tiers, des identifiants utilisateur) :

- Indiquer clairement ce qui n'a pas pu être vérifié et pourquoi
- Suggérer comment l'utilisateur peut le vérifier manuellement

## Règles

- JAMAIS dire "ça marche" sans avoir testé soi-même
- JAMAIS sauter un critère parce que "c'est évident"
- JAMAIS rapporter des résultats partiels comme complets — tous les critères doivent passer
- Si tu n'as aucun moyen de tester quelque chose, dis-le explicitement — ne fais pas semblant de l'avoir vérifié
- Préférer l'exécution réelle à la relecture de code : exécuter le code bat le lire
- Avec Playwright, ne tester plusieurs tailles d'écran que si l'utilisateur le demande ou si le critère porte sur le responsive
