#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "$0")
GREET_SCRIPT="$SCRIPT_DIR/../sample/greet.sh"

echo "Running tests for sample-greet..."

if [ ! -f "$GREET_SCRIPT" ]; then
    echo "FAIL: $GREET_SCRIPT does not exist"
    exit 1
fi

failed=0

# AC-1: with one arg prints 'hello <arg>' and exits 0
echo "Testing AC-1..."
output=$("$GREET_SCRIPT" "world" 2>&1)
exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "FAIL AC-1: Expected exit code 0, got $exit_code"
  failed=1
elif [ "$output" != "hello world" ]; then
  echo "FAIL AC-1: Expected 'hello world', got '$output'"
  failed=1
else
  echo "PASS AC-1"
fi

# AC-2: with no args exits non-zero and does not print hello*
echo "Testing AC-2..."
output=$("$GREET_SCRIPT" 2>&1)
exit_code=$?
if [ $exit_code -eq 0 ]; then
  echo "FAIL AC-2: Expected non-zero exit code, got 0"
  failed=1
elif [[ "$output" == hello* ]]; then
  echo "FAIL AC-2: Output should not start with hello, got '$output'"
  failed=1
else
  echo "PASS AC-2"
fi

if [ $failed -ne 0 ]; then
    echo "Some tests failed."
    exit 1
fi

echo "All tests passed!"
