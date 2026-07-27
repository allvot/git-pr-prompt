# Theme: default — the terminal's own eight colors.
#
# Deliberately named colors rather than hex: they resolve through whatever scheme
# your terminal already uses, so the prompt matches your setup instead of
# fighting it. Hex themes are for when you want one specific palette regardless.
#
# Also the backstop theme — every role must be defined here.

_gauge_palette \
  primary    magenta   `# branch, merged PR — the thing you're on` \
  secondary  blue      `# path` \
  remote     cyan      `# ahead/behind: about the remote, not your tree` \
  ok         green     `# staged, approved, open PR` \
  warn       yellow    `# unstaged work, the prompt character` \
  danger     red       `# untracked, changes requested, closed unmerged` \
  muted      242       `# separators, stash, draft — background detail`
