#!/bin/sh
# Run every tests/*.test.sh. Used by local hooks and by CI.
set -u
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
# Hooks export repository-selecting variables. Fixture repos must not inherit them.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
fail=0
found=0
for t in tests/*.test.sh tests/guards/*.test.sh; do
	[ -f "$t" ] || continue
	found=1
	echo "==> $t"
	if bash "$t"; then
		echo "PASS $t"
	else
		echo "FAIL $t"
		fail=1
	fi
done
if [ "$found" -eq 0 ]; then
	echo "no tests found" >&2
	exit 1
fi
exit "$fail"
