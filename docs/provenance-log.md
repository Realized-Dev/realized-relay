# Provenance log (internal)

Append-only. One row per decision. Do not put secrets, personal names, or client data here. Whether this file ships in the public commit is a later legal decision.

| Date | Decision | Source | Who |
|---|---|---|---|
| 2026-10-25 | Layers point to `AGENTS.md` and stay under 40 lines | Design choice (internal reviewer, 25 Oct), recorded in the approved clean-build plan | internal reviewer / plan |
| 2026-10-25 | Public label `approval-required` is the required-approver step | Design choice (legal review, 24 Oct), recorded in the approved clean-build plan | legal review / plan |
| 2026-10-25 | Sensitive labels are `sensitive`, `migration`, `approval-required`, `privacy`, `legal`, `security` | Approved clean-build plan § Summary | plan |
| 2026-10-25 | Public `PROVENANCE.md` uses the single prescribed sentence | Legal-review wording, 25 Oct, approved clean-build plan §4 | legal review / plan |
| 2026-10-25 | Keep `docs/provenance-log.md` internal | Legal review, item 5, 25 Oct | legal review / plan |
| 2026-10-25 | Stream A writes instructions, skills, spec template, and provenance; stream B writes hooks and CI | Approved clean-build plan §3 steps 4a and 4b; stream A brief | plan |
| 2026-10-25 | Root `AGENTS.md` is the single source; no required fields; nearest nested file wins | https://agents.md/ (checked 25 Oct 2026) | stream A |
| 2026-10-25 | Keep `AGENTS.md` short; include only lines that change agent action; record commands and how to know work is done | https://aaif.io/blog/writing-an-effective-agents-md (checked 25 Oct 2026) | stream A |
| 2026-10-25 | Cap `AGENTS.md` well under 32 KiB | https://learn.chatgpt.com/docs/agent-configuration/agents-md (`project_doc_max_bytes`, checked 25 Oct 2026) | stream A |
| 2026-10-25 | Codex discovers project skills in `.agents/skills`; front-load trigger words in `description` | https://learn.chatgpt.com/docs/build-skills (checked 25 Oct 2026) | stream A |
| 2026-10-25 | Skills use `SKILL.md` with `name` matching the folder (≤64 chars) and `description` (≤1024 chars) | https://agentskills.io/specification (checked 25 Oct 2026) | stream A |
| 2026-10-25 | Cursor reads root and nested `AGENTS.md`; project rules are `.cursor/rules/*.mdc` | https://cursor.com/docs/rules (checked 25 Oct 2026) | stream A |
| 2026-10-25 | Cursor discovers `.agents/skills/` natively; no Cursor skill-pointer layer | https://cursor.com/docs/skills (checked 25 Oct 2026); closes the research-note open question | stream A |
| 2026-10-25 | Antigravity reads `AGENTS.md`; `.agents/rules/*.md` needs `trigger` or it is discarded | https://antigravity.google/docs/rules/ (checked 25 Oct 2026) | stream A |
| 2026-10-25 | Antigravity workspace skills live at `.agents/skills/<name>/SKILL.md` | https://antigravity.google/docs/skills/ (checked 25 Oct 2026) | stream A |
| 2026-10-25 | Claude Code: `CLAUDE.md` with `@AGENTS.md` so `AGENTS.md` still loads when `CLAUDE.md` exists | https://code.claude.com/docs/en/claude-md (checked 25 Oct 2026) | stream A |
| 2026-10-25 | Claude Code does not discover `.agents/skills/`; `CLAUDE.md` points at those paths | https://code.claude.com/docs/en/skills (checked 25 Oct 2026); anthropics/claude-code#16345 still requests native discovery | stream A |
| 2026-10-25 | Smallest traceable spec is numbered `AC-n` → tests named or tagged `AC-n` | https://github.com/github/spec-kit/blob/main/spec-driven.md (checked 25 Oct 2026); design choice to use one `/sdd-to-tdd` skill rather than Spec Kit commands | stream A |
| 2026-10-25 | TDD is red, then green, then refactor; evidence is a test run, not a prompt | https://martinfowler.com/bliki/TestDrivenDevelopment.html (cited in the research note; method restated in our words) | stream A |
| 2026-10-25 | Prefer small, reviewable changes | https://google.github.io/eng-practices/review/developer/small-cls.html (cited in the research note) | stream A |
| 2026-10-25 | Commit messages follow Conventional Commits types | https://www.conventionalcommits.org/en/v1.0.0/ (checked 25 Oct 2026) | stream A |
| 2026-10-25 | `/init` writes only the layers for the selected agents | Approved clean-build plan §3 step 4b ("`/init` with agent selection") | plan / stream A |
| 2026-10-25 | No files or blocks copied from other repositories; public docs and the attached plan/research note only | Clean-room rules in the approved plan §2.1; stream A brief | plan / stream A |
| 2026-10-27 | Merge-range tdd-order hardening (`--range` expands integration merges; faked `MERGE_HEAD` does not skip) | Commit 69de441 on main | agent drafter |
| 2026-10-28 | Protected-paths guard: agent-authored pull requests touching `PROTECTED_PATHS` fail; listed human logins author those changes | Commits 6cf8471, 859667e, e001fc8 on main; `PROTECTED_PATHS` | agent drafter / plan |
| 2026-10-28 | Relay evals v1 product spec and ten task stubs; eval tasks count as test paths for tdd-order | Commits 3d4929a, a7fc5e5, f4aaa64 on main | agent drafter |
| 2026-10-28 | Cold-start README and docs fixes; README stays under the 80-line budget | Commit e148343 on main | agent drafter |
| 2026-11-03 | Release pack: `LICENSE` states the README notice (proprietary; no licence granted). The release ticket names Apache-2.0; that conflicts with the README and was not used. Legal to resolve before publication | README Notice section; release ticket REAZED-453; instruction on 3 Nov 2026 | agent drafter (flagged for human decision) |
| 2026-11-03 | Release pack: copyright holder in `LICENSE` and `NOTICE` taken from README ("Realized Development Corporation"); no holder invented | README Notice section | agent drafter |
| 2026-11-03 | Release pack: `SECURITY.md` reporting channel left as a TODO; no contact address invented | Repository has no stated contact (3 Nov 2026 check) | agent drafter |
| 2026-11-03 | Release pack: `NOTICE` third-party trademark wording is a draft; TODO to confirm against the 25 Oct legal memo, which was not available to the drafter | Release ticket deliverable 3 | agent drafter |
| 2026-11-03 | Release pack: public `PROVENANCE.md` keeps the prescribed sentence verbatim and adds a clean-build status below it | Legal-review wording, 25 Oct (row above); release ticket deliverable 6 | agent drafter |
| 2026-11-03 | Claude Code and Codex stay marked Beta wherever agent support is listed; guarded by AC-RP-6 in `tests/release-pack.test.sh` | Repository check (3 Nov 2026); README, AGENTS.md, init skill, getting-started | agent drafter |
| 2026-11-03 | No Cursor dry-run release check exists in the repository; none was run. The repository has no typecheck target; `bash tests/run.sh` is the authoritative check | Repository search (3 Nov 2026) | agent drafter |
| 2026-11-03 | Agent PRs touching `LICENSE`, `NOTICE`, `PROVENANCE.md`, or this log fail the protected-paths check until a listed human authors those commits | `PROTECTED_PATHS`; `checks/protected-paths.sh` | agent drafter (flagged for human) |
