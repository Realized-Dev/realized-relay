#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)/helpers.sh"
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
CHECKS="$ROOT/checks"
pp="$CHECKS/protected-paths.sh"

# Runtime identity tokens (source must not contain contiguous client identifiers).
AGENT=$(printf '%s-%s' ai realized)
HUMAN=$(printf '%s%s' ralf cam)
CITE=$(printf '%s%s' CL RO)
AGENT_BOT="${AGENT}[bot]"
AGENT_CASE=$(printf '%s-%s' AI Realized)

sha="103c5eb3103c5eb3103c5eb3103c5eb3103c5eb3"
body_pass="${CITE} pass @$sha"

# P1: human PR touching .github/workflows/ci.yml
expect_exit P1 0 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$HUMAN" RELAY_PP_COMMITS="$HUMAN	$HUMAN" RELAY_PP_FILES=".github/workflows/ci.yml" RELAY_PP_BODY="$body_pass" "$pp"
expect_contains P1-msg 'protected-paths: PASS'

# P2: agent PR touching only unprotected docs/x.md
expect_exit P2 0 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$AGENT" RELAY_PP_COMMITS="$AGENT	$AGENT" RELAY_PP_FILES="docs/x.md" "$pp"
expect_contains P2-msg 'protected-paths: PASS (agent=yes, 0 protected hits)'

# P3: agent PR whose path is like a glob but does not match
expect_exit P3 0 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$AGENT" RELAY_PP_FILES="src/protected-paths-notes.md" "$pp"
expect_contains P3-msg 'PASS'

# P4: empty-diff synchronize from agent
expect_exit P4 0 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$AGENT" RELAY_PP_SENDER="$AGENT" RELAY_PP_FILES="" "$pp"
expect_contains P4-msg 'PASS'

# P5: human PR that edits PROTECTED_PATHS
expect_exit P5 0 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$HUMAN" RELAY_PP_COMMITS="$HUMAN	$HUMAN" RELAY_PP_FILES="PROTECTED_PATHS" RELAY_PP_BODY="$body_pass" "$pp"
expect_contains P5-msg 'PASS'

# P6: agent docs-only edit to ordinary test file
expect_exit P6 0 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$AGENT" RELAY_PP_FILES="tests/foo.test.sh" "$pp"
expect_contains P6-msg 'PASS'

# F1: agent PR edits .github/workflows/guards.yml
expect_exit F1a 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$AGENT" RELAY_PP_FILES=".github/workflows/guards.yml" "$pp"
expect_contains F1a-msg 'FAIL'
# F1b: agent bot touching checks/approver-check.sh
expect_exit F1b 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$AGENT_BOT" RELAY_PP_FILES="checks/approver-check.sh" "$pp"
expect_contains F1b-msg "protected-paths: FAIL. ${AGENT} PR touches protected path(s): checks/approver-check.sh (rule checks/**, line 10)"
expect_contains F1b-msg2 "authored by ${HUMAN}"

# F2: agent PR edits PROTECTED_PATHS
expect_exit F2 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$AGENT" RELAY_PP_FILES="PROTECTED_PATHS" "$pp"

# F3: agent PR deletes protected file (deletion means it is in FILES)
expect_exit F3 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$AGENT" RELAY_PP_FILES="AGENTS.md" "$pp"

# F4: rename of protected file to unprotected (previous_filename)
expect_exit F4 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$AGENT" RELAY_PP_FILES=$'docs/new.md\tchecks/approver-check.sh' "$pp"

# F5: rename of unprotected file into protected path
expect_exit F5 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$AGENT" RELAY_PP_FILES=$'checks/new.sh\tdocs/old.md' "$pp"

# F6: human-authored PR containing one commit authored by agent
expect_exit F6 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$HUMAN" RELAY_PP_COMMITS="$HUMAN	$HUMAN
$AGENT	$HUMAN" RELAY_PP_FILES="PROTECTED_PATHS" "$pp"

# F7: commit with no linked GitHub login (eval fixture uses "-" sentinel)
expect_exit F7 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$HUMAN" RELAY_PP_COMMITS="-"$'\t'"$HUMAN" RELAY_PP_FILES="PROTECTED_PATHS" "$pp"

