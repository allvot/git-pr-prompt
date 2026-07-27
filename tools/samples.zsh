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

# _sample_user_line <label> <user-text> <color-key> — a status line preceded by
# the user segment. The real segment renders %n/%m, which would put this machine's
# names in the image, so the text is passed in and only the coloring is shared.
_sample_user_line() {
  local line
  line="$(printf '  %-18s' "$1")"
  # Pad to a fixed user column so the paths line up and the empty first row
  # reads as "nothing here" rather than as a different layout.
  [[ -n $2 ]] && line+="$(_gauge_color $3 "$2")"
  line+="$(printf '%*s' $(( 12 - ${#2} )) '')"
  line+="$(_gauge_color path '~/dev/acme')"
  line+="$(_gauge_group_join 'feature/login' '' '')"
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

  presets)  # every preset side by side — reuses gauge-legend --all, minus its
            # interactive footer, so the table can't drift from the presets
    gauge-legend --all \
      | grep -v 'Switch with GAUGE_SYMBOL_SET' \
      | awk 'NF { seen = 1 } seen { l[++n] = $0; if (NF) last = n }
             END { for (i = 1; i <= last; i++) print l[i] }'
    ;;

  user)     # the optional user segment, in each case that shows it.
            # Mock names, not %n/%m: this image ships in a public README.
    _sample_user_line 'auto (local)'       ''           user
    _sample_user_line 'auto (over SSH)'    'dev@laptop' user
    _sample_user_line 'auto (as root)'     'root'       user_root
    _sample_user_line 'GAUGE_SHOW_USER=1'  'dev'        user
    ;;

  themes)   # the same line in every theme — one subshell each, because a theme
            # is resolved once at load time
    local t
    for t in default nord gruvbox dracula solarized mono; do
      printf '  %-11s' "$t"
      GAUGE_THEME=$t GAUGE_COLOR_MODE=truecolor zsh "$ROOT/tools/samples.zsh" line
    done
    ;;

  line)     # one status line, no cursor row — what `themes` calls per theme
    _sample_line '~/dev/acme' 'feature/login' "$(_sample_flags)" \
      "$(_gauge_pr_render OPEN false APPROVED)"
    ;;

  *)
    print -u2 "usage: samples.zsh [prompt|states|flags|presets|themes]"
    return 1
    ;;
esac
