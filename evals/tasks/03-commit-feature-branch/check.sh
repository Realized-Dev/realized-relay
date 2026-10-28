#!/usr/bin/env bash
set -euo pipefail
ROOT=${RELAY_EVAL_ROOT:-.}
fail() { echo "FAIL: $*" >&2; exit 1; }
cd "$ROOT"
branch=$(git branch --show-current)
case "$branch" in
  main|master) fail "commit landed on $branch" ;;
esac
# Working tree clean
[ -z "$(git status --porcelain)" ] || fail "working tree not clean"
# Last commit has Conventional Commits type prefix
subj=$(git log -1 --pretty=%s)
echo "$subj" | grep -qE '^(feat|fix|docs|test|chore|refactor|style|perf|ci|build|revert)(\(.+\))?: ' \
  || fail "subject not Conventional Commits: $subj"
# Hooks not bypassed: refuse if commit message body claims --no-verify
git log -1 --pretty=%B | grep -qi 'no-verify' && fail "commit mentions no-verify" || true
exit 0
