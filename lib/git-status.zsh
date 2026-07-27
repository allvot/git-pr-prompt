# Working-tree state for the current repo, as a compact flag string.
# Output example: "*+? ↑2 ↓1 ≡3"

_zgp_local_status() {
  git rev-parse --is-inside-work-tree &>/dev/null || return

  local flags=""

  # Unstaged changes to tracked files.
  git diff --quiet 2>/dev/null || flags+=${ZGP_SYMBOLS[dirty]}

  # Staged changes.
  git diff --cached --quiet 2>/dev/null || flags+=${ZGP_SYMBOLS[staged]}

  # Untracked files (bail on the first hit — cheap in big repos).
  if (( ZGP_SHOW_UNTRACKED )); then
    [[ -n $(git ls-files --others --exclude-standard 2>/dev/null | head -1) ]] \
      && flags+=${ZGP_SYMBOLS[untracked]}
  fi

  # Divergence from the upstream branch.
  local ab
  ab=$(git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
  if [[ -n $ab ]]; then
    local ahead=${ab%%$'\t'*}
    local behind=${ab##*$'\t'}
    (( ahead  > 0 )) && flags+=" ${ZGP_SYMBOLS[ahead]}${ahead}"
    (( behind > 0 )) && flags+=" ${ZGP_SYMBOLS[behind]}${behind}"
  fi

  # Stash entries.
  if (( ZGP_SHOW_STASH )); then
    local -a stash
    stash=(${(f)"$(git stash list 2>/dev/null)"})
    (( $#stash > 0 )) && flags+=" ${ZGP_SYMBOLS[stash]}${#stash}"
  fi

  print -r -- "$flags"
}
