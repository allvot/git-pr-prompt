#!/usr/bin/env zsh
# Emit the README's example prompts, colored by the prompt's own renderers.
#
#   zsh tools/samples.zsh                  # ANSI, to look at in your terminal
#   zsh tools/samples.zsh | python3 tools/ansi2svg.py --theme dark
#
# Nothing here hardcodes a layout or a color: every line goes through
# _gauge_group_join and _gauge_color, so a change to the prompt shows up in the
# README's images the next time they're regenerated. No git repo needed.

emulate -L zsh
setopt no_unset

ROOT="${0:A:h:h}"
: ${GAUGE_SYMBOL_SET:=minimal}   # geometric symbols render for every reader
GAUGE_PR_ENABLED=1
GAUGE_TITLE=0
GAUGE_SET_PROMPT=0               # we assemble the lines ourselves
source "$ROOT/gauge.plugin.zsh"

# A full flag run: unstaged, staged, untracked, ahead, stashed.
_sample_flags() {
  local out
  out="$(_gauge_flag dirty "${GAUGE_SYMBOLS[dirty]}")"
  out+="$(_gauge_flag staged "${GAUGE_SYMBOLS[staged]}")"
  out+="$(_gauge_flag untracked "${GAUGE_SYMBOLS[untracked]}")"
  out+=" $(_gauge_flag ahead "${GAUGE_SYMBOLS[ahead]}2")"
  out+=" $(_gauge_flag stash "${GAUGE_SYMBOLS[stash]}1")"
  print -r -- "$out"
}

# _sample_line <path> <branch> <flags> <pr> — one status line, uncolored input.
_sample_line() {
  local line="$(_gauge_color path "$1")"
  line+="$(_gauge_group_join "$2" "$3" "$4")"
  print -P -- "$line"
}

_sample_cursor() {   # the ❯ line, with an optional command after it
  print -P -- "$(_gauge_color prompt_char "${GAUGE_SYMBOLS[prompt_char]}") ${1-}"
}

case ${1:-prompt} in
  prompt)
    _sample_line '~/dev/acme' 'feature/login' "$(_sample_flags)" \
      "$(_gauge_pr_render OPEN false APPROVED)"
    _sample_cursor 'git commit --amend'
    ;;

  states)   # one line per PR state, same repo and branch
    _sample_line '~/dev/acme' 'feature/login' '' "$(_gauge_pr_render OPEN false '')"
    _sample_line '~/dev/acme' 'feature/login' '' "$(_gauge_pr_render OPEN true '')"
    _sample_line '~/dev/acme' 'feature/login' '' "$(_gauge_pr_render OPEN false REVIEW_REQUIRED)"
    _sample_line '~/dev/acme' 'feature/login' '' "$(_gauge_pr_render OPEN false APPROVED)"
    _sample_line '~/dev/acme' 'feature/login' '' "$(_gauge_pr_render OPEN false CHANGES_REQUESTED)"
    _sample_line '~/dev/acme' 'feature/login' '' "$(_gauge_pr_render MERGED false '')"
    _sample_line '~/dev/acme' 'feature/login' '' "$(_gauge_pr_render CLOSED false '')"
    ;;

  flags)    # the working-tree flags, each on its own line
    _sample_line '~/repo' 'main' "$(_gauge_flag dirty "${GAUGE_SYMBOLS[dirty]}")" ''
    _sample_line '~/repo' 'main' "$(_gauge_flag staged "${GAUGE_SYMBOLS[staged]}")" ''
    _sample_line '~/repo' 'main' "$(_gauge_flag untracked "${GAUGE_SYMBOLS[untracked]}")" ''
    _sample_line '~/repo' 'main' "$(_gauge_flag ahead "${GAUGE_SYMBOLS[ahead]}2")" ''
    _sample_line '~/repo' 'main' "$(_gauge_flag behind "${GAUGE_SYMBOLS[behind]}1")" ''
    _sample_line '~/repo' 'main' "$(_gauge_flag stash "${GAUGE_SYMBOLS[stash]}3")" ''
    ;;

  *)
    print -u2 "usage: samples.zsh [prompt|states|flags]"
    return 1
    ;;
esac
