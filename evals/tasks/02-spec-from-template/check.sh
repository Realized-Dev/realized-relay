#!/usr/bin/env bash
set -euo pipefail
ROOT=${RELAY_EVAL_ROOT:-.}
fail() { echo "FAIL: $*" >&2; exit 1; }
# Find a new feature spec under docs/specs (exclude known non-feature docs).
mapfile -t specs < <(find "$ROOT/docs/specs" -maxdepth 1 -type f -name '*.md' ! -name 'relay-evals-v1.md' ! -name 'tdd-order-jscpd-followups.md' 2>/dev/null | sort)
[ "${#specs[@]}" -ge 1 ] || fail "no feature spec under docs/specs/"
spec="${specs[0]}"
ac_count=$(grep -cE '^#+ .*AC-[0-9]+|AC-[0-9]+' "$spec" || true)
# Prefer explicit AC-n markers
ac_count=$(grep -cE 'AC-[0-9]+' "$spec" || true)
[ "$ac_count" -ge 3 ] || fail "need at least three AC-n ids in $spec (found $ac_count)"
grep -q '\[NEEDS CLARIFICATION\]' "$spec" || fail "missing [NEEDS CLARIFICATION] for the intentional gap"
exit 0
