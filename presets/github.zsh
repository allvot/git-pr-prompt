# Preset: github — GitHub's own state colors as emoji circles. Unambiguous,
# uniform width, no font install needed.
#
# 🟢 open   ⚪ draft   🟣 merged   🔴 closed
#   — the exact colors GitHub uses for the PR state badge.
# ✅ approved   ❌ changes requested   👀 waiting on review

_zgp_fill ZGP_SYMBOLS \
  pr_open          '🟢' \
  pr_draft         '⚪' \
  pr_merged        '🟣' \
  pr_closed        '🔴' \
  review_approved  '✅' \
  review_changes   '❌' \
  review_pending   '👀'

_zgp_fill ZGP_COLORS \
  pr_open          none \
  pr_draft         none \
  pr_merged        none \
  pr_closed        none \
  review_approved  none \
  review_changes   none \
  review_pending   none
