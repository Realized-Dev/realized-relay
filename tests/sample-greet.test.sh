#!/usr/bin/env bash
# AC-1 and AC-2 from docs/specs/sample.md.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"
greet="$ROOT/sample/greet.sh"

if [ ! -x "$greet" ]; then
	bad test_greet_script_present_AC-1 "missing executable $greet"
	finish
fi
ok test_greet_script_present_AC-1

expect_exit test_greet_one_argument_AC-1 0 "$greet" World
expect_contains test_greet_one_argument_AC-1_output 'Hello, World!' "$("$greet" World 2>/dev/null || true)"

set +e
err=$("$greet" 2>&1 >/dev/null)
code=$?
out=$("$greet" 2>/dev/null)
set -e
if [ "$code" -ne 0 ]; then
	ok test_greet_no_argument_AC-2_exit
else
	bad test_greet_no_argument_AC-2_exit "exit 0, want non-zero"
fi
if [ -z "$out" ]; then
	ok test_greet_no_argument_AC-2_stdout
else
	bad test_greet_no_argument_AC-2_stdout "stdout: $out"
fi
case "$err" in
*usage:*) ok test_greet_no_argument_AC-2_stderr ;;
*) bad test_greet_no_argument_AC-2_stderr "stderr lacks usage line: $err" ;;
esac

finish
