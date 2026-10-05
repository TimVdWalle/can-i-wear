# Can I Wear — AI Working Rules

> Status: ACTIVE
> Last updated: 2026-10-04
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

## 4. Keep V1 small

Do not add features because they are common in weather apps or technically easy.

No V2 feature should leak into V1 without explicit approval.

## 5. Rain protection dominates

This app exists primarily to prevent leather-jacket damage from rain.

Do not let a comfortable temperature override meaningful rain risk.

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
1. update `DECISIONS.md`;
2. update affected specifications;
3. update `TODO.md`/roadmap;
4. then change implementation.

## 14. Detect contradictions

If a new request conflicts with an approved decision, stop and point out the conflict.

Do not silently overwrite the decision.

## 15. Definition of done

V1 is not done when code compiles.

V1 is done when the intended behavior works reliably on a real phone, key weather/location edge cases are tested, the UX is smooth, and the app can be submitted to the App Store.
