#!/bin/sh
# Run every tests/*.test.sh. Used by local hooks and by CI.
set -u
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
fail=0
found=0
for t in tests/*.test.sh; do
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
