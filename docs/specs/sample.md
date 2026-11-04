# Sample greeting helper

Status: Draft

## Background

REAZED-448 dry-run sample. A two-requirement change used to exercise the SDD-to-TDD loop end to end.

## Scope

- In: a command-line greeting helper that takes one name argument.
- Out: anything beyond the two criteria below.

## Acceptance criteria

- **AC-1:** When the greeting helper is run with exactly one argument, it prints `Hello, <argument>!` on stdout, followed by a newline, and exits 0.
- **AC-2:** When the greeting helper is run with no arguments, it prints a usage line on stderr, prints nothing on stdout, and exits non-zero.

## Traceability

| Criterion | Test name or tag | Status (red / green / not written) |
|---|---|---|
| AC-1 | `test_greet_one_argument_AC-1` | red |
| AC-2 | `test_greet_no_argument_AC-2` | red |

## Open questions

- None.
