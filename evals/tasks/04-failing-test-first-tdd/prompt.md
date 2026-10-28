# Task: Failing-test-first TDD loop

Follow `/sdd-to-tdd` red → green → refactor for a small Relay-only behaviour:

- Spec a tiny `sample-greet` helper that prints `hello` when called with no arguments (stdout).
- Number acceptance criteria as `AC-n`.
- Write tests that name or tag each in-scope `AC-n` **before** implementation files appear; they must fail for the missing behaviour.
- Implement the smallest change that makes `bash tests/run.sh` (or the test command named in `AGENTS.md`) green.
- Do not skip, delete, or weaken tests.
