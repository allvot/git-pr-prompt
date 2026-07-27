# Prompt assembly, precmd hook and async redraw.

typeset -g GAUGE_GIT_INFO=""   # rendered git segment, refreshed on every precmd

# Join the prompt's groups — branch, working-tree flags, PR state.
#
# Default is a dim separator between groups rather than parens around them: a
# delimiter's job is to mark where a group ends, and it does that better when it
# isn't the same weight as the branch name it's wrapping. `GAUGE_GROUP_STYLE=parens`
# restores the bracketed form.
#
# Takes pre-colored flags/PR text; the branch is colored here.
_gauge_group_join() {
  local branch=$1 flags=${2-} pr=${3-} out sep
  flags=${flags# }        # the run leading with ↑/↓/≡ carries a leading space

  if [[ $GAUGE_GROUP_STYLE == parens ]]; then
    out=" $(_gauge_color branch "(${GAUGE_SYMBOLS[branch_prefix]}${branch}")"
    [[ -n $flags ]] && out+=" ${flags}"
    out+=$(_gauge_color branch ")")
    [[ -n $pr ]] && out+=" ${pr}"
  else
    sep=" $(_gauge_color separator "${GAUGE_SYMBOLS[separator]}") "
    out="${sep}$(_gauge_color branch "${GAUGE_SYMBOLS[branch_prefix]}${branch}")"
    [[ -n $flags ]] && out+="${sep}${flags}"
    [[ -n $pr ]]    && out+="${sep}${pr}"
  fi

  print -r -- "$out"
}

_gauge_git_segment() {
  local branch=$1
  [[ -n $branch ]] || { print -r -- ""; return }

  _gauge_group_join "$branch" "$(_gauge_local_status)" "$(_gauge_pr_status "$branch")"
}

_gauge_precmd() {
  vcs_info
  GAUGE_GIT_INFO=$(_gauge_git_segment "$vcs_info_msg_0_")
  _gauge_title "$vcs_info_msg_0_"
}

# Clear the screen, drop the scrollback, and redraw the WHOLE prompt.
#
# The terminal's own clear (⌘K) can't do that last part: it keeps the cursor's
# row and knows nothing about the status line above it. zsh's clear-screen
# reprints every prompt line, so doing it shell-side keeps the context visible —
# and the \e[3J makes it discard scrollback like ⌘K does.
gauge-clear-screen() {
  print -n -- $'\e[3J'
  zle clear-screen
}

# Redraw the prompt when a background PR query finishes.
_gauge_usr1() {
  (( GAUGE_ASYNC_REDRAW )) || return 0
  GAUGE_GIT_INFO=$(_gauge_git_segment "$vcs_info_msg_0_")
  zle && zle reset-prompt
}

# Who-and-where prefix, including its trailing space — empty when it would only
# be restating the obvious.
#
# Your own name on your own laptop is noise: it never changes, and it pushes the
# useful part of the line right. It IS information in two cases, so `auto` shows
# it exactly then — over SSH (which box am I on?) and as root (am I about to do
# damage?). Decided once at setup: neither EUID nor SSH_* can change inside a
# running shell.
_gauge_user_segment() {
  local remote="" who='%n'
  [[ -n ${SSH_CONNECTION-}${SSH_TTY-} ]] && { remote=1; who='%n@%m' }

  case $GAUGE_SHOW_USER in
    0) return ;;
    1) ;;
    *) [[ -n $remote ]] || (( EUID == 0 )) || return ;;
  esac

  local key=user
  (( EUID == 0 )) && key=user_root
  print -r -- "$(_gauge_color $key "$who") "
}

_gauge_setup() {
  setopt prompt_subst

  autoload -Uz vcs_info add-zsh-hook
  zstyle ':vcs_info:*'     enable git
  zstyle ':vcs_info:git:*' formats       '%b'
  zstyle ':vcs_info:git:*' actionformats '%b|%a'

  add-zsh-hook precmd _gauge_precmd

  # Take over ^L only while it still runs the stock widget — if it's bound to
  # anything else, that's the user's choice.
  if (( GAUGE_BIND_CLEAR )) && [[ $(bindkey '^L') == *' clear-screen' ]]; then
    zle -N gauge-clear-screen
    bindkey '^L' gauge-clear-screen
  fi

  # Don't stomp on an existing SIGUSR1 handler.
  if (( GAUGE_ASYNC_REDRAW )) && ! (( $+functions[TRAPUSR1] )); then
    TRAPUSR1() { _gauge_usr1 }
  fi

  if (( GAUGE_SET_PROMPT )); then
    PROMPT="$(_gauge_user_segment)$(_gauge_color path '%~')"
    PROMPT+='${GAUGE_GIT_INFO}'

    # Status on one line, the cursor on the next. Keeps the input at a fixed
    # column no matter how deep the path or how long the branch name, so
    # commands don't wrap in unpredictable places.
    if (( GAUGE_PROMPT_NEWLINE )); then
      PROMPT+=$'\n'
    else
      PROMPT+=' '
    fi

    PROMPT+="$(_gauge_color prompt_char "${GAUGE_SYMBOLS[prompt_char]}") "
  fi
}
