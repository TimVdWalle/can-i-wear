# Can I Wear — AI Working Rules

> Status: ACTIVE
> Last updated: 2026-10-18
> Source of truth: YES

## 1. Optimize for the final product

Judge work by:
- Does it do what the user wants?
- Is the recommendation correct?
- Does it work reliably on a real phone?
- Are there tests?
- Is the UX smooth?
- Are there no unnecessary delays?
- Are there no annoying permission flows?
- Are there no stutters?
- Are there no avoidable micro-frustrations?
- Can it reach the App Store?

Do not optimize for clever implementation at the expense of these outcomes.

## 2. Never invent major decisions

If a missing decision can materially affect:
- product behavior;
- UX;
- architecture;
- platform;
- data provider;
- privacy;
- cost;
- scope;

ask the user.

If useful, provide a recommendation and explain the tradeoff, but label it as a proposal.

## 3. Distinguish three states

Every important item is:
- **DECIDED** — approved and authoritative;
- **PROPOSED** — recommendation awaiting approval;
- **TBD** — unknown and requiring a decision.

Never silently turn PROPOSED/TBD into DECIDED.

## 4. Keep the milestone small; honor the approved first-release scope

Do not add features because they are common in weather apps or technically easy. The **already completed initial real-device milestone** is leather-jacket-only; the **approved first public App Store release** additionally requires multiple predefined items (Phase 4) and an iOS widget (Phase 5). Custom items, threshold editing, saved cities, notifications and other future features must not leak into the initial release without explicit approval. See D-032–D-045 and `ROADMAP.md`.

## 5. Rain protection dominates

For the **leather-jacket recommendation**, rain/fog protection dominates and a comfortable temperature must not override a meaningful moisture risk. Other item types need **their own approved policies** rather than inheriting leather rules by default.

## 6. No scattered magic values

All product-level thresholds and tunable behavior must be centralized.

Do not hardcode a threshold in one service and another threshold in a UI component.

## 7. Deterministic core logic

V1 jacket decisions should be deterministic and testable.

Do not introduce opaque machine-learning scoring unless explicitly approved.

## 8. Dynamic periods must remain human-meaningful

Do not produce a timeline full of tiny alternating Wear/Avoid periods.

If hourly data is noisy, consolidate it into a meaningful period using conservative rain protection.

## 9. Respect battery

Do not introduce continuous background location tracking for V1.

## 9.5 Keep weather-provider dependency replaceable

The weather provider is an external dependency, not product logic.

AI must:
- use our weather-provider abstraction;
- use the normalized internal weather model;
- never leak provider-specific response objects into the decision engine or UI;
- keep provider-specific authentication/configuration inside the provider adapter/integration layer;
- make it possible to replace the provider without rewriting jacket logic.

Open-Meteo is the approved prototyping provider under D-022; WeatherKit remains a production candidate. Neither is an irreversible dependency. Keep each behind the thin provider abstraction and do not treat Open-Meteo's free endpoint as approved for distribution.

## 10. Prefer replaceable integrations

Weather and location access must be behind interfaces/abstractions.

## 11. Test the important things

Prioritize tests for:
- rain/no-rain;
- temperature boundaries;
- combinations of rain and temperature;
- dynamic periods;
- noisy forecast consolidation;
- stale/missing data;
- location failure;
- real-device startup and permissions.

## 12. Do not optimize prematurely

Measure actual startup, location and network behavior on a real phone.

Fix user-visible friction before polishing internal implementation.

## 13. Update truth files

When an approved decision changes:
1. record the approval or supersession in `DECISIONS.md`;
2. update only the affected specification(s) in their [assigned document roles](PROJECT.md#document-responsibilities);
3. update `ROADMAP.md` if scope or sequencing changes, `IMPLEMENTATION_PLAN.md` if gates or acceptance criteria change, and `TODO.md` if execution status or validation changes;
4. then change implementation.

Link to the owning file rather than copying its detailed rules into unrelated files.

## 13.5 Work from the issue ledger

Review relevant active entries in `ISSUES.md` when starting implementation work. An issue is authorized bug-fix work only when its expected behavior is already established by the higher-priority truth files. If the expected result is unclear or the fix would change an approved decision, mark the issue **NEEDS DECISION** and ask the user.

Keep issue status and evidence current. Do not mark an issue **RESOLVED** until its acceptance criteria pass. A defect observed on a physical device requires physical-device revalidation when that environment is available; otherwise leave it **AWAITING VERIFICATION**. Preserve resolved entries as regression history.

## 14. Detect contradictions

If a new request conflicts with an approved decision, stop and point out the conflict.

Do not silently overwrite the decision.

## 15. Definition of done

V1 is not done when code compiles.

V1 is done when the intended behavior works reliably on a real phone, key weather/location edge cases are tested, the UX is smooth, and the app can be submitted to the App Store.

## 16. Work from the assigned future feature gates

Every retained future idea has a phase or a decision/evaluation milestone in `ROADMAP.md`. Do **not** treat an evaluation milestone or tentative widget/visibility design as approved implementation behavior. Phase 12 (location schedules) and Phase 13 (notifications) are planning slots with **unapproved relative ordering**. Social features are explicitly excluded. Preserve finished Phase 0–2 evidence and approved leather rules. When a phase gate resolves a decision, follow §13: record the decision and update only the documents whose responsibilities it affects.
