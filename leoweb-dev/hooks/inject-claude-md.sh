#!/usr/bin/env bash
# Injecte le CLAUDE.md du plugin dans le contexte de session (hook SessionStart).
# Claude Code tronque toute sortie de hook au-delà d'environ 10 000 caractères :
# le fichier est donc découpé entre deux sections "## " en morceaux de moins de LIMIT
# caractères, et chaque entrée du hook (hooks.json) affiche le morceau n° $1.
set -euo pipefail

PART="${1:-1}"
SLOTS=4      # nombre d'entrées déclarées dans hooks.json
LIMIT=9500
FILE="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/CLAUDE.md"

[ -f "$FILE" ] || exit 0

LC_ALL=C.UTF-8 awk -v part="$PART" -v slots="$SLOTS" -v limit="$LIMIT" '
  function flush_section() {
    if (sec == "") return
    if (length(chunk[n]) > 0 && length(chunk[n]) + length(sec) > limit) n++
    chunk[n] = chunk[n] sec
    sec = ""
  }
  BEGIN { n = 1 }
  /^## / { flush_section() }
  { sec = sec $0 "\n" }
  END {
    flush_section()
    if (part > n) exit
    if (part == 1 && n > slots)
      printf "ATTENTION : CLAUDE.md du plugin leoweb-dev trop long, les parties %d à %d ne sont pas injectées (augmenter SLOTS dans hooks/inject-claude-md.sh et hooks.json).\n\n", slots + 1, n
    printf "<!-- CLAUDE.md du plugin leoweb-dev, partie %d/%d -->\n%s", part, n, chunk[part]
  }
' "$FILE"
