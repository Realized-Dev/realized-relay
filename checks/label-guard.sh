#!/bin/sh
# Fail-closed PR label reader for the sensitive-label set.
# Exit 0 when labels were read successfully (gated or not).
# Exit 1 when labels cannot be trusted (empty fetch, API error, bad JSON, missing CI inputs).
# --gated-only prints "yes" or "no" on stdout and keeps diagnostics on stderr.

set -eu

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$here/lib.sh"

gated_only=0
if [ "${1:-}" = --gated-only ]; then
	gated_only=1
fi

emit() {
	if [ "$gated_only" -eq 1 ]; then
		printf '%s\n' "$1"
	fi
}

collect_names() {
	# Prints one normalized-from-raw name per line (raw, not yet normalized).
	# RELAY_LABELS* are test-only and are ignored when CI=true (N3).
	if relay_allow_eval_overrides && [ -n "${RELAY_LABELS+x}" ]; then
		printf '%s\n' "$RELAY_LABELS"
		return 0
	fi

	_json=
	if relay_allow_eval_overrides && [ -n "${RELAY_LABELS_JSON+x}" ]; then
		_json=$RELAY_LABELS_JSON
	else
		_mode=$(relay_check_mode)
		if [ "$_mode" = hook ]; then
			if ! relay_have_cmd gh; then
				relay_notice "gh not available; no pull request labels to read"
				return 2
			fi
			_err=$(mktemp)
			if ! _view=$(gh pr view --json number,labels 2>"$_err"); then
				_msg=$(cat "$_err" 2>/dev/null || true)
				rm -f "$_err"
				# Only the "no PR yet" case is skippable; any other gh failure is closed.
				if printf '%s' "$_msg" | grep -qi 'no pull request'; then
					relay_notice "no pull request for this branch; skipping label guard"
					return 2
				fi
				relay_die "gh pr view failed (fail closed)"
			fi
			rm -f "$_err"
			if [ -z "$_view" ]; then
				relay_die "empty gh pr view output (fail closed)"
			fi
			_json=$_view
		else
			_repo=$(relay_repo)
			_pr=$(relay_pr_number)
			[ -n "$_repo" ] || relay_die "missing GITHUB_REPOSITORY (fail closed)"
			[ -n "$_pr" ] || relay_die "missing pull request number (fail closed)"
			relay_token_present || relay_die "missing GitHub token (fail closed)"
			relay_have_cmd gh || relay_die "gh is required to read labels (fail closed)"
			if ! _json=$(gh api "repos/${_repo}/pulls/${_pr}" --jq '{labels:[.labels[].name]}'); then
				relay_die "GitHub label API failed (fail closed)"
			fi
			if [ -z "$_json" ]; then
				relay_die "empty GitHub label API output (fail closed)"
			fi
		fi
	fi

	relay_require_jq
	# Reject anything that is not an object/array we recognize.
	if ! printf '%s' "$_json" | jq -e 'type == "object" or type == "array"' >/dev/null 2>&1; then
		relay_die "unparseable labels JSON (fail closed)"
	fi
	if ! printf '%s' "$_json" | jq -e '
		(type == "object" and has("labels"))
		or (type == "array")
	' >/dev/null 2>&1; then
		relay_die "labels JSON missing labels key (fail closed)"
	fi
	if ! printf '%s' "$_json" | jq -r '
		if type == "array" then
			if length == 0 then empty
			elif (.[0] | type) == "string" then .[]
			elif (.[0] | type) == "object" then .[].name // empty
			else error("unrecognized labels array")
			end
		else
			.labels[] | if type == "string" then . else .name // empty end
		end
	'; then
		relay_die "failed to extract label names (fail closed)"
	fi
}

names=$(collect_names) || {
	_st=$?
	if [ "$_st" -eq 2 ]; then
		emit no
		exit 0
	fi
	exit "$_st"
}

matched=
gated=no
# Preserve raw lines (including blanks) so padded names still normalize.
while IFS= read -r _raw || [ -n "${_raw:-}" ]; do
	[ -z "$_raw" ] && continue
	_norm=$(relay_normalize_label "$_raw")
	[ -z "$_norm" ] && continue
	if relay_is_gated_label "$_norm"; then
		gated=yes
		if [ -z "$matched" ]; then
			matched=$_norm
		else
			matched="$matched,$_norm"
		fi
	fi
done <<EOF
$names
EOF

if [ "$gated_only" -eq 1 ]; then
	emit "$gated"
	exit 0
fi

printf 'label-guard: labels readable\n'
printf 'gated: %s\n' "$gated"
if [ "$gated" = yes ]; then
	printf 'matched: %s\n' "$matched"
fi
exit 0
