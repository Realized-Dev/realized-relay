#!/usr/bin/env bash
# AC-TD: companion tests on a file list; red-then-green across a commit range.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"
td="$CHECKS/tdd-order.sh"

expect_exit AC-TD-01 1 env RELAY_FILE_LIST='checks/label-guard.sh' "$td" --files
expect_exit AC-TD-02 0 env RELAY_FILE_LIST="$(printf 'checks/label-guard.sh\ntests/label-guard.test.sh\n')" "$td" --files
expect_exit AC-TD-03 0 env RELAY_FILE_LIST='README.md' "$td" --files
expect_exit AC-TD-04 0 env RELAY_FILE_LIST='.githooks/INSTALL' "$td" --files
expect_exit AC-TD-05 0 env RELAY_FILE_LIST='' "$td" --files
expect_exit AC-TD-06 0 env RELAY_FILE_LIST='.github/workflows/ci.yml' "$td" --files
expect_exit AC-TD-07 1 env RELAY_FILE_LIST='.githooks/pre-commit' "$td" --files

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git init -q "$tmp"
git -C "$tmp" config user.email tdd@example.test
git -C "$tmp" config user.name TDD Range
printf 'base\n' >"$tmp/README.md"
git -C "$tmp" add README.md
git -C "$tmp" commit -q -m base
base=$(git -C "$tmp" rev-parse HEAD)

mkdir -p "$tmp/tests" "$tmp/app"
printf 'red\n' >"$tmp/tests/demo.test.sh"
git -C "$tmp" add tests/demo.test.sh
git -C "$tmp" commit -q -m red
printf 'impl\n' >"$tmp/app/demo.sh"
git -C "$tmp" add app/demo.sh
git -C "$tmp" commit -q -m green
head=$(git -C "$tmp" rev-parse HEAD)

set +e
out=$(cd "$tmp" && "$td" --range "$base" "$head" 2>&1)
code=$?
set -e
if [ "$code" -eq 0 ]; then
	ok AC-TD-08
else
	bad AC-TD-08 "range should pass when tests precede impl: $out"
fi

# Production-only commit with no prior test commit in the range.
tmp2=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp2"' EXIT
git init -q "$tmp2"
git -C "$tmp2" config user.email tdd@example.test
git -C "$tmp2" config user.name TDD Range
printf 'base\n' >"$tmp2/README.md"
git -C "$tmp2" add README.md
git -C "$tmp2" commit -q -m base
b2=$(git -C "$tmp2" rev-parse HEAD)
mkdir -p "$tmp2/app"
printf 'impl\n' >"$tmp2/app/demo.sh"
git -C "$tmp2" add app/demo.sh
git -C "$tmp2" commit -q -m impl-only
h2=$(git -C "$tmp2" rev-parse HEAD)
set +e
out2=$(cd "$tmp2" && "$td" --range "$b2" "$h2" 2>&1)
code2=$?
set -e
if [ "$code2" -eq 1 ]; then
	ok AC-TD-09
else
	bad AC-TD-09 "range should fail for impl-only: $out2"
fi

finish
