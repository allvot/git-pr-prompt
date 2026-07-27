# Prompt assembly, precmd hook and async redraw.

typeset -g ZGP_GIT_INFO=""   # rendered git segment, refreshed on every precmd

# Build the git segment: "(branch flags) pr-icons"
_zgp_git_segment() {
  local branch=$1
  [[ -n $branch ]] || { print -r -- ""; return }

  local flags pr out
  flags=$(_zgp_local_status)
  pr=$(_zgp_pr_status "$branch")

  out=" %F{${ZGP_COLORS[branch]}}(${branch}%f"
  [[ -n $flags ]] && out+="%F{${ZGP_COLORS[flags]}} ${flags}%f"
  out+="%F{${ZGP_COLORS[branch]}})%f"
  [[ -n $pr ]] && out+=" ${pr}"

  print -r -- "$out"
}

_zgp_precmd() {
  vcs_info
  ZGP_GIT_INFO=$(_zgp_git_segment "$vcs_info_msg_0_")
}

# Redraw the prompt when a background PR query finishes.
_zgp_usr1() {
  (( ZGP_ASYNC_REDRAW )) || return 0
  ZGP_GIT_INFO=$(_zgp_git_segment "$vcs_info_msg_0_")
  zle && zle reset-prompt
}

_zgp_setup() {
  setopt prompt_subst

  autoload -Uz vcs_info add-zsh-hook
  zstyle ':vcs_info:*'     enable git
  zstyle ':vcs_info:git:*' formats       '%b'
  zstyle ':vcs_info:git:*' actionformats '%b|%a'

  add-zsh-hook precmd _zgp_precmd

  # Don't stomp on an existing SIGUSR1 handler.
  if (( ZGP_ASYNC_REDRAW )) && ! (( $+functions[TRAPUSR1] )); then
    TRAPUSR1() { _zgp_usr1 }
  fi

  if (( ZGP_SET_PROMPT )); then
    PROMPT='%F{'${ZGP_COLORS[user]}'}%n%f %F{'${ZGP_COLORS[path]}'}%~%f${ZGP_GIT_INFO} %F{'${ZGP_COLORS[prompt_char]}'}❯%f '
  fi
}
