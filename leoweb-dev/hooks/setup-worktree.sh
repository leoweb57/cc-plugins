#!/usr/bin/env bash
# Prépare l'environnement d'une session lancée dans un worktree git
# (claude --worktree, claude --bg). Hook SessionStart : ne fait rien hors worktree.
#
# - Copie depuis le dépôt principal les fichiers .env* ignorés par git qui manquent dans le worktree.
# - Exporte pour les commandes de la session (CLAUDE_ENV_FILE) :
#     COMPOSE_PROJECT_NAME  unique par worktree, pour que les stacks Docker Compose ne se mélangent pas
#     WORKTREE_NAME         nom du worktree
#     WORKTREE_HOST_PREFIX  "<nom normalisé>." à préfixer aux hôtes Traefik
# - Affiche un résumé, ajouté au contexte de Claude.
set -uo pipefail

top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
gitdir=$(git rev-parse --absolute-git-dir 2>/dev/null) || exit 0
common=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P) || exit 0
[ "$(cd "$gitdir" && pwd -P)" = "$common" ] && exit 0   # dépôt principal : rien à faire

main=$(dirname "$common")
name=$(basename "$top")
repo=$(basename "$main")

# Fichiers .env* ignorés du dépôt principal, absents du worktree (les dossiers ignorés comme node_modules sont sautés).
copied=()
while IFS= read -r f; do
  [ -f "$main/$f" ] || continue
  [ -e "$top/$f" ] && continue
  mkdir -p "$top/$(dirname "$f")" && cp -p "$main/$f" "$top/$f" && copied+=("$f")
done < <(git -C "$main" ls-files --others --ignored --exclude-standard --directory 2>/dev/null | grep -E '(^|/)\.env[^/]*$')

project=$(printf '%s-%s' "$repo" "$name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-' | sed 's/^[-_]*//; s/-*$//')
host=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' | sed 's/^-*//; s/-*$//')

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    printf 'export COMPOSE_PROJECT_NAME=%q\n' "$project"
    printf 'export WORKTREE_NAME=%q\n' "$name"
    printf 'export WORKTREE_HOST_PREFIX=%q\n' "$host."
  } >> "$CLAUDE_ENV_FILE"
fi

echo "Session dans le worktree \`$name\` (dépôt principal : $main)."
echo "Variables exportées pour les commandes : COMPOSE_PROJECT_NAME=$project, WORKTREE_NAME=$name, WORKTREE_HOST_PREFIX=$host."
if [ ${#copied[@]} -gt 0 ]; then
  list=$(printf '%s, ' "${copied[@]}"); echo "Fichiers d'environnement copiés depuis le dépôt principal : ${list%, }"
fi
exit 0
