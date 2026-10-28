# Realized-Relay™

Canonical instructions for agents in this repository. Nested `AGENTS.md` files, if any, apply only to their directory; the nearest file wins. User chat overrides this file.

Pointer layers (`CLAUDE.md`, `.cursor/rules/`, `.agents/rules/`) must only name this file. Do not copy these rules into those files.

## Method

Work in this order. Do not skip a step.

1. **Spec.** Write or update a specification before changing behaviour. Use `docs/spec-template.md` when that file exists. The spec is the source of truth; code expresses it.
2. **Numbered acceptance criteria.** Every testable requirement is `AC-n` (`AC-1`, `AC-2`, …). Each criterion is independently testable. If a detail is missing, mark `[NEEDS CLARIFICATION]` and stop guessing.
3. **Tests first.** Add or update tests that name or tag the `AC-n` they cover. Run them. They must fail for the missing behaviour, not because of a broken harness.
4. **Implement.** Write the smallest change that makes those tests pass. Then refactor without changing behaviour.

Skills that encode this sequence: `/sdd-to-tdd` for the loop; `/init` for first-time layers; `/commit` and `/push` for landing work.

## Commands

Use these entry points. Do not invent a second set.

| Action | Command |
|---|---|
| Select agents and write pointer layers | `/init` |
| Spec → numbered ACs → tests → implement | `/sdd-to-tdd` |
| Create a commit | `/commit` |
| Push the current feature branch | `/push` |

Repository checks:

- Tests: `bash tests/run.sh`. Treat that result as authoritative.
- This repository already ships hooks and CI. Enable hooks with `git config core.hooksPath .githooks` (see `.githooks/INSTALL`). Do not add a second test runner here.
- Keep this file well under 32 KiB (Codex default `project_doc_max_bytes`).
- Keep each pointer file under 40 lines.

## What "done" means

A change is done only when all of the following are true:

1. Every `AC-n` in scope has at least one test that names or tags that id.
2. Those tests were actually executed in this session (not assumed, not skipped).
3. The run is green for the intended behaviour. No test was deleted, skipped, marked expected-fail, or weakened to get that green.
4. Pointer files still only point here. No rule text was duplicated into them.
5. No secrets, personal data, or client data were written to files or command output.

If a test command does not exist yet, documentation-only work is done when the line budgets above hold and the files match the spec. Behaviour changes are not done.

## Skills

Canonical skill files live at `.agents/skills/<name>/SKILL.md` (`init`, `sdd-to-tdd`, `commit`, `push`). Codex, Cursor, and Antigravity discover that path. Claude Code does not; `CLAUDE.md` tells it to open the same files when those names are invoked.

Status: Cursor and Antigravity are fully tested; Claude Code and Codex are beta. `/init` writes the per-agent pointer files.

## Git and publish

- Work on a feature branch. Open a draft pull request against `main`.
- Never push to `main`, never force-push, never tag.
- Do not mark a pull request ready and do not request reviewers. The ready step is a later gate.
- Do not add `.githooks/` or CI workflow files. This repository already ships hooks and CI.
- Do not bypass hooks with `--no-verify` when hooks exist. Hooks are bypassable; CI must re-check.

## Sensitive work

If the change is labelled, or is about, any of `sensitive`, `migration`, `approval-required`, `privacy`, `legal`, or `security`, stop. The required-approver step (tied to the current head SHA) must pass. This repository's hooks and CI own the fail-closed check. Missing labels, empty API output, or an approval on a different SHA means fail, not proceed.

Gated pull requests need an APPROVED review on the current head SHA from a GitHub user who is not the pull request's author. GitHub rejects author self-approval (HTTP 422). Stay draft until that review lands.

## Do not

- Copy, port, or read code from other repositories. Write from the spec and public docs.
- Put credentials, tokens, private keys, or personal or client identifiers in the tree or in output.
- Restate this file inside a pointer layer.
- Expand `README.md` beyond a short human overview. That file is for people; this file is for agents.
