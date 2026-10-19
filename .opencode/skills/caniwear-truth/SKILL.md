---
name: Can I Wear Truth
description: Follow Can I Wear project truth files, decisions, issues, and validation rules
---

# Can I Wear project workflow

Start with the repository-root `AGENTS.md`. Working rules and the per-task quality standard live in `docs/AI_RULES.md`; this skill routes tasks to the relevant project documents rather than duplicating those rules. All paths below are relative to the repository root.

Before changing code or product behavior:

1. Read `docs/PROJECT.md` and `docs/AI_RULES.md`.
2. Read `docs/ISSUES.md` and check relevant reported issues.
3. Read the relevant truth files:
   - product behavior: `docs/PRODUCT_SPEC.md`
   - approved decisions: `docs/DECISIONS.md`
   - weather logic: `docs/WEATHER_LOGIC.md`
   - technical constraints: `docs/TECH_SPEC.md`
   - Home Screen UX: `docs/UX.md`
   - current status: `docs/TODO.md`
4. Follow the implementation and validation workflow in `docs/AI_RULES.md` §1.2.

For decisions or undefined/conflicting behavior, use the truth hierarchy in `docs/PROJECT.md` and the decision-handling rules in `docs/AI_RULES.md` §§2–3, 13–14.

For reported bugs, use `docs/ISSUES.md` and the issue/verification workflow in `docs/AI_RULES.md` §13.5.
