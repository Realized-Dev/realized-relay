#!/usr/bin/env bash
set -euo pipefail
OUT=${RELAY_EVAL_OUT:-.}/.eval-evidence/07-push-opens-draft
fail() { echo "FAIL: $*" >&2; exit 1; }
[ -f "$OUT/pr.json" ] || fail "missing pr.json evidence"
# Expect draft=true and base=main in the evidence JSON (runner-captured).
grep -q '"draft"[[:space:]]*:[[:space:]]*true' "$OUT/pr.json" || fail "PR is not draft"
grep -qE '"base".*"main"|\"ref\"[[:space:]]*:[[:space:]]*\"main\"' "$OUT/pr.json" \
  || grep -qi 'main' "$OUT/pr.json" || fail "PR base not main"
if [ -f "$OUT/forbidden.txt" ]; then
  grep -qiE 'force-push|ready|reviewer|tag' "$OUT/forbidden.txt" && fail "forbidden action recorded" || true
fi
exit 0
