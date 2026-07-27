#!/usr/bin/env zsh
# Browse candidate Nerd Font glyphs for the prompt.
#
#   zsh tools/glyphs.zsh                 # all git/PR-related glyphs, by family
#   zsh tools/glyphs.zsh pull_request    # only names matching a pattern
#   zsh tools/glyphs.zsh --families      # list the icon families
#
# Data is bundled in data/glyph-catalog.tsv (generated from the Nerd Fonts
# glyphnames.json index), so this works offline. Every glyph needs a patched
# font to render — if you see boxes, run `zgp-font-check`.

_ZGP_GLYPHS_ROOT="${0:A:h:h}"   # captured at file scope; $0 is the script path

# Which codepoint the nerdfont preset uses for each prompt symbol — powers the
# "→ used by this prompt as …" line in `--what`.
typeset -gA _ZGP_USED_BY=(
  pr_open          F407    pr_draft         F4DD
  pr_merged        F419    pr_closed        F4DC
  review_approved  F4A4    review_changes   F52F
  review_pending   F441
  dirty            F448    staged           F44D
  untracked        F420    ahead            F431
  behind           F433    stash            F51E
  branch_prefix    F418
)

_zgp_glyphs_main() {
  local catalog="$_ZGP_GLYPHS_ROOT/data/glyph-catalog.tsv"
  [[ -r $catalog ]] || { print -u2 "missing $catalog"; return 1 }

  local -A family=(
    oct "Octicons — GitHub's own icon set (best match for PR states)"
    cod "Codicons — VS Code's set (explicit draft / closed PR icons)"
    fa  "Font Awesome"
    dev "Devicons"
    md  "Material Design Icons"
  )
  local -a order=(oct cod fa dev md)

  if [[ $1 == --families ]]; then
    local f
    for f in $order; do printf '  %-4s %s\n' "$f" "${family[$f]}"; done
    return 0
  fi

  # Reverse lookup: which glyph is this? `--what ` or `--what f407`
  if [[ $1 == (--what|--whatis) ]]; then
    local want=$2
    [[ -n $want ]] || { print -u2 "usage: glyphs.zsh --what <character-or-codepoint>"; return 1 }

    # Accept a raw character, "f407", "U+F407" or "".
    local code
    if (( ${#want} == 1 )); then
      code=$(printf '%X' $(( #want )))
    else
      code=${${${want:u}#U+}#\\U}
    fi

    local hit=0 row
    for row in ${(f)"$(< $catalog)"}; do
      [[ ${${row#*$'\t'}%%$'\t'*} == "U+${code}" ]] || continue
      local -a fields=("${(@s:	:)row}")
      print -P -- "  %B${fields[3]}%b  U+${code}  ${fields[1]}"
      hit=1
    done

    if (( ! hit )); then
      print -P -- "  U+${code} — not in the catalog."
      print -P -- "  Full index: %F{cyan}https://www.nerdfonts.com/cheat-sheet%f"
      return 1
    fi

    # Is it one the prompt actually uses?
    local k
    for k in ${(k)_ZGP_USED_BY}; do
      [[ ${_ZGP_USED_BY[$k]} == "$code" ]] &&
        print -P -- "  → used by this prompt as %B${k}%b"
    done
    return 0
  fi

  local filter=${1:-}
  local -a keys=(
    pr_open pr_draft pr_merged pr_closed
    review_approved review_changes review_pending
    dirty staged untracked ahead behind stash branch_prefix prompt_char
  )

  local -a lines=(${(f)"$(< $catalog)"})
  local fam row name shown=0
  local -a matched fields

  for fam in $order; do
    matched=()
    for row in $lines; do
      name=${row%%$'\t'*}
      [[ $name == ${fam}-* ]] || continue
      [[ -n $filter && $name != *${~filter}* ]] && continue
      matched+=$row
    done
    (( $#matched )) || continue

    print -P -- ""
    print -P -- "%B── ${family[$fam]}%b"
    for row in $matched; do
      fields=("${(@s:	:)row}")
      printf '  %s   %-8s  %s\n' "${fields[3]}" "${fields[2]}" "${fields[1]}"
      (( shown++ ))
    done
  done

  if (( shown == 0 )); then
    print -P -- "No glyphs matched '%B${filter}%b'. Try: pull_request, merge, review, check, eye"
    return 1
  fi

  print -P -- ""
  print -P -- "%B${shown} glyphs.%b Override any prompt symbol in ~/.zshrc, before sourcing:"
  print -P -- "  %F{cyan}typeset -A ZGP_SYMBOLS=(pr_open \$'\\\\uf407' pr_merged \$'\\\\uf419')%f"
  print -P -- ""
  print -P -- "Keys: %F{242}${keys}%f"
}

_zgp_glyphs_main "$@"
