#!/bin/sh
# Scan files for patterns supplied ONLY via RELAY_DENYLIST.
# The secret is never written to the repository. When it is unset or empty,
# this check passes and prints a notice.
# Matches report file paths only so pattern text does not enter logs.

set -eu

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$here/lib.sh"

# Missing Actions secrets expand to an empty string; treat that as absent.
if [ -z "${RELAY_DENYLIST+x}" ] || [ -z "$RELAY_DENYLIST" ]; then
	relay_notice "RELAY_DENYLIST is absent; denylist check passed without a scan"
	exit 0
fi

root=${RELAY_SCAN_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

pattern_count=0
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
		if grep -I -E -e "$_pat" "$root/$_rel" >/dev/null 2>&1; then
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
