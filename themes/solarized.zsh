# Theme: solarized — https://ethanschoonover.com/solarized
#
# Only the accent colors, which Solarized shares between its light and dark
# variants — so this one theme is legible on both backgrounds. `muted` is base01,
# the color Solarized itself uses for de-emphasized text either way.

_gauge_palette \
  primary    '#d33682'   `# magenta — branch, merged PR` \
  secondary  '#268bd2'   `# blue    — path` \
  remote     '#2aa198'   `# cyan    — ahead/behind` \
  ok         '#859900'   `# green   — staged, approved, open PR` \
  warn       '#b58900'   `# yellow  — unstaged work, prompt char` \
  danger     '#dc322f'   `# red     — untracked, changes requested` \
  muted      '#586e75'   `# base01  — separators, stash, draft`
