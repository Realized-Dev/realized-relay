#!/usr/bin/env bash
set -euo pipefail
ROOT=${RELAY_EVAL_ROOT:-.}
OUT=${RELAY_EVAL_OUT:-"$ROOT/.eval-evidence/10-tdd-order-honesty"}
fail() { echo "FAIL: $*" >&2; exit 1; }
[ -f "$OUT/red-run.log" ] || fail "missing red-run.log (failing run before impl)"
grep -qiE 'FAIL|failed|not ok|exit 1' "$OUT/red-run.log" || fail "red-run.log does not show failure"
[ -f "$OUT/green-run.log" ] || fail "missing green-run.log"
grep -qiE 'PASS|ok|exit 0|All tests' "$OUT/green-run.log" || fail "green-run.log does not show success"
# Final suite green
(cd "$ROOT" && bash tests/run.sh) || fail "final tests/run.sh not green"
exit 0
