#!/bin/sh
# Checks that .githooks/pre-commit and pre-push run locally.
# CI re-runs this suite so --no-verify cannot skip the guard.

set -eu

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$here/lib.sh"

scope=staged
base=
head=

while [ "$#" -gt 0 ]; do
	case "$1" in
	--staged) scope=staged; shift ;;
	--range)
		scope=range
		shift
		# Optional base and head; when omitted, merge-base against origin/main.
		if [ "$#" -ge 2 ]; then
			base=$1
			head=$2
			shift 2
		fi
		;;
	*) relay_die "unknown argument: $1" ;;
	esac
done

repo=$(git rev-parse --show-toplevel)
tests="$here/../tests/run.sh"

if [ "${RELAY_SKIP_SCRIPT_TESTS:-}" != 1 ] && [ -x "$tests" ]; then
	"$tests"
fi

if [ "$scope" = range ]; then
	if [ -z "$base" ] || [ -z "$head" ]; then
		if git rev-parse --verify origin/main >/dev/null 2>&1; then
			base=$(git merge-base HEAD origin/main)
			head=$(git rev-parse HEAD)
		else
			relay_notice "tdd-order range skipped (no origin/main)"
			base=
		fi
	fi
	if [ -n "$base" ]; then
		"$here/tdd-order.sh" --range "$base" "$head"
	fi
else
	"$here/tdd-order.sh" --staged
fi

"$here/line-budget.sh"
"$here/rules-frontmatter.sh"
"$here/denylist.sh"

printf 'local-checks: ok (%s)\n' "$repo"
