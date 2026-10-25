#!/usr/bin/env bash
# AC-AP: required approver is fail-closed and bound to the current head SHA.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"
ap="$CHECKS/approver-check.sh"

HEAD40='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
OTHER='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
SHORT='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'

approved_on() {
	# id, login, state, commit, submitted_at as TSV (RELAY_REVIEWS)
	printf '10\talice\tAPPROVED\t%s\t2026-10-01T00:00:00Z\n' "$1"
}

expect_exit AC-AP-01 1 env RELAY_LABELS=security RELAY_CHECK_MODE=eval "$ap"
expect_exit AC-AP-02 1 env RELAY_LABELS=security RELAY_HEAD_SHA=not-a-sha RELAY_CHECK_MODE=eval "$ap"
expect_exit AC-AP-03 1 env RELAY_LABELS=security RELAY_HEAD_SHA="$SHORT" RELAY_CHECK_MODE=eval "$ap"

expect_exit AC-AP-04 1 env RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS_JSON='' RELAY_CHECK_MODE=eval "$ap"
expect_exit AC-AP-05 1 env RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS_JSON='{"oops":true}' RELAY_CHECK_MODE=eval "$ap"
expect_exit AC-AP-06 1 env RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS_JSON='[]' RELAY_CHECK_MODE=eval "$ap"

expect_exit AC-AP-07 1 env RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$(approved_on "$OTHER")" RELAY_CHECK_MODE=eval "$ap"

expect_exit AC-AP-08 0 env RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$(approved_on "$HEAD40")" RELAY_CHECK_MODE=eval "$ap"
expect_contains AC-AP-09 'APPROVED review on the current head SHA'

expect_exit AC-AP-10 1 env RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$(printf '11\talice\tCOMMENTED\t%s\t2026-10-01T00:00:00Z\n' "$HEAD40")" \
	RELAY_CHECK_MODE=eval "$ap"

expect_exit AC-AP-11 1 env RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$(printf '12\talice\tDISMISSED\t%s\t2026-10-01T00:00:00Z\n' "$HEAD40")" \
	RELAY_CHECK_MODE=eval "$ap"

expect_exit AC-AP-12 1 env RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$(printf '13\talice\tCHANGES_REQUESTED\t%s\t2026-10-01T00:00:00Z\n' "$HEAD40")" \
	RELAY_CHECK_MODE=eval "$ap"

# Approve, then the same user requests changes on the same SHA: latest wins.
stale_flip=$(printf '%s\n%s\n' \
	"20	alice	APPROVED	${HEAD40}	2026-10-01T00:00:00Z" \
	"21	alice	CHANGES_REQUESTED	${HEAD40}	2026-10-02T00:00:00Z")
expect_exit AC-AP-13 1 env RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$stale_flip" RELAY_CHECK_MODE=eval "$ap"

# Two reviewers: stale approve from one, current approve from another.
two=$(printf '%s\n%s\n' \
	"30	alice	APPROVED	${OTHER}	2026-10-01T00:00:00Z" \
	"31	bob	APPROVED	${HEAD40}	2026-10-02T00:00:00Z")
expect_exit AC-AP-14 0 env RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$two" RELAY_CHECK_MODE=eval "$ap"

expect_exit AC-AP-15 0 env RELAY_LABELS='bug' RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS_JSON='[]' RELAY_CHECK_MODE=eval "$ap"
expect_contains AC-AP-16 'not needed'

expect_exit AC-AP-17 1 env -u RELAY_LABELS RELAY_LABELS_JSON='not-json' \
	RELAY_HEAD_SHA="$HEAD40" RELAY_REVIEWS_JSON='[]' RELAY_CHECK_MODE=eval "$ap"

expect_exit AC-AP-18 0 env RELAY_LABELS=' Approval-Required ' RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$(approved_on "$HEAD40")" RELAY_CHECK_MODE=eval "$ap"

# Prefix of the head SHA must not count as a match.
expect_exit AC-AP-19 1 env RELAY_LABELS=legal RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$(printf '40\talice\tAPPROVED\t%s\t2026-10-01T00:00:00Z\n' "${HEAD40:0:12}")" \
	RELAY_CHECK_MODE=eval "$ap"

finish
