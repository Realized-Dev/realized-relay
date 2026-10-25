---
name: init
description: Initializes Realized-Relay™ agent layers in a repository. Use when the user says /init, asks to set up Relay, select agents, or add AGENTS.md, CLAUDE.md, Cursor rules, or Antigravity rules.
---

# /init

Write the thinnest per-agent pointer layers so each tool loads the canonical `AGENTS.md`. Do not copy vendor starter templates. Do not write `.githooks/` or CI.

## Inputs

Ask once, then proceed. Default is all four agents if the user does not choose.

Supported agents:

| Agent | Status | What this skill writes |
|---|---|---|
| Cursor | supported | `.cursor/rules/relay-pointer.mdc` |
| Antigravity | supported | `.agents/rules/relay-pointer.md` with a valid `trigger` |
| Claude Code | beta | `CLAUDE.md` containing `@AGENTS.md` |
| Codex | beta | nothing extra; Codex reads root `AGENTS.md` |

Always ensure a root `AGENTS.md` exists. If it is missing, create it from [assets/agents.md.tpl](assets/agents.md.tpl). If it already exists, leave it and report that.

## Steps

1. Confirm the working directory is the repository root (a `.git` directory or `git rev-parse --show-toplevel`).
2. Record the selected agents.
3. If `AGENTS.md` is absent, write [assets/agents.md.tpl](assets/agents.md.tpl) to `AGENTS.md`.
4. For each selected agent, write the matching template only if that path is absent:
   - Cursor → [assets/cursor-rule.mdc.tpl](assets/cursor-rule.mdc.tpl) as `.cursor/rules/relay-pointer.mdc`
   - Antigravity → [assets/antigravity-rule.md.tpl](assets/antigravity-rule.md.tpl) as `.agents/rules/relay-pointer.md`
   - Claude Code → [assets/claude.md.tpl](assets/claude.md.tpl) as `CLAUDE.md`
   - Codex → no file
5. If a target file already exists, do not overwrite it. List it as skipped.
6. Check each written pointer is under 40 lines and does not restate the method.
7. Report written, skipped, and selected agents.

## Gotchas

- Antigravity silently discards `.agents/rules/*.md` without YAML `trigger` set to `always_on`, `model_decision`, `glob`, or `manual`. Use the template as-is.
- Antigravity scans only immediate children of `.agents/rules/`. Do not nest the pointer.
- Cursor project rules must use the `.mdc` extension and frontmatter. A plain `.md` file in `.cursor/rules/` is ignored.
- Claude Code loads `CLAUDE.md` instead of `AGENTS.md` when both exist, unless `CLAUDE.md` imports `AGENTS.md`. The `@AGENTS.md` line is required.
- Claude Code does not discover `.agents/skills/`. The Claude pointer tells it to open those files by name.
- Do not write `GEMINI.md` unless the user asks. Antigravity already reads `AGENTS.md`.
- Do not add secrets, personal data, or client data.

## Checklist

- [ ] Selected agents recorded
- [ ] `AGENTS.md` present
- [ ] Pointers written or skipped without overwrite
- [ ] Each new pointer is under 40 lines
- [ ] No hooks, CI, or vendor templates added
