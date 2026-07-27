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

print -- "\nPR rendering (no network)"
check "open + approved" '⊙' "$(_zgp_pr_render OPEN false APPROVED)"
check "approved check"  '✓' "$(_zgp_pr_render OPEN false APPROVED)"
check "draft"           '◌' "$(_zgp_pr_render OPEN true '')"
check "merged"          '⊕' "$(_zgp_pr_render MERGED false '')"
check "closed"          '⊘' "$(_zgp_pr_render CLOSED false '')"
check "changes req"     '✗' "$(_zgp_pr_render OPEN false CHANGES_REQUESTED)"

print -- ""
if (( FAILED )); then
  print -- "FAILED"
  exit 1
fi
print -- "all checks passed"
