# Preset: minimal — plain Unicode geometry, renders in any monospace font.
# Also the backstop preset: it fills in any key another preset left undefined,
# so every symbol must be present here.
#
# Symbols only. Colors are a separate axis — see themes/ and lib/theme.zsh.

_gauge_fill GAUGE_SYMBOLS \
  dirty            '*'  \
  staged           '+'  \
  untracked        '?'  \
  ahead            '↑'  \
  behind           '↓'  \
  stash            '≡'  \
  pr_open          '⊙'  \
  pr_draft         '◌'  \
  pr_merged        '⊕'  \
  pr_closed        '⊘'  \
  review_approved  '✓'  \
  review_changes   '✗'  \
  review_pending   '·'  \
  branch_prefix    ''   \
  separator        '│'  \
  prompt_char      '❯'
