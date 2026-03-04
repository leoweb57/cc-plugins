---
name: brainstorm
description: >
  S'active quand l'utilisateur est en phase de cadrage, de définition fonctionnelle ou technique d'une
  feature, d'un produit ou d'une architecture. Se déclenche aussi quand l'utilisateur demande de
  réfléchir à comment implémenter quelque chose, quand il veut explorer les différentes facettes
  d'un problème, ou quand la commande /feature entre en phase de cadrage (Phase 2).
  Peut aussi être invoqué manuellement avec /brainstorm.
---

# Brainstorm multi-perspectives

Ce skill orchestre une équipe d'agents spécialisés qui analysent un problème chacun à travers
leur prisme d'expertise, débattent entre eux, puis un synthétiseur produit une vision consolidée.

## Quand l'activer

- Pendant le cadrage d'une feature (phase de définition fonctionnelle/technique)
- Quand l'utilisateur demande "comment on devrait faire ça ?"
- Quand un choix d'architecture ou de design se présente
- Quand l'utilisateur invoque `/brainstorm` manuellement

## Phase 0 : Préparation

Avant de lancer l'équipe, formuler clairement :

1. **Le sujet** : qu'est-ce qu'on analyse ? (feature, architecture, problème technique, produit)
2. **Le contexte** : qu'est-ce qui existe déjà ? quelles sont les contraintes connues ?
3. **Les questions clés** : qu'est-ce qu'on cherche à déterminer ?

Présenter ce cadrage à l'utilisateur et obtenir sa validation avant de lancer l'équipe.

## Phase 1 : Analyse — chaque expert analyse indépendamment

Créer une équipe et lancer **7 agents en parallèle**, chacun avec un biais intentionnel.
Chaque agent reçoit le sujet, le contexte et les questions clés, et produit son analyse
à travers son prisme.

### Les 7 experts

**Business & Métier** — Pense en valeur
- Quel problème métier concret cette feature résout-elle ?
- Est-ce que ça apporte de la valeur mesurable (revenu, rétention, conversion, gain de temps) ?
- Quel est le coût d'opportunité — que ne fait-on PAS en faisant ça ?
- Est-ce aligné avec la stratégie produit et les priorités business ?
- Quel est le MVP — que peut-on couper pour livrer plus vite sans perdre la valeur ?
- Pour enrichir son analyse, cet agent doit lire les cadres théoriques dans **`shared/business-frameworks.md`**
  et appliquer les frameworks les plus pertinents au sujet (Christensen, Porter, Godin, etc.)

**Sécurité** — Pense en attaquant
- Quelles surfaces d'attaque cette approche expose-t-elle ?
- Quelles données sensibles sont en jeu ?
- Quels sont les scénarios d'abus possibles ?
- Quelles mesures de protection sont nécessaires ?
- Où sont les risques d'injection, de fuite, d'escalade de privilèges ?

**Performance** — Pense en charge
- Comment ça se comporte à grande échelle ?
- Quels sont les goulots d'étranglement prévisibles ?
- Quelles sont les implications mémoire, CPU, réseau, BDD ?
- Où faut-il du cache, de la pagination, du lazy loading ?
- Quel est le coût de cette approche en termes de ressources ?

**Maintenabilité** — Pense dans 6 mois
- Est-ce qu'un développeur qui n'a pas le contexte comprendrait ce code ?
- Quelle dette technique cette approche introduit-elle ?
- Est-ce que c'est facile à modifier, étendre, supprimer ?
- Est-ce que les responsabilités sont bien séparées ?
- Est-ce cohérent avec les patterns existants du projet ?

**Expérience utilisateur** — Pense comme l'utilisateur final
- Est-ce que l'utilisateur comprend intuitivement ce qui se passe ?
- Quels sont les cas d'erreur visibles par l'utilisateur ?
- Est-ce que l'expérience est fluide, rapide, prévisible ?
- Quels feedback visuels sont nécessaires (loading, erreurs, succès) ?
- Est-ce accessible ? Est-ce que ça marche sur mobile ?

