#!/usr/bin/env bash
# Release pack checks: legal files, contributor and security docs,
# public provenance, and agent support labels.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH='' cd -- "$(dirname "$0")" && pwd)/helpers.sh"

file_text() {
	cat "$ROOT/$1" 2>/dev/null || printf 'MISSING %s' "$1"
}

holder="Realized Development Corporation"

for f in LICENSE NOTICE SECURITY.md CONTRIBUTING.md; do
	if [ -f "$ROOT/$f" ] && [ -s "$ROOT/$f" ]; then
		ok "AC-RP-1 $f present"
	else
		bad "AC-RP-1 $f present" "missing or empty"
	fi
done

expect_contains AC-RP-2a "$holder" "$(file_text LICENSE)"
expect_contains AC-RP-2b "$holder" "$(file_text NOTICE)"

# LICENSE is a protected path. Until the owner commits the Apache-2.0 text,
# this branch keeps the placeholder, so these checks describe that state.
expect_contains AC-RP-3a "LICENCE PENDING" "$(file_text LICENSE)"
expect_omits AC-RP-3b "Apache" "$(file_text LICENSE)"
expect_omits AC-RP-3c "Permission is hereby granted" "$(file_text LICENSE)"

expect_contains AC-RP-7 "Licence: Apache-2.0" "$(file_text README.md)"

for f in README.md CONTRIBUTING.md SECURITY.md; do
	if grep -qi "proprietary" "$ROOT/$f" 2>/dev/null; then
		bad "AC-RP-9 $f has no proprietary wording" "proprietary found in $f"
	else
		ok "AC-RP-9 $f has no proprietary wording"
	fi
done

expect_omits AC-RP-10a "TODO" "$(file_text SECURITY.md)"
expect_contains AC-RP-10b "Report a vulnerability" "$(file_text SECURITY.md)"
expect_contains AC-RP-10c "Security tab" "$(file_text SECURITY.md)"

if grep -qiE "licensed under|Apache|Permission is hereby granted" "$ROOT/NOTICE" 2>/dev/null; then
	bad "AC-RP-8 NOTICE claims no licence" "licence wording found in NOTICE"
else
	ok "AC-RP-8 NOTICE claims no licence"
fi

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
