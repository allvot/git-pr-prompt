# Prompt assembly, precmd hook and async redraw.

typeset -g ZGP_GIT_INFO=""   # rendered git segment, refreshed on every precmd

# Join the prompt's groups — branch, working-tree flags, PR state.
#
# Default is a dim separator between groups rather than parens around them: a
# delimiter's job is to mark where a group ends, and it does that better when it
# isn't the same weight as the branch name it's wrapping. `ZGP_GROUP_STYLE=parens`
# restores the bracketed form.
#
# Takes pre-colored flags/PR text; the branch is colored here.
_zgp_group_join() {
  local branch=$1 flags=${2-} pr=${3-} out sep
  flags=${flags# }        # the run leading with ↑/↓/≡ carries a leading space

  if [[ $ZGP_GROUP_STYLE == parens ]]; then
    out=" $(_zgp_color branch "(${ZGP_SYMBOLS[branch_prefix]}${branch}")"
    [[ -n $flags ]] && out+=" ${flags}"
    out+=$(_zgp_color branch ")")
    [[ -n $pr ]] && out+=" ${pr}"
  else
    sep=" $(_zgp_color separator "${ZGP_SYMBOLS[separator]}") "
    out="${sep}$(_zgp_color branch "${ZGP_SYMBOLS[branch_prefix]}${branch}")"
    [[ -n $flags ]] && out+="${sep}${flags}"
    [[ -n $pr ]]    && out+="${sep}${pr}"
  fi

  print -r -- "$out"
}

_zgp_git_segment() {
  local branch=$1
  [[ -n $branch ]] || { print -r -- ""; return }

  _zgp_group_join "$branch" "$(_zgp_local_status)" "$(_zgp_pr_status "$branch")"
}

_zgp_precmd() {
  vcs_info
  ZGP_GIT_INFO=$(_zgp_git_segment "$vcs_info_msg_0_")
  _zgp_title "$vcs_info_msg_0_"
}

# Clear the screen, drop the scrollback, and redraw the WHOLE prompt.
#
# The terminal's own clear (⌘K) can't do that last part: it keeps the cursor's
# row and knows nothing about the status line above it. zsh's clear-screen
# reprints every prompt line, so doing it shell-side keeps the context visible —
# and the \e[3J makes it discard scrollback like ⌘K does.
zgp-clear-screen() {
  print -n -- $'\e[3J'
  zle clear-screen
}

# Redraw the prompt when a background PR query finishes.
_zgp_usr1() {
  (( ZGP_ASYNC_REDRAW )) || return 0
  ZGP_GIT_INFO=$(_zgp_git_segment "$vcs_info_msg_0_")
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
_zgp_user_segment() {
  local remote="" who='%n'
  [[ -n ${SSH_CONNECTION-}${SSH_TTY-} ]] && { remote=1; who='%n@%m' }

  case $ZGP_SHOW_USER in
    0) return ;;
    1) ;;
    *) [[ -n $remote ]] || (( EUID == 0 )) || return ;;
  esac

  local key=user
  (( EUID == 0 )) && key=user_root
  print -r -- "$(_zgp_color $key "$who") "
}

_zgp_setup() {
  setopt prompt_subst

  autoload -Uz vcs_info add-zsh-hook
  zstyle ':vcs_info:*'     enable git
  zstyle ':vcs_info:git:*' formats       '%b'
  zstyle ':vcs_info:git:*' actionformats '%b|%a'

  add-zsh-hook precmd _zgp_precmd

  # Take over ^L only while it still runs the stock widget — if it's bound to
  # anything else, that's the user's choice.
  if (( ZGP_BIND_CLEAR )) && [[ $(bindkey '^L') == *' clear-screen' ]]; then
    zle -N zgp-clear-screen
    bindkey '^L' zgp-clear-screen
  fi

  # Don't stomp on an existing SIGUSR1 handler.
  if (( ZGP_ASYNC_REDRAW )) && ! (( $+functions[TRAPUSR1] )); then
    TRAPUSR1() { _zgp_usr1 }
  fi

  if (( ZGP_SET_PROMPT )); then
    PROMPT="$(_zgp_user_segment)$(_zgp_color path '%~')"
    PROMPT+='${ZGP_GIT_INFO}'

    # Status on one line, the cursor on the next. Keeps the input at a fixed
    # column no matter how deep the path or how long the branch name, so
    # commands don't wrap in unpredictable places.
    if (( ZGP_PROMPT_NEWLINE )); then
      PROMPT+=$'\n'
    else
      PROMPT+=' '
    fi

    PROMPT+="$(_zgp_color prompt_char "${ZGP_SYMBOLS[prompt_char]}") "
  fi
}
