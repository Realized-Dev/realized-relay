#!/usr/bin/env bash
# AC-HK: zero-dep hooks exist, are executable, and run local checks via hooksPath.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"

[ -x "$ROOT/.githooks/pre-commit" ] && ok AC-HK-01 || bad AC-HK-01 'pre-commit not executable'
[ -x "$ROOT/.githooks/pre-push" ] && ok AC-HK-02 || bad AC-HK-02 'pre-push not executable'
[ -f "$ROOT/.githooks/INSTALL" ] && ok AC-HK-03 || bad AC-HK-03 'INSTALL note missing'

if grep -q 'core.hooksPath .githooks' "$ROOT/.githooks/INSTALL" \
	&& ! grep -q 'N2' "$ROOT/.githooks/INSTALL"; then
	ok AC-HK-04
else
	bad AC-HK-04 'INSTALL does not mention core.hooksPath and N2'
fi

if grep -q 'run-local.sh' "$ROOT/.githooks/pre-commit" && grep -q -- '--staged' "$ROOT/.githooks/pre-commit"; then
	ok AC-HK-05
else
	bad AC-HK-05 'pre-commit does not call run-local --staged'
fi

if grep -q 'run-local.sh' "$ROOT/.githooks/pre-push" && grep -q -- '--range' "$ROOT/.githooks/pre-push"; then
	ok AC-HK-06
else
	bad AC-HK-06 'pre-push does not call run-local --range'
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git init -q "$tmp"
git -C "$tmp" config user.email hooks@example.test
git -C "$tmp" config user.name Hook Test
git -C "$tmp" config core.hooksPath "$ROOT/.githooks"

printf 'hello\n' >"$tmp/README.md"
git -C "$tmp" add README.md
# Exempt-only first commit should pass tdd-order.
export RELAY_SKIP_SCRIPT_TESTS=1
export RELAY_SKIP_PR_GUARDS=1
if git -C "$tmp" commit -q -m 'readme only'; then
	ok AC-HK-07
else
	bad AC-HK-07 'exempt-only commit was blocked by hooks'
fi

mkdir -p "$tmp/app"
printf 'prod\n' >"$tmp/app/x.sh"
git -C "$tmp" add app/x.sh
set +e
git -C "$tmp" commit -q -m 'prod only' >"$tmp/hook-commit.out" 2>&1
code=$?
set -e
if [ "$code" -ne 0 ]; then
	ok AC-HK-08
else
	bad AC-HK-08 'production-only commit should fail tdd-order via pre-commit'
fi

mkdir -p "$tmp/tests"
printf 'prod\n' >"$tmp/app/x.sh"
printf 'test\n' >"$tmp/tests/x.test.sh"
git -C "$tmp" add app/x.sh tests/x.test.sh
if git -C "$tmp" commit -q -m 'prod with test'; then
	ok AC-HK-09
else
	bad AC-HK-09 'companion test commit should pass pre-commit'
fi

# pre-push calls --range with no SHAs; the script must resolve origin/main itself.
# CI's default pull_request checkout is GitHub's test merge; use the PR head.
hk_event_head=
if [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "${GITHUB_EVENT_PATH}" ]; then
	hk_event_head=$(python3 -c 'import json,sys
p=json.load(open(sys.argv[1])).get("pull_request") or {}
print((p.get("head") or {}).get("sha") or "")' "$GITHUB_EVENT_PATH" 2>/dev/null || true)
fi
if [ -n "$hk_event_head" ] && git cat-file -e "${hk_event_head}^{commit}" 2>/dev/null; then
	git checkout -q --detach "$hk_event_head"
fi
set +e
range_out=$(RELAY_SKIP_SCRIPT_TESTS=1 "$CHECKS/run-local.sh" --range 2>&1)
range_code=$?
set -e
if [ "$range_code" -eq 0 ]; then
	ok AC-HK-10
else
	bad AC-HK-10 "run-local --range without SHAs failed: $range_out"
fi

finish
