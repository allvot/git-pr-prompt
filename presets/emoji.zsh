# Preset: emoji — pictographic, works in any terminal with an emoji font
# (macOS, most Linux desktops, Windows Terminal). No font install needed.
#
# Emoji are double-width. If your terminal renders them at 1.5 cells the prompt
# can look slightly off; the `github` preset uses uniformly-wide glyphs, and
# `minimal` / `nerdfont` are single-width.
#
# 🔀 open      the standard "merge branches" pictogram
# 🚧 draft     work in progress, not ready for review
# 🎉 merged    it landed
# 🚫 closed    closed without merging
# ✅ approved  ❌ changes requested  👀 waiting on review

_gauge_fill GAUGE_SYMBOLS \
  pr_open          '🔀' \
  pr_draft         '🚧' \
  pr_merged        '🎉' \
  pr_closed        '🚫' \
  review_approved  '✅' \
  review_changes   '❌' \
  review_pending   '👀'

# Emoji carry their own color — `none` suppresses the %F{...} wrapper. Written
# straight into GAUGE_COLORS rather than as a palette role, so it outranks any
# theme: tinting an emoji is wrong whatever colors you've chosen.
_gauge_fill GAUGE_COLORS \
  pr_open          none \
  pr_draft         none \
  pr_merged        none \
  pr_closed        none \
  review_approved  none \
  review_changes   none \
  review_pending   none
