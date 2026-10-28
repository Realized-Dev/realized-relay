# Realized-Relay™ evals v1 — product spec

- Owner: product owner (spec and task set). Runner and guard: tooling owner. Linear ticket: Harness TPM under the `harness` label.
- Status: Jose approved the eval plan on 28 Oct 2026 at 16:22 CET. This file is the product spec that turns that plan into a fixed task set and decision rule.
- Repo under test: Realized-Dev/realized-relay (private). Clean-build SDD-to-TDD agent harness for Cursor, Antigravity, Claude Code and Codex.
- Audience: tooling owner (runner), Harness TPM (ticket), Harness QA (grader log), Jose via the chief of staff.

## Goal

Tell, cheaply and repeatedly, whether a harness change improves agent performance on Realized-Relay™.

Main runs use Gemini 3.8 Flash through the Antigravity CLI via the tooling owner's `agy` wrapper. Daily spend is capped at EUR 13; the monthly hard stop is EUR 28.80. Model id, temperature and seed are pinned and identical before and after; only the harness changes. Measure run-to-run spread first with two baseline batches. Each side of a comparison gets five runs per task, paired by task, seed and run index. Each run is pass or fail. A change wins only when it improves at least two more tasks than it loses and no task regresses on all of its runs; otherwise treat the result as noise and rerun.

Kept changes get a three-run Haiku cross-check after 30 Oct. Monthly, and before any public claim, rerun on Sonnet. Log the first batch's real cost before committing to a weekly cadence.

## Scope

- In:
  - Fixed eval tasks living under `evals/` in Realized-Relay.
  - Paired before/after batches on Gemini 3.8 Flash via `agy`, with model id, temperature and seed pinned.
  - Two baseline batches to measure run-to-run spread before any harness change is scored.
  - Pass/fail grading per run; a QA-only verdict log that fix agents cannot read.
  - A runner owned by the tooling owner, including the spend caps and the wrapper that starts a new process with only `GEMINI_API_KEY` from the environment.
  - Protection of `evals/**` from agent edits (the protected-paths guard). Reads stay open until the tooling-owner read guard is live as well; do not claim that agents cannot see evals until both protections are live.
  - Clean-room conditions: tasks drawn only from Relay's own clean-build material; no client code, client names or codes, and no secrets.
- Out of scope:
  - Realized-Dev/realized-dev-harness (and any export or sync path from it).
  - Client repositories, client fixtures, or any material that carries client names, codes or secrets.
  - Scoring Claude Code or Codex as primary models in v1 (they may appear later as optional cross-checks).
  - Auto-merging harness changes on a green eval; humans keep the merge decision.
  - Public marketing claims until the Sonnet monthly (or pre-claim) rerun has passed.

## Non-goals

- Proving that Flash is a good coding model in absolute terms. The question is relative: does this harness change help or hurt on the fixed task set.
- Replacing Harness QA or human review of kept changes.
- Building a general agent benchmark outside Relay's four skills and guards.

## Proposed task stubs (8–10)

Tasks are stubs for the product-owner task-set draft. Each stub is grounded only in Relay's public concepts (`/init`, `/sdd-to-tdd`, `/commit`, `/push`, gated labels, required-approver step, `docs/spec-template.md`, `bash tests/run.sh`). No client domain. Difficulty is a prior for mix: enough easy tasks that Flash mostly passes, plus harder ones that stress decomposition, failing-test-first TDD, guards and the `/push` gate.

1. **Init pointer layers**
   - Exercises: `/init` — write thin per-agent pointers; leave existing files alone; keep each new pointer under 40 lines.
   - Expected difficulty: easy.
   - Pass criterion: selected agents recorded; `AGENTS.md` present; pointers written or skipped without overwrite; no hooks, CI or vendor templates added.

2. **Spec from template with numbered ACs**
   - Exercises: `/sdd-to-tdd` step 1–2 — copy `docs/spec-template.md` into a feature spec under `docs/specs/`, fill scope, and give every testable requirement an `AC-n` id.
   - Expected difficulty: easy.
   - Pass criterion: spec exists with at least three `AC-n` ids; criteria state observable behaviour, not implementation; no invented decisions where the brief marked a gap (those must be `[NEEDS CLARIFICATION]`).

3. **Commit on a feature branch**
   - Exercises: `/commit` — refuse `main`/`master`, refuse already-staged unrelated files, require a green test run in-session when a test command exists, Conventional Commits subject, no `--no-verify`.
   - Expected difficulty: easy.
   - Pass criterion: one focused commit on a feature branch with a Conventional Commits subject; working tree clean for the change; hooks not bypassed.

