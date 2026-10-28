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
4. If the change is labelled, or is about, any of `sensitive`, `migration`, `approval-required`, `privacy`, `legal`, or `security`, and a pull request already exists for this branch, stop unless the required-approver check has passed for this exact head SHA. Missing labels, empty API output, or an approval on another SHA is a fail. If no pull request exists yet, continue: push and open the draft (step 6); enforce non-author approval for later gated actions and before merge.
5. Push only this branch: `git push -u origin HEAD`. On network failure, retry up to four times with 4s, 8s, 16s, 32s delays. Do not retry a rejection that is not a network error.
6. If no pull request exists for this branch, open a **draft** pull request against `main`.
7. Do not mark the pull request ready. Do not request reviewers. Do not merge.

## Hard stops

- Never `git push origin main`, never a bare `git push` while on `main`.
- Never `--force`, `--force-with-lease`, or other force-push forms.
- Never create or move a tag.
- Never `--no-verify`.

## Gotchas

- Local hooks are bypassable. When CI exists, it must re-run every guard. This repository already ships those checks.
- A draft pull request is the landing form until a later ready gate. Do not skip it by pushing to `main`.
- Gated labels need a non-author APPROVED review on the current head SHA. If an approve call returns HTTP 422, inspect the response body before explaining: when it says the author cannot approve their own pull request, stop and wait for another reviewer; for other validation failures, report those details and stop. Do not mark the pull request ready.
