#!/bin/sh
# Required-approver check, tied to the current head SHA.
# Fail closed: missing SHA, unread labels, API errors, empty output,
# stale approval, dismissed/comment-only reviews, or any reviewer's
# latest APPROVED/CHANGES_REQUESTED decision being CHANGES_REQUESTED
# (any SHA). That reviewer's later APPROVED on the current head clears it,
# matching GitHub. COMMENTED does not clear a changes-requested decision.

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
	# RELAY_REVIEWS* are test-only and are ignored when CI=true (N3).
	if relay_allow_eval_overrides && [ -n "${RELAY_REVIEWS+x}" ]; then
		printf '%s\n' "$RELAY_REVIEWS"
		return 0
	fi

	_json=
	if relay_allow_eval_overrides && [ -n "${RELAY_REVIEWS_JSON+x}" ]; then
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
		if [ "$mode" != hook ]; then
			relay_token_present || relay_die "missing GitHub token (fail closed)"
		fi
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

# Only write / maintain / admin reviews count (not author_association).
reviewer_permission_ok() {
	_login=$1
	[ -n "$_login" ] || return 1
	if relay_allow_eval_overrides; then
		if [ -n "${RELAY_REVIEWER_PERMS+x}" ]; then
			_p=$(printf '%s\n' "$RELAY_REVIEWER_PERMS" | awk -F= -v u="$_login" '
				$1 == u { print $2; exit }
			')
			case "$_p" in
			write|maintain|admin) return 0 ;;
			esac
			return 1
		fi
		return 0
	fi
	_repo=$(relay_repo)
	[ -n "$_repo" ] || return 1
	relay_have_cmd gh || return 1
	_p=$(gh api "repos/${_repo}/collaborators/${_login}/permission" --jq '.permission' 2>/dev/null || true)
	case "$_p" in
	write|maintain|admin) return 0 ;;
	esac
	return 1
}

_filtered=
while IFS= read -r _rev || [ -n "${_rev:-}" ]; do
	[ -z "$_rev" ] && continue
	_who=$(printf '%s' "$_rev" | awk -F '	' '{ print $2 }')
	if reviewer_permission_ok "$_who"; then
		_filtered="${_filtered}${_rev}
"
	fi
done <<EOF
$tsv
EOF
tsv=$_filtered

# Latest APPROVED / CHANGES_REQUESTED decision per user (COMMENTED ignored).
# Highest numeric id wins. A CR on an older SHA stays outstanding until
# that same reviewer later APPROVES the current head.
latest=$(printf '%s\n' "$tsv" | awk -F '	' '
	NF < 4 { next }
	{
		id = $1 + 0
		user = $2
		state = $3
		if (user == "") next
		if (state != "APPROVED" && state != "CHANGES_REQUESTED") next
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
outstanding=0
while IFS= read -r _line || [ -n "${_line:-}" ]; do
	[ -z "$_line" ] && continue
	_state=$(printf '%s' "$_line" | awk -F '	' '{ print $3 }')
	_sha=$(relay_normalize_sha "$(printf '%s' "$_line" | awk -F '	' '{ print $4 }')")
	if [ "$_state" = CHANGES_REQUESTED ]; then
		outstanding=1
	fi
	if [ "$_state" = APPROVED ] && [ "$_sha" = "$head" ] && relay_is_full_sha "$_sha"; then
		approved=1
	fi
done <<EOF
$latest
EOF

printf 'approver: required (gated labels present)\n'
printf 'head: %s\n' "$head"
if [ "$outstanding" -eq 1 ]; then
	relay_err "result: CHANGES_REQUESTED still outstanding (reviewer must approve the current head SHA)"
	exit 1
fi
if [ "$approved" -eq 1 ]; then
	printf 'result: APPROVED review on the current head SHA\n'
	exit 0
fi
relay_err "result: no APPROVED review on the current head SHA (fail closed)"
exit 1
