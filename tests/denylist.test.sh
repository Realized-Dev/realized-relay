#!/usr/bin/env bash
# AC-DL: patterns come from RELAY_DENYLIST only; absent secret passes with a notice.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"
dl="$CHECKS/denylist.sh"
marker='FIXTURE_DENY_MARKER_92f3ac'
safe='DENYLIST_NOHIT_TOKEN_7c1e'

expect_exit AC-DL-01 0 env -u RELAY_DENYLIST "$dl"
expect_contains AC-DL-02 'RELAY_DENYLIST is absent'

expect_exit AC-DL-03 0 env RELAY_DENYLIST='' "$dl"
expect_contains AC-DL-04 'RELAY_DENYLIST is absent'

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

# Comment-only secret payload is treated as unused.
expect_exit AC-DL-10 0 env RELAY_DENYLIST='# only a comment' RELAY_SCAN_ROOT="$tree" "$dl"
expect_contains AC-DL-11 'no usable patterns'

# Notices must not leak into captured stdout (label-guard --gated-only).
notice_out=$(env -u RELAY_DENYLIST "$dl" 2>/dev/null) || true
notice_err=$(env -u RELAY_DENYLIST "$dl" 2>&1 >/dev/null) || true
case "$notice_out" in
*notice:*) bad AC-DL-12 "notice leaked to stdout: $notice_out" ;;
*) ok AC-DL-12 ;;
esac
case "$notice_err" in
*notice:*) ok AC-DL-13 ;;
*) bad AC-DL-13 "notice missing on stderr: $notice_err" ;;
esac

finish
