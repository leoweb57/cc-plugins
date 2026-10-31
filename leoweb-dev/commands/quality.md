---
description: Analyse qualité du code (complexité et CRAP, duplication, principes de conception, tests) sur le code non commité, le dernier commit ou toute la branche, puis propose de corriger les points trouvés ou de les consigner dans un fichier Markdown.
argument-hint: "[points de vigilance]"
---

# /quality - Analyser la qualité du code

Commande d'analyse qualité. Elle mesure le code du périmètre choisi (complexité et score CRAP, duplication), le relit selon les principes du skill `code-quality`, présente les points trouvés, puis propose de les corriger ou de les consigner dans un fichier Markdown pour plus tard. Elle ne touche pas à Git (pas de commit, pas de push).

**Arguments** : `$ARGUMENTS`

- Texte libre : points de vigilance à examiner en priorité (ex. « gestion des erreurs du module paiement », « requêtes N+1 »).
- `--deliver` : appel par la commande `/deliver` (voir le mode deliver plus bas).

## 1. État Git

```bash
git branch --show-current
git status --porcelain
git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null   # branche par défaut, ex. origin/main
```

Si `origin/HEAD` n'est pas défini, prends `origin/main`, sinon `origin/master`, sinon `main`/`master` en local.

## 2. Périmètre

Demande à l'utilisateur (AskUserQuestion) ce qu'il faut analyser :

- **Le code non commité** : modifications indexées ou non, et fichiers non suivis.
- **Le dernier commit**.
- **Toute la branche courante** : tous les commits de la branche depuis la branche par défaut, plus le code non commité.

Option recommandée, placée en premier : le code non commité s'il y en a, sinon toute la branche. Si la branche courante est la branche par défaut, remplace « toute la branche » par « les commits non poussés » (`@{upstream}..HEAD`), et retire l'option s'il n'y en a aucun.

Fichiers du périmètre (fichiers supprimés exclus) :

| Périmètre | Référence | Fichiers |
| --- | --- | --- |
| Non commité | `HEAD` | `git diff --name-only --diff-filter=d HEAD` + `git ls-files --others --exclude-standard` |
| Dernier commit | `HEAD~1` | `git diff --name-only --diff-filter=d HEAD~1 HEAD` |
| Toute la branche | `$(git merge-base HEAD <branche par défaut>)` | `git diff --name-only --diff-filter=d <référence>` + `git ls-files --others --exclude-standard` |
| Commits non poussés | `@{upstream}` | `git diff --name-only --diff-filter=d @{upstream}` + `git ls-files --others --exclude-standard` |

Les lignes ajoutées ou modifiées se lisent avec `git diff -U0 <référence>` (et `git diff -U0 HEAD~1 HEAD` pour le dernier commit) : elles servent à séparer les constats du périmètre des constats préexistants.

Si le périmètre ne contient aucun fichier de code, dis-le et arrête-toi.

## 3. Analyse

Active le skill `code-quality` et suis sa section « Analyse qualité » sur ces fichiers, avec les points de vigilance passés en argument :

1. Préparer : outillage du projet, lieu d'exécution des tests, dossiers de rapports existants.
2. Mesurer : complexité et CRAP, duplication, en une seule exécution pour tout le périmètre.
3. Relire le diff selon les principes du skill et les points de vigilance.

## 4. Présentation

Affiche les constats du périmètre, triés par sévérité, puis les constats préexistants à part :

```
Analyse qualité — <périmètre> (<N> fichiers)

Bloquant
1. src/Billing/Invoice.php:42 Invoice::total — complexité : CC 14, couverture 20 %, CRAP 96
   → extraire le calcul des remises dans une fonction pure et la tester
Important
2. app/pricing.py:16-21 et :24-29 — duplication : similarité 1,00
   → factoriser invoice_total et receipt_total
Mineur
...

Préexistant (fichiers touchés, hors lignes modifiées) : ...
Limites : couverture PHP indisponible (pas de pilote de couverture), mutation non lancée
```

Si rien ne dépasse les seuils et que la relecture ne trouve rien, dis-le en une ligne avec les mesures principales.

Propose ensuite en une ligne les tests de mutation sur les fichiers du périmètre (lents : ne les lance que si l'utilisateur accepte).

## 5. Suite

Demande à l'utilisateur (AskUserQuestion) :

- **Corriger** : tous les constats du périmètre, ou ceux qu'il choisit (par numéro). Les constats préexistants ne sont corrigés que s'il les inclut explicitement.
- **Consigner pour plus tard** : écris les constats dans un fichier Markdown :
  - `docs/specs/NNN-slug/quality.md` si un dossier de spec correspond à la branche (glob `docs/specs/*-slug/`) ;
  - sinon `docs/quality/AAAA-MM-JJ-<branche>.md`, date obtenue via le MCP Time (`get_current_time`).

  Le fichier reprend la présentation de l'étape 4, avec en tête la date, la branche, le périmètre et sa référence Git, et une case à cocher par constat.
- **Rien** : l'analyse s'arrête là.

Pour une correction, suis la section « Corriger » du skill `code-quality` : corrections en lot, tests figés avant de restructurer, mesures avant/après sur les fichiers corrigés. Termine par un récapitulatif : constats corrigés, mesures avant/après, tests lancés, constats restants.

Dans tous les cas, termine par la section « Nettoyer » du skill (dossiers de rapports créés par l'analyse).

## Mode deliver

Avec l'argument `--deliver` :

- Pas de question de périmètre : analyse toute la branche courante (ou les commits non poussés sur la branche par défaut).
- Présente les constats comme à l'étape 4, puis demande : **corriger maintenant** (tout ou une sélection) ou **consigner dans `review.md`**. Les constats non corrigés sont rendus à `/deliver`, qui les écrit dans la section « Qualité du code » de `review.md` ; ne crée pas de fichier `quality.md`.
- Si des corrections sont appliquées, signale que ces fichiers sont modifiés et non commités.
