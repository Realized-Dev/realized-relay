[Back to README](../README.md)

# Troubleshooting

| Symptom | What to try |
|---------|-------------|
| `agy` stops with auth failure (403 / UNAUTHENTICATED), or exits because `GEMINI_API_KEY` is not set | Set a valid `GEMINI_API_KEY` in the **login** shell that launches `agy`. Fix key or billing before retrying. Do not paste the key into the tree. |
| Hooks seem idle on commit | Run `git config core.hooksPath .githooks` again (see `.githooks/INSTALL`). |
| Commit rejected with `tdd-order: production changes without a test change` | Add or update tests in the same change, then re-run `bash tests/run.sh`. |
| Denylist / secret scan noise | Unset `RELAY_DENYLIST` passes locally with a notice. Remove accidental secrets; do not weaken the check. |
| Gated draft stuck; `no APPROVED review on the current head SHA` | Ask a **different** GitHub user (not the PR author) to approve the **current** head. Author self-approval returns HTTP 422. Keep the PR draft. |
| Unsure which agents are ready | Use Cursor or Antigravity day-to-day. Treat Claude Code and Codex as beta. |