**Architecture** — Pense en système
- Est-ce que cette approche s'intègre bien dans l'architecture existante ?
- Quelles dépendances est-ce que ça crée ou renforce ?
- Est-ce que les couches sont bien respectées (frontend/backend/BDD) ?
- Quels sont les impacts sur les autres modules ?
- Est-ce qu'il y a un risque de couplage fort ?

**Qualité & Testabilité** — Pense en tests
- Comment on teste ça ? (unitaire, intégration, E2E)
- Quels sont les cas limites et les scénarios d'échec ?
- Est-ce que le code est facilement mockable/injectable ?
- Quels sont les scénarios de régression possibles ?
- Quelle couverture de test est réaliste et suffisante ?

### Consignes pour chaque agent

Chaque agent doit produire :
- **3-5 points clés** vus à travers son prisme (pas un cours magistral)
- **Risques identifiés** avec niveau de gravité (critique / important / mineur)
- **Recommandations concrètes** (pas de généralités — des actions spécifiques au contexte)
- **Questions en suspens** pour les autres experts ou pour l'utilisateur

## Phase 2 : Débat — les experts se challengent

Une fois toutes les analyses reçues :

1. **Partager les analyses** : chaque expert reçoit les analyses des autres via messages d'équipe
2. **Tour de réaction** : chaque expert peut :
   - Approuver un point d'un autre expert et le renforcer
   - Contester un point avec un argument issu de son prisme
   - Signaler un conflit entre deux recommandations (ex: "la sécurité recommande X mais la performance recommande Y")
   - Poser une question à un autre expert
3. **Résolution des conflits** : quand deux experts sont en désaccord, chacun argumente.
   Le synthétiseur tranchera en phase 3.

Limiter le débat à **2 tours de réactions** pour ne pas tourner en rond.

## Phase 3 : Synthèse — le meilleur de chaque perspective

Le synthétiseur (toi, l'orchestrateur) produit un document consolidé :

### Structure du livrable

```markdown
# Synthèse de brainstorm — [Sujet]

## Contexte et objectif
[Résumé du sujet analysé]

## Décisions clés
Pour chaque point de débat, la décision retenue et pourquoi :
- [Décision 1] : retenu l'argument de [expert] parce que [raison]
- [Décision 2] : compromis entre [expert A] et [expert B] — [solution]

## Spécifications fonctionnelles
[Ce que ça fait du point de vue utilisateur, enrichi par l'expert UX]

## Spécifications techniques
[Comment ça marche techniquement, enrichi par les experts architecture/performance/maintenabilité]

## Mesures de sécurité
[Protections à mettre en place, issues de l'expert sécurité]

## Stratégie de test
[Plan de test, issues de l'expert qualité]

## Risques identifiés
[Consolidation des risques de tous les experts, classés par gravité]

## Questions ouvertes
[Points qui nécessitent une décision de l'utilisateur]
```

### Présentation à l'utilisateur

Présenter la synthèse à l'utilisateur et lui demander :
- S'il valide les décisions prises
- S'il veut approfondir un point particulier
- S'il a des réponses aux questions ouvertes

## Intégration avec /feature

Quand ce skill est activé pendant la commande `/feature` :
- La synthèse produite alimente directement la `spec.md`
- Les spécifications techniques alimentent le `plan.md`
- Les risques identifiés sont inclus dans la section risques de la spec

## Règles

- Chaque expert doit rester dans son rôle — pas de "j'ai aussi un avis sur la performance" depuis l'expert sécurité
- Les analyses doivent être concrètes et contextuelles, pas des conseils génériques
- Le débat doit être constructif : l'objectif est de trouver la meilleure approche, pas de "gagner"
- Le synthétiseur ne fait pas la moyenne — il tranche en argumentant
- Si le sujet est simple (ex: ajouter un bouton), ne pas lancer les 7 experts — adapter le nombre au besoin
