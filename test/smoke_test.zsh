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

ZGP_SYMBOL_SET=minimal                 # deterministic symbols for assertions
ZGP_PR_ENABLED=0                       # keep the network out of the test
ZGP_PR_CACHE_DIR="$tmp/cache"
source "$ROOT/git-pr-prompt.plugin.zsh"

print -- "plugin loads"
check "PROMPT is set"        'ZGP_GIT_INFO'      "$PROMPT"
check "precmd hook added"    '_zgp_precmd'       "${precmd_functions[*]-}"
check "symbols populated"    '*'                 "${ZGP_SYMBOLS[dirty]}"

cd "$tmp"
git init -q repo
cd repo
git config user.email t@example.com
git config user.name  Test
print -- "hello" > a.txt

print -- "\nuntracked file"
_zgp_precmd
check "shows ? flag" '?' "$ZGP_GIT_INFO"

git add a.txt
print -- "\nstaged file"
_zgp_precmd
check "shows + flag" '+' "$ZGP_GIT_INFO"

git commit -qm init
print -- "world" >> a.txt
print -- "\nmodified tracked file"
_zgp_precmd
check "shows * flag" '*' "$ZGP_GIT_INFO"

git stash -q
print -- "\nstash entry"
_zgp_precmd
check "shows stash count" '≡1' "$ZGP_GIT_INFO"

print -- "\nbranch name"
git checkout -qb feature/thing
_zgp_precmd
check "shows branch" 'feature/thing' "$ZGP_GIT_INFO"

print -- "\noutside a repo"
cd "$tmp"
_zgp_precmd
check "segment is empty" '' "$ZGP_GIT_INFO"
[[ -z $ZGP_GIT_INFO ]] || { print -- "  FAIL expected empty segment, got: $ZGP_GIT_INFO"; FAILED=1 }

print -- "\nPR rendering, geometric fallback (no network)"
check "open"            '⊙' "$(_zgp_pr_render OPEN false '')"
check "approved"        '✓' "$(_zgp_pr_render OPEN false APPROVED)"
check "changes req"     '✗' "$(_zgp_pr_render OPEN false CHANGES_REQUESTED)"
check "review pending"  '·' "$(_zgp_pr_render OPEN false REVIEW_REQUIRED)"
check "draft"           '◌' "$(_zgp_pr_render OPEN true '')"
check "merged"          '⊕' "$(_zgp_pr_render MERGED false '')"
check "closed"          '⊘' "$(_zgp_pr_render CLOSED false '')"

# REVIEW_REQUIRED is meaningless on a draft or a closed PR.
[[ $(_zgp_pr_render OPEN true REVIEW_REQUIRED) == *'·'* ]] &&
  { print -- "  FAIL draft should not show the review-pending icon"; FAILED=1 } ||
  print -- "  ok   draft hides review-pending icon"

print -- "\nauto preset resolution"
out=$(zsh -c "ZGP_HAS_NERDFONT=1 ZGP_PR_ENABLED=0
  source '$ROOT/git-pr-prompt.plugin.zsh'
  c=\${ZGP_SYMBOLS[pr_open]}
  print -r -- \"\$ZGP_ACTIVE_SYMBOL_SET \$(( [##16] #c ))\"")
check "nerd font present -> nerdfont" 'nerdfont'  "$out"
check "pr_open is Octicon U+F407"     'F407'      "${out:u}"

out=$(zsh -c "ZGP_HAS_NERDFONT=0 ZGP_PR_ENABLED=0
  source '$ROOT/git-pr-prompt.plugin.zsh'
  print -r -- \"\$ZGP_ACTIVE_SYMBOL_SET \${ZGP_SYMBOLS[pr_open]}\"")
check "no nerd font -> minimal"   'minimal' "$out"
check "falls back to the ⊙ set"   '⊙'       "$out"

print -- "\nemoji presets are not color-tinted"
out=$(zsh -c "ZGP_SYMBOL_SET=emoji ZGP_PR_ENABLED=0
  source '$ROOT/git-pr-prompt.plugin.zsh'
  print -r -- \"\$(_zgp_pr_render OPEN false APPROVED)\"")
check "emoji rendered" '🔀' "$out"
[[ $out == *'%F'* ]] &&
  { print -- "  FAIL emoji preset should not emit %F color codes"; FAILED=1 } ||
  print -- "  ok   emits no %F color codes"

print -- "\nevery preset defines every symbol key"
for preset in emoji github nerdfont minimal; do
  out=$(zsh -c "
    ZGP_SYMBOL_SET=$preset ZGP_PR_ENABLED=0
    source '$ROOT/git-pr-prompt.plugin.zsh'
    missing=()
    for k in dirty staged untracked ahead behind stash pr_open pr_draft \
             pr_merged pr_closed review_approved review_changes review_pending \
             prompt_char; do
      [[ -n \${ZGP_SYMBOLS[\$k]-} ]] || missing+=\$k
    done
    for s in OPEN MERGED CLOSED; do
      [[ -n \$(_zgp_pr_render \$s false '') ]] || missing+=\"render:\$s\"
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
out=$(zsh -c "ZGP_SYMBOL_SET=nope ZGP_PR_ENABLED=0
  source '$ROOT/git-pr-prompt.plugin.zsh' 2>&1
  print -r -- \"\${ZGP_SYMBOLS[pr_open]}\"")
check "warns and uses minimal" '⊙' "$out"

print -- "\nuser overrides beat the preset"
out=$(zsh -c "typeset -A ZGP_SYMBOLS=(pr_open 'XX')
  ZGP_SYMBOL_SET=minimal ZGP_PR_ENABLED=0
  source '$ROOT/git-pr-prompt.plugin.zsh'
  print -r -- \"\${ZGP_SYMBOLS[pr_open]}|\${ZGP_SYMBOLS[pr_merged]}\"")
check "override applied"        'XX' "$out"
check "rest of preset intact"   '⊕' "$out"

print -- "\nzgp-legend"
# ZGP_PR_ENABLED=1 here: the legend only renders symbols, it never queries gh,
# so the PR/Review blocks can be checked without touching the network.
legend() {
  zsh -c "ZGP_SYMBOL_SET=${2:-minimal} ZGP_PR_ENABLED=1
    source '$ROOT/git-pr-prompt.plugin.zsh'
    zgp-legend ${1:-}" 2>&1
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

out=$(zsh -c "ZGP_PR_ENABLED=0 ZGP_SHOW_STASH=0
  source '$ROOT/git-pr-prompt.plugin.zsh'
  zgp-legend")
check "marks disabled PR lookups" 'ZGP_PR_ENABLED=0' "$out"
check "marks a hidden flag"       'ZGP_SHOW_STASH=0' "$out"

print -- ""
if (( FAILED )); then
  print -- "FAILED"
  exit 1
fi
print -- "all checks passed"
