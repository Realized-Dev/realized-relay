#!/usr/bin/env bash
# AC-LG: fail-closed label read; padded and mixed-case gated names still match.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"
lg="$CHECKS/label-guard.sh"

expect_exit AC-LG-01 1 env -u RELAY_LABELS RELAY_LABELS_JSON='' RELAY_CHECK_MODE=eval "$lg"
expect_exit AC-LG-02 1 env -u RELAY_LABELS RELAY_LABELS_JSON='not-json' RELAY_CHECK_MODE=eval "$lg"
expect_exit AC-LG-03 1 env -u RELAY_LABELS RELAY_LABELS_JSON='{"title":"no labels key"}' RELAY_CHECK_MODE=eval "$lg"
expect_exit AC-LG-04 1 env -u RELAY_LABELS -u RELAY_LABELS_JSON RELAY_CHECK_MODE=ci "$lg"
expect_exit AC-LG-05 1 env -u RELAY_LABELS -u RELAY_LABELS_JSON RELAY_CHECK_MODE=ci \
	GITHUB_REPOSITORY=acme/relay PR_NUMBER=9 "$lg"
expect_exit AC-LG-06 0 env -u RELAY_LABELS RELAY_LABELS_JSON='{"labels":[]}' RELAY_CHECK_MODE=eval "$lg"
expect_contains AC-LG-07 'gated: no'

expect_exit AC-LG-08 0 env -u RELAY_LABELS RELAY_LABELS_JSON='{"labels":[{"name":"bug"}]}' RELAY_CHECK_MODE=eval "$lg"
expect_contains AC-LG-09 'gated: no'

expect_exit AC-LG-10 0 env RELAY_LABELS='security' RELAY_CHECK_MODE=eval "$lg"
expect_contains AC-LG-11 'gated: yes'
expect_contains AC-LG-12 'matched: security'

expect_exit AC-LG-13 0 env RELAY_LABELS=' Sensitive ' RELAY_CHECK_MODE=eval "$lg"
expect_contains AC-LG-14 'matched: sensitive'

expect_exit AC-LG-15 0 env RELAY_LABELS='APPROVAL-REQUIRED' RELAY_CHECK_MODE=eval "$lg"
expect_contains AC-LG-16 'matched: approval-required'

expect_exit AC-LG-17 0 env RELAY_LABELS="$(printf '\tmigration\t')" RELAY_CHECK_MODE=eval "$lg"
expect_contains AC-LG-18 'matched: migration'

for name in privacy legal security; do
	expect_exit "AC-LG-19-${name}" 0 env RELAY_LABELS="$name" RELAY_CHECK_MODE=eval "$lg" --gated-only
	expect_contains "AC-LG-20-${name}" yes
done

expect_exit AC-LG-21 0 env RELAY_LABELS='enhancement' RELAY_CHECK_MODE=eval "$lg" --gated-only
expect_contains AC-LG-22 no

# N3: CI=true ignores RELAY_LABELS* unless MODE=eval.
expect_exit AC-LG-23 1 env CI=true RELAY_CHECK_MODE=ci RELAY_LABELS=security "$lg"
expect_exit AC-LG-24 0 env CI=true RELAY_CHECK_MODE=eval RELAY_LABELS=security "$lg"
expect_contains AC-LG-25 'gated: yes'

finish
