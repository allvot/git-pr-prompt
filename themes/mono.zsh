# Theme: mono — no color at all.
#
# `none` makes _gauge_color return the text untouched, so the prompt emits no
# escapes whatsoever. For screen sharing, e-ink, recordings, terminals with a
# palette you don't control, or simply wanting the prompt to recede.
#
# The symbols still carry the meaning — that's what `gauge-legend` is for.

_gauge_palette \
  primary    none \
  secondary  none \
  remote     none \
  ok         none \
  warn       none \
  danger     none \
  muted      none
