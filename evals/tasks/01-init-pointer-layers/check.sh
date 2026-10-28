#!/usr/bin/env bash
# Deterministic grader for 01-init-pointer-layers. Exit 0 = pass.
set -euo pipefail
ROOT=${RELAY_EVAL_ROOT:-.}
fail() { echo "FAIL: $*" >&2; exit 1; }
[ -f "$ROOT/AGENTS.md" ] || fail "AGENTS.md missing"
# Pointers, if present, must stay thin and must not duplicate AGENTS body.
shopt -s nullglob
for f in "$ROOT/CLAUDE.md" "$ROOT/.agents/rules/"*.md "$ROOT/.cursor/rules/"*; do
  [ -e "$f" ] || continue
  lines=$(wc -l < "$f")
  [ "$lines" -le 40 ] || fail "pointer $f has $lines lines (>40)"
done
# Must not have invented vendor/hook templates in this task scope.
[ ! -f "$ROOT/.github/workflows/eval-invented.yml" ] || fail "invented CI workflow present"
exit 0
