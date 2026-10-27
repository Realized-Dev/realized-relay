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
- **AC-TD-23:** The same faked-merge case still fails when the staged
  production pathname would be quoted by `git diff --name-only`
  (for example a double quote in the path).
- **AC-CI-06b:** When the PR-controlled duplication check runs and the
  trusted guard workflow contains duplicate content, the check reports
  it. The check does not have to report a clone when no duplicate
  content exists.
- **AC-CI-07-label-guard:** Status context `guards / label-guard` stays.
- **AC-CI-07-approver:** Status context `guards / approver` stays.
- **AC-CI-23:** Status context `guards / denylist` stays on the PR head.

## Traceability

| Criterion | Test name or tag | Status |
|---|---|---|
| AC-TD-22 | AC-TD-22 in `tests/tdd-order.test.sh` | green |
| AC-TD-23 | AC-TD-23 in `tests/tdd-order.test.sh` | green |
| AC-CI-06b | AC-CI-06b in `tests/workflow.test.sh` | green |
| AC-CI-07-label-guard | `AC-CI-07-label-guard` in `tests/guards-workflow.test.sh` | exists |
| AC-CI-07-approver | `AC-CI-07-approver` in `tests/guards-workflow.test.sh` | exists |
| AC-CI-23 | `AC-CI-23` in `tests/guards-workflow.test.sh` | exists |

## Open questions

- None.
