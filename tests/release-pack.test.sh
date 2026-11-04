#!/usr/bin/env bash
# Release pack checks: legal files, contributor and security docs,
# public provenance, README structure, and agent support labels.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH='' cd -- "$(dirname "$0")" && pwd)/helpers.sh"

file_text() {
	cat "$ROOT/$1" 2>/dev/null || printf 'MISSING %s' "$1"
}

is_text_file() {
	[ -f "$ROOT/$1" ] && [ -s "$ROOT/$1" ]
}

expect_present_ci() {
	_id=$1
	_file=$2
	_needle=$3
	if is_text_file "$_file" && grep -qiF -- "$_needle" "$ROOT/$_file"; then
		ok "$_id"
	else
		bad "$_id" "missing '${_needle}' in ${_file}"
	fi
}

expect_absent_ci() {
	_id=$1
	_file=$2
	shift 2
	if ! is_text_file "$_file"; then
		bad "$_id" "${_file} is missing, not a regular file, or empty"
		return 0
	fi
	for _needle in "$@"; do
		if grep -qiF -- "$_needle" "$ROOT/$_file"; then
			bad "$_id" "found '${_needle}' in ${_file}"
			return 0
		fi
	done
	ok "$_id"
}

holder="Realized Development Corporation"
apache_sha256=cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30

for f in LICENSE NOTICE SECURITY.md CONTRIBUTING.md; do
	if is_text_file "$f"; then
		ok "AC-RP-1 $f present"
	else
		bad "AC-RP-1 $f present" "missing, not a regular file, or empty"
	fi
done

expect_contains AC-RP-2 "$holder" "$(file_text NOTICE)"

if is_text_file LICENSE && [ "$(sha256sum "$ROOT/LICENSE" | cut -d' ' -f1)" = "$apache_sha256" ]; then
	ok "AC-RP-3a LICENSE is the verbatim Apache-2.0 text"
else
	bad "AC-RP-3a LICENSE is the verbatim Apache-2.0 text" "sha256 differs from Apache-2.0"
fi
expect_absent_ci AC-RP-3b LICENSE "pending" "placeholder" "decision"
expect_present_ci AC-RP-3c LICENSE "apache license"

expect_contains AC-RP-4a "AGENTS.md" "$(file_text CONTRIBUTING.md)"
expect_contains AC-RP-4b "draft" "$(file_text CONTRIBUTING.md)"
expect_contains AC-RP-4c "/push" "$(file_text CONTRIBUTING.md)"

expect_contains AC-RP-5a "Written fresh for this repository; earlier internal tooling was consulted as a design reference only." "$(file_text PROVENANCE.md)"
expect_contains AC-RP-5b "clean build" "$(file_text PROVENANCE.md)"
expect_contains AC-RP-5c "reference baseline" "$(file_text PROVENANCE.md)"

expect_contains AC-RP-6a "| Cursor | Fully tested |" "$(file_text README.md)"
expect_contains AC-RP-6b "| Claude Code | Beta |" "$(file_text README.md)"
expect_contains AC-RP-6c "| Codex | Beta |" "$(file_text README.md)"
expect_contains AC-RP-6d "| Antigravity | Fully tested |" "$(file_text README.md)"

expect_contains AC-RP-7 "Licence: Apache-2.0" "$(file_text README.md)"
expect_contains AC-RP-7b "[NOTICE](NOTICE)" "$(file_text README.md)"

expect_absent_ci AC-RP-8 NOTICE "TERMS AND CONDITIONS" "Permission is hereby granted" "Redistribution and use" "THE SOFTWARE IS PROVIDED" "WITHOUT WARRANTIES OR CONDITIONS" "Version 2.0, January 2004"

for f in LICENSE NOTICE README.md CONTRIBUTING.md SECURITY.md; do
	expect_absent_ci "AC-RP-9 $f has no proprietary wording" "$f" "proprietary"
done

expect_omits AC-RP-10a "TODO" "$(file_text SECURITY.md)"
expect_contains AC-RP-10b "Report a vulnerability" "$(file_text SECURITY.md)"
expect_contains AC-RP-10c "Security tab" "$(file_text SECURITY.md)"

expect_contains AC-RP-11a "Realized-Relay™ is licensed under Apache-2.0" "$(file_text CONTRIBUTING.md)"
expect_contains AC-RP-11b "Realized-Relay™ is a set of instructions" "$(file_text SECURITY.md)"

expect_contains AC-RP-12a "## Planned after v1" "$(file_text README.md)"
expect_contains AC-RP-12b "Optional content-tier check before tool egress" "$(file_text README.md)"
expect_contains AC-RP-12c "Deterministic prompt-injection denylist on \`/init\` and skill entry" "$(file_text README.md)"
expect_omits AC-RP-12d "REAZED" "$(file_text README.md)"

expect_contains AC-RP-13a "[Contributing](CONTRIBUTING.md)" "$(file_text README.md)"
expect_contains AC-RP-13b "[Security](SECURITY.md)" "$(file_text README.md)"

expect_contains AC-RP-14 "/sdd-to-tdd" "$(file_text README.md)"

expect_contains AC-RP-15a "| Cursor | fully tested |" "$(file_text .agents/skills/init/SKILL.md)"
expect_contains AC-RP-15b "| Antigravity | fully tested |" "$(file_text .agents/skills/init/SKILL.md)"
expect_contains AC-RP-15c "| Claude Code | beta |" "$(file_text .agents/skills/init/SKILL.md)"
expect_contains AC-RP-15d "| Codex | beta |" "$(file_text .agents/skills/init/SKILL.md)"
expect_contains AC-RP-15e "**Cursor:** a current Cursor install" "$(file_text docs/getting-started.md)"
expect_contains AC-RP-15f "Treat Claude Code and Codex as beta." "$(file_text docs/troubleshooting.md)"

finish
