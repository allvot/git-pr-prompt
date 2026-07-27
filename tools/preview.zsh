#!/usr/bin/env zsh
# Render every symbol preset as it will look in YOUR terminal and font.
# Nothing is installed or changed. Run: zsh tools/preview.zsh
#
# Internally re-execs itself once per preset (`zsh tools/preview.zsh <preset>`)
# so each preset is loaded in a clean shell and can't bleed into the next.

ROOT="${0:A:h:h}"
SELF="${0:A}"

# --- child mode: print the sample rows for one preset -----------------------

if (( $# )); then
  GAUGE_SYMBOL_SET=$1
  GAUGE_PR_ENABLED=0
  GAUGE_SET_PROMPT=0
  source "$ROOT/gauge.plugin.zsh"

  # state | isDraft | reviewDecision | description
  local -a rows=(
    'OPEN|false|"|no review yet'
    'OPEN|false|REVIEW_REQUIRED|waiting on review'
    'OPEN|false|APPROVED|approved'
    'OPEN|false|CHANGES_REQUESTED|changes requested'
    'OPEN|true|"|draft'
    'MERGED|false|"|merged'
    'CLOSED|false|"|closed without merging'
  )

  local row icon line
  local -a f
  for row in $rows; do
    f=("${(@s:|:)row}")
    [[ $f[3] == '"' ]] && f[3]=''
    icon=$(_gauge_pr_render "$f[1]" "$f[2]" "$f[3]")

    line="  $(_gauge_color path '~/code/underwriting')"
    line+="$(_gauge_color branch "(${GAUGE_SYMBOLS[branch_prefix]}PRE-1470")"
    line+="$(_gauge_color flags ' *+? ↑2 ≡1')"
    line+="$(_gauge_color branch ')')"
    line+=" ${icon} $(_gauge_color prompt_char "${GAUGE_SYMBOLS[prompt_char]}")"
    print -P -- "${line}   %F{242}${f[4]}%f"
  done

  print -P -- "  %F{242}local flags:%f $(_gauge_color flags "${GAUGE_SYMBOLS[dirty]} modified  ${GAUGE_SYMBOLS[staged]} staged  ${GAUGE_SYMBOLS[untracked]} untracked  ${GAUGE_SYMBOLS[ahead]}2 ahead  ${GAUGE_SYMBOLS[behind]}1 behind  ${GAUGE_SYMBOLS[stash]}3 stashed")"
  return 0
fi

# --- parent mode: loop the presets -----------------------------------------

for preset in nerdfont minimal emoji github; do
  print -P -- ""
  print -P -- "%B─── ${preset} ${(l:56::─:)}%b"
  zsh "$SELF" "$preset"
done

print -P -- ""
print -P -- "The default is %Bauto%b: nerdfont if a patched font is detected, else minimal."
print -P -- "Force one in ~/.zshrc %Bbefore%b sourcing the plugin:"
print -P -- "  %F{cyan}GAUGE_SYMBOL_SET=nerdfont%f   # or minimal / emoji / github / auto"
print -P -- ""
print -P -- "If the %Bnerdfont%b rows show boxes (□) or blanks, install a patched font:"
print -P -- "  %F{cyan}brew install --cask font-jetbrains-mono-nerd-font%f"
print -P -- "then set it as your terminal font and run %F{cyan}gauge-font-check%f."
print -P -- ""
