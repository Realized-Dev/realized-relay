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

## Prerequisites

- **git** and **GitHub CLI (`gh`)**, signed in with `gh auth login` (minimum scopes `repo`, `read:org`, `gist`) to the account that will push and open draft pull requests.
- **Hooks enabled** in this clone (see First run).
- **A supported agent:**
  - **Antigravity:** `curl -fsSL https://antigravity.google/cli/install.sh | bash`, `agy` on `PATH`, and `GEMINI_API_KEY` in the shell that launches `agy` (a login shell is safest). For API-key auth set `"modelProvider": "gemini"` in `~/.gemini/antigravity-cli/settings.json`. Do not put the key in the repository.
  - **Cursor:** a current Cursor install signed in with your own account; open this folder (no further local setup beyond `/init`).
  - **Claude Code / Codex (beta):** Claude Code — run `/login` (or set Anthropic credentials). Codex — sign in with your OpenAI account. No minimum version is pinned here.

Optional: `RELAY_DENYLIST` in the environment for local secret scanning. If unset, the local denylist check passes with a notice; CI may treat a missing value differently. Do not commit denylist contents or keys.

## First run

1. Clone `https://github.com/Realized-Dev/realized-relay.git` (private; you need access) and open a terminal in the clone root.
2. Enable the shipped hooks (from `.githooks/INSTALL`):

       git config core.hooksPath .githooks

3. Confirm sign-in: `gh` can see the target GitHub repo, and (for Antigravity) `GEMINI_API_KEY` is set in the shell that will run `agy`.
4. Open the folder in your agent (Antigravity or Cursor) and run **`/init`**. Choose the agents you use, or accept the default of all four.
5. Write or refine a spec (see `docs/spec-template.md`; feature specs go under `docs/specs/`), then run **`/sdd-to-tdd`**.
6. On a feature branch (not `main`), run **`/commit`**, then **`/push`**. Expect a **draft** pull request against `main`.

Do not skip step 2. Hooks must be on before `/commit`, or the local checks that accompany a commit will not run.

## Tests

The repository test command is `bash tests/run.sh`. Hooks and `/sdd-to-tdd` rely on this runner. Run it yourself when you want a green check outside an agent turn.

## Gated labels and approval

If the change is labelled (or is about) any of `sensitive`, `migration`, `approval-required`, `privacy`, `legal`, or `security`, stop for the required-approver step. That step needs an **APPROVED** review on the **current head SHA** from a GitHub user who is **not** the pull request's author. GitHub rejects an approval from the author (HTTP 422: "Review Can not approve your own pull request"). Stay on a draft pull request until that non-author approval lands on the current head. Agents must not mark the pull request ready and must not request reviewers.

Label names are matched without regard to letter case (for example `Security` and `security`). Local hooks skip the label check when there is no pull request yet, or when `gh` is missing; approval is checked in CI. See `.githooks/INSTALL` and `docs/guard-workflow.md` (advanced).

## Expected signals

| Step | You should see |
|------|----------------|
| `/init` | Selected agents; **written** or **skipped** pointer files (existing files left alone). |
| `/sdd-to-tdd` | Spec with `AC-n` ids; tests that fail for the missing behaviour; then a green `bash tests/run.sh`. |
| Tests | Lines like `==> tests/….test.sh` and `PASS tests/….test.sh`. |
| `/commit` | A Conventional Commits subject (`feat:`, `fix:`, `docs:`, …) and `local-checks: ok (…)` when hooks are enabled. |
| `/push` | Feature branch pushed; a **draft** pull request against `main` (stays draft). |

## Troubleshooting

| Symptom | What to try |
|---------|-------------|
| `agy` stops with auth failure (403 / UNAUTHENTICATED), or exits because `GEMINI_API_KEY` is not set | Set a valid `GEMINI_API_KEY` in the **login** shell that launches `agy`. Fix key or billing before retrying. Do not paste the key into the tree. |
| Hooks seem idle on commit | Run `git config core.hooksPath .githooks` again (see `.githooks/INSTALL`). |
| Commit rejected with `tdd-order: production changes without a test change` | Add or update tests in the same change, then re-run `bash tests/run.sh`. |
| Denylist / secret scan noise | Unset `RELAY_DENYLIST` passes locally with a notice. Remove accidental secrets; do not weaken the check. |
| Gated draft stuck; `no APPROVED review on the current head SHA` | Ask a **different** GitHub user (not the PR author) to approve the **current** head. Author self-approval returns HTTP 422. Keep the PR draft. |
| Unsure which agents are ready | Use Cursor or Antigravity day-to-day. Treat Claude Code and Codex as beta. |

## What this is not

Not a hosted service, not a full CI product, and it does not merge your work for you. You stay in charge of every merge.

## Notice

Copyright (c) 2026 Realized Development Corporation. All rights reserved. Proprietary; no licence granted.

Realized-Relay™ is a trademark of Realized Development Corporation.
