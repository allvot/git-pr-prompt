# Asynchronous GitHub pull-request status for the current branch.
#
# The prompt never blocks on the network: `_zgp_pr_status` prints whatever is in
# the cache and kicks off a background `gh` query when the entry is stale. When
# the fresh answer lands, the background job signals the shell (SIGUSR1) so the
# prompt redraws itself.

zmodload -F zsh/datetime p:EPOCHSECONDS 2>/dev/null
zmodload -F zsh/stat b:zstat 2>/dev/null

# Absolute path of the cache entry for <branch> in the current repo.
_zgp_cache_file() {
  local branch=$1 root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  local key="${root//[^A-Za-z0-9]/_}--${branch//[^A-Za-z0-9._-]/_}"
  print -r -- "$ZGP_PR_CACHE_DIR/${key: -180}"
}

# Seconds since <file> was last written, or a large number if unknown.
_zgp_age() {
  local -a mt
  zstat -A mt +mtime -- "$1" 2>/dev/null || { print -r -- 999999; return }
  print -r -- $(( EPOCHSECONDS - mt[1] ))
}

# Render a `gh pr view` result (state, isDraft, reviewDecision) as prompt text.
_zgp_pr_render() {
  local state=$1 draft=$2 review=$3 out=""

  if [[ $draft == true ]]; then
    out="%F{${ZGP_COLORS[pr_draft]}}${ZGP_SYMBOLS[pr_draft]}%f"
  else
    case $state in
      MERGED) out="%F{${ZGP_COLORS[pr_merged]}}${ZGP_SYMBOLS[pr_merged]}%f" ;;
      CLOSED) out="%F{${ZGP_COLORS[pr_closed]}}${ZGP_SYMBOLS[pr_closed]}%f" ;;
      OPEN)   out="%F{${ZGP_COLORS[pr_open]}}${ZGP_SYMBOLS[pr_open]}%f" ;;
    esac
  fi

  case $review in
    APPROVED)          out+=" %F{${ZGP_COLORS[review_approved]}}${ZGP_SYMBOLS[review_approved]}%f" ;;
    CHANGES_REQUESTED) out+=" %F{${ZGP_COLORS[review_changes]}}${ZGP_SYMBOLS[review_changes]}%f" ;;
  esac

  print -r -- "$out"
}

# Refresh the cache entry for <branch> in the background, unless it is fresh.
_zgp_pr_refresh() {
  local branch=$1 cache_file=$2
  local shell_pid=$$

  if [[ -f $cache_file ]] && (( $(_zgp_age "$cache_file") < ZGP_PR_CACHE_TTL )); then
    return
  fi

  # Touch the entry first so concurrent prompts don't all spawn the same query.
  mkdir -p "$ZGP_PR_CACHE_DIR" 2>/dev/null
  command touch "$cache_file" 2>/dev/null

  (
    local fields rendered="" tmp="$cache_file.$RANDOM"
    fields=$(gh pr view "$branch" \
      --json state,isDraft,reviewDecision \
      --jq '[.state, (.isDraft | tostring), (.reviewDecision // "")] | @tsv' 2>/dev/null)

    if [[ -n $fields ]]; then
      local -a f=(${(@s:	:)fields})
      rendered=$(_zgp_pr_render "$f[1]" "$f[2]" "$f[3]")
    fi

    # Write atomically so a half-written entry is never read by the prompt.
    print -r -- "$rendered" > "$tmp" 2>/dev/null && mv -f "$tmp" "$cache_file" 2>/dev/null

    (( ZGP_ASYNC_REDRAW )) && [[ -n $rendered ]] && kill -USR1 "$shell_pid" 2>/dev/null
  ) &>/dev/null &!
}

# Prompt fragment for the current branch's PR, from cache (never blocks).
_zgp_pr_status() {
  local branch=$1
  (( ZGP_PR_ENABLED )) || return
  [[ -n $branch ]] || return
  (( ${ZGP_SKIP_BRANCHES[(Ie)$branch]} )) && return
  (( $+commands[gh] )) || return

  local cache_file
  cache_file=$(_zgp_cache_file "$branch") || return

  _zgp_pr_refresh "$branch" "$cache_file"

  [[ -f $cache_file ]] && print -r -- "$(<$cache_file)"
}

# Drop every cached PR answer (handy after opening or merging a PR).
zgp-pr-cache-clear() {
  [[ -n $ZGP_PR_CACHE_DIR ]] && rm -rf -- "$ZGP_PR_CACHE_DIR"
  print "git-pr-prompt: PR cache cleared"
}
