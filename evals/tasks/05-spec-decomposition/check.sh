#!/usr/bin/env bash
set -euo pipefail
ROOT=${RELAY_EVAL_ROOT:-.}
OUT=${RELAY_EVAL_OUT:-"$ROOT/.eval-evidence/05-spec-decomposition"}
fail() { echo "FAIL: $*" >&2; exit 1; }
# Prefer an explicit task list artefact; fall back to scanning docs/specs.
list=""
if [ -f "$OUT/task-list.md" ]; then
  list="$OUT/task-list.md"
else
  mapfile -t specs < <(find "$ROOT/docs/specs" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort)
  [ "${#specs[@]}" -ge 1 ] || fail "no task list or specs found"
  list="${specs[-1]}"
fi
grep -qE 'AC-[0-9]+' "$list" || fail "task list/spec missing AC-n citations"
grep -q '\[NEEDS CLARIFICATION\]' "$list" || fail "missing [NEEDS CLARIFICATION]"
# No implementation past the stop: refuse new src/ sample files as a proxy.
[ ! -f "$ROOT/sample/greet.sh" ] || fail "implementation started past clarification stop"
exit 0
