#!/usr/bin/env bash
# AC-LB: pointer files stay at or under 40 lines; README at or under 80.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"
lb="$CHECKS/line-budget.sh"

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

write_n() {
	_f=$1
	_n=$2
	: >"$_f"
	i=1
	while [ "$i" -le "$_n" ]; do
		printf 'line %s\n' "$i" >>"$_f"
		i=$((i + 1))
	done
}

expect_exit AC-LB-01 0 env RELAY_BUDGET_ROOT="$scratch" "$lb"
expect_contains AC-LB-02 'no pointer or README'

write_n "$scratch/CLAUDE.md" 40
expect_exit AC-LB-03 0 env RELAY_BUDGET_ROOT="$scratch" "$lb"
expect_contains AC-LB-04 'within budget'

write_n "$scratch/GEMINI.md" 41
expect_exit AC-LB-05 1 env RELAY_BUDGET_ROOT="$scratch" "$lb"
expect_contains AC-LB-06 'GEMINI.md has 41 lines'

mkdir -p "$scratch/.agents/rules" "$scratch/.agents/rules/nested"
write_n "$scratch/.agents/rules/keep.md" 40
write_n "$scratch/.agents/rules/nested/too-long.md" 90
rm -f "$scratch/GEMINI.md"
expect_exit AC-LB-07 0 env RELAY_BUDGET_ROOT="$scratch" "$lb"

write_n "$scratch/README.md" 80
expect_exit AC-LB-08 0 env RELAY_BUDGET_ROOT="$scratch" "$lb"
write_n "$scratch/README.md" 81
expect_exit AC-LB-09 1 env RELAY_BUDGET_ROOT="$scratch" "$lb"

finish
