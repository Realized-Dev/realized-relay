#!/usr/bin/env bash
set -euo pipefail
ROOT=${RELAY_EVAL_ROOT:-.}
fail() { echo "FAIL: $*" >&2; exit 1; }
# Evidence file written by the runner/session (optional for dry structure checks)
EVIDENCE=${RELAY_EVAL_EVIDENCE:-"$ROOT/.eval-evidence/04-failing-test-first-tdd"}
# Final suite must be runnable and green when evidence says implementation landed.
if [ -f "$EVIDENCE/red-then-green.ok" ]; then
  (cd "$ROOT" && bash tests/run.sh) || fail "final tests/run.sh not green"
  exit 0
fi
# Without session evidence, verify harness still green (no broken suite left behind).
(cd "$ROOT" && bash tests/run.sh) || fail "tests/run.sh red"
# Soft structural hint: at least one test file mentioning AC-
if ! grep -R -l --include='*.sh' --include='*.md' -E 'AC-[0-9]+' "$ROOT/tests" "$ROOT/docs/specs" >/dev/null 2>&1; then
  fail "no AC-n tagged tests/specs found for this task outcome"
fi
exit 0
