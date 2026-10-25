@AGENTS.md

Skills, when present, live at `.agents/skills/<name>/SKILL.md`. Claude Code does not discover that path. When the user invokes `/init`, `/sdd-to-tdd`, `/commit`, or `/push`, read the matching `SKILL.md` and follow it. Do not copy `AGENTS.md` or the skill bodies into this file.
