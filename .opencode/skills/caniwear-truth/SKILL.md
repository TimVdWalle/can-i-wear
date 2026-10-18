---
name: Can I Wear Truth
description: Follow Can I Wear project truth files, decisions, issues, and validation rules
---

# Can I Wear project workflow

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
4. Inspect the existing implementation before editing.

Do not invent or silently change approved behavior. If the requested change conflicts with an approved decision, or expected behavior is undefined, ask the user first.

For reported bugs, update the matching entry in `docs/ISSUES.md`, implement only behavior already supported by the truth files, add regression coverage where practical, and record validation. Do not mark an issue resolved without passing acceptance checks.

Keep recommendation logic, thresholds, aggregation, caching, and provider behavior unchanged unless the user explicitly approves a change.
