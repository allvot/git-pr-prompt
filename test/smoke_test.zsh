#!/usr/bin/env zsh
# Smoke test: load the plugin in a scratch repo and assert the segments render.
# Read-only with respect to your environment — it works in a temp dir and never
# touches ~/.zshrc. Run: zsh test/smoke_test.zsh

set -u
ROOT="${0:A:h:h}"
FAILED=0

check() {
  local desc=$1 expected=$2 actual=$3
  if [[ $actual == *$expected* ]]; then
    print -- "  ok   $desc"
  else
    print -- "  FAIL $desc"
    print -- "       expected to contain: $expected"
    print -- "       got:                 $actual"
    FAILED=1
  fi
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

GAUGE_SYMBOL_SET=minimal                 # deterministic symbols for assertions
GAUGE_PR_ENABLED=0                       # keep the network out of the test
GAUGE_TITLE=0                            # don't spray OSC escapes over the output
GAUGE_PR_CACHE_DIR="$tmp/cache"
source "$ROOT/gauge.plugin.zsh"

print -- "plugin loads"
check "PROMPT is set"        'GAUGE_GIT_INFO'      "$PROMPT"
check "precmd hook added"    '_gauge_precmd'       "${precmd_functions[*]-}"
check "symbols populated"    '*'                 "${GAUGE_SYMBOLS[dirty]}"

cd "$tmp"
git init -q repo
cd repo
git config user.email t@example.com
git config user.name  Test
print -- "hello" > a.txt

print -- "\nuntracked file"
_gauge_precmd
check "shows ? flag" '?' "$GAUGE_GIT_INFO"

git add a.txt
print -- "\nstaged file"
_gauge_precmd
check "shows + flag" '+' "$GAUGE_GIT_INFO"

git commit -qm init
print -- "world" >> a.txt
print -- "\nmodified tracked file"
_gauge_precmd
check "shows * flag" '*' "$GAUGE_GIT_INFO"

git stash -q
print -- "\nstash entry"
_gauge_precmd
check "shows stash count" '≡1' "$GAUGE_GIT_INFO"

print -- "\nbranch name"
git checkout -qb feature/thing
_gauge_precmd
check "shows branch" 'feature/thing' "$GAUGE_GIT_INFO"

print -- "\noutside a repo"
cd "$tmp"
_gauge_precmd
check "segment is empty" '' "$GAUGE_GIT_INFO"
[[ -z $GAUGE_GIT_INFO ]] || { print -- "  FAIL expected empty segment, got: $GAUGE_GIT_INFO"; FAILED=1 }

print -- "\nPR rendering, geometric fallback (no network)"
check "open"            '⊙' "$(_gauge_pr_render OPEN false '')"
check "approved"        '✓' "$(_gauge_pr_render OPEN false APPROVED)"
check "changes req"     '✗' "$(_gauge_pr_render OPEN false CHANGES_REQUESTED)"
check "review pending"  '·' "$(_gauge_pr_render OPEN false REVIEW_REQUIRED)"
check "draft"           '◌' "$(_gauge_pr_render OPEN true '')"
check "merged"          '⊕' "$(_gauge_pr_render MERGED false '')"
check "closed"          '⊘' "$(_gauge_pr_render CLOSED false '')"

# REVIEW_REQUIRED is meaningless on a draft or a closed PR.
[[ $(_gauge_pr_render OPEN true REVIEW_REQUIRED) == *'·'* ]] &&
  { print -- "  FAIL draft should not show the review-pending icon"; FAILED=1 } ||
  print -- "  ok   draft hides review-pending icon"

print -- "\ngroup separators"
# Groups are delimited by a dim separator rather than parens, so the delimiters
# don't compete with the branch name they surround.
cd "$tmp/repo"
_gauge_precmd
check "uses a dim separator" $'%F{242}│' "$GAUGE_GIT_INFO"
[[ $GAUGE_GIT_INFO == *'('* || $GAUGE_GIT_INFO == *')'* ]] &&
  { print -- "  FAIL separator style still emitted parens"; FAILED=1 } ||
  print -- "  ok   no parens in separator style"
# One separator before the branch, one before the flag run (stash, here).
seps=( ${(s:│:)GAUGE_GIT_INFO} )
check "one separator per group" '3' "$#seps"   # 2 separators -> 3 fields

out=$(zsh -c "cd '$tmp/repo'
  GAUGE_GROUP_STYLE=parens GAUGE_PR_ENABLED=0 GAUGE_SYMBOL_SET=minimal GAUGE_TITLE=0
  source '$ROOT/gauge.plugin.zsh'
  _gauge_precmd; print -r -- \"\$GAUGE_GIT_INFO\"")
check "parens style still available" '(feature/thing' "$out"
check "parens style closes"          ')'              "$out"
[[ $out == *'│'* ]] &&
  { print -- "  FAIL parens style leaked a separator"; FAILED=1 } ||
  print -- "  ok   parens style emits no separator"

out=$(zsh -c "cd '$tmp/repo'
  typeset -A GAUGE_SYMBOLS=(separator '@')
  GAUGE_PR_ENABLED=0 GAUGE_SYMBOL_SET=minimal GAUGE_TITLE=0
  source '$ROOT/gauge.plugin.zsh'
  _gauge_precmd; print -r -- \"\$GAUGE_GIT_INFO\"")
check "separator is overridable" '@' "$out"

out=$(zsh -c "cd '$tmp'
  GAUGE_PR_ENABLED=0 GAUGE_SYMBOL_SET=minimal GAUGE_TITLE=0
  source '$ROOT/gauge.plugin.zsh'
  _gauge_precmd; print -r -- \"[\$GAUGE_GIT_INFO]\"")
check "no stray separator outside a repo" '[]' "$out"

out=$(zsh -c "GAUGE_PR_ENABLED=1 GAUGE_SYMBOL_SET=minimal GAUGE_TITLE=0
  source '$ROOT/gauge.plugin.zsh'
  gauge-legend" 2>&1)
check "legend sample follows the style" '│' "$out"

print -- "\nper-flag colors"
# `*+? ↑2 ≡1` in one color has to be read; colored per meaning it can be
# recognised without reading. Colors stay as literal %F{...} here — PROMPT
# expands them later.
cd "$tmp"
git init -q colors
cd colors
git config user.email t@example.com
git config user.name  Test
print -- one > tracked.txt
git add tracked.txt
git commit -qm init
print -- two >> tracked.txt      # unstaged change
print -- new > staged.txt
git add staged.txt               # staged change
print -- loose > loose.txt       # untracked

_gauge_precmd
check "unstaged is yellow"  '%F{yellow}*'  "$GAUGE_GIT_INFO"
check "staged is green"     '%F{green}+'   "$GAUGE_GIT_INFO"
check "untracked is red"    '%F{red}?'     "$GAUGE_GIT_INFO"

# Upstream and stash flags never coexist with the above in one fixture, so test
# the shared helper they all go through.
check "ahead is cyan"       '%F{cyan}↑2'   "$(_gauge_flag ahead '↑2')"
check "behind is cyan"      '%F{cyan}↓1'   "$(_gauge_flag behind '↓1')"
check "stash is dim"        '%F{242}≡1'    "$(_gauge_flag stash '≡1')"

out=$(zsh -c "cd '$tmp/colors'
  GAUGE_FLAG_COLORS=0 GAUGE_PR_ENABLED=0 GAUGE_SYMBOL_SET=minimal GAUGE_TITLE=0
  source '$ROOT/gauge.plugin.zsh'
  print -r -- \"\$(_gauge_local_status)\"")
check "=0 uses one color for all"  '%F{yellow}*+?'  "$out"
[[ $out == *'%F{green}'* || $out == *'%F{red}'* ]] &&
  { print -- "  FAIL GAUGE_FLAG_COLORS=0 still colored flags individually"; FAILED=1 } ||
  print -- "  ok   =0 emits no per-flag colors"

# The legend must agree with the prompt, so it can't hardcode the `flags` color.
legend_flags() {   # raw, not cat -v: that would mangle the multibyte symbols
  zsh -c "$* GAUGE_PR_ENABLED=1 GAUGE_SYMBOL_SET=minimal GAUGE_TITLE=0
    source '$ROOT/gauge.plugin.zsh'
    gauge-legend --keys" 2>&1
}
out=$(legend_flags)
check "legend still lists the flags" 'untracked'          "$out"
check "legend tints untracked red"   $'\e[31m?'            "$out"
check "legend dims the stash"        $'\e[38;5;242m≡'      "$out"

out=$(legend_flags GAUGE_FLAG_COLORS=0)
check "=0 legend falls back to yellow" $'\e[33m?' "$out"
[[ $out == *$'\e[31m?'* ]] &&
  { print -- "  FAIL legend showed per-flag colors with GAUGE_FLAG_COLORS=0"; FAILED=1 } ||
  print -- "  ok   =0 legend matches the monochrome prompt"

print -- "\nterminal title carries the repo context"
# ⌘K in Tabby and Ghostty keeps only the cursor row, so a two-line prompt loses
# its status line. The title survives every kind of clear.
title_in() {   # title_in <dir> [env assignments...]
  local dir=$1; shift
  zsh -c "cd '$dir'
    $* GAUGE_PR_ENABLED=0 GAUGE_SYMBOL_SET=minimal
    source '$ROOT/gauge.plugin.zsh'
    _gauge_precmd" | cat -v
}

out=$(title_in "$tmp/repo")
check "sets an OSC 0 title"      '^[]0;'          "$out"
check "names the repo"           'repo'           "$out"
check "names the branch"         'feature/thing'  "$out"
check "terminated with BEL"      '^G'             "$out"

out=$(title_in "$tmp")
check "outside a repo, shows the path" '/'  "$out"
[[ $out == *'feature/thing'* ]] &&
  { print -- "  FAIL leaked a branch name outside the repo"; FAILED=1 } ||
  print -- "  ok   no branch name outside a repo"

out=$(title_in "$tmp/repo" "GAUGE_TITLE=0")
[[ $out == *']0;'* ]] &&
  { print -- "  FAIL GAUGE_TITLE=0 still wrote a title"; FAILED=1 } ||
  print -- "  ok   GAUGE_TITLE=0 writes nothing"

print -- "\nclear-screen redraws the whole prompt"
# zsh's own clear-screen reprints every prompt line; ⌘K can't. Binding ^L to a
# widget that ALSO drops scrollback makes a shell-side ⌘K equivalent.
bound() {   # bound [env assignments...] -> what ^L runs
  zsh -f -ic "$* GAUGE_PR_ENABLED=0 GAUGE_TITLE=0
    source '$ROOT/gauge.plugin.zsh'
    bindkey '^L'" 2>&1
}

check "^L runs the widget"      'gauge-clear-screen' "$(bound)"
check "opt out leaves ^L alone" 'clear-screen'     "$(bound GAUGE_BIND_CLEAR=0)"
out=$(bound GAUGE_BIND_CLEAR=0)
[[ $out == *'gauge-clear-screen'* ]] &&
  { print -- "  FAIL GAUGE_BIND_CLEAR=0 still rebound ^L"; FAILED=1 } ||
  print -- "  ok   GAUGE_BIND_CLEAR=0 does not rebind"

# Never stomp a binding the user set themselves.
out=$(zsh -f -ic "GAUGE_PR_ENABLED=0 GAUGE_TITLE=0
  zle -N my-clear() { }
  bindkey '^L' undefined-key
  source '$ROOT/gauge.plugin.zsh'
  bindkey '^L'" 2>&1)
[[ $out == *'gauge-clear-screen'* ]] &&
  { print -- "  FAIL overwrote a user's own ^L binding"; FAILED=1 } ||
  print -- "  ok   leaves a customised ^L binding alone"

print -- "\nuser@host only when it tells you something"
# Your own name on your own laptop is noise. It becomes information over SSH
# (which box?) or as root (am I about to do damage?).
prompt_with() {   # prompt_with <env assignments...>
  zsh -c "unset SSH_TTY SSH_CONNECTION
    $* GAUGE_PR_ENABLED=0 GAUGE_SYMBOL_SET=minimal
    source '$ROOT/gauge.plugin.zsh'
    print -r -- \"\$PROMPT\""
}

out=$(prompt_with)
[[ $out == *'%n'* ]] &&
  { print -- "  FAIL local shell should not show the user: $out"; FAILED=1 } ||
  print -- "  ok   hidden in a local shell"
check "path is still there" '%~' "$out"

out=$(prompt_with "SSH_TTY=/dev/ttys001")
check "SSH shows user and host" '%n@%m' "$out"

out=$(prompt_with "SSH_CONNECTION='10.0.0.1 22 10.0.0.2 22'")
check "SSH_CONNECTION alone is enough" '%n@%m' "$out"

out=$(prompt_with "GAUGE_SHOW_USER=1")
check "=1 forces it on locally" '%n' "$out"
[[ $out == *'%n@%m'* ]] &&
  { print -- "  FAIL local shell should not append the hostname"; FAILED=1 } ||
  print -- "  ok   =1 shows the user without the hostname"

out=$(prompt_with "SSH_TTY=/dev/ttys001 GAUGE_SHOW_USER=0")
[[ $out == *'%n'* ]] &&
  { print -- "  FAIL =0 should win even over SSH: $out"; FAILED=1 } ||
  print -- "  ok   =0 wins even over SSH"

print -- "\ntwo-line prompt"
# The cursor should sit at a fixed column on its own line, so long paths and
# branch names never push the input right or wrap it unpredictably.
out=$(zsh -c "GAUGE_PR_ENABLED=0 GAUGE_SYMBOL_SET=minimal
  source '$ROOT/gauge.plugin.zsh'
  print -r -- \"\$PROMPT\"")
lines=( ${(f)out} )
check "default is two lines"          '2'          "$#lines"
check "git segment on the first line" 'GAUGE_GIT_INFO' "${lines[1]}"
check "prompt char starts line two"   '❯'          "${lines[2]}"
[[ ${lines[1]} == *' ' ]] &&
  { print -- "  FAIL trailing space before the newline"; FAILED=1 } ||
  print -- "  ok   no trailing space before the newline"
# Line two carries the prompt char and nothing else — no path, no git segment.
# (Colors are still raw %F{...} escapes here; PROMPT isn't expanded by print.)
[[ ${lines[2]} == *'❯'*' ' && ${lines[2]} != *('%~'|GAUGE_GIT_INFO)* ]] &&
  print -- "  ok   line two is just the prompt char" ||
  { print -- "  FAIL line two has more than the prompt char: ${lines[2]}"; FAILED=1 }

out=$(zsh -c "GAUGE_PR_ENABLED=0 GAUGE_SYMBOL_SET=minimal GAUGE_PROMPT_NEWLINE=0
  source '$ROOT/gauge.plugin.zsh'
  print -r -- \"\$PROMPT\"")
lines=( ${(f)out} )
check "GAUGE_PROMPT_NEWLINE=0 is one line" '1' "$#lines"
check "still has the git segment"        'GAUGE_GIT_INFO' "$out"
check "still has the prompt char"        '❯'            "$out"
[[ $out == *'GAUGE_GIT_INFO}'* && $out != *'GAUGE_GIT_INFO} '* ]] &&
  { print -- "  FAIL one-line form lost the space after the git segment"; FAILED=1 } ||
  print -- "  ok   one-line form keeps its separating space"

print -- "\nauto preset resolution"
out=$(zsh -c "GAUGE_HAS_NERDFONT=1 GAUGE_PR_ENABLED=0
  source '$ROOT/gauge.plugin.zsh'
  c=\${GAUGE_SYMBOLS[pr_open]}
  print -r -- \"\$GAUGE_ACTIVE_SYMBOL_SET \$(( [##16] #c ))\"")
check "nerd font present -> nerdfont" 'nerdfont'  "$out"
check "pr_open is Octicon U+F407"     'F407'      "${out:u}"

out=$(zsh -c "GAUGE_HAS_NERDFONT=0 GAUGE_PR_ENABLED=0
  source '$ROOT/gauge.plugin.zsh'
  print -r -- \"\$GAUGE_ACTIVE_SYMBOL_SET \${GAUGE_SYMBOLS[pr_open]}\"")
check "no nerd font -> minimal"   'minimal' "$out"
check "falls back to the ⊙ set"   '⊙'       "$out"

print -- "\nemoji presets are not color-tinted"
out=$(zsh -c "GAUGE_SYMBOL_SET=emoji GAUGE_PR_ENABLED=0
  source '$ROOT/gauge.plugin.zsh'
  print -r -- \"\$(_gauge_pr_render OPEN false APPROVED)\"")
check "emoji rendered" '🔀' "$out"
[[ $out == *'%F'* ]] &&
  { print -- "  FAIL emoji preset should not emit %F color codes"; FAILED=1 } ||
  print -- "  ok   emits no %F color codes"

print -- "\nevery preset defines every symbol key"
for preset in emoji github nerdfont minimal; do
  out=$(zsh -c "
    GAUGE_SYMBOL_SET=$preset GAUGE_PR_ENABLED=0
    source '$ROOT/gauge.plugin.zsh'
    missing=()
    for k in dirty staged untracked ahead behind stash pr_open pr_draft \
             pr_merged pr_closed review_approved review_changes review_pending \
             separator prompt_char; do
      [[ -n \${GAUGE_SYMBOLS[\$k]-} ]] || missing+=\$k
    done
    for s in OPEN MERGED CLOSED; do
      [[ -n \$(_gauge_pr_render \$s false '') ]] || missing+=\"render:\$s\"
    done
    print -r -- \"\${missing[*]}\"
  ")
  if [[ -z $out ]]; then
    print -- "  ok   $preset"
  else
    print -- "  FAIL $preset missing: $out"
    FAILED=1
  fi
done

print -- "\nunknown preset falls back to minimal"
out=$(zsh -c "GAUGE_SYMBOL_SET=nope GAUGE_PR_ENABLED=0
  source '$ROOT/gauge.plugin.zsh' 2>&1
  print -r -- \"\${GAUGE_SYMBOLS[pr_open]}\"")
check "warns and uses minimal" '⊙' "$out"

print -- "\nuser overrides beat the preset"
out=$(zsh -c "typeset -A GAUGE_SYMBOLS=(pr_open 'XX')
  GAUGE_SYMBOL_SET=minimal GAUGE_PR_ENABLED=0
  source '$ROOT/gauge.plugin.zsh'
  print -r -- \"\${GAUGE_SYMBOLS[pr_open]}|\${GAUGE_SYMBOLS[pr_merged]}\"")
check "override applied"        'XX' "$out"
check "rest of preset intact"   '⊕' "$out"

print -- "\nNerd Font name recognition"
# Homebrew casks register the SHORT family (nameID 1): "JetBrainsMono NFM".
# The long "…Nerd Font Mono" spelling is only nameID 16, so both must match.
for name in 'JetBrainsMono NFM' 'MesloLGS NF' 'JetBrainsMono Nerd Font Mono' \
            'Hack Nerd Font Mono' 'FiraCode NFP' 'CaskaydiaCove NF'; do
  if [[ "font: ${name:l}" =~ $_gauge_nerdfont_pattern ]]; then
    print -- "  ok   recognises '$name'"
  else
    print -- "  FAIL did not recognise '$name'"
    FAILED=1
  fi
done
for name in Monaco Menlo 'SF Mono' 'Fira Code'; do
  if [[ "font: ${name:l}" =~ $_gauge_nerdfont_pattern ]]; then
    print -- "  FAIL '$name' is not a Nerd Font but matched"
    FAILED=1
  else
    print -- "  ok   rejects '$name'"
  fi
done

print -- "\ngauge-legend"
# GAUGE_PR_ENABLED=1 here: the legend only renders symbols, it never queries gh,
# so the PR/Review blocks can be checked without touching the network.
legend() {
  zsh -c "GAUGE_SYMBOL_SET=${2:-minimal} GAUGE_PR_ENABLED=1
    source '$ROOT/gauge.plugin.zsh'
    gauge-legend ${1:-}" 2>&1
}

out=$(legend)
check "shows the active preset"  'preset: minimal'  "$out"
check "has a Pull request block" 'Pull request'     "$out"
check "has a Review block"       'Review'           "$out"
check "explains the eye/pending" 'awaiting review'  "$out"
check "shows a symbol"           '⊙'                "$out"
[[ $out == *'%F'* ]] &&
  { print -- "  FAIL legend leaked raw %F prompt escapes"; FAILED=1 } ||
  print -- "  ok   prompt escapes are expanded, not printed"
[[ $out == *'='* && $out == *'local'* ]] &&
  { print -- "  FAIL legend leaked variable declarations"; FAILED=1 } ||
  print -- "  ok   no leaked variable declarations"

out=$(legend '--keys --codes')
check "--keys shows the config key" 'review_pending' "$out"
check "--codes shows a codepoint"   'U+'             "$out"

out=$(legend '--codes' nerdfont)
check "--codes is right for nerdfont" 'U+F407' "$out"

out=$(legend --all)
for preset in nerdfont minimal emoji github; do
  check "--all has a $preset column" "$preset" "$out"
done
check "--all rows are labelled" 'awaiting review' "$out"

out=$(legend --bogus)
check "rejects unknown options" 'unknown option' "$out"

out=$(zsh -c "GAUGE_PR_ENABLED=0 GAUGE_SHOW_STASH=0
  source '$ROOT/gauge.plugin.zsh'
  gauge-legend")
check "marks disabled PR lookups" 'GAUGE_PR_ENABLED=0' "$out"
check "marks a hidden flag"       'GAUGE_SHOW_STASH=0' "$out"

print -- "\nREADME images match the code"
# The SVGs in assets/ are generated from the prompt's own renderers. If a color
# or a symbol changes and the images aren't regenerated, the README lies — so
# regenerate into a temp file and diff.
if (( $+commands[python3] )); then
  for mode in prompt states presets; do
    for theme in dark light; do
      case $mode in
        prompt)  title="gauge: path, branch, working-tree flags, PR state" ;;
        states)  title="gauge: every pull request state" ;;
        presets) title="Every symbol in every preset: nerdfont, minimal, emoji, github" ;;
      esac
      zsh "$ROOT/tools/samples.zsh" $mode \
        | python3 "$ROOT/tools/ansi2svg.py" --theme $theme --title "$title" \
        > "$tmp/$mode-$theme.svg" 2>/dev/null
      if diff -q "$tmp/$mode-$theme.svg" "$ROOT/assets/$mode-$theme.svg" >/dev/null 2>&1; then
        print -- "  ok   assets/$mode-$theme.svg is current"
      else
        print -- "  FAIL assets/$mode-$theme.svg is stale — regenerate it:"
        print -- "       zsh tools/samples.zsh $mode | python3 tools/ansi2svg.py --theme $theme --title '$title' > assets/$mode-$theme.svg"
        FAILED=1
      fi
    done
  done

  # The presets table is shipped as a PNG too — SVG text can't show Private Use
  # Area glyphs to a reader without a Nerd Font. Freshness of the PNG can't be
  # diffed (rasterizers differ), so just insist it exists and isn't empty.
  for theme in dark light; do
    if [[ -s $ROOT/assets/presets-$theme.png ]]; then
      print -- "  ok   assets/presets-$theme.png exists"
    else
      print -- "  FAIL assets/presets-$theme.png missing — tools/svg2png.sh assets/presets-$theme.svg"
      FAILED=1
    fi
  done

  # Emoji are two cells wide but one character. The converter measures display
  # width, not length: otherwise the presets table's width would be short and
  # its right-hand column would be clipped.
  out=$(python3 -c "
import sys; sys.path.insert(0, '$ROOT/tools')
from ansi2svg import cell_width as w
print(w('*'), w('\u2295'), w('\U0001f500'), w('a\U0001f7e2'), w('\u2705\ufe0f'))")
  check "cell width: ascii, geometric, emoji, mixed, +VS16" '1 1 2 3 2' "$out"

  # Colors must survive the ANSI -> SVG conversion, not just be present.
  out=$(zsh "$ROOT/tools/samples.zsh" prompt | python3 "$ROOT/tools/ansi2svg.py" --theme dark)
  check "SVG is well-formed enough"  '</svg>'   "$out"
  check "path keeps its blue"        '#58a6ff'  "$out"
  check "untracked keeps its red"    '#ff7b72'  "$out"
  check "stash stays dim (242)"      '#6c6c6c'  "$out"
  [[ $out == *$'\e'* ]] &&
    { print -- "  FAIL raw escape survived into the SVG"; FAILED=1 } ||
    print -- "  ok   no raw escapes left in the SVG"
else
  print -- "  skip python3 not found, cannot check the README images"
fi

print -- ""
if (( FAILED )); then
  print -- "FAILED"
  exit 1
fi
print -- "all checks passed"
