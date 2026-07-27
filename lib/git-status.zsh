# Working-tree state for the current repo, as a compact flag string.
# Output example: "*+? ↑2 ↓1 ≡3", already colored.

# One flag, tinted by what it MEANS rather than by being a flag: yellow for work
# in progress, green for staged and ready, red for files git isn't tracking,
# cyan for anything about the remote, dim for the stash. Six glyphs of one color
# have to be read; six colors are recognised at a glance.
#
# With GAUGE_FLAG_COLORS=0 each flag comes back bare and the caller tints the whole
# run with the single `flags` color instead.
_gauge_flag() {
  local key=$1 text=$2
  if (( GAUGE_FLAG_COLORS )); then
    _gauge_color "$key" "$text"
  else
    print -r -- "$text"
  fi
}

_gauge_local_status() {
  git rev-parse --is-inside-work-tree &>/dev/null || return

  local flags=""

  # Unstaged changes to tracked files.
  git diff --quiet 2>/dev/null || flags+=$(_gauge_flag dirty "${GAUGE_SYMBOLS[dirty]}")

  # Staged changes.
  git diff --cached --quiet 2>/dev/null || flags+=$(_gauge_flag staged "${GAUGE_SYMBOLS[staged]}")

  # Untracked files (bail on the first hit — cheap in big repos).
  if (( GAUGE_SHOW_UNTRACKED )); then
    [[ -n $(git ls-files --others --exclude-standard 2>/dev/null | head -1) ]] \
      && flags+=$(_gauge_flag untracked "${GAUGE_SYMBOLS[untracked]}")
  fi

  # Divergence from the upstream branch.
  local ab
  ab=$(git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
  if [[ -n $ab ]]; then
    local ahead=${ab%%$'\t'*}
    local behind=${ab##*$'\t'}
    (( ahead  > 0 )) && flags+=" $(_gauge_flag ahead  "${GAUGE_SYMBOLS[ahead]}${ahead}")"
    (( behind > 0 )) && flags+=" $(_gauge_flag behind "${GAUGE_SYMBOLS[behind]}${behind}")"
  fi

  # Stash entries.
  if (( GAUGE_SHOW_STASH )); then
    local -a stash
    stash=(${(f)"$(git stash list 2>/dev/null)"})
    (( $#stash > 0 )) && flags+=" $(_gauge_flag stash "${GAUGE_SYMBOLS[stash]}${#stash}")"
  fi

  # Monochrome mode tints the finished run in one go.
  if (( GAUGE_FLAG_COLORS )); then
    print -r -- "$flags"
  else
    print -r -- "$(_gauge_color flags "$flags")"
  fi
}
