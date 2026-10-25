#!/usr/bin/env bash
# AC-CI: ci.yml re-runs local checks; guards.yml holds secret-bearing jobs.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"
wf="$ROOT/.github/workflows/ci.yml"
gw="$ROOT/.github/workflows/guards.yml"

[ -f "$wf" ] && ok AC-CI-01 || bad AC-CI-01 'ci.yml missing'
[ -f "$gw" ] && ok AC-CI-01b || bad AC-CI-01b 'guards.yml missing'

if grep -q 'pull_request.head.sha' "$gw"; then
	ok AC-CI-02
else
	bad AC-CI-02 'guards workflow does not bind to pull_request.head.sha'
fi

if grep -q 'secrets.RELAY_DENYLIST' "$gw" && ! grep -q 'RELAY_DENYLIST' "$wf"; then
	ok AC-CI-03
else
	bad AC-CI-03 'RELAY_DENYLIST must live only in the trusted guards workflow'
fi

if grep -n 'RELAY_DENYLIST:' "$gw" | grep -v 'secrets.RELAY_DENYLIST' >/dev/null; then
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

for job in script-tests local-checks gitleaks jscpd line-budget rules-frontmatter; do
	if grep -q "^  ${job}:" "$wf"; then
		ok "AC-CI-07-${job}"
	else
		bad "AC-CI-07-${job}" "missing job ${job} in ci.yml"
	fi
done

if grep -q "^  denylist:" "$gw"; then
	ok AC-CI-07-denylist
else
	bad AC-CI-07-denylist 'missing job denylist in guards.yml'
fi
if grep -q "^  denylist:" "$wf"; then
	bad AC-CI-07-denylist-untrusted 'denylist must not run from the PR-controlled ci.yml'
else
	ok AC-CI-07-denylist-untrusted
fi

for job in label-guard approver; do
	if grep -q "job: ${job}" "$gw"; then
		ok "AC-CI-07-${job}"
	else
		bad "AC-CI-07-${job}" "missing ${job} in guards.yml"
	fi
	if grep -qE "^  ${job}:|${job}\\.sh" "$wf"; then
		bad "AC-CI-07-${job}-untrusted" "${job} must not run from the PR-controlled ci.yml"
	else
		ok "AC-CI-07-${job}-untrusted"
	fi
done

if grep -q 'pull_request_review' "$wf" && grep -q 'workflow_run' "$gw"; then
	ok AC-CI-08
else
	bad AC-CI-08 'ci.yml must still run on reviews so workflow_run can re-check approval'
fi

if grep -q 'gitleaks-action' "$wf" "$gw"; then
	bad AC-CI-09 'gitleaks-action needs an org license; use the OSS CLI'
else
	ok AC-CI-09
fi

# Workflow must not inject fixtures or eval mode; CI=true ignores eval anyway.
if grep -qE 'RELAY_LABELS|RELAY_REVIEWS|RELAY_CHECK_MODE=eval|RELAY_CHECK_MODE:[[:space:]]*eval' "$wf" "$gw"; then
	bad AC-CI-10 'CI must not set RELAY_LABELS*, RELAY_REVIEWS*, or RELAY_CHECK_MODE=eval'
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
	# checkout must pin base / default branch, never the PR head as the workspace.
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

# materialize-pr-head is fail-closed without a full SHA / repo.
expect_exit AC-CI-18 1 "$CHECKS/materialize-pr-head.sh" '' /tmp/relay-empty
expect_exit AC-CI-19 1 env -u GITHUB_REPOSITORY -u GH_REPO \
	"$CHECKS/materialize-pr-head.sh" aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa /tmp/relay-empty

finish
