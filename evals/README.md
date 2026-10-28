# Realized-Relay™ evals v1

Fixed task stubs for repeated harness evals. Product spec: `docs/specs/relay-evals-v1.md`.

## Layout

Each task lives at `evals/tasks/<NN-slug>/`:

| File | Role |
| --- | --- |
| `task.yaml` | id, title, difficulty, timeout, needs_sandbox |
| `prompt.md` | only text the agent under test sees |
| `fixtures/` | fixed fake values only (isolation) |
| `check.sh` | deterministic grader; exit 0 = pass; no LLM judge |

## Pins

- Model: `gemini-3.8-flash-medium` via `agy` (runner-owner runner; not in this tree).
- Grader dry-run log: `/workspace/qa/evals-log/` — one line per run: task id, seed, run index, pass/fail, note ≤ 120 characters. No full prompts. No diffs that echo fixtures. Before and after batches use separate, uniquely named log files (or each line includes a batch/side id) so paired cells stay attributable.

## Sandbox tasks

Stubs `03`, `07`, and `08` set `needs_sandbox: true`. They run only against a throwaway sandbox repo or fork with a token scoped to that repo — never Realized-Dev/realized-relay. Excluded from batches until the sandbox exists.

## Out of scope here

The runner owner owns the runner under `scripts/evals/` (or external tooling). This directory is task fixtures only.
