# `gauge-legend` — print the active symbols and what they mean.
#
#   gauge-legend           the symbols this shell is actually using
#   gauge-legend --keys    also show the GAUGE_SYMBOLS key to override
#   gauge-legend --codes   also show the Unicode codepoint
#   gauge-legend --all     every preset side by side
#
# Reflects the live configuration: the resolved preset, your color choices, and
# anything switched off (GAUGE_SHOW_STASH=0 and friends are marked "off").

# Display width of a string, so emoji (2 cells) and glyphs (1 cell) both align.
_gauge_width() { print -r -- ${(m)#1} }

# "U+F407" for a single character, "U+1F600 U+FE0F" for a composed emoji.
_gauge_codepoints() {
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
_gauge_legend_row() {
  local key=$1 meaning=$2 note=${3-}
  local sym=${GAUGE_SYMBOLS[$key]-}
  [[ -n $sym ]] || return

  local color_key=$key
  case $key in
    dirty|staged|untracked|ahead|behind|stash)
      (( GAUGE_FLAG_COLORS )) || color_key=flags ;;   # monochrome mode shares one
    branch_prefix) color_key=branch ;;
  esac

  local pad=$(( 4 - $(_gauge_width "$sym") ))
  (( pad < 1 )) && pad=1

  local line="  $(_gauge_color $color_key "$sym")$(printf '%*s' $pad '')"

  # Only pad the meaning column when something follows it.
  if (( _gauge_legend_keys || _gauge_legend_codes )) || [[ -n $note ]]; then
    line+=$(printf '%-30s' "$meaning")
  else
    line+=$meaning
  fi

  (( _gauge_legend_keys ))  && line+=$(printf '%-18s' "$key")
  (( _gauge_legend_codes )) && line+=$(printf '%-16s' "$(_gauge_codepoints "$sym")")

  [[ -n $note ]] && line+="%F{242}${note}%f"
  print -P -- "$line"
}

_gauge_legend_section() {
  print -P -- ""
  print -P -- "  %B${1}%b"
}

gauge-legend() {
  local -i _gauge_legend_keys=0 _gauge_legend_codes=0
  local arg
  for arg in "$@"; do
    case $arg in
      --keys)  _gauge_legend_keys=1 ;;
      --codes) _gauge_legend_codes=1 ;;
      --all)   _gauge_legend_all ; return ;;
      -h|--help)
        print -- "usage: gauge-legend [--keys] [--codes] [--all]"
        return 0 ;;
      *) print -u2 "gauge-legend: unknown option '$arg'"; return 1 ;;
    esac
  done

  local set_note="preset: ${GAUGE_ACTIVE_SYMBOL_SET}"
  [[ $GAUGE_SYMBOL_SET == auto ]] &&
    set_note+=" (auto — Nerd Font $( (( GAUGE_HAS_NERDFONT )) && print detected || print "not found"))"
  set_note+="   theme: ${GAUGE_ACTIVE_THEME}"
  print -P -- ""
  print -P -- "  %Bgauge%b  %F{242}${set_note}%f"

  # A live sample so the symbols have context.
  # Built with the real joiner, so the sample can't drift from the prompt.
  local sample_flags="$(_gauge_flag dirty "${GAUGE_SYMBOLS[dirty]}")$(_gauge_flag staged "${GAUGE_SYMBOLS[staged]}")"
  sample_flags+=" $(_gauge_flag ahead "${GAUGE_SYMBOLS[ahead]}2")"

  local sample="  $(_gauge_color path '~/repo')"
  sample+=$(_gauge_group_join 'feature/x' "$sample_flags" "$(_gauge_pr_render OPEN false APPROVED)")
  sample+=" $(_gauge_color prompt_char "${GAUGE_SYMBOLS[prompt_char]}")"
  print -P -- "$sample"

  _gauge_legend_section 'Branch'
  _gauge_legend_row branch_prefix 'current branch'

  _gauge_legend_section 'Working tree'
  _gauge_legend_row dirty     'unstaged changes'
  _gauge_legend_row staged    'staged changes'
  _gauge_legend_row untracked 'untracked files' \
    "$( (( GAUGE_SHOW_UNTRACKED )) || print 'off (GAUGE_SHOW_UNTRACKED=0)')"
  _gauge_legend_row stash     'stash entries (count follows)' \
    "$( (( GAUGE_SHOW_STASH )) || print 'off (GAUGE_SHOW_STASH=0)')"

  _gauge_legend_section 'Upstream'
  _gauge_legend_row ahead  'commits ahead of upstream'
  _gauge_legend_row behind 'commits behind upstream'

  _gauge_legend_section 'Pull request'
  if (( GAUGE_PR_ENABLED )); then
    _gauge_legend_row pr_open   'open'
    _gauge_legend_row pr_draft  'draft — not ready for review'
    _gauge_legend_row pr_merged 'merged'
    _gauge_legend_row pr_closed 'closed without merging'
  else
    print -P -- "  %F{242}disabled (GAUGE_PR_ENABLED=0)%f"
  fi

  if (( GAUGE_PR_ENABLED )); then
    _gauge_legend_section 'Review'
    _gauge_legend_row review_approved 'approved'
    _gauge_legend_row review_changes  'changes requested'
    _gauge_legend_row review_pending  'awaiting review' \
      "$( (( GAUGE_SHOW_REVIEW_PENDING )) || print 'off (GAUGE_SHOW_REVIEW_PENDING=0)')"
  fi

  print -P -- ""
  if (( ! _gauge_legend_keys || ! _gauge_legend_codes )); then
    print -P -- "  %F{242}more: gauge-legend --keys --codes --all%f"
  else
    print -P -- "  %F{242}Override any key before sourcing:%f"
    print -P -- "  %F{cyan}typeset -A GAUGE_SYMBOLS=(pr_open \$'\\\\uf407')%f"
  fi
  print -P -- ""
}

# --all: compare every preset. Each runs in a subshell so presets stay isolated.
_gauge_legend_all() {
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
      GAUGE_SYMBOL_SET=$preset GAUGE_PR_ENABLED=0
      source '${GAUGE_ROOT}/gauge.plugin.zsh' 2>/dev/null
      for k in \${(k)GAUGE_SYMBOLS}; do print -r -- \"\$k=\${GAUGE_SYMBOLS[\$k]}\"; done")
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
      printf '%*s' $(( 12 - $(_gauge_width "$sym") )) ''
    done
    print -- ""
  done

  print -P -- ""
  print -P -- "  %F{242}active: ${GAUGE_ACTIVE_SYMBOL_SET}.  Switch with GAUGE_SYMBOL_SET=<preset>%f"
  print -P -- ""
}