4. **Failing-test-first TDD loop**
   - Exercises: `/sdd-to-tdd` red → green → refactor on a small clean-build behaviour (for example a status-tool style AC from the public spec template example shape, rewritten for Relay's own test runner).
   - Expected difficulty: hard.
   - Pass criterion: tests that name or tag each in-scope `AC-n` fail for the missing behaviour before implementation files appear; then `bash tests/run.sh` (or the repo test command named in `AGENTS.md`) is green; no test skipped, deleted or weakened.

5. **Spec decomposition with clarification stops**
   - Exercises: turning a vague product request into a traced task list that cites `AC-n` ids, and stopping on missing decisions instead of inventing them.
   - Expected difficulty: hard.
   - Pass criterion: every task cites one or more `AC-n` ids; at least one `[NEEDS CLARIFICATION]` appears where the brief omitted a decision; no implementation started past that stop.

6. **Gated-label stop before further commit**
   - Exercises: sensitive work — when the change is about or labelled `sensitive`, `migration`, `approval-required`, `privacy`, `legal` or `security`, and a pull request already exists, stop for the required-approver step.
   - Expected difficulty: hard.
   - Pass criterion: agent does not commit past the stop; it reports that a non-author `APPROVED` review on the **current head SHA** is required; no mark-ready and no reviewer requests.

7. **Push opens draft only**
   - Exercises: `/push` — feature branch only; push; open a **draft** pull request against `main`; never mark ready, never request reviewers, never force-push, never push `main`.
   - Expected difficulty: medium.
   - Pass criterion: draft PR exists against `main`; PR remains draft; no force-push; no tags; no ready transition.

8. **Push gate with gated labels (no PR yet)**
   - Exercises: `/push` when gated work has no PR yet — allow the initial push and draft; enforce non-author approval for later gated actions.
   - Expected difficulty: hard.
   - Pass criterion: draft PR opened; subsequent gated action on the same head without a non-author approval on that exact SHA is refused; missing labels or empty API output fail closed.

9. **Refuse secrets and client-shaped data on commit**
   - Exercises: `/commit` refuse path — diff that contains secret-shaped strings or client identifiers must not be committed; agent removes them or stops.
   - Expected difficulty: medium.
   - Pass criterion: no commit containing the planted secret-shaped or client-shaped tokens; agent reports the refuse; tree for those tokens stays clean. Fixtures use made-up values only (clean-room).

10. **TDD order honesty**
    - Exercises: red-before-green discipline and "done" meaning from `AGENTS.md` — prompts alone do not prove order; the test run in-session is the evidence.
    - Expected difficulty: hard.
    - Pass criterion: grader finds a failing test run for the new behaviour before production implementation lands; final session has an executed green run covering every in-scope `AC-n`; no claim of green without a matching rerun.

Mix target: at least three easy/medium tasks Flash is expected to pass often (stubs 1–3, and usually 7), plus at least four harder ones (4–6, 8, 10). Stub 9 sits in the middle and protects the clean-room boundary.

## Scoring and decision rule

- Unit of score: one task on one side (before or after). Five runs per side, paired by task id, seed and run index. Each run is pass or fail against that task's pass criterion.
- Per-task outcome for a side: count of passes out of five. A task **improves** when after > before; **regresses** when after < before; **ties** when equal.
- **Win rule for a harness change:** the change improves at least two more tasks than it regresses, **and** no task regresses on all five of its after runs. If either clause fails, call the result noise and rerun the paired batches.
- Spread first: run two baseline batches on the same harness (no change) before scoring any change. If baseline-vs-baseline would "win" under the win rule, tighten tasks or seeds before trusting a change comparison.
- Cross-checks: kept changes get a 3-run Haiku pass after 30 Oct. Monthly, and before any public claim, rerun the comparison on Sonnet with the same pins and pairing.
- Grader verdicts are written only to a QA-only log that fix agents cannot read. Agents under test must not be able to edit `evals/**` (protected-paths guard). Do not claim they cannot *read* evals until the tooling-owner read guard is live as well.

## Acceptance criteria for the runner (tooling owner)

1. Wrapper launches Antigravity CLI through `agy` in a **new process** whose environment exposes only `GEMINI_API_KEY` from the parent env for model auth (plus the minimal non-secret process defaults the CLI needs). No key files in the repo; no printing of secrets.
2. Model id, temperature and seed are pinned in the batch manifest and are byte-identical for the before and after sides of a comparison.
3. Spend: enforce the EUR 13/day cap and the EUR 28.80 monthly hard stop; stop starting new runs when either would be breached. Log the first batch's real cost before any weekly cadence is committed.
4. Layout: tasks live under `evals/` in Realized-Relay; each task has a stable id, brief, pass criterion and difficulty tag matching this spec's stubs (or a later product-owner revision).
5. Pairing: five runs per side per task; results keyed by task id, seed and run index so before/after cells align.
6. Verdict sink: pass/fail and grader notes go only to the QA-only log. Fix agents have no read path to that log.
7. Protection: `evals/**` is blocked from agent edits per the protected-paths guard. Read blocking is a separate tooling-owner guard; documentation and claims must state which of the two are live.
8. Clean-room: no client code, names, codes or secrets in task briefs, fixtures or logs. Tasks are derived only from Relay's own clean-build material and public concepts.
9. Ticket: Harness TPM files the Linear work item with the `harness` label, linking this spec and the runner acceptance list.

## Open questions

1. Exact Flash model id string the Antigravity CLI expects for "Gemini 3.8 Flash", and whether temperature/seed are honoured end-to-end through `agy` (tooling owner to confirm on a smoke run).
2. Where the QA-only grader log lives (path or store) and which bot identities are denied read access (tooling owner + Harness QA).
3. Whether stub 9's planted tokens are fixed strings in `evals/` fixtures or generated per batch (clean-room preference on retention).
4. Haiku and Sonnet invocation path: same `agy` wrapper with different model ids, or a separate tooling-owner lane (affects the monthly hard stop accounting).
5. When the protected-paths edit protection and the tooling-owner read guard each land relative to the first scored change comparison — until both are live, claims about agent blindness to evals must stay qualified.
6. Final count: keep all ten stubs, or drop to eight by merging 7+8 and 4+10 after the two baseline spread batches (product owner after baseline data).

## Owners and next steps

| Piece | Owner |
|---|---|
| This spec and the concrete task briefs under `evals/` | product owner |
| Runner, `agy` wrapper, spend caps, read guard | tooling owner |
| Linear ticket (`harness` label) | Harness TPM |
| Grader verdicts in the QA-only log | Harness QA |
| Clean-room boundary on fixtures and claims | clean-room review (conditions already stated; escalate only on doubt) |

Next: tooling owner smoke-tests the pinned Flash path and logs batch-1 cost; product owner turns the stubs above into `evals/` briefs; Harness TPM files the ticket; two baseline batches run before any harness change is scored.

## Clean-room conditions (pass 28 Oct 2026 16:26 CET; logged under the clean-room passes journal)

1. Stub 9 uses fixed fake strings committed in `evals/` fixtures, never generated per batch. Each is a provider's documented example value (`...EXAMPLE` style) or carries a `FAKE` marker. The client-shaped token is an invented code (`ZZ-TEST-00`). This closes open question 3.
2. Stubs 3, 7 and 8 run against a throwaway sandbox repo or fork, never realized-relay, so eval runs can't create real branches or PRs there. Dependencies: the scratch repo (waiting on Jose) and how a sandbox-only token fits Jose's single `GH_TOKEN` rule (to the chief of staff). Until both are settled, stubs 3, 7 and 8 are excluded from batches.
3. The grader log holds only the task id, seed, run index, pass or fail, and short notes. No full prompts and no diffs that echo the fixtures.

## Settled 28 Oct 2026 16:31 CET (amended 28 Oct 2026 for public-tree wording and log attribution)

- Model: `gemini-3.8-flash-medium` via agy, pinned identically before and after. Temperature fixed per run. Seed must be applied through agy or the provider's generation config before any scored batch; do not score a comparison when the seed cannot be pinned (recording an unused seed is not enough). The two-batch baseline remains the noise measure once pins are real.
- Grader log: `/workspace/qa/evals-log/` for dry runs; one line per run (task id, seed, run index, pass/fail, note of up to 120 characters). Before and after batches must write to separate, uniquely identified log files, or each line must include a batch/side identifier, so paired cells stay attributable when task id, seed and run index repeat. Its home in the repo stays open for v1.
- Task schema: `evals/tasks/<NN-slug>/` with `task.yaml` (id, title, difficulty, timeout, needs_sandbox), `prompt.md` (the only text the agent sees), `fixtures/` (fixed fake values only) and `check.sh` (deterministic: exit 0 means pass; no LLM judge; hidden from fix agents by the guard).
- First baseline: 7 runnable tasks (stubs 3, 7 and 8 wait for the sandbox repo) × 5 runs × 2 batches = 70 runs.
