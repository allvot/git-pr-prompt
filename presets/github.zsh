# Preset: github — GitHub's own state colors as emoji circles. Unambiguous,
# uniform width, no font install needed.
#
# 🟢 open   ⚪ draft   🟣 merged   🔴 closed
#   — the exact colors GitHub uses for the PR state badge.
# ✅ approved   ❌ changes requested   👀 waiting on review

_gauge_fill GAUGE_SYMBOLS \
  pr_open          '🟢' \
  pr_draft         '⚪' \
  pr_merged        '🟣' \
  pr_closed        '🔴' \
  review_approved  '✅' \
  review_changes   '❌' \
  review_pending   '👀'

# The circles already carry GitHub's own state colors — `none` suppresses the
# %F{...} wrapper. Written straight into GAUGE_COLORS rather than as a palette
# role, so it outranks any theme: recoloring these would destroy their meaning.
_gauge_fill GAUGE_COLORS \
  pr_open          none \
  pr_draft         none \
  pr_merged        none \
  pr_closed        none \
  review_approved  none \
  review_changes   none \
  review_pending   none