# F8: ** nested match
expect_exit F8 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$AGENT" RELAY_PP_FILES=".cursor/rules/nested/file.md" "$pp"

# F9: case-variant agent login
expect_exit F9 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$AGENT_CASE" RELAY_PP_FILES="checks/approver-check.sh" "$pp"

# F10: PR that edits check script and protected path
expect_exit F10 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$AGENT" RELAY_PP_FILES=$'checks/protected-paths.sh\nchecks/approver-check.sh' "$pp"

# F11: pagination, >300 files
files=""
for i in {1..350}; do
	files="${files}docs/unprotected${i}.md
"
done
files="${files}checks/approver-check.sh"
expect_exit F11 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$AGENT" RELAY_PP_FILES="$files" "$pp"

# F12: missing PROTECTED_PATHS
expect_exit F12 1 run_eval env RELAY_PP_PATHS_FILE="/does/not/exist" "$pp"
expect_contains F12-msg 'ERROR'

# F13: !negation line
tmp=$(mktemp)
echo "!checks/**" > "$tmp"
expect_exit F13 1 run_eval env RELAY_PP_PATHS_FILE="$tmp" "$pp"
expect_contains F13-msg 'ERROR'
rm -f "$tmp"

# F14: eval-mode injected API error sentinel
expect_exit F14 1 run_eval env RELAY_PP_FILES="__ERROR__" "$pp"
expect_contains F14-msg 'ERROR'

# F15: QA rubric touched by agent
expect_exit F15 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$AGENT" RELAY_PP_FILES="qa/rubrics/x.md" "$pp"

# F16: agent edit to one of the ten guard test files
expect_exit F16 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$AGENT" RELAY_PP_FILES="tests/denylist.test.sh" "$pp"

# F17: human PR touching protected path with no citation
expect_exit F17 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$HUMAN" RELAY_PP_COMMITS="$HUMAN	$HUMAN" RELAY_PP_FILES="checks/approver-check.sh" RELAY_PP_BODY="some text" "$pp"
expect_contains F17-msg "protected-paths: FAIL. protected path(s) touched but PR body missing '${CITE} pass @<headsha>'; see PROTECTED_PATHS."

# F18: unknown login fail-closed as agent on protected path
expect_exit F18 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="contractor-x" RELAY_PP_SENDER="contractor-x" RELAY_PP_COMMITS=$'contractor-x\tcontractor-x' RELAY_PP_FILES="checks/approver-check.sh" "$pp"
expect_contains F18-msg 'FAIL'

# F19: Co-authored-by trailer naming the agent fails
_co_msg=$(printf 'feat: x\\n\\nCo-authored-by: %s <a@b.c>' "$AGENT")
expect_exit F19 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$HUMAN" RELAY_PP_SENDER="$HUMAN" RELAY_PP_COMMITS="$HUMAN	$HUMAN	${_co_msg}" RELAY_PP_FILES="checks/approver-check.sh" RELAY_PP_BODY="$body_pass" "$pp"
expect_contains F19-msg 'FAIL'

# P7: web-flow committer allowed when author is the listed human
expect_exit P7 0 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$HUMAN" RELAY_PP_COMMITS="$HUMAN	web-flow" RELAY_PP_FILES="checks/approver-check.sh" RELAY_PP_BODY="$body_pass" "$pp"
expect_contains P7-msg 'PASS'

# F20: web-flow committer rejected when author is not the listed human
expect_exit F20 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="someone-else" RELAY_PP_SENDER="someone-else" RELAY_PP_COMMITS=$'someone-else\tweb-flow' RELAY_PP_FILES="checks/approver-check.sh" RELAY_PP_BODY="$body_pass" "$pp"
expect_contains F20-msg 'FAIL'

# F21: changed_files hits 3000 API limit
expect_exit F21 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$HUMAN" RELAY_PP_COMMITS="$HUMAN	$HUMAN" RELAY_PP_FILES="docs/x.md" RELAY_PP_PR_CHANGED_FILES=3000 "$pp"
expect_contains F21-msg 'ERROR'
expect_contains F21-msg2 '3000'

