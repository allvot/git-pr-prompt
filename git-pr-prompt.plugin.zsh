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

: ${ZGP_PR_ENABLED:=1}                                        # query gh at all
: ${ZGP_PR_CACHE_TTL:=30}                                     # seconds
: ${ZGP_PR_CACHE_DIR:="${TMPDIR:-/tmp}/git-pr-prompt-cache"}
: ${ZGP_ASYNC_REDRAW:=1}                                      # redraw prompt when PR data lands
: ${ZGP_SET_PROMPT:=1}                                        # install our PROMPT
: ${ZGP_SHOW_STASH:=1}
: ${ZGP_SHOW_UNTRACKED:=1}

# Branches that never have a PR of their own.
typeset -ga ZGP_SKIP_BRANCHES
(( $#ZGP_SKIP_BRANCHES )) || ZGP_SKIP_BRANCHES=(main master production)

# --- Symbols ---------------------------------------------------------------

typeset -gA ZGP_SYMBOLS
() {
  local -A defaults=(
    dirty            '*'
    staged           '+'
    untracked        '?'
    ahead            '↑'
    behind           '↓'
    stash            '≡'
    pr_draft         '◌'
    pr_open          '⊙'
    pr_merged        '⊕'
    pr_closed        '⊘'
    review_approved  '✓'
    review_changes   '✗'
  )
  local k
  for k in ${(k)defaults}; do
    [[ -n ${ZGP_SYMBOLS[$k]-} ]] || ZGP_SYMBOLS[$k]=${defaults[$k]}
  done
}

# --- Colors (zsh prompt color names or 256-color numbers) ------------------

typeset -gA ZGP_COLORS
() {
  local -A defaults=(
    user             green
    path             blue
    branch           magenta
    flags            yellow
    prompt_char      yellow
    pr_draft         242
    pr_open          green
    pr_merged        magenta
    pr_closed        red
    review_approved  green
    review_changes   red
  )
  local k
  for k in ${(k)defaults}; do
    [[ -n ${ZGP_COLORS[$k]-} ]] || ZGP_COLORS[$k]=${defaults[$k]}
  done
}

# --- Load the pieces -------------------------------------------------------

source "$ZGP_ROOT/lib/git-status.zsh"
source "$ZGP_ROOT/lib/pr-status.zsh"
source "$ZGP_ROOT/lib/prompt.zsh"

_zgp_setup
