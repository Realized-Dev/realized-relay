# Test helpers. Sourced by tests/*.test.sh

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
CHECKS="$ROOT/checks"
pass=0
fail=0

ok() {
	pass=$((pass + 1))
	printf 'ok %s\n' "$1"
}

bad() {
	fail=$((fail + 1))
	printf 'not ok %s\n' "$1"
	if [ -n "${2:-}" ]; then
		printf '  %s\n' "$2"
	fi
}

expect_exit() {
	_id=$1
	_want=$2
	shift 2
	set +e
	_out=$("$@" 2>&1)
	_code=$?
	set -e
	if [ "$_code" -eq "$_want" ]; then
		ok "$_id"
	else
		bad "$_id" "exit ${_code} (want ${_want}): ${_out}"
	fi
	LAST_OUT=$_out
}

expect_contains() {
	_id=$1
	_needle=$2
	_hay=${3:-$LAST_OUT}
	case "$_hay" in
	*"$_needle"*) ok "$_id" ;;
	*) bad "$_id" "missing '${_needle}' in: ${_hay}" ;;
	esac
}

expect_omits() {
	_id=$1
	_needle=$2
	_hay=${3:-$LAST_OUT}
	case "$_hay" in
	*"$_needle"*) bad "$_id" "found '${_needle}' in: ${_hay}" ;;
	*) ok "$_id" ;;
	esac
}

finish() {
	printf '%s: %s passed, %s failed\n' "$(basename "$0")" "$pass" "$fail"
	if [ "$fail" -ne 0 ]; then
		exit 1
	fi
	exit 0
}
