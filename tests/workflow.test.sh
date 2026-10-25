#!/usr/bin/env bash
# AC-CI: the workflow re-runs local checks and pins fail-closed, secret-only extras.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"
wf="$ROOT/.github/workflows/ci.yml"

[ -f "$wf" ] && ok AC-CI-01 || bad AC-CI-01 'ci.yml missing'

if grep -q 'pull_request.head.sha' "$wf"; then
	ok AC-CI-02
else
	bad AC-CI-02 'workflow does not bind RELAY_HEAD_SHA to pull_request.head.sha'
fi

if grep -q 'secrets.RELAY_DENYLIST' "$wf"; then
	ok AC-CI-03
else
	bad AC-CI-03 'denylist job does not read secrets.RELAY_DENYLIST'
fi

if grep -n 'RELAY_DENYLIST:' "$wf" | grep -v 'secrets.RELAY_DENYLIST' >/dev/null; then
	bad AC-CI-04 'RELAY_DENYLIST is assigned from something other than the secret'
else
	ok AC-CI-04
fi

if grep -q 'log-opts=--all' "$wf" || grep -q 'log-opts: --all' "$wf" || grep -q '\-\-log-opts=--all' "$wf"; then
	ok AC-CI-05
else
	bad AC-CI-05 'gitleaks is not asked for a full-history scan'
fi

if grep -q 'min-tokens 50' "$wf" && grep -q 'min-lines 10' "$wf"; then
	ok AC-CI-06
else
	bad AC-CI-06 'jscpd thresholds are not 50 tokens / 10 lines'
fi

for job in script-tests local-checks gitleaks jscpd line-budget rules-frontmatter denylist label-guard approver; do
	if grep -q "^  ${job}:" "$wf"; then
		ok "AC-CI-07-${job}"
	else
		bad "AC-CI-07-${job}" "missing job ${job}"
	fi
done

if grep -q 'pull_request_review' "$wf"; then
	ok AC-CI-08
else
	bad AC-CI-08 'approver job will not re-run when a review is submitted'
fi

if grep -q 'gitleaks-action' "$wf"; then
	bad AC-CI-09 'gitleaks-action needs an org license; use the OSS CLI'
else
	ok AC-CI-09
fi

# Workflow must not inject fixtures or eval mode; CI=true ignores eval anyway.
if grep -qE 'RELAY_LABELS|RELAY_REVIEWS|RELAY_CHECK_MODE=eval|RELAY_CHECK_MODE:[[:space:]]*eval' "$wf"; then
	bad AC-CI-10 'CI must not set RELAY_LABELS*, RELAY_REVIEWS*, or RELAY_CHECK_MODE=eval'
else
	# Behavioral: eval fixtures are ignored when CI=true.
	expect_exit AC-CI-10 1 env CI=true RELAY_CHECK_MODE=eval RELAY_LABELS=security \
		"$CHECKS/label-guard.sh"
fi

finish
