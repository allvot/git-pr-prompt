# Colors, as their own axis.
#
# `presets/` decides what the symbols LOOK like; `themes/` decides what color
# they are. The two compose freely — nerdfont glyphs in a mono theme, geometric
# glyphs in a bright one.
#
# A theme doesn't set the ~20 GAUGE_COLORS keys directly. It declares seven
# semantic roles and the map below assigns them, so a new theme is seven lines
# and cannot forget a key. Precedence, highest first:
#
#   GAUGE_COLORS[key]  — your explicit per-key override
#   GAUGE_PALETTE[role]— your explicit per-role override
#   themes/$GAUGE_THEME— the selected theme
#   themes/default     — the backstop, so every key always resolves
#
# Whatever wins, GAUGE_COLOR_MODE has the last word on how it's emitted — see
# lib/color.zsh.

typeset -gA GAUGE_PALETTE

# Which role paints which key. This is the only place the mapping lives.
typeset -gA _GAUGE_ROLE_OF=(
  path             secondary
  branch           primary
  separator        muted
  user             ok
  user_root        danger
  prompt_char      warn

  dirty            warn
  staged           ok
  untracked        danger
  ahead            remote
  behind           remote
  stash            muted
  flags            warn        # the whole run, when GAUGE_FLAG_COLORS=0

  pr_open          ok
  pr_draft         muted
  pr_merged        primary
  pr_closed        danger
  review_approved  ok
  review_changes   danger
  review_pending   muted
)

# Themes call this. Same fill semantics as _gauge_fill: an already-set role is
# left alone, so your own GAUGE_PALETTE beats the theme's.
_gauge_palette() { _gauge_fill GAUGE_PALETTE "$@" }

# Roles -> keys. Only fills keys you haven't set yourself.
_gauge_apply_palette() {
  local key role
  for key in ${(k)_GAUGE_ROLE_OF}; do
    [[ -n ${GAUGE_COLORS[$key]-} ]] && continue
    role=${_GAUGE_ROLE_OF[$key]}
    [[ -n ${GAUGE_PALETTE[$role]-} ]] && GAUGE_COLORS[$key]=${GAUGE_PALETTE[$role]}
  done
}

# Load the selected theme, then the default as backstop, then map to keys.
_gauge_load_theme() {
  typeset -g GAUGE_ACTIVE_THEME=$GAUGE_THEME

  if [[ -r $GAUGE_ROOT/themes/$GAUGE_ACTIVE_THEME.zsh ]]; then
    source "$GAUGE_ROOT/themes/$GAUGE_ACTIVE_THEME.zsh"
  else
    print -u2 "gauge: unknown GAUGE_THEME '$GAUGE_THEME' (using default)"
    GAUGE_ACTIVE_THEME=default
  fi

  source "$GAUGE_ROOT/themes/default.zsh"   # fills any role the theme omitted
  _gauge_apply_palette

  # Last: fit the resolved colors to what this terminal can actually show.
  _gauge_resolve_color_mode
  _gauge_degrade_colors
}
