#!/usr/bin/env bash
# AC-RF: every immediate .agents/rules file needs a valid trigger.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"
rf="$CHECKS/rules-frontmatter.sh"

missing=$(mktemp -d)
trap 'rm -rf "$missing" "$tree"' EXIT
expect_exit AC-RF-01 0 env RELAY_RULES_DIR="$missing/nope" "$rf"
expect_contains AC-RF-02 'no .agents/rules directory'

tree=$(mktemp -d)
mkdir -p "$tree/nested"

cat >"$tree/ok.md" <<'EOR'
---
trigger: always_on
---
body
EOR
expect_exit AC-RF-03 0 env RELAY_RULES_DIR="$tree" "$rf"

cat >"$tree/quoted.md" <<'EOR'
---
trigger: "model_decision"
---
EOR
expect_exit AC-RF-04 0 env RELAY_RULES_DIR="$tree" "$rf"

cat >"$tree/manual.md" <<'EOR'
---
trigger: manual
---
EOR
expect_exit AC-RF-05 0 env RELAY_RULES_DIR="$tree" "$rf"

cat >"$tree/globbed.md" <<'EOR'
---
trigger: glob
globs: "**/*.ts"
---
EOR
expect_exit AC-RF-06 0 env RELAY_RULES_DIR="$tree" "$rf"

cat >"$tree/nested/ignored.md" <<'EOR'
this is not frontmatter and must be ignored because it is not an immediate child
EOR
expect_exit AC-RF-07 0 env RELAY_RULES_DIR="$tree" "$rf"

cat >"$tree/bare.md" <<'EOR'
# no frontmatter
EOR
expect_exit AC-RF-08 1 env RELAY_RULES_DIR="$tree" "$rf"
expect_contains AC-RF-09 'bare.md has no YAML frontmatter'
rm -f "$tree/bare.md"

cat >"$tree/silent.md" <<'EOR'
---
description: discarded without a trigger
---
EOR
expect_exit AC-RF-10 1 env RELAY_RULES_DIR="$tree" "$rf"
expect_contains AC-RF-11 'has no trigger'
rm -f "$tree/silent.md"

cat >"$tree/bad.md" <<'EOR'
---
trigger: whenever
---
EOR
expect_exit AC-RF-12 1 env RELAY_RULES_DIR="$tree" "$rf"
rm -f "$tree/bad.md"

cat >"$tree/glob-only.md" <<'EOR'
---
trigger: glob
---
EOR
expect_exit AC-RF-13 1 env RELAY_RULES_DIR="$tree" "$rf"
expect_contains AC-RF-14 'no glob/globs key'
rm -f "$tree/glob-only.md"

printf -- '---\r\ntrigger: always_on\r\n---\r\nbody\r\n' >"$tree/crlf.md"
expect_exit AC-RF-15 0 env RELAY_RULES_DIR="$tree" "$rf"
rm -f "$tree/crlf.md"

printf -- '---\ntrigger: always_on\nbody with no closing delimiter\n' >"$tree/open.md"
expect_exit AC-RF-16 1 env RELAY_RULES_DIR="$tree" "$rf"
expect_contains AC-RF-17 'no closing ---'

finish
