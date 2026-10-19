# Can I Wear — Implementation Phases & Roadmap

> Status: ACTIVE
> Last updated: 2026-10-19
> Source of truth: YES

## Version and milestone rule

The first **working real-iPhone milestone** is intentionally leather-jacket-only (Phases 0–2). Do not mistake that small engineering milestone for the **first public App Store release**. The first public release must include a **predefined collection of items** and an **iOS widget**, in addition to the already working current-location, weather and daily-period behavior. The first public release is the V1 release in the existing documentation. Do not artificially label incomplete work V2/V3 or imply later features are already implemented.

Decisions about the first release and future sequence are recorded in [DECISIONS.md](DECISIONS.md); concrete subphases, dependencies and gates are in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md). Execution status and historical evidence remain in [TODO.md](TODO.md).

## Scope statuses and sequencing

- **Approved for delivery:** features the user explicitly wants. They have an assigned phase, but detailed interaction/technical decisions may still be TBD until the stated design gate.
- **Evaluation/decision milestone:** an idea with an assigned phase where the first deliverable is to decide its usefulness/scope. This is **not** permission to build the idea automatically.
- **Explicitly excluded:** social features; no implementation phase is assigned because the user rejected them. Background/continuous location tracking remains excluded unless separately reconsidered.
- **Approved early sequence:** custom items (8) → adjustable thresholds (9) → multiple locations (10). **Provisional later slots:** Phase 11 onward is a coherent planning placement, **not** user approval of every relative priority. Specifically, location schedules (12) versus notifications (13) is undecided. Reconfirm the relevant order at each later design gate.

## Phase 0 — Decisions & technical foundation (completed; historical)

Native Swift/SwiftUI project; real-device development; replaceable normalized weather-provider contracts; current-location acquisition; centralized jacket weather rules; period/noise and cache freshness policy; deterministic test foundation. Open-Meteo is approved for unpaid prototyping; production provider remains to be chosen before distribution.

## Phase 1 — First real-device vertical slice (completed; historical)

Current location → live weather → deterministic leather-jacket recommendation → basic result UI → real iPhone. This is the deliberately small working milestone, **not** the complete first public release.

## Phase 2 — Daily intelligence and diagnostics (completed; historical)

Daily/hourly evaluation; meaningful periods and conservative noise consolidation; rain/temperature/fog protection for leather; safe caching, failure handling and pull-to-refresh; opt-in local diagnostics. Original thresholds and test evidence remain authoritative and are not rewritten for new items.

## Phase 3 — Core app polish (next execution phase)

Polish the already implemented single-item flow: permissions, errors, speed, accessibility, language, interactions and presentation. Preserve Phase 3 tasks 3.1–3.5 and their quality evidence. Phase 4 will subsequently adapt the approved design for several items.

D-046 approves the reference-based single-item Home Screen for Phase 3 implementation. Broader recovery, performance and real-device accessibility gates remain pending; detail views and multi-item/multi-location layouts are not decided by this screen.

## Phase 4 — Predefined multi-item support (required before first release)

- The initial collection is approved in D-058, the two shared daily algorithms/useful-hour minimum in D-063/D-064, all launch-item assignments in D-065, and missing-input/gap handling in D-066. Resolve other unsupported condition/precipitation cases, non-jacket grouping and concrete presentation at 4.1 rather than reopening settled choices or inventing per-item daily algorithms. The detailed contract belongs in `WEATHER_LOGIC.md`.
- Refactor the item/rules representation enough to support multiple predefined items with their own sensible rules and short explanations. Preserve all approved jacket-protection behavior; do **not** apply leather thresholds blindly to other items.
- Support the existing current-location, remaining-day/meaningful-period recommendation for supported items.
- D-067 adds focused item configuration before first Home and through a header gear thereafter. One selected item retains the existing Home layout/variants; several use the new Guided-Home-based overview. Prototype visuals and the setup reset contract must be reviewed before app implementation; this is not broad settings.
- Design and validate the approved compact overview with explicit daily verdicts and timing (D-058/D-060). Fixed-item policies may be predefined; a user-facing group taxonomy is not required for Phase 4. Remaining behavior and concrete presentation cases stay gated in 4.1.
- No user-created items, personalized thresholds, accounts, saved cities or notifications yet.

## Phase 5 — First-release iOS widget

- Include an iOS home-screen widget in the first public release.
- At the design gate choose between separate item widgets plus a combined overview, or a smart combined item overview (or another explicitly approved solution); exact sizes, information density, refresh and interaction remain **TBD**.
- Examples such as “A and B are wearable today; C from 18:00–23:00” illustrate desired intelligence, **not** fixed widget copy or item-specific rules.
- Use shared recommendation and freshness contracts; no independently invented background tracking or weather policy.

## Phase 6 — First-release validation

Validate jacket rules **and** every supported additional predefined item, multiple-item UI, widget, accessibility, network/cache/permission failure, weather/provider behavior and real iPhone reliability. “Multiple locations” in old Phase 6 field-testing text means testing forecasts in different places, **not** the post-release saved-city feature.

