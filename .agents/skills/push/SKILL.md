---
name: push
description: Pushes the current feature branch to origin. Use when the user says /push, asks to publish a branch, or open a pull request. Never push main, force-push, or tag.
---

# /push

Push the current feature branch. Never update `main` from this skill.

## Steps

1. Run `git branch --show-current`, `git status`, and `git rev-parse --abbrev-ref @{upstream}` (upstream may be missing).
2. Abort if the current branch is `main` or `master`.
3. Abort if the working tree has uncommitted changes that belong to this work. Use `/commit` first.
4. If the change is labelled, or is about, any of `sensitive`, `migration`, `approval-required`, `privacy`, `legal`, or `security`, stop unless the required-approver check has passed for this exact head SHA. Missing labels, empty API output, or an approval on another SHA is a fail.
5. Push only this branch: `git push -u origin HEAD`. On network failure, retry up to four times with 4s, 8s, 16s, 32s delays. Do not retry a rejection that is not a network error.
6. If no pull request exists for this branch, open a **draft** pull request against `main`.
7. Do not mark the pull request ready. Do not request reviewers. Do not merge.

## Hard stops

- Never `git push origin main`, never a bare `git push` while on `main`.
- Never `--force`, `--force-with-lease`, or other force-push forms.
- Never create or move a tag.
- Never `--no-verify`.

## Gotchas

- Local hooks are bypassable. When CI exists, it must re-run every guard. Stream B owns those checks in this repository.
- A draft pull request is the landing form until a later ready gate. Do not skip it by pushing to `main`.
