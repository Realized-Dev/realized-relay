# Provenance log (internal)

Append-only. One row per decision. Do not put secrets, personal names, or client data here. Whether this file ships in the public commit is a later legal decision.

| Date | Decision | Source | Who |
|---|---|---|---|
| 2026-10-25 | Layers point to `AGENTS.md` and stay under 40 lines | Realized design choice (CSTO, 25 Oct), recorded in the approved clean-build plan | CSTO / plan |
| 2026-10-25 | Public label `approval-required` is the required-approver step | Realized design choice (CLRO, 24 Oct), recorded in the approved clean-build plan | CLRO / plan |
| 2026-10-25 | Sensitive labels are `sensitive`, `migration`, `approval-required`, `privacy`, `legal`, `security` | Approved clean-build plan § Summary | plan |
| 2026-10-25 | Public `PROVENANCE.md` uses the single prescribed sentence | CLRO wording, 25 Oct, approved clean-build plan §4 | CLRO / plan |
| 2026-10-25 | Keep `docs/provenance-log.md` internal | CLRO answer 5, 25 Oct | CLRO / plan |
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
| 2026-10-25 | Smallest traceable spec is numbered `AC-n` → tests named or tagged `AC-n` | https://github.com/github/spec-kit/blob/main/spec-driven.md (checked 25 Oct 2026); Realized design choice to use one `/sdd-to-tdd` skill rather than Spec Kit commands | stream A |
| 2026-10-25 | TDD is red, then green, then refactor; evidence is a test run, not a prompt | https://martinfowler.com/bliki/TestDrivenDevelopment.html (cited in the research note; method restated in our words) | stream A |
| 2026-10-25 | Prefer small, reviewable changes | https://google.github.io/eng-practices/review/developer/small-cls.html (cited in the research note) | stream A |
| 2026-10-25 | Commit messages follow Conventional Commits types | https://www.conventionalcommits.org/en/v1.0.0/ (checked 25 Oct 2026) | stream A |
| 2026-10-25 | `/init` writes only the layers for the selected agents | Approved clean-build plan §3 step 4b ("`/init` with agent selection") | plan / stream A |
| 2026-10-25 | No files or blocks copied from other Realized repositories; public docs and the attached plan/research note only | Clean-room rules in the approved plan §2.1; stream A brief | plan / stream A |
