# Spec template

Copy this file to `docs/specs/<change-id>.md` (or replace the headings in place for a single-change repository). Fill every section. Number every testable requirement as `AC-n`. Tests must name or tag the same id.

Do not describe implementation (libraries, file layout, APIs) in acceptance criteria. Criteria state what must be true and how a test would observe it.

## Title

One line. What changes.

## Status

Draft | In review | Accepted

## Background

Why this change exists. Link related specs if any.

## Scope

- In:
- Out:

## Acceptance criteria

Write one independently testable behaviour per id. If a decision is missing, write `[NEEDS CLARIFICATION]` instead of guessing.

- **AC-1:** …
- **AC-2:** …
- **AC-3:** …

## Traceability

Each `AC-n` needs at least one test whose name or tag includes that id. Record the mapping here when tests exist.

| Criterion | Test name or tag | Status (red / green / not written) |
|---|---|---|
| AC-1 | | not written |

## Open questions

- …

## Example (delete in a real spec)

Title: Print `ok` when the status tool is called with `--check`.

- **AC-1:** When the status tool is invoked with `--check` and the process can start, it prints `ok` on stdout and exits 0.
- **AC-2:** When the status tool is invoked without `--check`, it does not print `ok`.
- **AC-3:** When the status tool is invoked with an unknown flag, it exits non-zero and prints nothing that looks like a success token.

Tests: `test_status_check_prints_ok_AC-1`, `test_status_default_silent_AC-2`, `test_status_unknown_flag_nonzero_AC-3`.
