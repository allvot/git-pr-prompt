# `zgp-legend` — print the active symbols and what they mean.
#
#   zgp-legend           the symbols this shell is actually using
#   zgp-legend --keys    also show the ZGP_SYMBOLS key to override
#   zgp-legend --codes   also show the Unicode codepoint
#   zgp-legend --all     every preset side by side
#
# Reflects the live configuration: the resolved preset, your color choices, and
# anything switched off (ZGP_SHOW_STASH=0 and friends are marked "off").

# Display width of a string, so emoji (2 cells) and glyphs (1 cell) both align.
_zgp_width() { print -r -- ${(m)#1} }

# "U+F407" for a single character, "U+1F600 U+FE0F" for a composed emoji.
_zgp_codepoints() {
  local s=$1 out="" i c
  for (( i = 1; i <= ${#s}; i++ )); do
    c=${s[i]}
    out+="U+$(printf '%04X' $(( #c ))) "
  done
  print -r -- "${out% }"
}

# One table row: symbol, meaning, optional key/codepoint columns.
# The symbol is tinted with the color it actually gets in the prompt, which is
# not always keyed by its own name (all the local flags share `flags`).
_zgp_legend_row() {
  local key=$1 meaning=$2 note=${3-}
  local sym=${ZGP_SYMBOLS[$key]-}
  [[ -n $sym ]] || return

  local color_key=$key
  case $key in
    dirty|staged|untracked|ahead|behind|stash)
      (( ZGP_FLAG_COLORS )) || color_key=flags ;;   # monochrome mode shares one
    branch_prefix) color_key=branch ;;
  esac

  local pad=$(( 4 - $(_zgp_width "$sym") ))
  (( pad < 1 )) && pad=1

  local line="  $(_zgp_color $color_key "$sym")$(printf '%*s' $pad '')"

  # Only pad the meaning column when something follows it.
  if (( _zgp_legend_keys || _zgp_legend_codes )) || [[ -n $note ]]; then
    line+=$(printf '%-30s' "$meaning")
  else
    line+=$meaning
  fi

  (( _zgp_legend_keys ))  && line+=$(printf '%-18s' "$key")
  (( _zgp_legend_codes )) && line+=$(printf '%-16s' "$(_zgp_codepoints "$sym")")

  [[ -n $note ]] && line+="%F{242}${note}%f"
  print -P -- "$line"
}

_zgp_legend_section() {
  print -P -- ""
  print -P -- "  %B${1}%b"
}

zgp-legend() {
  local -i _zgp_legend_keys=0 _zgp_legend_codes=0
  local arg
  for arg in "$@"; do
    case $arg in
      --keys)  _zgp_legend_keys=1 ;;
      --codes) _zgp_legend_codes=1 ;;
      --all)   _zgp_legend_all ; return ;;
      -h|--help)
        print -- "usage: zgp-legend [--keys] [--codes] [--all]"
        return 0 ;;
      *) print -u2 "zgp-legend: unknown option '$arg'"; return 1 ;;
    esac
  done

  local set_note="preset: ${ZGP_ACTIVE_SYMBOL_SET}"
  [[ $ZGP_SYMBOL_SET == auto ]] &&
    set_note+=" (auto — Nerd Font $( (( ZGP_HAS_NERDFONT )) && print detected || print "not found"))"
  print -P -- ""
  print -P -- "  %Bgit-pr-prompt%b  %F{242}${set_note}%f"

  # A live sample so the symbols have context.
  local sample="  $(_zgp_color path '~/repo') $(_zgp_color branch "(${ZGP_SYMBOLS[branch_prefix]}feature/x")"
  sample+=" $(_zgp_flag dirty "${ZGP_SYMBOLS[dirty]}")$(_zgp_flag staged "${ZGP_SYMBOLS[staged]}")"
  sample+=" $(_zgp_flag ahead "${ZGP_SYMBOLS[ahead]}2")"
  sample+="$(_zgp_color branch ')') $(_zgp_pr_render OPEN false APPROVED)"
  sample+=" $(_zgp_color prompt_char "${ZGP_SYMBOLS[prompt_char]}")"
  print -P -- "$sample"

  _zgp_legend_section 'Branch'
  _zgp_legend_row branch_prefix 'current branch'

  _zgp_legend_section 'Working tree'
  _zgp_legend_row dirty     'unstaged changes'
  _zgp_legend_row staged    'staged changes'
  _zgp_legend_row untracked 'untracked files' \
    "$( (( ZGP_SHOW_UNTRACKED )) || print 'off (ZGP_SHOW_UNTRACKED=0)')"
  _zgp_legend_row stash     'stash entries (count follows)' \
    "$( (( ZGP_SHOW_STASH )) || print 'off (ZGP_SHOW_STASH=0)')"

  _zgp_legend_section 'Upstream'
  _zgp_legend_row ahead  'commits ahead of upstream'
  _zgp_legend_row behind 'commits behind upstream'

  _zgp_legend_section 'Pull request'
  if (( ZGP_PR_ENABLED )); then
    _zgp_legend_row pr_open   'open'
    _zgp_legend_row pr_draft  'draft — not ready for review'
    _zgp_legend_row pr_merged 'merged'
    _zgp_legend_row pr_closed 'closed without merging'
  else
    print -P -- "  %F{242}disabled (ZGP_PR_ENABLED=0)%f"
  fi

  if (( ZGP_PR_ENABLED )); then
    _zgp_legend_section 'Review'
    _zgp_legend_row review_approved 'approved'
    _zgp_legend_row review_changes  'changes requested'
    _zgp_legend_row review_pending  'awaiting review' \
      "$( (( ZGP_SHOW_REVIEW_PENDING )) || print 'off (ZGP_SHOW_REVIEW_PENDING=0)')"
  fi

  print -P -- ""
  if (( ! _zgp_legend_keys || ! _zgp_legend_codes )); then
    print -P -- "  %F{242}more: zgp-legend --keys --codes --all%f"
  else
    print -P -- "  %F{242}Override any key before sourcing:%f"
    print -P -- "  %F{cyan}typeset -A ZGP_SYMBOLS=(pr_open \$'\\\\uf407')%f"
  fi
  print -P -- ""
}

