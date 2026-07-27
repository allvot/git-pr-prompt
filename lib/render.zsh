# Shared rendering helper.

# _zgp_color <color-key> <text>
# Wraps <text> in the prompt color registered under <color-key>. A color of
# `none` (or an empty one) returns the text untouched — emoji presets rely on
# this so their own colors aren't tinted.
_zgp_color() {
  local color=${ZGP_COLORS[$1]-} text=$2
  [[ -z $text ]] && return
  if [[ -z $color || $color == none ]]; then
    print -r -- "$text"
  else
    print -r -- "%F{${color}}${text}%f"
  fi
}
