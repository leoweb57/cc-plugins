---
name: karpathy-guidelines
description: >
  Règles de comportement pour réduire les erreurs de code typiques des LLM. S'active quand tu écris,
  relis ou refactores du code : éviter la sur-complexité, faire des changements chirurgicaux,
  expliciter les hypothèses et définir des critères de réussite vérifiables.
license: MIT
---

# Règles Karpathy

Règles de comportement pour réduire les erreurs de code typiques des LLM, tirées des [observations d'Andrej Karpathy](https://x.com/karpathy/status/2015883857489522876) sur les travers des LLM quand ils codent. Source : [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) (MIT).

**Compromis :** ces règles privilégient la prudence plutôt que la vitesse. Pour les tâches triviales, fais preuve de jugement.

## 1. Réfléchir avant de coder

**Ne suppose pas. Ne cache pas ta confusion. Expose les compromis.**

Avant d'implémenter :
- Énonce tes hypothèses explicitement. En cas de doute, demande.
- S'il existe plusieurs interprétations, présente-les : n'en choisis pas une en silence.
- S'il existe une approche plus simple, dis-le. Conteste quand c'est justifié.
- Si quelque chose n'est pas clair, arrête-toi. Nomme ce qui te bloque. Demande.

## 2. La simplicité d'abord

**Le minimum de code qui résout le problème. Rien de spéculatif.**

- Aucune fonctionnalité au-delà de ce qui est demandé.
- Aucune abstraction pour du code utilisé une seule fois.
- Aucune « flexibilité » ou « configurabilité » non demandée.
- Aucune gestion d'erreur pour des scénarios impossibles.
- Si tu écris 200 lignes et que ça pourrait en faire 50, réécris.

Demande-toi : « Un développeur senior trouverait-il ça trop compliqué ? » Si oui, simplifie.

## 3. Des changements chirurgicaux

**Ne touche qu'à ce qui est nécessaire. Ne nettoie que ton propre désordre.**

Quand tu modifies du code existant :
- N'« améliore » pas le code, les commentaires ou le formatage adjacents.
- Ne refactore pas ce qui n'est pas cassé.
- Respecte le style existant, même si tu ferais autrement.
- Si tu remarques du code mort sans rapport, signale-le : ne le supprime pas.

Quand tes changements créent des orphelins :
- Supprime les imports/variables/fonctions que TES changements ont rendus inutilisés.
- Ne supprime pas le code mort préexistant sauf si on te le demande.

Le test : chaque ligne modifiée doit se rattacher directement à la demande de l'utilisateur.

## 4. Une exécution guidée par les objectifs

**Définis des critères de réussite. Boucle jusqu'à vérification.**

Transforme les tâches en objectifs vérifiables :
- « Ajouter une validation » → « Écrire des tests pour les entrées invalides, puis les faire passer »
- « Corriger le bug » → « Écrire un test qui le reproduit, puis le faire passer »
- « Refactorer X » → « S'assurer que les tests passent avant et après »

Pour les tâches en plusieurs étapes, énonce un plan bref :
```
1. [Étape] → vérification : [contrôle]
2. [Étape] → vérification : [contrôle]
3. [Étape] → vérification : [contrôle]
```

Le moment de chaque vérification suit la section « Organisation de l'implémentation » du CLAUDE.md du plugin : après l'étape pour des tâches dépendantes, une seule fois pour un lot de tâches indépendantes, ou dans la CI.

Des critères de réussite solides te permettent de boucler en autonomie. Des critères faibles (« fais que ça marche ») exigent des clarifications constantes.

---

**Ces règles fonctionnent si :** les diffs contiennent moins de changements inutiles, il y a moins de réécritures dues à la sur-complexité, et les questions de clarification arrivent avant l'implémentation plutôt qu'après les erreurs.
