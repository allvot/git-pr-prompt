# Color depth.
#
# Themes may name colors two ways:
#
#   magenta, 242   the terminal's own palette — portable everywhere, and it
#                  follows whatever scheme the terminal is already using
#   #bd93f9        one exact color, the same in every terminal — but only if the
#                  terminal can show 24-bit color
#
# GAUGE_COLOR_MODE decides what happens to the hex ones:
#
#   truecolor  emit as-is (%F{#bd93f9})
#   256        degrade to the nearest xterm-256 index, so hex themes still look
#              close on a terminal without truecolor
#   none       drop all color, whatever the theme said
#   auto       NO_COLOR -> none; COLORTERM=truecolor|24bit -> truecolor; else 256
#
# Named colors and plain indices pass through untouched in every mode but `none`.

# "#abc" / "#aabbcc" -> "#aabbcc". Anything else comes back unchanged.
_gauge_normalize_hex() {
  local h=${1#\#}
  if (( ${#h} == 3 )); then
    print -r -- "#${h[1]}${h[1]}${h[2]}${h[2]}${h[3]}${h[3]}"
  else
    print -r -- "#${h}"
  fi
}

# Nearest xterm-256 index for a hex color.
#
# Two candidates, because the palette has two ways to be gray: the 6x6x6 cube
# (indices 16-231, channel levels 0/95/135/175/215/255) and the 24-step gray ramp
# (232-255, values 8,18,...,238). Squared RGB distance picks between them. The
# cube part is separable — nearest level per channel is the best cube color — so
# only the two finalists need comparing. Indices 0-15 are excluded on purpose:
# the terminal is free to redefine them, so they aren't a color we can match to.
_gauge_hex_to_256() {
  local hex=$(_gauge_normalize_hex "$1")
  local -i r=$(( 16#${hex[2,3]} )) g=$(( 16#${hex[4,5]} )) b=$(( 16#${hex[6,7]} ))

  local -a levels=(0 95 135 175 215 255)
  local -i i ci ri gi bi best cr cg cb
  local -i cube_d gray_d

  # Nearest cube level for each channel, independently.
  local -a idx
  local -i v
  for v in $r $g $b; do
    best=1
    for (( i = 2; i <= 6; i++ )); do
      (( (v - levels[i]) ** 2 < (v - levels[best]) ** 2 )) && best=$i
    done
    idx+=$best
  done
  ri=idx[1] gi=idx[2] bi=idx[3]
  cr=levels[ri] cg=levels[gi] cb=levels[bi]
  (( cube_d = (r - cr) ** 2 + (g - cg) ** 2 + (b - cb) ** 2 ))
  (( ci = 16 + 36 * (ri - 1) + 6 * (gi - 1) + (bi - 1) ))

  # Nearest step on the gray ramp.
  local -i gi2 gv
  (( gi2 = ((r + g + b) / 3 - 8 + 5) / 10 ))
  (( gi2 < 0 )) && gi2=0
  (( gi2 > 23 )) && gi2=23
  (( gv = 8 + gi2 * 10 ))
  (( gray_d = (r - gv) ** 2 + (g - gv) ** 2 + (b - gv) ** 2 ))

  if (( gray_d < cube_d )); then
    print -r -- $(( 232 + gi2 ))
  else
    print -r -- $ci
  fi
}

# Resolve GAUGE_COLOR_MODE into GAUGE_ACTIVE_COLOR_MODE.
_gauge_resolve_color_mode() {
  typeset -g GAUGE_ACTIVE_COLOR_MODE
  local mode=$GAUGE_COLOR_MODE

  if [[ $mode == auto ]]; then
    if [[ -n ${NO_COLOR-} ]]; then
      mode=none                          # no-color.org: any non-empty value
    elif [[ ${COLORTERM-} == (truecolor|24bit) ]] && _gauge_can_truecolor; then
      mode=truecolor
    else
      mode=256
    fi
  fi

  case $mode in
    truecolor|256|none) ;;
    *) print -u2 "gauge: unknown GAUGE_COLOR_MODE '$GAUGE_COLOR_MODE' (using 256)"
       mode=256 ;;
  esac

  GAUGE_ACTIVE_COLOR_MODE=$mode
}

# %F{#rrggbb} is zsh 5.7 and later. Older zsh would print the literal text.
_gauge_can_truecolor() {
  autoload -Uz is-at-least
  is-at-least 5.7
}

# Rewrite GAUGE_COLORS for the resolved depth. Runs last, so it catches theme
# colors and your own per-key overrides alike — set `#bd93f9` yourself and it
# degrades on a 256-color terminal exactly like a theme's would.
_gauge_degrade_colors() {
  local key val
  for key in ${(k)GAUGE_COLORS}; do
    val=${GAUGE_COLORS[$key]}
    if [[ $GAUGE_ACTIVE_COLOR_MODE == none ]]; then
      GAUGE_COLORS[$key]=none
    elif [[ $val == \#* ]]; then
      case $GAUGE_ACTIVE_COLOR_MODE in
        truecolor) GAUGE_COLORS[$key]=$(_gauge_normalize_hex "$val") ;;
        256)       GAUGE_COLORS[$key]=$(_gauge_hex_to_256 "$val") ;;
      esac
    fi
  done
}
