# Preset: minimal — plain Unicode geometry, renders in any monospace font.
# Also the backstop preset: it fills in any key another preset left undefined,
# so every key must be present here.

_zgp_fill ZGP_SYMBOLS \
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
  prompt_char      '❯'

_zgp_fill ZGP_COLORS \
  user             green    \
  user_root        red      \
  path             blue     \
  branch           magenta  \
  flags            yellow   \
  prompt_char      yellow   \
  pr_open          green    \
  pr_draft         242      \
  pr_merged        magenta  \
  pr_closed        red      \
  review_approved  green    \
  review_changes   red      \
  review_pending   242
