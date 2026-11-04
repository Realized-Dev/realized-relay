# Contributing

Realized-Relay™ is licensed under Apache-2.0 (see [LICENSE](LICENSE) and [NOTICE](NOTICE)). Do not submit code or text you are not entitled to contribute.

## Before you start

- Read [AGENTS.md](AGENTS.md). It is the canonical method for people and agents: spec, numbered acceptance criteria, tests, then implementation.
- Enable the repository hooks with `git config core.hooksPath .githooks`. See [.githooks/INSTALL](.githooks/INSTALL).
- Run the checks with `bash tests/run.sh`. It must pass before you open a pull request.

## Workflow

- Work on a feature branch. Never push to `main`, never force-push, and never tag.
- Publish a branch with `/push` (see [.agents/skills/push/SKILL.md](.agents/skills/push/SKILL.md)). Open a **draft** pull request against `main`.
- Agents do not mark a pull request ready or request reviewers. A maintainer makes that step.
- Use Conventional Commits and keep one logical change per commit (see [.agents/skills/commit/SKILL.md](.agents/skills/commit/SKILL.md)).

## Protected paths

Paths listed in [PROTECTED_PATHS](PROTECTED_PATHS) need commits authored by a listed maintainer. A pull request authored by an agent that touches them fails the protected-paths check.

## Hooks and CI

Do not bypass hooks with `--no-verify`. Local hooks can be skipped, so CI re-runs the same checks on the pull request head.
