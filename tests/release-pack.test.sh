#!/usr/bin/env bash
# Release pack checks: legal files, contributor and security docs,
# public provenance, and agent support labels.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"

file_text() {
	cat "$ROOT/$1" 2>/dev/null || printf 'MISSING %s' "$1"
}

holder="Realized Development Corporation"

for f in LICENSE NOTICE SECURITY.md CONTRIBUTING.md; do
	if [ -s "$ROOT/$f" ]; then
		ok "AC-RP-1 $f present"
	else
		bad "AC-RP-1 $f present" "missing or empty"
	fi
done

expect_contains AC-RP-2a "$holder" "$(file_text LICENSE)"
expect_contains AC-RP-2b "$holder" "$(file_text NOTICE)"

expect_contains AC-RP-3 "no licence granted" "$(file_text LICENSE)"

expect_contains AC-RP-4a "AGENTS.md" "$(file_text CONTRIBUTING.md)"
expect_contains AC-RP-4b "draft" "$(file_text CONTRIBUTING.md)"
expect_contains AC-RP-4c "/push" "$(file_text CONTRIBUTING.md)"

expect_contains AC-RP-5a "Written fresh for this repository; earlier internal tooling was consulted as a design reference only." "$(file_text PROVENANCE.md)"
expect_contains AC-RP-5b "clean build" "$(file_text PROVENANCE.md)"
expect_contains AC-RP-5c "reference baseline only" "$(file_text PROVENANCE.md)"

expect_contains AC-RP-6a "| Claude Code | Beta |" "$(file_text README.md)"
expect_contains AC-RP-6b "| Codex | Beta |" "$(file_text README.md)"
expect_contains AC-RP-6c "| Cursor | Fully tested |" "$(file_text README.md)"
expect_contains AC-RP-6d "| Antigravity | Fully tested |" "$(file_text README.md)"

finish
