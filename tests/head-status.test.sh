#!/usr/bin/env bash
# AC-HS: workflow_run results land on the PR head SHA, never on main.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"

HEAD40='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
MAIN40='cccccccccccccccccccccccccccccccccccccccc'
resolve="$CHECKS/resolve-guard-context.sh"
publish="$CHECKS/publish-head-status.sh"

# pull_request_target: explicit head wins over GITHUB_SHA (main).
expect_exit AC-HS-01 0 env GITHUB_SHA="$MAIN40" RELAY_PR_HEAD_SHA="$HEAD40" \
	RELAY_PR_NUMBER=4 GITHUB_REPOSITORY=acme/relay "$resolve"
expect_contains AC-HS-02 "head_sha=$HEAD40"
expect_contains AC-HS-03 'pr_number=4'
expect_omits AC-HS-04 "$MAIN40"

# workflow_run: use workflow_run.head_sha; resolve PR from the commits API fixture.
expect_exit AC-HS-05 0 env -u CI -u GITHUB_ACTIONS GITHUB_SHA="$MAIN40" \
	RELAY_WORKFLOW_HEAD_SHA="$HEAD40" GITHUB_REPOSITORY=acme/relay \
	RELAY_COMMITS_PULLS_JSON='[{"number":9}]' "$resolve"
expect_contains AC-HS-06 "head_sha=$HEAD40"
expect_contains AC-HS-07 'pr_number=9'
expect_omits AC-HS-08 "$MAIN40"

# No head at all: fail. Do not fall back to GITHUB_SHA.
expect_exit AC-HS-09 1 env GITHUB_SHA="$MAIN40" GITHUB_REPOSITORY=acme/relay "$resolve"
expect_contains AC-HS-10 'will not use GITHUB_SHA'

# Empty pulls list on workflow_run: fail closed (fork with no API match).
expect_exit AC-HS-11 1 env -u CI -u GITHUB_ACTIONS GITHUB_SHA="$MAIN40" \
	RELAY_WORKFLOW_HEAD_SHA="$HEAD40" GITHUB_REPOSITORY=acme/relay \
	RELAY_COMMITS_PULLS_JSON='[]' "$resolve"

# publish-head-status posts to RELAY_HEAD_SHA, never GITHUB_SHA.
fake=$(mktemp -d)
trap 'rm -rf "$fake"' EXIT
cat >"$fake/gh" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${FAKE_GH_LOG:?}"
exit 0
EOF
chmod +x "$fake/gh"

expect_exit AC-HS-12 0 env PATH="$fake:$PATH" FAKE_GH_LOG="$fake/log" \
	GITHUB_SHA="$MAIN40" RELAY_HEAD_SHA="$HEAD40" \
	GITHUB_REPOSITORY=acme/relay GH_TOKEN=test-token \
	"$publish" 'guards / approver' success 'trusted check on the PR head'
expect_contains AC-HS-13 "$HEAD40" "$(cat "$fake/log")"
expect_omits AC-HS-14 "$MAIN40" "$(cat "$fake/log")"
expect_contains AC-HS-15 "repos/acme/relay/statuses/${HEAD40}" "$(cat "$fake/log")"

# Missing RELAY_HEAD_SHA: do not post to GITHUB_SHA.
: >"$fake/log"
expect_exit AC-HS-16 1 env PATH="$fake:$PATH" FAKE_GH_LOG="$fake/log" \
	GITHUB_SHA="$MAIN40" GITHUB_REPOSITORY=acme/relay GH_TOKEN=test-token \
	"$publish" 'guards / approver' success 'no'
if [ -s "$fake/log" ]; then
	bad AC-HS-17 'posted a status without RELAY_HEAD_SHA'
else
	ok AC-HS-17
fi

finish
