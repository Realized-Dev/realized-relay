#!/usr/bin/env bash
# AC-DL: patterns come from RELAY_DENYLIST only.
# CI fail-closes on a missing/empty secret; a local run may skip with a notice.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"
dl="$CHECKS/denylist.sh"
marker='FIXTURE_DENY_MARKER_92f3ac'
safe='DENYLIST_NOHIT_TOKEN_7c1e'
local_env=(env -u RELAY_DENYLIST -u CI -u GITHUB_ACTIONS RELAY_CHECK_MODE=hook)

expect_exit AC-DL-01 1 env -u RELAY_DENYLIST CI=true RELAY_CHECK_MODE=ci "$dl"
expect_contains AC-DL-02 'missing or empty'

expect_exit AC-DL-03 1 env RELAY_DENYLIST='' CI=true RELAY_CHECK_MODE=ci "$dl"
expect_contains AC-DL-04 'missing or empty'

# Local still notice-passes (negative of the CI fail-closed cases).
expect_exit AC-DL-01-local 0 "${local_env[@]}" "$dl"
expect_contains AC-DL-01-local-notice 'RELAY_DENYLIST is absent'
expect_exit AC-DL-03-local 0 env -u CI -u GITHUB_ACTIONS RELAY_CHECK_MODE=hook RELAY_DENYLIST='' "$dl"

# A file sitting in the repo must not be treated as the pattern source.
tree=$(mktemp -d)
trap 'rm -rf "$tree"' EXIT
printf 'ignore-this-file-as-source\n' >"$tree/denylist.txt"
printf 'clean text\n' >"$tree/sample.txt"
expect_exit AC-DL-05 0 env RELAY_DENYLIST="$safe" RELAY_SCAN_ROOT="$tree" "$dl"
expect_contains AC-DL-06 'no matches'

printf '%s\n' "visible $marker in a fixture tree" >"$tree/sample.txt"
expect_exit AC-DL-07 1 env RELAY_DENYLIST="$marker" RELAY_SCAN_ROOT="$tree" "$dl"
expect_contains AC-DL-08 'match in sample.txt'
expect_omits AC-DL-09 "$marker"

# Comment-only: local skip, CI fail.
expect_exit AC-DL-10 0 env -u CI -u GITHUB_ACTIONS RELAY_CHECK_MODE=hook \
	RELAY_DENYLIST='# only a comment' RELAY_SCAN_ROOT="$tree" "$dl"
expect_contains AC-DL-11 'no usable patterns'
expect_exit AC-DL-16 1 env CI=true RELAY_CHECK_MODE=ci \
	RELAY_DENYLIST='# only a comment' RELAY_SCAN_ROOT="$tree" "$dl"

# Notices must not leak into captured stdout (label-guard --gated-only).
notice_out=$("${local_env[@]}" "$dl" 2>/dev/null) || true
notice_err=$("${local_env[@]}" "$dl" 2>&1 >/dev/null) || true
case "$notice_out" in
*notice:*) bad AC-DL-12 "notice leaked to stdout: $notice_out" ;;
*) ok AC-DL-12 ;;
esac
case "$notice_err" in
*notice:*) ok AC-DL-13 ;;
*) bad AC-DL-13 "notice missing on stderr: $notice_err" ;;
esac

# grep exit 2 (invalid ERE) is a failure; do not treat it as "no match".
errtree=$(mktemp -d)
printf 'plain\n' >"$errtree/plain.txt"
expect_exit AC-DL-14 1 env RELAY_DENYLIST='[' RELAY_SCAN_ROOT="$errtree" "$dl"
expect_contains AC-DL-14-msg 'grep exit 2'
expect_omits AC-DL-14-secret '['
rm -rf "$errtree"

# Binary files are scanned (-a); -I must not hide a match.
printf 'clean text\n' >"$tree/sample.txt"
printf 'xx\0%s\n' "$marker" >"$tree/blob.bin"
expect_exit AC-DL-15 1 env RELAY_DENYLIST="$marker" RELAY_SCAN_ROOT="$tree" "$dl"
expect_contains AC-DL-15-path 'match in blob.bin'

finish
