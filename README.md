# Realized-Relay™

A small starter for new projects with AI coding agents: write the spec first, turn it into tests, then commit and push in small steps. Agents open draft pull requests. A person approves every merge.

Realized-Relay™ ships no vendor tools or keys; you use your own accounts under each vendor's terms.

## Works with

| Agent | Status |
|-------|--------|
| Cursor | Fully tested |
| Antigravity | Fully tested |
| Claude Code | Beta |
| Codex | Beta |

## Quick start

1. [Clone](docs/getting-started.md#first-run) `https://github.com/Realized-Dev/realized-relay.git` (private; you need access) and open a terminal in the clone root.
2. [Enable hooks](docs/getting-started.md#first-run): `git config core.hooksPath .githooks`.
3. [Sign in](docs/getting-started.md#prerequisites): `gh auth login` (minimum scopes `repo`, `read:org`, `gist`).
4. Open the folder in your agent and run [`/init`](docs/getting-started.md#first-run).
5. Confirm green with [`bash tests/run.sh`](docs/getting-started.md#tests).

## Approval

If the change is labelled (or is about) any of `sensitive`, `migration`, `approval-required`, `privacy`, `legal`, or `security`, stop for the required-approver step. That step needs an **APPROVED** review on the **current head SHA** from a GitHub user who is **not** the pull request's author. GitHub rejects an approval from the author (HTTP 422: "Review Can not approve your own pull request"). Stay on a draft pull request until that non-author approval lands on the current head. Agents must not mark the pull request ready and must not request reviewers.

## Docs

- [Getting started](docs/getting-started.md) — prerequisites, first-run path, expected signals
- [Troubleshooting](docs/troubleshooting.md)
- [Spec template](docs/spec-template.md)
- [Guard workflow](docs/guard-workflow.md) (advanced)

## Notice

Copyright (c) 2026 Realized Development Corporation. All rights reserved. Proprietary; no licence granted.

Realized-Relay™ is a trademark of Realized Development Corporation.
