# gauge — a fast zsh prompt showing git working-tree state and
# asynchronous GitHub pull-request status (via the `gh` CLI).
#
# Usage: source this file from your ~/.zshrc.
#   source /path/to/gauge/gauge.plugin.zsh
#
# Everything is configurable; see README.md for the full list of GAUGE_* options.

# Resolve our own directory, whether sourced directly or loaded as a plugin.
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
typeset -g GAUGE_ROOT="${0:A:h}"

# --- Options (only defaults; never clobber what the user already set) -------

: ${GAUGE_SYMBOL_SET:=auto}                  # auto | nerdfont | minimal | emoji | github
: ${GAUGE_THEME:=default}                    # colors: see themes/
: ${GAUGE_COLOR_MODE:=auto}                  # auto | truecolor | 256 | none
: ${GAUGE_PR_ENABLED:=1}                                         # query gh at all
: ${GAUGE_PR_CACHE_TTL:=30}                                      # seconds
: ${GAUGE_PR_CACHE_DIR:="${TMPDIR:-/tmp}/gauge-cache"}
: ${GAUGE_ASYNC_REDRAW:=1}                                       # redraw prompt when PR data lands
: ${GAUGE_SET_PROMPT:=1}
: ${GAUGE_PROMPT_NEWLINE:=1}
: ${GAUGE_SHOW_USER:=auto}                   # auto (SSH or root only) | 1 | 0
: ${GAUGE_FLAG_COLORS:=1}                    # color each local flag by meaning
: ${GAUGE_GROUP_STYLE:=separator}            # separator | parens
: ${GAUGE_TITLE:=1}                          # set the terminal title to repo:branch
: ${GAUGE_BIND_CLEAR:=1}                     # ^L clears scrollback and redraws in full                                         # install our PROMPT
: ${GAUGE_SHOW_STASH:=1}
: ${GAUGE_SHOW_UNTRACKED:=1}
: ${GAUGE_SHOW_REVIEW_PENDING:=1}                                # 👀 while awaiting review

# Branches that never have a PR of their own.
typeset -ga GAUGE_SKIP_BRANCHES
(( $#GAUGE_SKIP_BRANCHES )) || GAUGE_SKIP_BRANCHES=(main master production)

# --- Symbols and colors ----------------------------------------------------
#
# Two independent axes. `presets/` sets GAUGE_SYMBOLS (what the glyphs are),
# `themes/` sets GAUGE_COLORS (what color they take), and any combination works.
#
# Precedence for both: whatever the user set  >  the selected preset or theme  >
# the backstop (presets/minimal.zsh, themes/default.zsh). So
# `typeset -A GAUGE_SYMBOLS=(pr_open '●')` before sourcing overrides one key and
# leaves the rest intact.

typeset -gA GAUGE_SYMBOLS GAUGE_COLORS

# _gauge_fill <assoc-array-name> <key> <value> [<key> <value> ...]
# Assigns each pair only if that key is currently unset or empty.
_gauge_fill() {
  local name=$1; shift
  local k v
  while (( $# >= 2 )); do
    k=$1 v=$2; shift 2
    [[ -n ${${(P)name}[$k]-} ]] || eval "${name}[\$k]=\$v"
  done
}

# `auto` means: real GitHub Octicon glyphs if this terminal has a Nerd Font,
# otherwise the geometric set. Detection is cached on disk — see lib/font-detect.zsh
# and the `gauge-font-check` command.
source "$GAUGE_ROOT/lib/font-detect.zsh"

typeset -g GAUGE_ACTIVE_SYMBOL_SET=$GAUGE_SYMBOL_SET
if [[ $GAUGE_ACTIVE_SYMBOL_SET == auto ]]; then
  if _gauge_has_nerdfont; then
    GAUGE_ACTIVE_SYMBOL_SET=nerdfont
  else
    GAUGE_ACTIVE_SYMBOL_SET=minimal
  fi
fi

if [[ -r $GAUGE_ROOT/presets/$GAUGE_ACTIVE_SYMBOL_SET.zsh ]]; then
  source "$GAUGE_ROOT/presets/$GAUGE_ACTIVE_SYMBOL_SET.zsh"
else
  print -u2 "gauge: unknown GAUGE_SYMBOL_SET '$GAUGE_SYMBOL_SET' (using minimal)"
  GAUGE_ACTIVE_SYMBOL_SET=minimal
fi

# Backstop: minimal fills any key the chosen preset left undefined.
source "$GAUGE_ROOT/presets/minimal.zsh"

# Colors. After the presets, so a preset that must not be tinted (emoji, github)
# can pin those keys to `none` and have that survive any theme.
source "$GAUGE_ROOT/lib/color.zsh"
source "$GAUGE_ROOT/lib/theme.zsh"
_gauge_load_theme

# --- Load the pieces -------------------------------------------------------

source "$GAUGE_ROOT/lib/render.zsh"
source "$GAUGE_ROOT/lib/git-status.zsh"
source "$GAUGE_ROOT/lib/title.zsh"
source "$GAUGE_ROOT/lib/pr-status.zsh"
source "$GAUGE_ROOT/lib/prompt.zsh"
source "$GAUGE_ROOT/lib/legend.zsh"

_gauge_setup
