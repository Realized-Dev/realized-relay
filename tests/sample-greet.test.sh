#!/usr/bin/env bash
# AC-1 and AC-2 of the sample greeting helper.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"
greet="$ROOT/sample/greet.sh"

if [ ! -x "$greet" ]; then
	bad test_greet_script_present_AC-1 "missing executable $greet"
	finish
fi
ok test_greet_script_present_AC-1

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

expect_exit test_greet_one_argument_AC-1 0 "$greet" World
"$greet" World >"$tmp/one.out" 2>/dev/null || true
if printf 'Hello, World!\n' | cmp -s - "$tmp/one.out"; then
	ok test_greet_one_argument_AC-1_stdout
else
	bad test_greet_one_argument_AC-1_stdout "stdout bytes differ from 'Hello, World!' followed by a newline"
fi

set +e
"$greet" >"$tmp/none.out" 2>"$tmp/none.err"
code=$?
set -e
if [ "$code" -ne 0 ]; then
	ok test_greet_no_argument_AC-2_exit
else
	bad test_greet_no_argument_AC-2_exit "exit 0, want non-zero"
fi
if [ ! -s "$tmp/none.out" ]; then
	ok test_greet_no_argument_AC-2_stdout
else
	bad test_greet_no_argument_AC-2_stdout "stdout is not empty"
fi
if grep -q 'usage:' "$tmp/none.err"; then
	ok test_greet_no_argument_AC-2_stderr
else
	bad test_greet_no_argument_AC-2_stderr "stderr lacks usage line"
fi

finish
