#!/bin/sh
# Resolve the PR head SHA and number for the trusted guards workflow.
# Never uses GITHUB_SHA (that is main on workflow_run / pull_request_target).
# Prints GitHub Actions outputs: head_sha=... and pr_number=...
# Usage: invoked from guards.yml with event fields in the environment.

set -eu
set +x

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$here/lib.sh"

emit() {
	printf 'head_sha=%s\n' "$1"
	printf 'pr_number=%s\n' "$2"
}

pr_head=$(relay_normalize_sha "${RELAY_PR_HEAD_SHA:-}")
wf_head=$(relay_normalize_sha "${RELAY_WORKFLOW_HEAD_SHA:-}")
pr_num=$(printf '%s' "${RELAY_PR_NUMBER:-}" | relay_trim)
github_sha=$(relay_normalize_sha "${GITHUB_SHA:-}")

head=
if relay_is_full_sha "$pr_head"; then
	head=$pr_head
elif relay_is_full_sha "$wf_head"; then
	head=$wf_head
else
	relay_die "resolve-guard-context: missing PR head SHA (will not use GITHUB_SHA)"
fi

if [ -n "$github_sha" ] && [ "$head" = "$github_sha" ] && [ "$pr_head" != "$github_sha" ] && [ "$wf_head" != "$github_sha" ]; then
	relay_die "resolve-guard-context: refused to treat GITHUB_SHA as the PR head"
fi

if [ -n "$pr_num" ]; then
	emit "$head" "$pr_num"
	exit 0
fi

# workflow_run: github.event.workflow_run.pull_requests can be empty (forks).
# Resolve the PR from the head SHA through the API.
repo=$(relay_repo)
[ -n "$repo" ] || relay_die "resolve-guard-context: missing GITHUB_REPOSITORY"

_json=
if [ -n "${RELAY_COMMITS_PULLS_JSON+x}" ] && ! relay_ci_claimed; then
	_json=$RELAY_COMMITS_PULLS_JSON
else
	relay_have_cmd gh || relay_die "resolve-guard-context: gh is required to resolve the PR"
	relay_token_present || relay_die "resolve-guard-context: missing GitHub token"
	if ! _json=$(gh api "repos/${repo}/commits/${head}/pulls"); then
		relay_die "resolve-guard-context: commits-pulls API failed"
	fi
fi

[ -n "$_json" ] || relay_die "resolve-guard-context: empty commits-pulls payload"
relay_require_jq
pr_num=$(printf '%s' "$_json" | jq -r '
	if type != "array" then error("not an array")
	else (map(.number) | map(select(. != null)) | first // empty)
	end
' 2>/dev/null || true)

[ -n "$pr_num" ] || relay_die "resolve-guard-context: no pull request for the head SHA"

emit "$head" "$pr_num"
exit 0
