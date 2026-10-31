# Outils de mesure

Commandes à lancer **depuis la racine du projet**, avec la liste des fichiers du périmètre (`<fichiers>`). Privilégie toujours la commande et la configuration déjà prévues par le projet (script `composer`/`npm`, fichier de configuration de l'outil).

## Outils d'Uncle Bob : Python, TypeScript, JavaScript, Java, Go, Rust

[crapper](https://github.com/unclebob/crapper) (complexité, couverture, CRAP par fonction), [dryer](https://github.com/unclebob/dryer) (duplication structurelle) et [mutator](https://github.com/unclebob/mutator) (tests de mutation). Licence 0BSD. Ils ne gèrent ni PHP ni les fichiers `.vue`.

### Installation (une fois par machine)

Les trois dépôts sont clonés côte à côte (mutator a besoin de `../crapper`) dans un cache partagé entre projets :

```bash
UB="${XDG_CACHE_HOME:-$HOME/.cache}/leoweb-dev/unclebob"
mkdir -p "$UB"
for t in crapper dryer mutator; do
  [ -d "$UB/$t" ] || git clone --depth 1 "https://github.com/unclebob/$t.git" "$UB/$t"
done
```

Ils exigent **Python 3.11 ou plus**. Le script de chaque outil crée son `.venv` avec `python3` au premier lancement : si `python3` est plus ancien, l'installation échoue et laisse un `.venv` cassé que le script ne refait plus. Crée donc toi-même le `.venv` avec un Python récent :

```bash
PY=$(command -v python3.13 || command -v python3.12 || command -v python3.11)
for t in crapper dryer mutator; do
  [ -x "$UB/$t/.venv/bin/$t" ] || { rm -rf "$UB/$t/.venv"; "$PY" -m venv "$UB/$t/.venv" && "$UB/$t/.venv/bin/pip" install -q -e "$UB/$t"; }
done
```

Sans Python 3.11+ sur la machine, `uv venv -p 3.12 "$UB/<outil>/.venv"` puis `uv pip install -p "$UB/<outil>/.venv" -e "$UB/<outil>"`. Ne mets pas les outils à jour sans le demander.

### Commandes

```bash
"$UB/crapper/crapper" <fichiers>                 # tableau CC / couverture / CRAP, pire score en premier
"$UB/crapper/crapper" --no-coverage <fichiers>   # complexité seule, si les tests ne peuvent pas tourner
"$UB/dryer/dryer" --threshold 0.8 <fichiers>     # paires de blocs dupliqués, score ≥ 0,8
"$UB/mutator/mutator" <fichier>                  # mutation, sur demande seulement
```

- crapper lance les tests pour mesurer la couverture : pytest ou unittest en Python, `npm run coverage`, Vitest `--coverage` ou `c8` en TypeScript.
- **Python : utilise l'interpréteur du projet**, pas celui du système. Repère-le (`.venv/bin/python`, `$VIRTUAL_ENV/bin/python`, ou `uv run`/`poetry run` selon le projet), vérifie ce qu'il contient, puis lance crapper avec son dossier `bin` en tête du `PATH` :
  ```bash
  VENV=.venv   # ou le dossier de l'environnement du projet
  "$VENV/bin/python" -m coverage --version && "$VENV/bin/python" -m pytest --version
  PATH="$PWD/$VENV/bin:$PATH" "$UB/crapper/crapper" <fichiers>
  ```
- **TypeScript** : vérifie la présence d'un script `coverage` dans `package.json` ou de `node_modules/@vitest/coverage-v8`.
- **Effets de bord** : s'il manque `coverage`/`pytest` dans l'environnement Python du projet, ou `@vitest/coverage-v8` dans `node_modules`, crapper les installe (sans modifier `package.json`). Demande avant le premier lancement, ou passe `--no-coverage`.
- `--coverage-command "<commande>"` remplace la commande de couverture ; `--use-existing-coverage` relit les rapports déjà présents (`target/coverage/<langage>/lcov.info`, `coverage/lcov.info`).
- Les outils écrivent `.metrics/` et `target/coverage/` à la racine du projet (à supprimer à la fin s'ils n'existaient pas).
- Les dossiers `test`, `spec`, `vendor`, `node_modules` et `target` sont ignorés.
- mutator : la première exécution sur un fichier lance tous les mutants couverts, les suivantes sont différentielles. `--test-command "<commande>"` cible les tests concernés, `--max-workers N` limite le parallélisme. Code de sortie 3 : au moins un mutant a survécu ; 2 : les tests de base échouent.

## PHP (Symfony, Laravel)

Lance ces outils là où tournent les tests du projet : sur l'hôte, ou dans le conteneur (`docker compose exec <service> …`).

- **CRAP** : PHPUnit calcule le CRAP par méthode, avec un pilote de couverture (Xdebug ou PCOV) :
  ```bash
  XDEBUG_MODE=coverage vendor/bin/phpunit --coverage-crap4j /tmp/crap4j.xml
  ```
  (ou `php -d pcov.enabled=1 vendor/bin/phpunit …` avec PCOV ; dans un conteneur, écris le rapport dans `/tmp` du conteneur et lis-le avec `docker compose exec <service> cat /tmp/crap4j.xml`). Garde les méthodes des fichiers du périmètre dont `crap` ≥ 10. Sans pilote de couverture, mesure la complexité seule :
  ```bash
  vendor/bin/phpmd <fichiers séparés par des virgules> text codesize
  ```
  (si PHPMD n'est pas installé : `phpmetrics` s'il l'est, sinon signale que la complexité PHP n'est pas mesurée et propose de l'ajouter en dépendance de dev, sans l'installer d'office).
- **Duplication** :
  ```bash
  npx -y jscpd@4 --min-lines 4 --min-tokens 50 --reporters console <fichiers>
  ```
  Avec le reporter `console`, jscpd n'écrit aucun fichier.
- **Mutation** (sur demande) : Infection, limité aux lignes modifiées, avec le même pilote de couverture que PHPUnit :
  ```bash
  vendor/bin/infection --git-diff-lines --git-diff-base=<référence du périmètre> --threads=max --no-progress
  ```
  Si Infection n'est pas dans les dépendances du projet, propose de l'ajouter sans l'installer d'office. Sans `infection.json5` dans le projet, Infection en crée un au premier lancement : supprime-le à la fin s'il n'existait pas.

## Vue (`.vue`)

- **Complexité** : `npx eslint --rule '{"complexity": ["warn", 10]}' <fichiers>` avec la configuration ESLint du projet.
- **Duplication** : `jscpd`, comme pour PHP (il gère les fichiers `.vue`).
- **Mutation** (sur demande) : Stryker, seulement s'il est déjà configuré dans le projet (`npx stryker run --mutate <fichiers>`).

## Seuils par défaut

| Mesure | Seuil |
| --- | --- |
| CRAP par fonction | < 10 ; ≥ 30 = bloquant |
| Similarité structurelle (dryer) | ≥ 0,8 à examiner |
| Duplication (jscpd) | ≥ 4 lignes et 50 tokens |
| Mutants survivants | 0 sur le code du périmètre |

Les seuils configurés dans le projet passent avant ceux-ci.
