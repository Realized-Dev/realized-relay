# Sample greeting helper

## Status
Accepted

## Background
Dry-run sample for REAZED-447 Antigravity nine-step script.

## Scope
- In: a tiny greeting helper used only for dry-run evidence
- Out: production features

## Acceptance criteria
- **AC-1:** When `sample/greet.sh` is invoked with one argument, it prints `hello <arg>` on stdout and exits 0.
- **AC-2:** When `sample/greet.sh` is invoked with no arguments, it exits non-zero and prints nothing that starts with `hello`.

## Traceability
| Criterion | Test name or tag | Status |
|---|---|---|
| AC-1 | tests/sample-greet.test.sh::AC-1 | green |
| AC-2 | tests/sample-greet.test.sh::AC-2 | green |
