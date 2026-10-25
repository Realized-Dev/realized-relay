#!/bin/sh
# Required-approver check, tied to the current head SHA.
# Fail closed: missing SHA, unread labels, API errors, empty output,
# stale approval, dismissed/comment-only reviews, or a later
# changes-requested review from the same user.
# When no gated label is present and labels were read, approval is not required.

set -eu

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$here/lib.sh"

head=$(relay_head_sha)
mode=$(relay_check_mode)

if [ "$mode" = hook ] && [ -z "$head" ]; then
	head=$(relay_normalize_sha "$(git rev-parse HEAD 2>/dev/null || true)")
fi

if [ -z "$head" ]; then
	relay_die "missing RELAY_HEAD_SHA (fail closed)"
fi
if ! relay_is_full_sha "$head"; then
	relay_die "RELAY_HEAD_SHA is not a full 40-char SHA (fail closed)"
fi

# Reuse the label guard so padding/case/API failures stay consistent.
if ! gated=$("$here/label-guard.sh" --gated-only); then
	relay_die "cannot read labels for approver check (fail closed)"
fi
case "$gated" in
yes|no) ;;
*) relay_die "label guard returned an unusable gated flag (fail closed)" ;;
esac

if [ "$gated" = no ]; then
	relay_notice "no gated labels; required-approver step is not needed"
	exit 0
fi

collect_reviews_tsv() {
	if [ -n "${RELAY_REVIEWS+x}" ]; then
		printf '%s\n' "$RELAY_REVIEWS"
		return 0
	fi

	_json=
	if [ -n "${RELAY_REVIEWS_JSON+x}" ]; then
		_json=$RELAY_REVIEWS_JSON
	else
		if [ "$mode" = hook ]; then
			if ! relay_have_cmd gh; then
				relay_die "gh is required to read reviews (fail closed)"
			fi
			_pr=$(gh pr view --json number --jq '.number' 2>/dev/null || true)
			if [ -z "$_pr" ]; then
				relay_die "gated pull request but reviews could not be resolved (fail closed)"
			fi
			_repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || relay_repo)
		else
			_repo=$(relay_repo)
			_pr=$(relay_pr_number)
		fi
		[ -n "$_repo" ] || relay_die "missing GITHUB_REPOSITORY (fail closed)"
		[ -n "$_pr" ] || relay_die "missing pull request number (fail closed)"
		relay_token_present || relay_die "missing GitHub token (fail closed)"
		relay_have_cmd gh || relay_die "gh is required to read reviews (fail closed)"
		# Paginate, then slurp into one array. Empty page stream becomes [].
		if ! _stream=$(gh api --paginate "repos/${_repo}/pulls/${_pr}/reviews" --jq '.[]'); then
			relay_die "GitHub reviews API failed (fail closed)"
		fi
		relay_require_jq
		_json=$(printf '%s\n' "$_stream" | jq -s '.')
	fi

	if [ -z "$_json" ]; then
		relay_die "empty reviews payload (fail closed)"
	fi
	relay_require_jq
	if ! printf '%s' "$_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
		relay_die "reviews JSON is not an array (fail closed)"
	fi
	printf '%s' "$_json" | jq -r '
		.[]
		| select((.state // "") != "PENDING")
		| [(.id|tostring), (.user.login // ""), (.state // ""), (.commit_id // ""), (.submitted_at // "")]
		| @tsv
	'
}

tsv=$(collect_reviews_tsv) || exit 1

# Latest submitted review per user (highest numeric id wins).
latest=$(printf '%s\n' "$tsv" | awk -F '	' '
	NF < 4 { next }
	{
		id = $1 + 0
		user = $2
		if (user == "") next
		if (!(user in seen) || id >= seen[user]) {
			seen[user] = id
			rec[user] = $0
		}
	}
	END {
		for (u in rec) print rec[u]
	}
')

approved=0
while IFS= read -r _line || [ -n "${_line:-}" ]; do
	[ -z "$_line" ] && continue
	_state=$(printf '%s' "$_line" | awk -F '	' '{ print $3 }')
	_sha=$(relay_normalize_sha "$(printf '%s' "$_line" | awk -F '	' '{ print $4 }')")
	if [ "$_state" = APPROVED ] && [ "$_sha" = "$head" ]; then
		if relay_is_full_sha "$_sha"; then
			approved=1
			break
		fi
	fi
done <<EOF
$latest
EOF

printf 'approver: required (gated labels present)\n'
printf 'head: %s\n' "$head"
if [ "$approved" -eq 1 ]; then
	printf 'result: APPROVED review on the current head SHA\n'
	exit 0
fi
relay_err "result: no APPROVED review on the current head SHA (fail closed)"
exit 1
