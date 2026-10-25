# AGENTS.md

Canonical instructions for agents in this repository. Nested `AGENTS.md` files, if any, apply only to their directory; the nearest file wins. User chat overrides this file.

Pointer layers must only name this file. Do not copy these rules into those files.

## Method

Work in this order. Do not skip a step.

1. **Spec.** Write or update a specification before changing behaviour. Use `docs/spec-template.md` when that file exists. The spec is the source of truth; code expresses it.
2. **Numbered acceptance criteria.** Every testable requirement is `AC-n` (`AC-1`, `AC-2`, …). Each criterion is independently testable. If a detail is missing, mark `[NEEDS CLARIFICATION]` and stop guessing.
3. **Tests first.** Add or update tests that name or tag the `AC-n` they cover. Run them. They must fail for the missing behaviour, not because of a broken harness.
4. **Implement.** Write the smallest change that makes those tests pass. Then refactor without changing behaviour.

## Commands

Document the real install, test, and lint commands for this repository here. Agents will run what you list.

- Tests: `[NEEDS CLARIFICATION: test command]`
- Lint: `[NEEDS CLARIFICATION: lint command]`

Skills, when present: `/init`, `/sdd-to-tdd`, `/commit`, `/push`.

## What "done" means

A change is done only when all of the following are true:

1. Every `AC-n` in scope has at least one test that names or tags that id.
2. Those tests were actually executed in this session.
3. The run is green for the intended behaviour. No test was deleted, skipped, marked expected-fail, or weakened to get that green.
4. Pointer files still only point here.
5. No secrets, personal data, or client data were written to files or command output.
