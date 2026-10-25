#!/bin/sh
# Evidence that tests accompany (and, across a commit range, precede) production edits.
# --staged / --files: companion rule on a file list.
# --range <base> <head>: each production commit must include tests, or the previous commit did.
#
# Merge skip (range): a commit is skipped ONLY when all of these hold:
#   1. exactly 2 parents
#   2. the second parent is an ancestor of origin/main (RELAY_TDD_BASE overrides)
#   3. no edits of its own: `git diff-tree --cc --no-commit-id -r` is empty,
#      or its tree equals `git merge-tree --write-tree p1 p2`
# Otherwise the commit is checked against its first parent (root: empty tree,
# via --root). 3 or more parents fail closed.
#
# MERGE_HEAD is a local convenience, not a trusted signal. --staged honours
# it only after the same three checks (HEAD+MERGE_HEAD, MERGE_HEAD on the
# PR base, index tree equals a clean merge-tree). A faked .git/MERGE_HEAD
# falls through to the companion rule. CI / pre-push `--range` is the gate.

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

pr_base_ref() {
	printf '%s' "${RELAY_TDD_BASE:-origin/main}"
}

parent_count() {
	_n=0
	for _p in $(git rev-parse "${1}^@" 2>/dev/null); do
		_n=$((_n + 1))
	done
	printf '%s\n' "$_n"
}

is_clean_own_edits() {
	# $1 = commit. Empty combined diff, or tree matches auto-merge.
	_cc=$(git diff-tree --cc --no-commit-id -r "$1")
	if [ -z "$_cc" ]; then
		return 0
	fi
	_p1=$(git rev-parse "${1}^1")
	_p2=$(git rev-parse "${1}^2")
	_auto=$(git merge-tree --write-tree "$_p1" "$_p2") || return 1
	_tree=$(git rev-parse "${1}^{tree}")
	[ "$_auto" = "$_tree" ]
}

is_skippable_merge() {
	# Skip only a clean two-parent merge whose second parent is on the PR base.
	_c=$1
	[ "$(parent_count "$_c")" -eq 2 ] || return 1
	_p2=$(git rev-parse "${_c}^2")
	_br=$(pr_base_ref)
	git rev-parse --verify "$_br" >/dev/null 2>&1 || return 1
	git merge-base --is-ancestor "$_p2" "$_br" || return 1
	is_clean_own_edits "$_c"
}

# MERGE_HEAD is not trusted on its own. Verify the in-progress merge, or
# fall through so a faked file cannot skip the companion rule.
if [ "$mode" = staged ] && git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
	_mh=$(git rev-parse MERGE_HEAD)
	_br=$(pr_base_ref)
	_ok=0
	if git rev-parse -q --verify HEAD >/dev/null 2>&1 \
		&& git rev-parse --verify "$_br" >/dev/null 2>&1 \
		&& git merge-base --is-ancestor "$_mh" "$_br" \
		&& _auto=$(git merge-tree --write-tree HEAD MERGE_HEAD 2>/dev/null) \
		&& _idx=$(git write-tree 2>/dev/null) \
		&& [ -n "$_auto" ] && [ "$_auto" = "$_idx" ]; then
		_ok=1
	fi
	if [ "$_ok" -eq 1 ]; then
		printf 'tdd-order: verified clean merge from the PR base (local convenience; CI --range is the gate)\n'
		exit 0
	fi
	# Unverified MERGE_HEAD: keep going and apply the companion rule.
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
	# --root: include the initial commit and diff it against the empty tree.
	for _c in $(git rev-list --reverse --root "${base}..${head}"); do
		_n=$(parent_count "$_c")
		if [ "$_n" -ge 3 ]; then
			relay_err "tdd-order: commit ${_c} has ${_n} parents (octopus merges fail closed)"
			exit 1
		fi
		if [ "$_n" -eq 2 ]; then
			if is_skippable_merge "$_c"; then
				prev_had_test=0
				continue
			fi
			# Not skippable: classify the merge against its first parent.
			_files=$(git diff-tree --root --no-commit-id --name-only -r "${_c}^1" "$_c")
		else
			_files=$(git diff-tree --root --no-commit-id --name-only -r "$_c")
		fi
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
