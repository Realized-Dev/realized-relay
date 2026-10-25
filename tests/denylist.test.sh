#!/usr/bin/env bash
# AC-DL: patterns come from RELAY_DENYLIST only.
# CI fail-closes on a missing/empty secret; a local run may skip with a notice.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"
dl="$CHECKS/denylist.sh"
# AC-DL-00: run the script against fixtures. The names list is test-only
# and comes from the environment (RELAY_TEST_NAMES, else a disposable token).
# Never lint comments for Title-case English.
_dl00_names=${RELAY_TEST_NAMES:-ACDL00_ENV_NAME_TOKEN}
_dl00=$(mktemp -d)
printf 'visible %s in a fixture file\n' "$_dl00_names" >"$_dl00/person.txt"
printf 'clean text\n' >"$_dl00/ok.txt"
expect_exit AC-DL-00 1 env RELAY_DENYLIST="$_dl00_names" RELAY_SCAN_ROOT="$_dl00" "$dl"
expect_contains AC-DL-00-path 'match in person.txt'
expect_omits AC-DL-00-secret "$_dl00_names"
rm -rf "$_dl00"

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

# Tracked-but-deleted paths must not become grep exit 2.
wt=$(mktemp -d)
git -C "$wt" init -q
git -C "$wt" config user.email deny@example.test
git -C "$wt" config user.name Deny Test
printf 'only-in-deleted-file\n' >"$wt/gone.txt"
git -C "$wt" add gone.txt
git -C "$wt" commit -q -m gone
rm -f "$wt/gone.txt"
expect_exit AC-DL-17 0 env RELAY_DENYLIST='only-in-deleted-file' RELAY_SCAN_ROOT="$wt" "$dl"
rm -rf "$wt"

# Symlinks are skipped and never followed. The marker lives only in a
# file outside the scan root, reached solely through a symlink. If the
# scanner followed the link, this case would fail.
linktree=$(mktemp -d)
outside=$(mktemp -d)
printf 'clean regular file\n' >"$linktree/ok.txt"
printf '%s\n' "$marker" >"$outside/secret-target.txt"
ln -s "$outside/secret-target.txt" "$linktree/alias.txt"
expect_exit AC-DL-18 0 env RELAY_DENYLIST="$marker" RELAY_SCAN_ROOT="$linktree" "$dl"
expect_contains AC-DL-18-msg 'no matches'
expect_omits AC-DL-18-path 'alias.txt'
rm -rf "$linktree" "$outside"

# Ordinary English is not flagged. The pattern is a test-only token, not
# sentence starts, weekdays, or product names.
eng=$(mktemp -d)
printf '%s\n' \
	'The Scan starts on Monday.' \
	'Linux and Docker ship on Friday.' \
	'Local checks pass with a notice.' >"$eng/english.txt"
expect_exit AC-DL-19 0 env RELAY_DENYLIST="${RELAY_TEST_NAMES:-ACDL00_ENV_NAME_TOKEN}" \
	RELAY_SCAN_ROOT="$eng" "$dl"
expect_contains AC-DL-19-msg 'no matches'
rm -rf "$eng"

finish
