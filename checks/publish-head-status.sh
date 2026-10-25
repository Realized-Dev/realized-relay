#!/bin/sh
# Post a commit status on RELAY_HEAD_SHA only.
# Never posts to GITHUB_SHA (that is main on workflow_run).
# Usage: publish-head-status.sh <context> <state> <description>

set -eu
set +x

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$here/lib.sh"

context=${1:-}
state=${2:-}
desc=${3:-}

[ -n "$context" ] || relay_die "publish-head-status: context is required"
case "$state" in
success|failure|error|pending) ;;
*) relay_die "publish-head-status: state must be success, failure, error, or pending" ;;
esac

head=$(relay_head_sha)
if ! relay_is_full_sha "$head"; then
	relay_die "publish-head-status: RELAY_HEAD_SHA must be a full 40-char SHA"
fi

repo=$(relay_repo)
[ -n "$repo" ] || relay_die "publish-head-status: missing GITHUB_REPOSITORY"
relay_have_cmd gh || relay_die "publish-head-status: gh is required"
relay_token_present || relay_die "publish-head-status: missing GitHub token"

# Path is repos/{repo}/statuses/{RELAY_HEAD_SHA} — never GITHUB_SHA.
if ! gh api --method POST "repos/${repo}/statuses/${head}" \
	-f state="$state" \
	-f context="$context" \
	-f description="$desc" >/dev/null; then
	relay_die "publish-head-status: status API failed"
fi

printf 'publish-head-status: %s %s on %s\n' "$context" "$state" "$head"
exit 0
