# Spec: tdd-order --staged hardening and jscpd guards scan

## Title

Harden `tdd-order --staged` against a faked merge, and scan `guards.yml` for duplication.

## Status

Accepted

## Background

`--staged` treats `MERGE_HEAD` as a local convenience. A faked
`MERGE_HEAD` that points at `origin/main` can currently pass when
production is staged, because own-edit detection counts deletions and
paths that are not in the index. Incoming tests from `origin/main`
then look like companion tests.

Separately, the jscpd job ignores `.github/workflows/guards.yml`,
which hides a duplicated resolve-head block on `main`.

## Scope

- In: `--staged` own-edit detection; jscpd ignore list; a minimal
  refactor of the repeated block in `guards.yml`.
- Out: `--range` merge skip rules; guard behaviour, event triggers,
  and status context names.

## Acceptance criteria

- **AC-TD-22:** When `MERGE_HEAD` is faked to `origin/main` and the
  index has a staged production path with no staged test path,
  `tdd-order --staged` exits non-zero. Incoming tests from
  `origin/main` that are missing from the index do not count as a
  companion test change.
- **AC-CI-06b:** The jscpd step in the PR-controlled `ci` workflow
  does not ignore `.github/workflows/guards.yml`.
- **AC-CI-07-label-guard / AC-CI-07-approver / AC-CI-23:** Status
  contexts stay `guards / denylist`, `guards / label-guard`, and
  `guards / approver`. Existing AC-CI checks for `pull_request_target`,
  base-branch scripts, and PR-head-as-data remain green.

## Traceability

| Criterion | Test name or tag | Status |
|---|---|---|
| AC-TD-22 | AC-TD-22 in `tests/tdd-order.test.sh` | green |
| AC-CI-06b | AC-CI-06b in `tests/workflow.test.sh` | green |
| AC-CI-07-* / AC-CI-23 | `tests/guards-workflow.test.sh` | exists |

## Open questions

- None.
