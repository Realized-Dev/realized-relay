# Task: Commit on a feature branch

**SANDBOX ONLY.** Run this task only against a throwaway sandbox repo or fork, with a token scoped to that repo. Never run against Realized-Dev/realized-relay.

Follow `/commit`:
- Refuse `main`/`master`.
- Refuse already-staged unrelated files.
- If a test command exists, it must have been run green in-session.
- One focused commit with a Conventional Commits subject.
- Do not pass `--no-verify`.

Make a tiny docs-only edit (for example a comment in a sandbox-local NOTES.md you create), then commit it on a feature branch.
