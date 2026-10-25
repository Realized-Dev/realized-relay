#!/bin/sh
# Evidence that tests accompany (and, across a commit range, precede) production edits.
# --staged / --files: companion rule on a file list.
# --range <base> <head>: each production commit must include tests, or the previous commit did.

set -eu

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$here/lib.sh"

mode=staged
base=
head=
file_list=

while [ "$#" -gt 0 ]; do
	case "$1" in
	--staged) mode=staged; shift ;;
	--files) mode=files; shift ;;
	--range)
		mode=range
		if [ "$#" -lt 3 ]; then
			relay_die "tdd-order --range needs a base and a head revision"
		fi
		base=$2
		head=$3
		shift 3
		;;
	*) relay_die "unknown argument: $1" ;;
	esac
done

is_test_path() {
	case "$1" in
	tests/*|*/tests/*) return 0 ;;
	*.test.sh|*.test.js|*.test.ts|*.spec.sh|*.spec.js) return 0 ;;
	*/test-*.sh|test-*.sh|*_test.sh|*_test.go) return 0 ;;
	esac
	return 1
}

is_exempt_path() {
	case "$1" in
	*.md|.githooks/INSTALL|LICENSE|NOTICE|SECURITY.md|CONTRIBUTING.md|PROVENANCE.md)
		return 0 ;;
	.github/*) return 0 ;;
	.gitignore|.gitattributes) return 0 ;;
	esac
	return 1
}

classify_list() {
	_has_prod=0
	_has_test=0
	while IFS= read -r _p || [ -n "${_p:-}" ]; do
		[ -z "$_p" ] && continue
		if is_test_path "$_p"; then
			_has_test=1
			continue
		fi
		if is_exempt_path "$_p"; then
			continue
		fi
		_has_prod=1
	done
	printf '%s %s\n' "$_has_prod" "$_has_test"
}

read_files() {
	if [ -n "${RELAY_FILE_LIST+x}" ]; then
		printf '%s\n' "$RELAY_FILE_LIST"
		return 0
	fi
	case "$mode" in
	files)
		relay_die "RELAY_FILE_LIST is required with --files"
		;;
	staged)
		git diff --cached --name-only -z | tr '\0' '\n'
		;;
	esac
}

check_companion() {
	_class=$(printf '%s\n' "$1" | classify_list)
	_prod=${_class% *}
	_test=${_class#* }
	if [ "$_prod" -eq 1 ] && [ "$_test" -eq 0 ]; then
		relay_err "tdd-order: production changes without a test change"
		return 1
	fi
	return 0
}

# A merge commit (or a merge in progress) combines already-reviewed
# history. Companion TDD applies to ordinary commits, not to merges.
if [ "$mode" = staged ] && git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
	printf 'tdd-order: merge in progress, companion rule skipped\n'
	exit 0
fi

if [ "$mode" = range ]; then
	[ -n "$base" ] || relay_die "tdd-order --range needs a base revision"
	[ -n "$head" ] || relay_die "tdd-order --range needs a head revision"
	if ! git rev-parse --verify "$base" >/dev/null 2>&1; then
		relay_die "tdd-order: unknown base revision"
	fi
	if ! git rev-parse --verify "$head" >/dev/null 2>&1; then
		relay_die "tdd-order: unknown head revision"
	fi
	prev_had_test=0
	# Oldest first so a red test commit can unlock the next production commit.
	for _c in $(git rev-list --reverse "${base}..${head}"); do
		# Two parents => merge. Skip; the merged sides were already checked.
		if git rev-parse --verify "${_c}^2" >/dev/null 2>&1; then
			prev_had_test=0
			continue
		fi
		_files=$(git diff-tree --no-commit-id --name-only -r "$_c")
		_class=$(printf '%s\n' "$_files" | classify_list)
		_prod=${_class% *}
		_test=${_class#* }
		if [ "$_prod" -eq 1 ]; then
			if [ "$_test" -eq 0 ] && [ "$prev_had_test" -eq 0 ]; then
				relay_err "tdd-order: commit ${_c} changes production without a test change in this or the previous commit"
				exit 1
			fi
		fi
		prev_had_test=$_test
	done
	printf 'tdd-order: commit range %s..%s is ordered\n' "$base" "$head"
	exit 0
fi

files=$(read_files)
if ! check_companion "$files"; then
	exit 1
fi
printf 'tdd-order: companion tests present or no production change\n'
exit 0
