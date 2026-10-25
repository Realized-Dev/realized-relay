#!/bin/sh
# Lint immediate children of .agents/rules for Antigravity trigger frontmatter.
# Valid trigger values: always_on, model_decision, glob, manual.
# A missing rules directory is a pass (nothing to discard).

set -eu

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$here/lib.sh"

root=${RELAY_RULES_DIR:-}
if [ -z "$root" ]; then
	_repo=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
	root="${_repo}/.agents/rules"
fi

if [ ! -d "$root" ]; then
	relay_notice "rules-frontmatter: no .agents/rules directory"
	exit 0
fi

valid_trigger() {
	case "$1" in
	always_on|model_decision|glob|manual) return 0 ;;
	esac
	return 1
}

fail=0
checked=0

for _f in "$root"/*; do
	[ -f "$_f" ] || continue
	checked=$((checked + 1))
	_base=$(basename "$_f")

	_first=$(sed -n '1p' "$_f")
	if [ "$_first" != --- ]; then
		relay_err "rules-frontmatter: ${_base} has no YAML frontmatter"
		fail=1
		continue
	fi

	# Text between the opening --- and the next --- (or EOF).
	_fm=$(awk '
		NR == 1 && $0 == "---" { next }
		$0 == "---" { exit }
		{ print }
	' "$_f")

	_trigger=$(printf '%s\n' "$_fm" | awk -F: '
		tolower($1) ~ /^[[:space:]]*trigger[[:space:]]*$/ {
			val = $2
			for (i = 3; i <= NF; i++) val = val ":" $i
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
			gsub(/^["'\'']|["'\'']$/, "", val)
			print val
			exit
		}
	')

	if [ -z "$_trigger" ]; then
		relay_err "rules-frontmatter: ${_base} frontmatter has no trigger"
		fail=1
		continue
	fi
	if ! valid_trigger "$_trigger"; then
		relay_err "rules-frontmatter: ${_base} has invalid trigger '${_trigger}'"
		fail=1
		continue
	fi
	if [ "$_trigger" = glob ]; then
		_glob=$(printf '%s\n' "$_fm" | awk -F: '
			tolower($1) ~ /^[[:space:]]*(glob|globs)[[:space:]]*$/ {
				print "yes"
				exit
			}
		')
		if [ "$_glob" != yes ]; then
			relay_err "rules-frontmatter: ${_base} trigger is glob but no glob/globs key is set"
			fail=1
		fi
	fi
done

if [ "$checked" -eq 0 ]; then
	relay_notice "rules-frontmatter: .agents/rules has no immediate files"
	exit 0
fi

if [ "$fail" -ne 0 ]; then
	exit 1
fi
printf 'rules-frontmatter: %s file(s) have a valid trigger\n' "$checked"
exit 0
