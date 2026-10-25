#!/usr/bin/env bash
# AC-HS: workflow_run results land on the PR head SHA, never on main.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"

HEAD40='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
OTHER40='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
MAIN40='cccccccccccccccccccccccccccccccccccccccc'
resolve="$CHECKS/resolve-guard-context.sh"
publish="$CHECKS/publish-head-status.sh"

# One exact match: open, head.sha == SHA, base repo == this repo.
exact9=$(printf '{"number":9,"state":"open","head":{"sha":"%s","repo":{"full_name":"fork/relay"}},"base":{"repo":{"full_name":"acme/relay"}}}' "$HEAD40")
# Other-base (or a PR opened on a fork's own default branch).
otherbase=$(printf '{"number":3,"state":"open","head":{"sha":"%s","repo":{"full_name":"fork/relay"}},"base":{"repo":{"full_name":"fork/relay"}}}' "$HEAD40")
# Second exact match (ambiguous).
exact10=$(printf '{"number":10,"state":"open","head":{"sha":"%s","repo":{"full_name":"acme/relay"}},"base":{"repo":{"full_name":"acme/relay"}}}' "$HEAD40")
# Open but head.sha does not match.
wronghead=$(printf '{"number":8,"state":"open","head":{"sha":"%s","repo":{"full_name":"acme/relay"}},"base":{"repo":{"full_name":"acme/relay"}}}' "$OTHER40")
# Merged/closed with the same SHA and base.
closed9=$(printf '{"number":9,"state":"closed","head":{"sha":"%s","repo":{"full_name":"acme/relay"}},"base":{"repo":{"full_name":"acme/relay"}}}' "$HEAD40")

resolve_wf() {
	env -u CI -u GITHUB_ACTIONS GITHUB_SHA="$MAIN40" \
		RELAY_WORKFLOW_HEAD_SHA="$HEAD40" GITHUB_REPOSITORY=acme/relay \
		RELAY_COMMITS_PULLS_JSON="$1" "$resolve"
}

# pull_request_target: explicit head wins over GITHUB_SHA (main).
expect_exit AC-HS-01 0 env GITHUB_SHA="$MAIN40" RELAY_PR_HEAD_SHA="$HEAD40" \
	RELAY_PR_NUMBER=4 GITHUB_REPOSITORY=acme/relay "$resolve"
expect_contains AC-HS-02 "head_sha=$HEAD40"
expect_contains AC-HS-03 'pr_number=4'
expect_omits AC-HS-04 "$MAIN40"

# workflow_run: one exact match from the commits API fixture.
expect_exit AC-HS-05 0 resolve_wf "[${exact9}]"
expect_contains AC-HS-06 "head_sha=$HEAD40"
expect_contains AC-HS-07 'pr_number=9'
expect_omits AC-HS-08 "$MAIN40"

# No head at all: fail. Do not fall back to GITHUB_SHA.
expect_exit AC-HS-09 1 env GITHUB_SHA="$MAIN40" GITHUB_REPOSITORY=acme/relay "$resolve"
expect_contains AC-HS-10 'will not use GITHUB_SHA'

# Zero matches: empty pulls list (fail closed).
expect_exit AC-HS-11 1 resolve_wf '[]'
expect_contains AC-HS-11-msg 'expected exactly one matching open PR (got 0)'

# One exact match already covered by AC-HS-05. Several exact matches: fail closed.
expect_exit AC-HS-18 1 resolve_wf "[${exact9},${exact10}]"
expect_contains AC-HS-18-msg 'expected exactly one matching open PR (got 2)'

# Other-base only (PR targeting a fork / other repo): not a match.
expect_exit AC-HS-19 1 resolve_wf "[${otherbase}]"
expect_contains AC-HS-19-msg 'expected exactly one matching open PR (got 0)'

# Fork head with this repo as base, plus an other-base PR: accept the one match.
expect_exit AC-HS-20 0 resolve_wf "[${otherbase},${exact9}]"
expect_contains AC-HS-20-num 'pr_number=9'
expect_omits AC-HS-20-other 'pr_number=3'

# Closed/merged PR with the same SHA is not a match.
expect_exit AC-HS-21 1 resolve_wf "[${closed9}]"
expect_contains AC-HS-21-msg 'expected exactly one matching open PR (got 0)'

# Open PR whose head.sha is a different commit is not a match.
expect_exit AC-HS-22 1 resolve_wf "[${wronghead}]"
expect_contains AC-HS-22-msg 'expected exactly one matching open PR (got 0)'

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
