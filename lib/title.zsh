# Terminal / tab title: "repo:branch".
#
# This is the one place repo context survives a screen clear. ⌘K in Tabby and
# Ghostty wipes the buffer and keeps only the cursor's row, so a two-line prompt
# loses its status line — the title doesn't care, and it makes a tab bar
# readable while you're at it.

_gauge_title() {
  (( GAUGE_TITLE )) || return

  local branch=$1 root text
  root=$(git rev-parse --show-toplevel 2>/dev/null)

  if [[ -n $root ]]; then
    text="${root:t}${branch:+:$branch}"
  else
    text=${(%):-%~}      # expand %~ here, so a '%' in the path stays literal
  fi

  # OSC 0 sets the window and the tab/icon title in one go.
  print -n -- $'\e]0;'"${text}"$'\a'
}
