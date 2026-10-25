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

expect_exit AC-AP-01 1 run_eval RELAY_LABELS=security "$ap"
expect_exit AC-AP-02 1 run_eval RELAY_LABELS=security RELAY_HEAD_SHA=not-a-sha "$ap"
expect_exit AC-AP-03 1 run_eval RELAY_LABELS=security RELAY_HEAD_SHA="$SHORT" "$ap"

expect_exit AC-AP-04 1 run_eval RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS_JSON='' "$ap"
expect_exit AC-AP-05 1 run_eval RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS_JSON='{"oops":true}' "$ap"
expect_exit AC-AP-06 1 run_eval RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS_JSON='[]' "$ap"

expect_exit AC-AP-07 1 run_eval RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$(approved_on "$OTHER")" "$ap"

expect_exit AC-AP-08 0 run_eval RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$(approved_on "$HEAD40")" "$ap"
expect_contains AC-AP-09 'APPROVED review on the current head SHA'

expect_exit AC-AP-10 1 run_eval RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$(printf '11\talice\tCOMMENTED\t%s\t2026-10-01T00:00:00Z\n' "$HEAD40")" \
	"$ap"

expect_exit AC-AP-11 1 run_eval RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$(printf '12\talice\tDISMISSED\t%s\t2026-10-01T00:00:00Z\n' "$HEAD40")" \
	"$ap"

expect_exit AC-AP-12 1 run_eval RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$(printf '13\talice\tCHANGES_REQUESTED\t%s\t2026-10-01T00:00:00Z\n' "$HEAD40")" \
	"$ap"

# Approve, then the same user requests changes on the same SHA: latest wins.
stale_flip=$(printf '%s\n%s\n' \
	"20	alice	APPROVED	${HEAD40}	2026-10-01T00:00:00Z" \
	"21	alice	CHANGES_REQUESTED	${HEAD40}	2026-10-02T00:00:00Z")
expect_exit AC-AP-13 1 run_eval RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$stale_flip" "$ap"

# Two reviewers: stale approve from one, current approve from another.
two=$(printf '%s\n%s\n' \
	"30	alice	APPROVED	${OTHER}	2026-10-01T00:00:00Z" \
	"31	bob	APPROVED	${HEAD40}	2026-10-02T00:00:00Z")
expect_exit AC-AP-14 0 run_eval RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$two" "$ap"

expect_exit AC-AP-15 0 run_eval RELAY_LABELS='bug' RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS_JSON='[]' "$ap"
expect_contains AC-AP-16 'not needed'

expect_exit AC-AP-17 1 run_eval RELAY_LABELS_JSON='not-json' \
	RELAY_HEAD_SHA="$HEAD40" RELAY_REVIEWS_JSON='[]' "$ap"

expect_exit AC-AP-18 0 run_eval RELAY_LABELS=' Approval-Required ' RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$(approved_on "$HEAD40")" "$ap"

# Prefix of the head SHA must not count as a match.
expect_exit AC-AP-19 1 run_eval RELAY_LABELS=legal RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$(printf '40\talice\tAPPROVED\t%s\t2026-10-01T00:00:00Z\n' "${HEAD40:0:12}")" \
	"$ap"

# N1: any latest CHANGES_REQUESTED blocks even if someone else approved the head.
split=$(printf '%s\n%s\n' \
	"50	alice	APPROVED	${HEAD40}	2026-10-01T00:00:00Z" \
	"51	bob	CHANGES_REQUESTED	${HEAD40}	2026-10-02T00:00:00Z")
expect_exit AC-AP-20 1 run_eval RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$split" "$ap"
expect_contains AC-AP-21 'CHANGES_REQUESTED still outstanding'

# CR on an older commit still blocks until that reviewer approves the head.
old_cr=$(printf '%s\n%s\n' \
	"60	alice	CHANGES_REQUESTED	${OTHER}	2026-10-01T00:00:00Z" \
	"61	bob	APPROVED	${HEAD40}	2026-10-02T00:00:00Z")
expect_exit AC-AP-22 1 run_eval RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$old_cr" "$ap"

# Same reviewer later approves the head: the older CR is cleared.
cleared=$(printf '%s\n%s\n' \
	"70	alice	CHANGES_REQUESTED	${OTHER}	2026-10-01T00:00:00Z" \
	"71	alice	APPROVED	${HEAD40}	2026-10-02T00:00:00Z")
expect_exit AC-AP-25 0 run_eval RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$cleared" "$ap"

# CI=true ignores RELAY_LABELS* / RELAY_REVIEWS* and RELAY_CHECK_MODE=eval.
expect_exit AC-AP-23 1 env CI=true RELAY_CHECK_MODE=ci RELAY_LABELS=security \
	RELAY_HEAD_SHA="$HEAD40" RELAY_REVIEWS="$(approved_on "$HEAD40")" "$ap"
expect_exit AC-AP-24 1 env CI=true RELAY_CHECK_MODE=eval RELAY_LABELS=security \
	RELAY_HEAD_SHA="$HEAD40" RELAY_REVIEWS="$(approved_on "$HEAD40")" "$ap"

# Read-only approvals do not satisfy the gate; write does.
expect_exit AC-AP-26 1 run_eval RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$(approved_on "$HEAD40")" RELAY_REVIEWER_PERMS='alice=read' "$ap"
expect_exit AC-AP-27 0 run_eval RELAY_LABELS=security RELAY_HEAD_SHA="$HEAD40" \
	RELAY_REVIEWS="$(approved_on "$HEAD40")" RELAY_REVIEWER_PERMS='alice=write' "$ap"

finish
