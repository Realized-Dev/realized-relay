# Guard workflow

`guards` (`.github/workflows/guards.yml`) is a **base-branch** workflow.

It is triggered by `pull_request_target`, so GitHub loads the workflow
file and the check scripts from the pull request's **base** (usually
`main`). A pull request can edit `guards.yml` or `checks/*.sh`; those
edits **do not run** until they are merged to `main`.

## What it does

- **denylist** — downloads the pull request head as a tarball (data
  only) and scans it with the trusted `checks/denylist.sh`. The
  `RELAY_DENYLIST` secret is injected only in this job. The job never
  echoes the secret, never checks the head out over the trusted
  scripts, and never runs `npm` or other code from the pull request.
- **label-guard** and **approver** — run the trusted scripts against
  the GitHub API. They bind approval to
  `github.event.pull_request.head.sha`.

After a review is submitted, `ci` (no secrets) re-runs. A
`workflow_run` on that completion re-runs **label-guard** and
**approver** from the trusted copy of this file.

`workflow_run` jobs have `GITHUB_SHA` equal to the default branch, so
their native check run can land on `main`. The job therefore posts a
commit status (`guards / label-guard`, `guards / approver`) on the PR
head SHA (`workflow_run.head_sha`, or the PR resolved from that SHA
through the API). It does not use `workflow_run.pull_requests[0]`.

## Least privilege

`contents: read` and `pull-requests: read` on every job. The
`pr-guards` job also has `statuses: write` so it can post those
head-SHA statuses. No other write scopes. Credentials are not
persisted on the checkout.

## Required checks

Require the `denylist` check (pull_request_target) and the commit
statuses `guards / label-guard` and `guards / approver` on the current
head SHA.
