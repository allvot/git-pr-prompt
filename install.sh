#!/usr/bin/env bash
# Add git-pr-prompt to ~/.zshrc (idempotent, backs up first).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$ROOT/git-pr-prompt.plugin.zsh"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
LINE="source \"$PLUGIN\""

[[ -f "$PLUGIN" ]] || { echo "error: $PLUGIN not found" >&2; exit 1; }

command -v git >/dev/null || echo "warning: git not found on PATH" >&2
command -v gh  >/dev/null || echo "note: gh CLI not found — the PR segment will stay empty" >&2

if [[ -f "$ZSHRC" ]] && grep -qF "git-pr-prompt.plugin.zsh" "$ZSHRC"; then
  echo "already installed in $ZSHRC — nothing to do"
  exit 0
fi

if [[ -f "$ZSHRC" ]]; then
  backup="$ZSHRC.git-pr-prompt.bak"
  cp "$ZSHRC" "$backup"
  echo "backed up $ZSHRC -> $backup"
fi

{
  echo ""
  echo "# git-pr-prompt"
  echo "$LINE"
} >> "$ZSHRC"

echo "added to $ZSHRC"
echo "run: exec zsh"
