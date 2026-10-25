#!/bin/sh
# Scan files for patterns supplied ONLY via RELAY_DENYLIST.
# The secret is never written to the repository.
# Local: missing or empty secret passes with a notice.
# CI: missing or empty secret fails (the repository owner must set the Actions secret).

set -eu

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$here/lib.sh"

absent_or_empty=0
if [ -z "${RELAY_DENYLIST+x}" ] || [ -z "$RELAY_DENYLIST" ]; then
	absent_or_empty=1
fi

if [ "$absent_or_empty" -eq 1 ]; then
	if relay_running_in_ci; then
		relay_die "RELAY_DENYLIST is missing or empty (fail closed in CI)"
	fi
	relay_notice "RELAY_DENYLIST is absent; denylist check passed without a scan"
	exit 0
fi

root=${RELAY_SCAN_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

printf '%s\n' "$RELAY_DENYLIST" | while IFS= read -r _line || [ -n "${_line:-}" ]; do
	_pat=$(printf '%s' "$_line" | relay_trim)
	[ -z "$_pat" ] && continue
	case "$_pat" in
	\#*) continue ;;
	esac
	printf '%s\n' "$_pat"
done >"$tmpdir/patterns"

pattern_count=$(awk 'END { print NR+0 }' "$tmpdir/patterns")
if [ "$pattern_count" -eq 0 ]; then
	if relay_running_in_ci; then
		relay_die "RELAY_DENYLIST contained no usable patterns (fail closed in CI)"
	fi
	relay_notice "RELAY_DENYLIST contained no usable patterns; denylist check passed without a scan"
	exit 0
fi

if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	git -C "$root" ls-files >"$tmpdir/files"
else
	(CDPATH= cd -- "$root" && find . -type f ! -path './.git/*' | sed 's|^\./||') >"$tmpdir/files"
fi

hit=0
while IFS= read -r _pat; do
	[ -z "$_pat" ] && continue
	while IFS= read -r _rel; do
		[ -z "$_rel" ] && continue
		# -a: scan binary files too so -I cannot hide a match (B1).
		# Discard grep stderr: it can echo the pattern on a bad regex.
		set +e
		grep -a -q -E -e "$_pat" "$root/$_rel" 2>/dev/null
		_gc=$?
		set -e
		if [ "$_gc" -eq 2 ]; then
			relay_die "denylist: grep exit 2 (bad pattern or read error)"
		fi
		if [ "$_gc" -eq 0 ]; then
			relay_err "denylist: match in ${_rel}"
			hit=1
		fi
	done <"$tmpdir/files"
done <"$tmpdir/patterns"

if [ "$hit" -eq 1 ]; then
	relay_err "denylist: one or more files matched a secret pattern"
	exit 1
fi

printf 'denylist: scanned %s pattern(s), no matches\n' "$pattern_count"
exit 0
