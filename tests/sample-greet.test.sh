#!/bin/bash
# Tests for sample/greet.sh

cd "$(dirname "$0")" || exit 1

SCRIPT_PATH="../sample/greet.sh"
if [ ! -f "$SCRIPT_PATH" ]; then
    mkdir -p ../sample
    echo '#!/bin/bash' > "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
fi

FAILURES=0

echo "Running AC-1 test..."
OUTPUT=$("$SCRIPT_PATH" "world")
EXIT_CODE=$?

if [ "$EXIT_CODE" -ne 0 ]; then
    echo "FAIL AC-1: Expected exit 0, got $EXIT_CODE"
    FAILURES=$((FAILURES + 1))
elif [ "$OUTPUT" != "hello world" ]; then
    echo "FAIL AC-1: Expected 'hello world', got '$OUTPUT'"
    FAILURES=$((FAILURES + 1))
else
    echo "PASS AC-1"
fi

echo "Running AC-2 test..."
OUTPUT=$("$SCRIPT_PATH" 2>&1)
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
    echo "FAIL AC-2: Expected non-zero exit code, got 0"
    FAILURES=$((FAILURES + 1))
elif echo "$OUTPUT" | grep -q "^hello"; then
    echo "FAIL AC-2: Expected no 'hello*' output, got '$OUTPUT'"
    FAILURES=$((FAILURES + 1))
else
    echo "PASS AC-2"
fi

if [ "$FAILURES" -gt 0 ]; then
    echo "Tests failed ($FAILURES)"
    exit 1
else
    echo "All tests passed"
    exit 0
fi
