#!/usr/bin/env bash
# AC-CI: ci.yml re-runs local checks. Trusted guards live on main
# (.github/workflows/guards.yml) and are not asserted here.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"
wf="$ROOT/.github/workflows/ci.yml"

[ -f "$wf" ] && ok AC-CI-01 || bad AC-CI-01 'ci.yml missing'

if grep -q 'RELAY_DENYLIST' "$wf"; then
	bad AC-CI-03 'RELAY_DENYLIST must not appear in the PR-controlled ci.yml'
else
	ok AC-CI-03
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

# guards.yml is owned by main. jscpd must not force this PR to rewrite it.
if grep -q 'guards.yml' "$wf" && grep -q -- '--ignore' "$wf"; then
	ok AC-CI-06b
else
	bad AC-CI-06b 'jscpd must ignore the trusted guards.yml from main'
fi

for job in script-tests local-checks gitleaks jscpd line-budget rules-frontmatter; do
	if grep -q "^  ${job}:" "$wf"; then
		ok "AC-CI-07-${job}"
	else
		bad "AC-CI-07-${job}" "missing job ${job} in ci.yml"
	fi
done

if grep -q "^  denylist:" "$wf"; then
	bad AC-CI-07-denylist-untrusted 'denylist must not run from the PR-controlled ci.yml'
else
	ok AC-CI-07-denylist-untrusted
fi

for job in label-guard approver; do
	if grep -qE "^  ${job}:|${job}\\.sh" "$wf"; then
		bad "AC-CI-07-${job}-untrusted" "${job} must not run from the PR-controlled ci.yml"
	else
		ok "AC-CI-07-${job}-untrusted"
	fi
done

if grep -q 'pull_request_review' "$wf"; then
	ok AC-CI-08
else
	bad AC-CI-08 'ci.yml must still run on reviews so the base-branch guards can re-check approval'
fi

if grep -q 'gitleaks-action' "$wf"; then
	bad AC-CI-09 'gitleaks-action needs an org license; use the OSS CLI'
else
	ok AC-CI-09
fi

if grep -qE 'RELAY_LABELS|RELAY_REVIEWS|RELAY_CHECK_MODE=eval|RELAY_CHECK_MODE:[[:space:]]*eval' "$wf"; then
	bad AC-CI-10 'ci.yml must not set RELAY_LABELS*, RELAY_REVIEWS*, or RELAY_CHECK_MODE=eval'
else
	expect_exit AC-CI-10 1 env CI=true RELAY_CHECK_MODE=eval RELAY_LABELS=security \
		"$CHECKS/label-guard.sh"
fi

if grep -n 'echo' "$wf" | grep -q 'RELAY_DENYLIST'; then
	bad AC-CI-13 'ci.yml must never echo RELAY_DENYLIST'
else
	ok AC-CI-13
fi

if grep -Eq 'contents: write|pull-requests: write|id-token:' "$wf"; then
	bad AC-CI-14 'ci.yml must stay least-privilege (no contents/PR write, no id-token)'
else
	ok AC-CI-14
fi

finish
