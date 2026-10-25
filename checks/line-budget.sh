#!/bin/sh
# Line budgets for pointer layers (40) and the root README (80).
# Missing paths are skipped; a file over its budget fails the check.

set -eu

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$here/lib.sh"

root=${RELAY_BUDGET_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}
pointer_max=${RELAY_POINTER_MAX:-40}
readme_max=${RELAY_README_MAX:-80}

count_lines() {
	# NR counts the last line even when it has no trailing newline.
	awk 'END { print NR+0 }' "$1"
}

fail=0
checked=0

check_file() {
	_path=$1
	_max=$2
	_rel=${_path#"$root"/}
	if [ ! -f "$_path" ]; then
		return 0
	fi
	checked=$((checked + 1))
	_n=$(count_lines "$_path")
	if [ "$_n" -gt "$_max" ]; then
		relay_err "line-budget: ${_rel} has ${_n} lines (max ${_max})"
		fail=1
	fi
}

check_dir_children() {
	_dir=$1
	if [ ! -d "$_dir" ]; then
		return 0
	fi
	for _f in "$_dir"/*; do
		[ -f "$_f" ] || continue
		check_file "$_f" "$pointer_max"
	done
}

# Pointer / per-agent layers. Immediate children only for rule folders
# (Antigravity scans the same way).
check_file "$root/CLAUDE.md" "$pointer_max"
check_file "$root/GEMINI.md" "$pointer_max"
check_dir_children "$root/.cursor/rules"
check_dir_children "$root/.agents/rules"
check_dir_children "$root/.claude/rules"
check_file "$root/README.md" "$readme_max"

if [ "$checked" -eq 0 ]; then
	relay_notice "line-budget: no pointer or README files to measure"
	exit 0
fi

if [ "$fail" -ne 0 ]; then
	exit 1
fi
printf 'line-budget: %s file(s) within budget\n' "$checked"
exit 0