# --all: compare every preset. Each runs in a subshell so presets stay isolated.
_zgp_legend_all() {
  # Declare every local ONCE: re-running `local x` on an existing local makes
  # zsh print "x=value", which would leak into the table.
  local preset row label sym key dump
  local -a keys=(
    'pr_open|PR open'  'pr_draft|draft'  'pr_merged|merged'  'pr_closed|closed'
    'review_approved|approved'  'review_changes|changes req'
    'review_pending|awaiting review'
    'dirty|unstaged'  'staged|staged'  'untracked|untracked'
    'ahead|ahead'  'behind|behind'  'stash|stashed'  'branch_prefix|branch'
  )

  local -a presets=(nerdfont minimal emoji github)

  # One subshell per preset (not per cell): each returns key=symbol lines.
  local -A table
  for preset in $presets; do
    dump=$(zsh -c "
      ZGP_SYMBOL_SET=$preset ZGP_PR_ENABLED=0
      source '${ZGP_ROOT}/git-pr-prompt.plugin.zsh' 2>/dev/null
      for k in \${(k)ZGP_SYMBOLS}; do print -r -- \"\$k=\${ZGP_SYMBOLS[\$k]}\"; done")
    for row in ${(f)dump}; do
      table[${preset}:${row%%=*}]=${row#*=}
    done
  done

  print -P -- ""
  printf '  %-18s' ''
  for preset in $presets; do printf '%-12s' "$preset"; done
  print -- ""

  for row in $keys; do
    key=${row%%|*} label=${row#*|}
    printf '  %-18s' "$label"
    for preset in $presets; do
      sym=${table[${preset}:${key}]}
      printf '%s' "$sym"
      printf '%*s' $(( 12 - $(_zgp_width "$sym") )) ''
    done
    print -- ""
  done

  print -P -- ""
  print -P -- "  %F{242}active: ${ZGP_ACTIVE_SYMBOL_SET}.  Switch with ZGP_SYMBOL_SET=<preset>%f"
  print -P -- ""
}
