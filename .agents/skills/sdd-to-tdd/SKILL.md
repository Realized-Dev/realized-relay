---
name: sdd-to-tdd
description: Runs the spec-then-tests-then-implement loop. Use when the user says /sdd-to-tdd, asks for SDD, TDD, numbered acceptance criteria, a spec, or red-green-refactor.
---

# /sdd-to-tdd

Turn a request into a spec with numbered acceptance criteria, then prove the behaviour with tests before writing production code.

## Steps

1. **Spec.** Open `docs/spec-template.md` and write or update a spec for this change. Put feature specs under `docs/specs/` when more than one change is in flight. The spec states what must be true, not how to implement it.
2. **Number the criteria.** Give every testable requirement an `AC-n` id (`AC-1`, `AC-2`, …). One behaviour per id. If the user omitted a decision, write `[NEEDS CLARIFICATION]` and ask; do not invent it.
3. **Trace tasks.** List the work as tasks that each cite one or more `AC-n` ids. Keep the change small enough to review as one unit.
4. **Red.** Write tests first. Each test name or tag includes the `AC-n` it covers. Run the repository test command from `AGENTS.md`. The new tests must fail for the missing behaviour.
5. **Green.** Implement the smallest change that makes those tests pass. Run the same test command.
6. **Refactor.** Clean the change without changing behaviour. Run the tests again. They must stay green.

## Done

Stop only when `AGENTS.md` "What done means" holds: tests for every in-scope `AC-n` were executed, the run is green, and no test was skipped or weakened.

If no test command exists yet, write the spec and the failing tests, then stop. Do not add a second test runner. Stream B owns hooks and CI for this repository.

## Gotchas

- A test that fails because the harness cannot start is not a red-for-behaviour. Fix the harness first, or stop.
- Replacing an assertion with a weaker one, adding `skip` / `xfail`, or deleting the test is not green.
- Prompts alone do not prove red-before-green. The test run in this session is the evidence.
- Do not start implementation files before the red run, except test files.