## Phase 7 — First public App Store release

Complete identity, production weather-provider/license decision, privacy/telemetry decisions, icon/listing/screenshots, TestFlight, review and release. Shipped listing and tests must reflect predefined multiple items + widget. Saved cities, custom items, threshold editing, schedules and notifications are **not** first-release blockers.

## Phase 8 — Basic custom items (early post-release)

Let users create/manage basic custom items alongside the predefined collection, working locally. Keep information minimal. Rule/template mechanism, default choices and any mandatory properties are decided in 8.1; do not silently implement a full rule builder, detailed wardrobe catalog or photo management. D-060 defers exact group labels and the configuration UX explaining different item behaviors to this gate, where users need to understand their choices. D-059's historical wording is superseded; no particular category field or editor is assumed.

## Phase 9 — Adjustable per-item weather thresholds

After basic custom items work, enable editing appropriate item thresholds such as temperature and precipitation. Items begin with sensible defaults; whether editing applies to predefined and/or custom items and exact editing UX are decided at the phase gate. Complex rule-building is **later**, not part of this phase.

## Phase 10 — Multiple locations and a clean overview

Search for cities, save favorites, use current location automatically, switch location, and see recommendations for multiple selected/relevant locations in a **very clean, easily differentiated, scan-friendly overview**. The initial location-inclusion model is decided here. An active/inactive setting for saved cities is a **candidate, not an approved behavior**. Recurring location schedules are not required in this phase.

## Phase 11 — Simple forward-looking forecast extension

Keep today's overview as the starting point; introduce a modest, approved extension of forecast lookahead. Exact number of hours/days, interface and whether the extension applies by location or globally are **TBD**. Full configurable horizons are later in Phase 15.

## Phase 12 — Recurring location schedules (later; relative order provisional)

Allow schedules attached to saved locations, including selected weekdays each week, every nth weekday of the month (e.g. second Monday), and every two weeks/other repeating intervals. A scheduled location appears in the overview **only on relevant scheduled days**, alongside current location and any other relevant locations; on a nonmatching day, do not automatically display it. Manual access/override and active/inactive semantics remain **TBD**. Exact order relative to Phase 13 notifications must be reconfirmed before executing either phase.

## Phase 13 — Optional notifications (late; relative order provisional)

After the first release, design and implement notifications only with user-approved triggers, timing, opt-in and safe-staleness behavior. The user explicitly permits this feature to be **late**. No background location tracking or push/backend assumption. Relative position against Phase 12 is **TBD**; phase numbers are planning slots, not a settled priority decision.

## Phase 14 — Later item details, photos and lightweight settings review

Keep custom items minimal for a long time. At this later phase, decide whether/how to add useful item details and photos; neither their exact schema nor photo support is pre-approved as an implementation requirement. Revisit a settings surface only if existing capabilities actually require one; avoid inventing a broad settings screen.

## Phase 15 — Advanced recommendation logic and configurable horizons

Provide a separately gated later phase for more complex configurable rule combinations, item-specific factors and more flexible forecast horizons. Additional weather inputs may already be added **incrementally in whichever earlier item phase requires them**, with explicit approval and tests. Wind remains diagnostic-only for leather until a later approved rule change. Exact advanced builder and horizon UI are TBD, not preselected.

## Phase 16 — Evaluate broader personal preferences

Evaluate whether cross-item personal preferences add value beyond Phase 9 per-item thresholds. This is a **decision/evaluation milestone**, not automatic authorization to build preferences. If approved, specify implementable follow-up work inside this phase or an expressly approved successor.

## Phase 17 — Recommendation history (late)

Add a user-facing view of previous recommendations, with privacy/retention/presentation defined first. Distinct from the already implemented bounded **local debug-event history**; do not confuse or reuse it as product history without approval.

## Phase 18 — Accounts and cross-device synchronization (very late)

Maintain local-first operation through the earlier phases. Later decide account model, what to sync, privacy, conflict behavior and whether accounts are optional. Accounts/sync must **not** block custom items, saved locations or personal thresholds.

## Phase 19 — Android (much later)

Consider/implement Android only once the iOS experience is mature. Determine architecture, scope parity and release plan at this later phase; do not compromise the native Swift/SwiftUI iOS delivery path now.

## Explicitly excluded or not yet approved

- **Social functionality:** explicitly excluded from the roadmap; no implementation phase.
- **Continuous background location tracking:** not approved, not an implicit prerequisite for widget, notifications or schedules.
- **One-off trip/date planning, exact arrival times, automatic trip detection:** discussed only as examples/possibilities; no approved feature commitment. Re-evaluate, if useful, in Phase 11/15 forecast-scope gates.
- **General settings screen:** undecided; relevant decisions occur with their actual feature in Phases 9–15, not as a mandatory standalone workstream.
- **Separate user-facing history vs diagnostics:** real recommendation history belongs to Phase 17; existing diagnostics must remain local, opt-in and bounded.

## App naming

The official app/product name is **Can I Wear**. It remains locked unless the user reopens the decision.