# F22: commits hits 250 API limit
expect_exit F22 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$HUMAN" RELAY_PP_COMMITS="$HUMAN	$HUMAN" RELAY_PP_FILES="docs/x.md" RELAY_PP_PR_COMMITS_COUNT=250 "$pp"
expect_contains F22-msg 'ERROR'
expect_contains F22-msg2 '250'

# F23: incomplete files pagination fails closed
expect_exit F23 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$HUMAN" RELAY_PP_COMMITS="$HUMAN	$HUMAN" RELAY_PP_FILES="docs/x.md" RELAY_PP_PR_CHANGED_FILES=2 "$pp"
expect_contains F23-msg 'incomplete files pagination'

# F24: incomplete commits pagination fails closed
expect_exit F24 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$HUMAN" RELAY_PP_COMMITS="$HUMAN	$HUMAN" RELAY_PP_FILES="docs/x.md" RELAY_PP_PR_COMMITS_COUNT=2 "$pp"
expect_contains F24-msg 'incomplete commits pagination'


# P8: PROTECTED_PATHS keeps named humans/agents without contiguous denylist tokens
expect_exit P8 1 bash -c "grep -Fqe \"$AGENT\" \"$ROOT/PROTECTED_PATHS\""
expect_exit P8b 1 bash -c "grep -Fqe \"$HUMAN\" \"$ROOT/PROTECTED_PATHS\""
expect_contains P8c '@agents:' "$(head -n1 "$ROOT/PROTECTED_PATHS")"
expect_contains P8d '@humans:' "$(sed -n '2p' "$ROOT/PROTECTED_PATHS")"
# Membership still resolves (human with citation passes against real file)
expect_exit P8e 0 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$HUMAN" RELAY_PP_COMMITS="$HUMAN	$HUMAN" RELAY_PP_FILES="PROTECTED_PATHS" RELAY_PP_BODY="$body_pass" "$pp"
expect_contains P8e-msg 'PASS'


# F25: null-author sentinel + human committer + valid citation must FAIL (bypass class)
expect_exit F25 1 run_eval env RELAY_HEAD_SHA="$sha" RELAY_PP_AUTHOR="$HUMAN" RELAY_PP_SENDER="$HUMAN" RELAY_PP_COMMITS="-"$'\t'"$HUMAN"$'\t'"msg" RELAY_PP_FILES="PROTECTED_PATHS" RELAY_PP_BODY="$body_pass" "$pp"
expect_contains F25-msg 'FAIL'

# F26: CI-mode gh-stub — null author, human committer, valid citation → FAIL
# Stub applies the script's --jq filter so the sentinel emit path is exercised.
_f26_fake=$(mktemp -d)
cat >"$_f26_fake/gh" <<'GHEOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${FAKE_GH_LOG:?}"
jq_expr=""
prev=""
for a in "$@"; do
	if [ "$prev" = "--jq" ]; then jq_expr="$a"; fi
	prev="$a"
done
joined="$*"
if [[ "$joined" == *"/commits"* ]]; then
	payload='[{"author":null,"committer":{"login":"ralfcam"},"commit":{"message":"x"}}]'
elif [[ "$joined" == *"/files"* ]]; then
	payload='[{"filename":"PROTECTED_PATHS"}]'
else
	payload='{"changed_files":1,"commits":1}'
fi
if [ -n "$jq_expr" ]; then
	printf '%s' "$payload" | jq -r "$jq_expr"
else
	printf '%s' "$payload"
fi
GHEOF
chmod +x "$_f26_fake/gh"
_f26_log="$_f26_fake/log"
: >"$_f26_log"
expect_exit F26 1 env PATH="$_f26_fake:$PATH" FAKE_GH_LOG="$_f26_log" \
	RELAY_CHECK_MODE=ci \
	GITHUB_REPOSITORY=acme/relay PR_NUMBER=13 RELAY_HEAD_SHA="$sha" \
	RELAY_PP_AUTHOR="$HUMAN" RELAY_PP_SENDER="$HUMAN" RELAY_PP_BODY="$body_pass" \
	RELAY_PP_PATHS_FILE="$ROOT/PROTECTED_PATHS" \
	"$pp"
expect_contains F26-msg 'FAIL'
rm -rf "$_f26_fake"

finish
