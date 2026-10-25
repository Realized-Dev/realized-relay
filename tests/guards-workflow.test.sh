#!/usr/bin/env bash
# AC-CI: guards.yml is the trusted base-branch workflow. This split PR
# does not ship ci.yml; #3 keeps the PR-controlled checks.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"
gw="$ROOT/.github/workflows/guards.yml"

[ -f "$gw" ] && ok AC-CI-01 || bad AC-CI-01 'guards.yml missing'
if [ -f "$ROOT/.github/workflows/ci.yml" ]; then
	bad AC-CI-01b 'this split must not include the PR-controlled ci.yml'
else
	ok AC-CI-01b
fi

if grep -q 'pull_request.head.sha' "$gw"; then
	ok AC-CI-02
else
	bad AC-CI-02 'guards workflow does not bind to pull_request.head.sha'
fi

if grep -q 'secrets.RELAY_DENYLIST' "$gw"; then
	ok AC-CI-03
else
	bad AC-CI-03 'denylist job does not read secrets.RELAY_DENYLIST'
fi

if grep -n 'RELAY_DENYLIST:' "$gw" | grep -v 'secrets.RELAY_DENYLIST' >/dev/null; then
	bad AC-CI-04 'RELAY_DENYLIST is assigned from something other than the secret'
else
	ok AC-CI-04
fi

if grep -q "^  denylist:" "$gw"; then
	ok AC-CI-07-denylist
else
	bad AC-CI-07-denylist 'missing job denylist in guards.yml'
fi

for job in label-guard approver; do
	if grep -q "job: ${job}" "$gw"; then
		ok "AC-CI-07-${job}"
	else
		bad "AC-CI-07-${job}" "missing ${job} in guards.yml"
	fi
done

if grep -q 'workflow_run' "$gw" && grep -q 'workflows: \[ci\]' "$gw"; then
	ok AC-CI-08
else
	bad AC-CI-08 'guards.yml must re-run approval after the ci workflow completes'
fi

if grep -q 'gitleaks-action' "$gw"; then
	bad AC-CI-09 'gitleaks-action needs an org license; use the OSS CLI'
else
	ok AC-CI-09
fi

if grep -qE 'RELAY_LABELS|RELAY_REVIEWS|RELAY_CHECK_MODE=eval|RELAY_CHECK_MODE:[[:space:]]*eval' "$gw"; then
	bad AC-CI-10 'guards.yml must not set RELAY_LABELS*, RELAY_REVIEWS*, or RELAY_CHECK_MODE=eval'
else
	expect_exit AC-CI-10 1 env CI=true RELAY_CHECK_MODE=eval RELAY_LABELS=security \
		"$CHECKS/label-guard.sh"
fi

if grep -q 'pull_request_target' "$gw"; then
	ok AC-CI-11
else
	bad AC-CI-11 'guards.yml must use pull_request_target'
fi

if grep -q 'persist-credentials: false' "$gw" && ! grep -q 'npm' "$gw"; then
	ok AC-CI-12
else
	bad AC-CI-12 'guards.yml must persist no credentials and must not run npm'
fi

if grep -n 'echo' "$gw" | grep -q 'RELAY_DENYLIST'; then
	bad AC-CI-13 'guards.yml must never echo RELAY_DENYLIST'
else
	ok AC-CI-13
fi

if grep -Eq 'contents: write|pull-requests: write|id-token:' "$gw"; then
	bad AC-CI-14 'guards.yml must stay least-privilege (read only)'
else
	ok AC-CI-14
fi

if grep -q 'materialize-pr-head.sh' "$gw" && grep -q 'actions/checkout@v4' "$gw"; then
	if grep -E 'ref:.*head\.sha' "$gw"; then
		bad AC-CI-15 'guards.yml must not check the PR head out over trusted scripts'
	else
		ok AC-CI-15
	fi
else
	bad AC-CI-15 'guards.yml must check out base scripts and materialize the head as data'
fi

if grep -q 'docs/guard-workflow.md' "$gw" && [ -f "$ROOT/docs/guard-workflow.md" ]; then
	ok AC-CI-16
else
	bad AC-CI-16 'docs/guard-workflow.md must explain that edits apply only after merge to main'
fi

if grep -Eiq 'merged to `?main`?' "$ROOT/docs/guard-workflow.md"; then
	ok AC-CI-17
else
	bad AC-CI-17 'guard docs must say changes take effect once merged to main'
fi

expect_exit AC-CI-18 1 "$CHECKS/materialize-pr-head.sh" '' /tmp/relay-empty
expect_exit AC-CI-19 1 env -u GITHUB_REPOSITORY -u GH_REPO \
	"$CHECKS/materialize-pr-head.sh" aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa /tmp/relay-empty

finish
