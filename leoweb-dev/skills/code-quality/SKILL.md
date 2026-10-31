---
name: code-quality
description: >
  Principes de qualité du code et méthode d'analyse mesurée (complexité et score CRAP, duplication,
  tests de mutation). S'active quand tu implémentes ou refactores du code non trivial, quand
  l'utilisateur demande une revue ou un audit de qualité, et quand les commandes /quality ou
  /deliver lancent une analyse qualité.
---

# Qualité du code

Principes inspirés de [ub-mode](https://github.com/unclebob/ub-mode) de Robert C. Martin (Uncle Bob), reformulés et adaptés à ce plugin, et des outils de mesure qui les accompagnent ([crapper](https://github.com/unclebob/crapper), [dryer](https://github.com/unclebob/dryer), [mutator](https://github.com/unclebob/mutator), licence 0BSD). Ils complètent le skill `karpathy-guidelines`.

Les pratiques de ub-mode qui font agir l'agent de lui-même (push sur la branche principale en fin de travail, nettoyage des worktrees, journal exhaustif de chaque action) ne sont pas reprises : les règles Git et de communication du CLAUDE.md du plugin s'appliquent.

## 1. D'abord, que ça marche

- **Une décision, un seul endroit.** Une règle métier, une constante ou un choix technique n'existe qu'une fois dans le code.
- **Les données avant la logique.** Fixe la forme des données (types, schéma, structures) avant d'écrire le traitement.
- **Test d'abord.** Écris le test qui échoue, vérifie qu'il échoue pour la raison attendue, puis fais le plus petit changement qui le fait passer. Si un test honnête est impraticable, n'écris pas un mauvais test : dis-le.
- **Repenser plutôt que greffer.** Quand un besoin nouveau ne rentre pas dans la conception, demande-toi ce que tu aurais construit s'il avait été là dès le départ. Si cette refonte dépasse la demande, propose-la à l'utilisateur au lieu de l'appliquer.
- **Remettre en cause la prémisse.** Quand deux corrections reposant sur la même hypothèse échouent au même contrôle, écris cette hypothèse en une phrase et vérifie-la avant toute nouvelle tentative.
- **Retirer avant d'ajouter.** Simplifie l'existant avant d'y ajouter quelque chose.
- **Outiller le répétitif.** Si une transformation se répète sur de nombreux endroits, fais-en une à la main, puis écris le script qui reproduit exactement ce résultat.

### Conception

- **États illégaux impossibles** : modélise le domaine pour qu'un état invalide ne puisse pas être construit (types, enums, objets valeur).
- **Valider aux frontières** : contrôle et parse les données extérieures une seule fois, là où elles entrent. À l'intérieur, fais-leur confiance.
- **Logique métier pure** : garde les règles métier dans des fonctions sans effet de bord, séparées des I/O.
- **Typage strict** : ne fais pas taire le compilateur ou l'analyseur (`any`, `@ts-ignore`, `# type: ignore`, `@phpstan-ignore`) pour faire passer du code.
- **Idempotence** : exécuter une opération deux fois, ou la relancer après un crash à mi-parcours, aboutit au même état.
- **État partagé** : si deux traitements n'ont pas besoin du même objet mutable, donne-leur chacun le leur. S'ils en ont besoin, un seul écrivain, imposé par la structure.

## 2. Ensuite, que ce soit bien

- **Corriger la cause.** Reproduis le défaut, corrige sa cause. Une garde qui masque le plantage n'est pas une correction.
- **Tester le comportement, pas l'implémentation.** Le test appelle le code comme son utilisateur et vérifie ce que cet utilisateur observerait. Un test qui passerait encore si toutes les fonctions ne renvoyaient rien est à jeter.
- **Complexité maîtrisée.** Chaque fonction reste sous un score CRAP de 10, en la découpant, en la testant, ou les deux. Un `switch`/`match` plat qui fait monter la complexité n'est pas forcément à découper : juge au cas par cas.
- **Pas de duplication structurelle.** Les blocs dont la structure est identique à 80 % ou plus sont factorisés, sauf s'ils évoluent pour des raisons différentes.
- **Tests de mutation.** Couvre le code non couvert, renforce les tests qui laissent survivre des mutants, supprime le code mort.
- **Refactorer sous tests.** Fige le comportement par des tests, change la structure, prouve que le comportement n'a pas changé.

## 3. Analyse qualité

Procédure utilisée par les commandes `/quality` et `/deliver`, ou quand l'utilisateur demande une revue qualité. Elle prend en entrée une **liste de fichiers** (le périmètre) et, éventuellement, des **points de vigilance** donnés par l'utilisateur.

### 3.1 Préparer

1. Ne garde que les fichiers de code du périmètre : exclus les fichiers supprimés, la documentation, les lockfiles, les fichiers générés, `vendor/`, `node_modules/`.
2. Repère les langages et l'outillage **déjà présent dans le projet** (`composer.json`, `package.json`, `pyproject.toml`, `phpmd.xml`, `infection.json5`, `stryker.config.*`, `.jscpd.json`, règle ESLint `complexity`…). L'outillage et les seuils du projet passent avant ceux de ce skill.
3. Repère où tournent les tests (machine hôte ou conteneur Docker) et la commande qui les lance.
4. Note quels dossiers de rapports existent déjà (`.metrics/`, `target/coverage/`, `coverage/`), pour ne supprimer à la fin que ceux créés par l'analyse.

### 3.2 Mesurer

Outils par langage, installation et pièges : voir [outils.md](outils.md).

| Langage | Complexité et CRAP | Duplication | Mutation (sur demande) |
| --- | --- | --- | --- |
| Python, TypeScript, JavaScript (et Java, Go, Rust) | `crapper` | `dryer` | `mutator` |
| PHP | PHPUnit `--coverage-crap4j`, sinon PHPMD (`codesize`) | `jscpd` | Infection |
| Vue (`.vue`) | règle ESLint `complexity` | `jscpd` | Stryker, si déjà configuré dans le projet |

- Lance les mesures **une seule fois pour tout le périmètre**, en passant la liste des fichiers aux outils.
- **Fiabilité** : les tests doivent passer avant de mesurer la couverture. Si toutes les couvertures sortent à 0 %, l'exécution des tests a échoué : diagnostique-la au lieu de rapporter ces scores CRAP.
- Si la couverture ne peut pas être calculée (tests uniquement dans un conteneur, outil absent), mesure la complexité seule et signale-le dans le rapport. **Sans couverture mesurée, ne calcule et n'estime aucun score CRAP ni pourcentage de couverture** : rapporte la complexité (CC) seule, et l'absence de test quand tu l'as constatée en lisant les tests.
- Les **tests de mutation** sont lents : ne les lance pas d'office. Propose-les en une ligne à la fin de l'analyse, limités aux fichiers du périmètre.

### 3.3 Relire

Relis le diff du périmètre à la lumière des sections 1 et 2, et des points de vigilance de l'utilisateur :

- décisions dupliquées, constantes magiques répétées ;
- validations absentes aux frontières, ou répétées à l'intérieur ;
- gardes qui masquent une erreur au lieu d'en corriger la cause ;
- tests qui vérifient l'implémentation, ou qui passeraient avec un code vide ;
- compilateur ou analyseur réduit au silence ;
- opérations non idempotentes (migrations, jobs, handlers rejouables) ;
- état mutable partagé ;
- code mort introduit par le périmètre.

Si le périmètre est large (plus d'une quinzaine de fichiers), répartis cette relecture par module entre des sous-agents lancés en parallèle (`sonnet`). Les mesures restent dans le thread principal.

### 3.4 Rapporter

Chaque constat indique :

- **Sévérité** : `bloquant` (bug probable, CRAP ≥ 30, garde qui masque une erreur), `important` (CRAP entre 10 et 30, duplication ≥ 0,8, test sans valeur), `mineur` (le reste).
- **Emplacement** : `fichier:ligne` et la fonction concernée.
- **Catégorie** : complexité, duplication, tests, frontières, conception, typage, idempotence, code mort, vigilance utilisateur.
- **Mesure** quand il y en a une (CC, couverture, CRAP, score de similarité), uniquement issue d'un outil, jamais estimée.
- **Correction proposée**, en une ou deux lignes.
- **Origine** : `périmètre` (lignes ajoutées ou modifiées, repérées avec `git diff -U0`) ou `préexistant` (code ancien d'un fichier touché). Les constats préexistants sont listés à part et ne sont corrigés que si l'utilisateur le demande.

Trie par sévérité. Termine par les limites de l'analyse : langages non mesurés, couverture indisponible, mutation non lancée.

### 3.5 Corriger, si l'utilisateur le demande

- Applique les corrections retenues en suivant la section « Organisation de l'implémentation » du CLAUDE.md du plugin : corrections indépendantes en lot parallèle, un seul passage de tests à la fin du lot.
- Avant de restructurer une fonction peu couverte, fige son comportement par un test.
- Après le lot, relance les mesures sur les seuls fichiers corrigés pour montrer l'avant/après, et les tests concernés.
- Ne commite pas : Git reste à l'utilisateur, sauf demande explicite.

### 3.6 Nettoyer

Supprime les dossiers de rapports créés par l'analyse (`.metrics/`, `target/coverage/`…) s'ils n'existaient pas avant, et ne les commite jamais.
