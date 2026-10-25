---
name: commit
description: Creates a git commit for the current change. Use when the user says /commit, asks to commit, stage, or write a commit message.
---

# /commit

Create one focused commit on the current feature branch. Do not push.

## Steps

1. Run `git status`, `git diff`, and `git log --oneline -10`. Read them before staging.
2. Refuse if the branch is `main` or `master`. Ask for a feature branch first.
3. Refuse if the diff contains secrets, personal data, client data, or credentials. Remove them; do not commit.
4. If the change is labelled, or is about, any of `sensitive`, `migration`, `approval-required`, `privacy`, `legal`, or `security`, stop for the required-approver step. Do not commit past that stop.
5. If `AGENTS.md` lists a test command, that command must have been run in this session and green. If it was not run, run it. If it fails, fix or stop; do not commit a red suite.
6. Stage only the files that belong to this change. Do not add generated noise or local settings.
7. Commit with a Conventional Commits subject (`feat:`, `fix:`, `docs:`, `test:`, `chore:`, …). Explain why in the body when the subject is not enough.
8. Do not pass `--no-verify`.

## Message shape

```
type: short summary

Optional body: why this change exists, and which AC-n ids it covers.
```

## Gotchas

- One concern per commit. Split unrelated edits.
- Do not amend a commit that has already been pushed.
- Do not tag.
- If hooks do not exist yet (stream B owns them in this repository), still follow the checks above.
