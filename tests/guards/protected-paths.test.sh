#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)/helpers.sh"
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
CHECKS="$ROOT/checks"
pp="$CHECKS/protected-paths.sh"

sha="103c5eb3103c5eb3103c5eb3103c5eb3103c5eb3"
body_pass="CLRO pass @$sha"

# P1: ralfcam PR touching .github/workflows/ci.yml
expect_exit P1 0 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ralfcam" RELAY_PP_COMMITS="ralfcam	ralfcam" RELAY_PP_FILES=".github/workflows/ci.yml" RELAY_PP_BODY="$body_pass" "$pp"
expect_contains P1-msg 'protected-paths: PASS'

# P2: ai-realized PR touching only unprotected docs/x.md
expect_exit P2 0 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ai-realized" RELAY_PP_COMMITS="ai-realized	ai-realized" RELAY_PP_FILES="docs/x.md" "$pp"
expect_contains P2-msg 'protected-paths: PASS (agent=yes, 0 protected hits)'

# P3: ai-realized PR whose path is like a glob but doesn't match
expect_exit P3 0 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ai-realized" RELAY_PP_FILES="src/protected-paths-notes.md" "$pp"
expect_contains P3-msg 'PASS'

# P4: empty-diff synchronize from ai-realized
expect_exit P4 0 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ai-realized" RELAY_PP_SENDER="ai-realized" RELAY_PP_FILES="" "$pp"
expect_contains P4-msg 'PASS'

# P5: ralfcam PR that edits PROTECTED_PATHS
expect_exit P5 0 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ralfcam" RELAY_PP_COMMITS="ralfcam	ralfcam" RELAY_PP_FILES="PROTECTED_PATHS" RELAY_PP_BODY="$body_pass" "$pp"
expect_contains P5-msg 'PASS'

# P6: ai-realized docs-only edit to ordinary test file
expect_exit P6 0 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ai-realized" RELAY_PP_FILES="tests/foo.test.sh" "$pp"
expect_contains P6-msg 'PASS'

# F1: ai-realized PR edits .github/workflows/guards.yml
expect_exit F1a 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ai-realized" RELAY_PP_FILES=".github/workflows/guards.yml" "$pp"
expect_contains F1a-msg 'FAIL'
# F1b: ai-realized touching checks/approver-check.sh
expect_exit F1b 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ai-realized[bot]" RELAY_PP_FILES="checks/approver-check.sh" "$pp"
expect_contains F1b-msg 'protected-paths: FAIL. ai-realized PR touches protected path(s): checks/approver-check.sh (rule checks/**, line 10)'
expect_contains F1b-msg2 'authored by ralfcam'

# F2: ai-realized PR edits PROTECTED_PATHS
expect_exit F2 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ai-realized" RELAY_PP_FILES="PROTECTED_PATHS" "$pp"

# F3: ai-realized PR deletes protected file (deletion means it's in FILES)
expect_exit F3 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ai-realized" RELAY_PP_FILES="AGENTS.md" "$pp"

# F4: rename of protected file to unprotected (previous_filename)
expect_exit F4 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ai-realized" RELAY_PP_FILES=$'docs/new.md\tchecks/approver-check.sh' "$pp"

# F5: rename of unprotected file into protected path
expect_exit F5 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ai-realized" RELAY_PP_FILES=$'checks/new.sh\tdocs/old.md' "$pp"

# F6: human-authored PR containing one commit authored by ai-realized
expect_exit F6 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ralfcam" RELAY_PP_COMMITS=$'ralfcam\tralfcam\nai-realized\tralfcam' RELAY_PP_FILES="PROTECTED_PATHS" "$pp"

# F7: commit with no linked GitHub login
expect_exit F7 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ralfcam" RELAY_PP_COMMITS=$'\tralfcam' RELAY_PP_FILES="PROTECTED_PATHS" "$pp"

# F8: ** nested match
expect_exit F8 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ai-realized" RELAY_PP_FILES=".cursor/rules/nested/file.md" "$pp"

# F9: case-variant ai-realized login
expect_exit F9 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="AI-Realized" RELAY_PP_FILES="checks/approver-check.sh" "$pp"

# F10: PR that edits check script and protected path
expect_exit F10 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ai-realized" RELAY_PP_FILES=$'checks/protected-paths.sh\nchecks/approver-check.sh' "$pp"

# F11: pagination, >300 files
files=""
for i in {1..350}; do
	files="${files}docs/unprotected${i}.md
"
done
files="${files}checks/approver-check.sh"
expect_exit F11 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ai-realized" RELAY_PP_FILES="$files" "$pp"

# F12: missing PROTECTED_PATHS
expect_exit F12 1 run_eval env RELAY_PP_PATHS_FILE="/does/not/exist" "$pp"
expect_contains F12-msg 'ERROR'

# F13: !negation line
tmp=$(mktemp)
echo "!checks/**" > "$tmp"
expect_exit F13 1 run_eval env RELAY_PP_PATHS_FILE="$tmp" "$pp"
expect_contains F13-msg 'ERROR'
rm -f "$tmp"

# F14: API error or truncation
expect_exit F14 1 run_eval env RELAY_PP_FILES="__ERROR__" "$pp"
expect_contains F14-msg 'ERROR'

# F15: QA rubric touched by ai-realized
expect_exit F15 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ai-realized" RELAY_PP_FILES="qa/rubrics/x.md" "$pp"

# F16: ai-realized edit to one of the ten guard test files
expect_exit F16 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ai-realized" RELAY_PP_FILES="tests/denylist.test.sh" "$pp"

# F17: ralfcam PR touching protected path with no citation
expect_exit F17 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="ralfcam" RELAY_PP_COMMITS="ralfcam	ralfcam" RELAY_PP_FILES="checks/approver-check.sh" RELAY_PP_BODY="some text" "$pp"
expect_contains F17-msg "protected-paths: FAIL. protected path(s) touched but PR body missing 'CLRO pass @<headsha>'; see PROTECTED_PATHS."

finish
