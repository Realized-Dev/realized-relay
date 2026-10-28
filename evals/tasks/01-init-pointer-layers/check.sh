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
# Must not have invented hooks or CI workflows in this task scope.
# Reject any path under .githooks/ or .github/workflows/ that is untracked
# or newly appears vs RELAY_EVAL_BASE (when the runner sets it).
if [ -n "${RELAY_EVAL_BASE:-}" ]; then
  while IFS= read -r rel; do
    case "$rel" in
      .githooks/*|.github/workflows/*)
        fail "new hook/workflow in task scope: $rel"
        ;;
    esac
  done < <(git -C "$ROOT" diff --name-only --diff-filter=A "$RELAY_EVAL_BASE" HEAD 2>/dev/null || true)
fi
# Always reject a clearly invented workflow name even without a base SHA.
[ ! -f "$ROOT/.github/workflows/eval-invented.yml" ] || fail "invented CI workflow present"
# Untracked hooks/workflows also fail.
while IFS= read -r rel; do
  case "$rel" in
    .githooks/*|.github/workflows/*) fail "untracked hook/workflow: $rel" ;;
  esac
done < <(git -C "$ROOT" ls-files --others --exclude-standard 2>/dev/null || true)
exit 0
