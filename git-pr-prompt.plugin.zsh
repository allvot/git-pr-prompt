# git-pr-prompt — a fast zsh prompt showing git working-tree state and
# asynchronous GitHub pull-request status (via the `gh` CLI).
#
# Usage: source this file from your ~/.zshrc.
#   source /path/to/git-pr-prompt/git-pr-prompt.plugin.zsh
#
# Everything is configurable; see README.md for the full list of ZGP_* options.

# Resolve our own directory, whether sourced directly or loaded as a plugin.
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
typeset -g ZGP_ROOT="${0:A:h}"

# --- Options (only defaults; never clobber what the user already set) -------

: ${ZGP_SYMBOL_SET:=auto}                  # auto | nerdfont | minimal | emoji | github
: ${ZGP_PR_ENABLED:=1}                                         # query gh at all
: ${ZGP_PR_CACHE_TTL:=30}                                      # seconds
: ${ZGP_PR_CACHE_DIR:="${TMPDIR:-/tmp}/git-pr-prompt-cache"}
: ${ZGP_ASYNC_REDRAW:=1}                                       # redraw prompt when PR data lands
: ${ZGP_SET_PROMPT:=1}
: ${ZGP_PROMPT_NEWLINE:=1}
: ${ZGP_SHOW_USER:=auto}                   # auto (SSH or root only) | 1 | 0
: ${ZGP_FLAG_COLORS:=1}                    # color each local flag by meaning
: ${ZGP_GROUP_STYLE:=separator}            # separator | parens
: ${ZGP_TITLE:=1}                          # set the terminal title to repo:branch
: ${ZGP_BIND_CLEAR:=1}                     # ^L clears scrollback and redraws in full                                         # install our PROMPT
: ${ZGP_SHOW_STASH:=1}
: ${ZGP_SHOW_UNTRACKED:=1}
: ${ZGP_SHOW_REVIEW_PENDING:=1}                                # 👀 while awaiting review

# Branches that never have a PR of their own.
typeset -ga ZGP_SKIP_BRANCHES
(( $#ZGP_SKIP_BRANCHES )) || ZGP_SKIP_BRANCHES=(main master production)

# --- Symbols and colors ----------------------------------------------------
#
# Precedence: whatever the user set  >  the selected preset  >  minimal preset.
# So `typeset -A ZGP_SYMBOLS=(pr_open '●')` before sourcing overrides one key
# and leaves the rest of the preset intact.

typeset -gA ZGP_SYMBOLS ZGP_COLORS

# _zgp_fill <assoc-array-name> <key> <value> [<key> <value> ...]
# Assigns each pair only if that key is currently unset or empty.
_zgp_fill() {
  local name=$1; shift
  local k v
  while (( $# >= 2 )); do
    k=$1 v=$2; shift 2
    [[ -n ${${(P)name}[$k]-} ]] || eval "${name}[\$k]=\$v"
  done
}

# `auto` means: real GitHub Octicon glyphs if this terminal has a Nerd Font,
# otherwise the geometric set. Detection is cached on disk — see lib/font-detect.zsh
# and the `zgp-font-check` command.
source "$ZGP_ROOT/lib/font-detect.zsh"

typeset -g ZGP_ACTIVE_SYMBOL_SET=$ZGP_SYMBOL_SET
if [[ $ZGP_ACTIVE_SYMBOL_SET == auto ]]; then
  if _zgp_has_nerdfont; then
    ZGP_ACTIVE_SYMBOL_SET=nerdfont
  else
    ZGP_ACTIVE_SYMBOL_SET=minimal
  fi
fi

if [[ -r $ZGP_ROOT/presets/$ZGP_ACTIVE_SYMBOL_SET.zsh ]]; then
  source "$ZGP_ROOT/presets/$ZGP_ACTIVE_SYMBOL_SET.zsh"
else
  print -u2 "git-pr-prompt: unknown ZGP_SYMBOL_SET '$ZGP_SYMBOL_SET' (using minimal)"
  ZGP_ACTIVE_SYMBOL_SET=minimal
fi

# Backstop: minimal fills any key the chosen preset left undefined.
source "$ZGP_ROOT/presets/minimal.zsh"

# --- Load the pieces -------------------------------------------------------

source "$ZGP_ROOT/lib/render.zsh"
source "$ZGP_ROOT/lib/git-status.zsh"
source "$ZGP_ROOT/lib/title.zsh"
source "$ZGP_ROOT/lib/pr-status.zsh"
source "$ZGP_ROOT/lib/prompt.zsh"
source "$ZGP_ROOT/lib/legend.zsh"

_zgp_setup
