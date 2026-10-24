# Can I Wear — Complete Implementation Plan

> Status: ACTIVE — agreed scope plus gated, sometimes provisional future execution
> Last updated: 2026-10-24
> Source of truth: execution detail subordinate to the existing truth files

## Authority and execution rules

This plan implements the updated scope/sequence in [ROADMAP.md](ROADMAP.md). Resolve conflicts using the hierarchy in [PROJECT.md](PROJECT.md): approved decisions, product specification, technical specification, weather logic, UX, active issue records, then roadmap/execution detail. [DECISIONS.md](DECISIONS.md) remains authoritative for approved decisions. Review relevant active defects in [ISSUES.md](ISSUES.md) and follow [AI_RULES.md](AI_RULES.md).

Each numbered subphase is a separate implementation/review unit. Complete its acceptance criteria and required validation before marking it done in [TODO.md](TODO.md). Dependencies mean completed subphases unless explicitly described as evidence-gathering that may run earlier. A decision subphase is complete only when the user has approved the material choices and the affected truth files have been updated; this plan does not approve them.

The already completed **first real-device milestone (Phases 0–2)** was leather-jacket-only. The **first public release** additionally requires several predefined items (Phase 4) and an iOS widget (Phase 5). Custom items, editable thresholds, saved/multiple cities, schedules, notifications, recommendation history, accounts and Android are planned **after release** in assigned future phases. A future phase gate may resolve scope, not imply its undecided details are already approved. Social features are excluded. Continuous background location tracking remains unapproved.

Keep the existing app and test targets unless a newly approved requirement (such as the widget extension) needs more. Component separation does not require packages, a dependency-injection framework, a generic rules framework, or a backend. Names and paths below are likely implementation locations, not a mandated file layout. New Swift files would live under `Can I Wear/`, unit tests under `Can I WearTests/`, and UI tests under `Can I WearUITests/`.

All product thresholds, freshness windows, grouping parameters, location accuracy requirements and behavior-affecting timeouts belong in a concentrated configuration area. The approved 15°C/20°C boundaries are **leather-jacket rules**, not defaults for new items. Explicit test inputs may exercise candidate values without making those values production defaults.

## Current baseline (source-of-truth handoff as of 2026-10-13)

`TODO.md` is the authoritative completion record, not the historical scaffold snapshot previously embedded here. Phases 0–2 / subphases 0.1–2.9 are recorded complete with real-iPhone evidence, deterministic test coverage, weather/location/provider and cache work, fog/mist protection, daily periods and opt-in diagnostics. Phase 3 was closed by user acceptance on 2026-10-18; follow-up validation with no specific recorded result is listed without a phase in `TODO.md`. This documentation update does not claim a new build, regression pass, release or new Swift implementation. Consult `TODO.md` for precise evidence and limitations.

**Original historical baseline:** the project initially had a SwiftUI scaffold, placeholder UI, unit/UI test targets, and configured-but-unverified signing/device settings. Those observations were superseded by later implementation and device testing; preserve that sequence in `TODO.md` rather than treating the scaffold as the present state.

## Decision tracking

These identifiers originated as implementation-blocking TBDs. Their current resolution status is authoritative only when recorded in `DECISIONS.md` and `TODO.md`; this table tracks the topic and where it is needed.

| ID | Decision topic/status | Needed by |
| --- | --- | --- |
| T-01 | Measurable “few drops” tolerance; precipitation amount/type/probability interpretation and normal/heavy rain classification | 0.7, 1.1 |
| T-02 | Actual versus apparent temperature selection/weighting, including unavailable selected input | 0.7, 1.1 |
| T-03 | Resolved in D-024: relevant local-day window, most-protective summary and incomplete hourly coverage behavior | 0.7, 1.2, 2.1 |
| T-04 | Minimum meaningful period duration, material-change/grouping rules, and conservative noise-consolidation parameters | 0.8, 2.2–2.3 |
| T-05 | Weather cache freshness/reliability, expiry behavior, and matching cached forecasts to location | 0.9, 2.5–2.6 |
| T-06 | Location accuracy and freshness, safe reuse, and behavior-affecting acquisition/request timeout values | 0.5, 0.9, 2.4 |
| T-07 | Resolved in D-020: minimum supported iOS version is 26.2 | 0.2, 0.3, 7.5 |
| T-08 | Final bundle identifiers; whether the current identifier can be used for development/provider setup before finalization | 0.2, 0.6, 7.1 |
| T-09 | Analytics/telemetry policy, including whether any collection is allowed | 7.1, 7.3; before any instrumentation that collects data |
| T-10 | Exact recommendation/caution labels, reason copy, semantic palette and final layout | Basic proposal in 1.3; final decisions in 3.1 |
| T-11 | Loading presentation, no-location/no-weather/stale-data wording, permission-denied UX and accessibility details | Basic proposal in 1.3; final decisions in 3.1–3.4 |
| T-12 | **Timing resolved:** widget before first release (5.1–5.3); notifications after release (13.1–13.2), possibly late. Exact UX/timing TBD. | 5.1, 13.1 |
| T-13 | **Resolved in D-029:** use only an explicit provider fog/mist forecast condition; Open-Meteo WMO codes 45/48 produce Avoid. Do not infer from humidity, dew point or visibility. | 2.8 |

D-032–D-045 resolve the phase-level roadmap choices, but do not settle still-open design gates. This plan does not resolve any undecided behavior on its own. Record approved material choices in `DECISIONS.md` and affected specifications before implementing them. When a blocker covers only part of a subphase, independent evidence gathering or contract work may proceed, but the subphase cannot be marked complete with invented defaults.

## Phase 0 — Decisions & technical foundation

Goal and exit remain those in the roadmap: establish the native/device/provider foundation and resolve the details needed for the first vertical slice. Thin provider implementations belong here; connecting them into the recommendation experience belongs in Phase 1.

### 0.1 — Record the existing scaffold

- **Type:** Setup verification/documentation. **Status:** Complete by source inspection only.
- **Objective:** Start from the project that actually exists.
- **Exact scope:** Confirm app, unit/UI test targets, SwiftUI entry point and placeholder assets; mark initialization complete and distinguish configuration from validated behavior.
- **Likely files/components:** `Can I Wear.xcodeproj/project.pbxproj`, `Can_I_WearApp.swift`, `ContentView.swift`, existing test files, `Assets.xcassets`, `TODO.md`.
- **Acceptance criteria:** Existing setup is accurately recorded; no test, integration or device success is claimed from templates/settings.
- **Tests/validation:** Read-only source/project inspection; no build needed to establish file existence.
- **Dependencies:** None.
- **Non-goals:** Application changes, icons/design, real-device certification.
- **Blocking TBDs:** None; record T-07/T-08 as unresolved.

### 0.2 — Confirm development platform and identity

- **Type:** Product/architecture decision.
- **Objective:** Make device/provider setup intentional.
- **Exact scope:** Obtain approval for minimum iOS support and the identifier to use for development, including whether final identity is deferred; reconcile existing project settings only during later implementation.
- **Likely files/components:** `DECISIONS.md`, `TECH_SPEC.md`, `TODO.md`; eventual project build/signing settings.
- **Acceptance criteria:** T-07 is approved; T-08 either finalized or explicitly permits a development identifier with finalization still tracked in 7.1.
- **Tests/validation:** Check installed Xcode/SDK and target-phone compatibility; inspect account/signing prerequisites without claiming a device run.
- **Dependencies:** 0.1.
- **Non-goals:** Provider migration, Android, adding iPad-specific features, changing framework.
- **Blocking TBDs:** T-07, T-08.

### 0.3 — Establish a real-iPhone development baseline

- **Type:** Implementation/setup and real-device validation.
- **Objective:** Prove the existing app can run on the intended phone before debugging integrations.
- **Exact scope:** Apply approved development settings, resolve signing/device setup, build and launch the existing scaffold; run the existing test targets as a harness check.
- **Likely files/components:** Xcode project/signing settings, existing app/test targets, `TODO.md` validation evidence.
- **Acceptance criteria:** A signed scaffold launches on a real iPhone; build/test outcomes and device/OS are recorded. Template tests are not counted as product coverage.
- **Tests/validation:** Build and unit/UI harness execution; manual real-device cold launch and relaunch.
- **Dependencies:** 0.2.
- **Non-goals:** Recommendation milestone, live weather/location, performance targets.
- **Blocking TBDs:** None after 0.2; developer-account/device availability is an external prerequisite.

### 0.4 — Define normalized contracts and fixture harness

- **Type:** Architecture implementation and testing.
- **Objective:** Keep external integrations replaceable and domain tests deterministic.
- **Exact scope:** Define thin `LocationProvider` and `WeatherProvider` interfaces, location identity, normalized hourly forecast inputs (actual/apparent temperature, precipitation amount/type/chance, timestamps/timezone, missing values), forecast fetch metadata, and simple deterministic fakes. Keep time an explicit test input where relevant.
- **Likely files/components:** Provider protocol files, internal weather/location models, unit-test fixture helpers; `TECH_SPEC.md` only if an approved clarification is needed.
- **Acceptance criteria:** Contracts represent required inputs and missing data; domain/UI contract types contain no WeatherKit response objects; fixtures can run without GPS/network/live time.
- **Tests/validation:** Compile interfaces/fakes; focused tests demonstrate missing values, units and timestamps are preserved. Establish that decision and period tests use these fixtures.
- **Dependencies:** 0.2, 0.3; interface drafting can start after 0.2, but completion requires the verified test harness.
- **Non-goals:** Concrete adapters, production caching, decision rules, a generic data-provider framework.
- **Blocking TBDs:** None for retaining both temperatures and raw rain inputs; do not resolve T-01/T-02 through the model.

### 0.5 — Implement one-time location acquisition

- **Type:** Decision, implementation, testing and real-device validation.
- **Objective:** Obtain useful local forecast coordinates without continuous tracking.
- **Exact scope:** Approve required accuracy and behavior-affecting acquisition timeouts from T-06; implement the thin native provider, permission purpose description, permission/failure/cancellation handling, and stop acquisition after success. No reuse/cache yet.
- **Likely files/components:** `LocationProvider`, native location adapter, central configuration, generated Info.plist settings in the project, location unit tests.
- **Acceptance criteria:** Successful one-time location and explicit denied/unavailable outcomes; no continuing tracking after completion/cancellation; approved values centralized.
- **Tests/validation:** Fake-driven success, denied permission, unavailable services, timeout/cancellation tests; fresh permission and denied-permission checks on a real iPhone.
- **Dependencies:** 0.3, 0.4; approval/update of the acquisition portion of T-06 before production defaults.
- **Non-goals:** Continuous/background tracking, location history, manual city selection, cached reuse, polished permission flow.
- **Blocking TBDs:** T-06 accuracy/timeouts and basic permission copy approval; cache freshness portion of T-06 remains for 0.9.

### 0.6 — Implement and probe the weather adapter

- **Type:** Integration implementation, testing and real-device validation.
- **Objective:** Fetch live hourly weather through our interface.
- **Exact scope:** Configure the approved development weather service; implement its adapter mapping into normalized data and explicit errors; validate a live fetch independently of recommendation UI. Identify provider attribution and licensing needs for presentation/release. D-022 selects Open-Meteo for unpaid prototyping and defers WeatherKit capability work until a paid Apple Developer Program team is available.
- **Likely files/components:** `WeatherProvider`, concrete provider adapter, internal weather models, project configuration, mapping tests; `TODO.md` evidence.
- **Acceptance criteria:** Live real-device forecast can be obtained and normalized; required fields or unavailable inputs are represented honestly; authentication/configuration stays in integration code; provider types do not escape.
- **Tests/validation:** Mapping checks for units, precipitation type/chance/amount, actual/apparent temperature, time context and missing data; manual live fetch and network-failure mapping check. Record rain resolution, reliability, setup and cost observations; timing and accuracy validation continue in 1.4/4.2.
- **Dependencies:** 0.3, 0.4, approved development identity from 0.2. A live-coordinate probe can follow 0.5.
- **Non-goals:** Jacket rules, UI weather dashboard, exhaustive accuracy claims, final production-provider selection.
- **Blocking TBDs:** T-08 development identity if not settled; service availability is an external prerequisite. T-01/T-02 do not block raw mapping.

### 0.7 — Approve first-slice recommendation policies

- **Type:** Product decision with evidence gathering.
- **Objective:** Make the live recommendation implementable without invented behavior.
- **Exact scope:** Propose and obtain approval for T-01 rain interpretation, T-02 temperature selection, and T-03 local-day window/basic whole-day summary and incomplete-coverage behavior. Use provider samples and deterministic fixtures as evidence; preserve rain precedence and existing temperature bands.
- **Likely files/components:** `DECISIONS.md`, `PRODUCT_SPEC.md`, `WEATHER_LOGIC.md`, `TECH_SPEC.md`, `TODO.md`; forecast samples/fixtures.
- **Acceptance criteria:** Material choices are approved and recorded, with measurable inputs and expected dry/rain/caution/missing-data examples. A single basic daily answer does not hide meaningful rain elsewhere in its approved window.
- **Tests/validation:** Review candidate boundary examples and actual provider units; explicitly cover normal/heavy rain overriding comfortable temperatures and partial forecasts. Candidate examples are evidence, not production defaults.
- **Dependencies:** 0.4; use evidence from 0.6 before final measurable rain mapping.
- **Non-goals:** Changing approved thresholds, personalization, detailed period grouping, final UI copy.
- **Blocking TBDs:** T-01, T-02, T-03.

### 0.8 — Approve dynamic-period parameters

- **Type:** Product decision with fixture review.
- **Objective:** Define human-meaningful daily changes before implementing grouping.
- **Exact scope:** Propose material-change rules, minimum duration and consolidation behavior; review morning-only rain, later rain and alternating hourly fixtures; obtain approval and record centralized parameter definitions.
- **Likely files/components:** `DECISIONS.md`, `WEATHER_LOGIC.md`, `TODO.md`, period fixture examples.
- **Acceptance criteria:** T-04 has approved criteria/examples; noisy rain alternation is consolidated conservatively without claiming dry intervals are safe.
- **Tests/validation:** Review expected periods against dry, changing, short-rain and noisy timelines.
- **Dependencies:** 0.7.
- **Non-goals:** Period implementation, minute-by-minute nowcasting, user-adjustable rules.
- **Blocking TBDs:** T-04.

### 0.9 — Approve freshness and safe-reuse policies

- **Type:** Product/technical decision.
- **Objective:** Define trustworthy reuse and failure behavior before caching.
- **Exact scope:** Approve weather/location freshness, location matching, expiry and request timeout policies relevant to fallback. Specify when relaunch/network failure may reuse data and when no recommendation is permitted.
- **Likely files/components:** `DECISIONS.md`, `PRODUCT_SPEC.md`, `TECH_SPEC.md`, `WEATHER_LOGIC.md`, `TODO.md`.
- **Acceptance criteria:** T-05 and remaining T-06 choices are approved, measurable, centrally configurable, and distinguish a valid recent cache from stale or wrong-location data.
- **Tests/validation:** Review freshness boundary, moved-location, no-network, stale-location and stale-weather examples with explicit time inputs.
- **Dependencies:** 0.5–0.7; measured acquisition/fetch evidence may inform proposals.
- **Non-goals:** Cache implementation, background refresh, location history, speculative performance targets.
- **Blocking TBDs:** T-05, remaining T-06.

**Phase 0 exit:** 0.1–0.9 criteria met. Phase 1 decision work/tests may be prepared when their own dependencies are met, but the Phase 0 gate is not declared complete with unresolved policies.

## Phase 1 — First real-device vertical slice

The first major milestone remains **current location → live weather → deterministic recommendation → basic result screen → real iPhone**. The scaffold run and provider probes in Phase 0 are prerequisite checks, not this milestone. Do not substitute fixture weather for the live milestone. A basic daily summary is an intermediate presentation; Phase 2 adds meaningful periods rather than changing V1 into a current-weather-only app.

### 1.1 — Implement centralized hourly jacket rules

- **Type:** Domain implementation and testing.
- **Objective:** Classify weather deterministically with rain protection first.
- **Exact scope:** Add `JacketRulesConfig`, recommendation/reason types and `JacketDecisionEngine`; implement approved input validation, rain interpretation, temperature selection, 15°C/20°C boundaries and caution. Inject configuration and necessary time inputs.
- **Likely files/components:** Central configuration, decision engine/model files, existing unit-test target.
- **Acceptance criteria:** Validity precedes rain, which precedes excessive heat/caution; no WeatherKit/UI dependency; tuning requires changing configuration rather than scattered constants.
- **Tests/validation:** Dry 12°C/18°C/24°C, at and immediately around 15°C/20°C, few drops at approved boundaries, normal/heavy rain, rain+cold/warm, missing precipitation/temperature, and repeated identical input/output.
- **Dependencies:** 0.4, 0.7.
- **Non-goals:** Day grouping, network/location, cache, UI, opaque scoring.
- **Blocking TBDs:** None after T-01/T-02 approval in 0.7.

### 1.2 — Implement the basic daily summary

- **Type:** Domain implementation and testing.
- **Objective:** Make the first answer consider the relevant day rather than just current weather.
- **Exact scope:** Select the approved local-day window from normalized hourly data, classify it, and produce a single basic recommendation/reason using the approved summary and coverage policy. Keep this small; reuse selection/classification in Phase 2.
- **Likely files/components:** Daily evaluation helper, `JacketDecisionEngine`, normalized forecast model, daily fixture tests.
- **Acceptance criteria:** Meaningful rain later in the window is not ignored; local time and incomplete input follow approved policy; result is independent of device GPS/network and wall-clock time.
- **Tests/validation:** All-day dry/cool, all-day heat, morning/later rain, midnight/timezone boundaries, empty and partially missing hourly coverage.
- **Dependencies:** 1.1, 0.7.
- **Non-goals:** Meaningful multi-period output, noise consolidation, final period UI.
- **Blocking TBDs:** None after T-03 approval in 0.7; new behavior ambiguities require explicit proposals.

### 1.3 — Connect providers to a basic result screen

- **Type:** Presentation/application implementation and integration testing.
- **Objective:** Turn the tested domain output into the smallest working user flow.
- **Exact scope:** Approve basic copy/loading presentation as a reviewable proposal; wire providers, daily summary and SwiftUI state through a small presentation model. Show recommendation and short primary reason plus necessary provider attribution; represent loading, unavailable location and unavailable weather explicitly. Use live providers normally and fakes only in tests/previews.
- **Likely files/components:** `Can_I_WearApp.swift`, `ContentView.swift`, small presentation model, provider adapters, UI/integration tests.
- **Acceptance criteria:** First frame does not wait for location/network; successful requests produce a result; failures do not leave endless “Checking…” text or a fabricated recommendation; repeated view updates do not duplicate requests; provider types stay out of UI.
- **Tests/validation:** Fake-driven success, caution, rain avoid, denied location and fetch failure; UI checks for recommendation/reason and unavailable states; manual live flow smoke check.
- **Dependencies:** 0.5, 0.6, 1.2.
- **Non-goals:** Final visual design, cache, period UI, broad settings, telemetry, widget/notifications.
- **Blocking TBDs:** Basic T-10/T-11 proposals must be reviewed before treating copy/presentation as settled; final design remains for 3.1.

### 1.4 — Prove the complete vertical slice on a real iPhone

- **Type:** Real-device validation and milestone review.
- **Objective:** Demonstrate the first major milestone with live data.
- **Exact scope:** Run installed app from launch through current location, live weather fetch through the active provider, normalized inputs, deterministic daily recommendation and visible short reason. Record actual outcome, device/OS and observed startup/location/network timings.
- **Likely files/components:** Existing app, tests, adapters/engine/presentation, `TODO.md` evidence.
- **Acceptance criteria:** The full live flow works on a real iPhone; output agrees with a deterministic replay of the relevant inputs; permission denial/network failure are honest; no continuous location work remains. Blocking integration defects are fixed and narrowly rechecked.
- **Tests/validation:** Real-device first permission flow, allowed relaunch, denial and network failure; targeted unit/integration suite; measure rather than claim responsiveness.
- **Dependencies:** Phase 0 exit, 1.1–1.3.
- **Non-goals:** Declaring V1 complete, exhaustive field accuracy, polish, Store submission.
- **Blocking TBDs:** None after prerequisites; available phone, signing and live service access required.

## Phase 2 — V1 daily intelligence

Goal: add meaningful periods and safe reuse/fallback while retaining deterministic, rain-first decisions.

### 2.1 — Expose per-hour daily evaluation

- **Type:** Domain implementation and testing.
- **Objective:** Provide the ordered daily classifications needed by period logic.
- **Exact scope:** Extend/reuse 1.2 to expose classified hours and their reasons, preserving the approved window/timezone and coverage policy; handle ordering, gaps and day-boundary inputs explicitly.
- **Likely files/components:** Daily evaluation helper, forecast models, decision engine, daily fixture tests.
- **Acceptance criteria:** Only relevant hours are evaluated; timestamps and coverage are retained; unavailable inputs are not converted into dry/safe hours; calculations use explicit time context.
- **Tests/validation:** Stable days, morning/later rain, mixed caution/heat, out-of-order/gapped inputs, timezone/midnight and daylight-saving transitions.
- **Dependencies:** 1.4, 0.7.
- **Non-goals:** Grouping/noise rules, fetching more forecast products, forecasting beyond V1's day.
- **Blocking TBDs:** None after T-03 approval; unspecified gap/time cases require clarification rather than guessed rules.

### 2.2 — Group contiguous meaningful periods

- **Type:** Domain implementation and testing.
- **Objective:** Represent changes without a row for every hour.
- **Exact scope:** Add `DayPeriodEngine` and period output model; merge contiguous classifications using approved material-change rules and retain actionable reasons/time boundaries. Keep noise consolidation for 2.3.
- **Likely files/components:** `DayPeriodEngine`, period models, fixture tests.
- **Acceptance criteria:** Stable weather returns one period; material changes produce ordered, non-overlapping periods; missing coverage does not create confident Wear spans.
- **Tests/validation:** All-day stable, morning rain then dry, later rain, heat/caution transitions, day end and missing coverage.
- **Dependencies:** 2.1, 0.8.
- **Non-goals:** Noisy-forecast smoothing, timeline UI, new thresholds.
- **Blocking TBDs:** None after relevant T-04 rules are approved in 0.8.

### 2.3 — Consolidate noisy forecasts conservatively

- **Type:** Domain implementation and testing.
- **Objective:** Avoid tiny alternating Wear/Avoid periods without hiding rain risk.
- **Exact scope:** Implement approved minimum-duration and consolidation parameters in the period engine, stored centrally; preserve explanation of rain-driven Avoid periods.
- **Likely files/components:** `DayPeriodEngine`, central configuration, noisy timeline fixtures/tests.
- **Acceptance criteria:** Approved noisy examples produce meaningful larger periods; consolidation never turns meaningful rain into a safe recommendation; identical fixtures are deterministic.
- **Tests/validation:** Alternating dry/rain, isolated short rain, short dry gaps, approved duration boundaries and multiple material changes.
- **Dependencies:** 2.2, 0.8.
- **Non-goals:** ML smoothing, provider forecast correction, arbitrary new period limits.
- **Blocking TBDs:** None after T-04 approval; fixture disagreements return to a decision review.

### 2.4 — Add recent-location reuse

- **Type:** Implementation and testing.
- **Objective:** Avoid unnecessary fixes without using stale or inadequate location.
- **Exact scope:** Cache only the recent useful location and its timestamp/accuracy; apply approved reuse policy and request a new fix when needed. Support intended relaunch behavior without keeping location history.
- **Likely files/components:** Location provider/cache helper, central configuration, location reuse tests.
- **Acceptance criteria:** Reliable recent location can be reused; expiry/inadequate accuracy forces acquisition or explicit failure; no growing location log or tracking loop.
- **Tests/validation:** Fresh/expired/insufficient-accuracy data, time boundaries, acquisition failure, relaunch and unavailable cache using explicit time.
- **Dependencies:** 1.4, 0.9.
- **Non-goals:** Continuous movement detection, history, background refresh, manual locations.
- **Blocking TBDs:** None after T-06 reuse approval; storage mechanism should remain the simplest that meets approved relaunch behavior.

### 2.5 — Add weather cache and validity checks

- **Type:** Implementation and testing.
- **Objective:** Reuse forecasts only when trustworthy for the relevant location/day.
- **Exact scope:** Add `WeatherCache` holding normalized forecast, fetch timestamp and location identity; apply approved freshness/matching/coverage policy, handle unavailable or malformed stored data, and keep stale entries from driving recommendations.
- **Likely files/components:** `WeatherCache`, forecast metadata, central configuration, cache tests.
- **Acceptance criteria:** Fresh matching entries are usable; stale, wrong-location and invalid entries are rejected explicitly; provider response objects are not the cache contract.
- **Tests/validation:** Freshness boundary, wrong location, day changes, missing/invalid stored data and relaunch with controlled time.
- **Dependencies:** 1.4, 0.9, 2.4.
- **Non-goals:** Database framework, forecast history, sync, background fetch.
- **Blocking TBDs:** None after T-05 approval; do not invent matching/freshness defaults.

### 2.6 — Present daily periods and integrate safe fallback

- **Type:** Application/presentation implementation and integration testing.
- **Objective:** Show the daily intelligence and retain useful results during failures safely.
- **Exact scope:** Connect period output and cache selection to the existing flow; display a few meaningful periods and short reasons, valid cached results with agreed indication, and explicit no-location/no-weather/stale states when no trustworthy answer is available.
- **Likely files/components:** Presentation model, `ContentView`, period engine, location/weather cache, integration/UI tests.
- **Acceptance criteria:** Display matches period outputs; cache fallback follows approved location/freshness policies; stale or mismatched forecasts never masquerade as current; requests remain on demand.
- **Tests/validation:** Morning/later rain and noisy UI fixtures; fresh fallback during fetch failure; stale/absent cache, location failure, moved-location context, relaunch and forecast changes.
- **Dependencies:** 2.3–2.5, 1.3.
- **Non-goals:** Final polish, weather dashboard, user controls for thresholds, background refresh.
- **Blocking TBDs:** Basic period/cache presentation and T-11 wording must be reviewed if not already covered; final presentation decisions remain in 3.1.

### 2.7 — Review daily-intelligence completeness

- **Type:** Testing and real-device validation.
- **Objective:** Prove periods and fallback work together before polish.
- **Exact scope:** Run the integrated deterministic fixture matrix and real-phone cached/live/relaunch flow; document remaining defects and fix them within affected subphases.
- **Likely files/components:** Decision/period/cache/integration/UI tests, app, `TODO.md` evidence.
- **Acceptance criteria:** Rain-first decisions, boundaries, meaningful periods and valid fallback are covered and passing; live phone behavior agrees with evaluated inputs; no fabricated answer on missing/stale data.
- **Tests/validation:** Dry/caution/hot/rain combinations, noisy forecasts, missing data/location, unavailable network, recent/stale cache, forecast updates and relaunch; phone checks complement fixtures rather than replacing them.
- **Dependencies:** 2.1–2.6.
- **Non-goals:** Exhaustive field validation, final design, declaring release readiness.
- **Blocking TBDs:** None after prerequisites.

### 2.8 — Add fog and mist protection

- **Type:** Product-detail decision, provider/domain implementation and testing.
- **Objective:** Prevent recommending leather during forecast fog/mist because atmospheric moisture can damage it.
- **Exact scope:** Add an app-owned normalized fog/mist signal; map explicit Open-Meteo WMO codes 45/48 to it without humidity/dew-point/visibility inference; make a positive signal produce Avoid with an explicit domain reason; preserve it through daily evaluation, period grouping, caching and presentation. A missing fog/mist-specific signal alone has no effect and does not invalidate otherwise usable rain/temperature data. Keep informational wind separate from decision logic.
- **Likely files/components:** Provider contracts, `OpenMeteoProvider`, future provider adapters, forecast cache schema, jacket engine/reasons, presentation mapping, deterministic fixtures and affected truth files.
- **Acceptance criteria:** Approved fog/mist inputs always produce Avoid; comfortable/dry conditions cannot override them; absent fog data follows D-029; provider types do not leak into domain/UI; cached forecasts preserve the normalized signal; the user-visible reason remains short and truthful.
- **Tests/validation:** Explicit fog and rime-fog fixtures, dry/cool fog, warm fog, fog plus rain, absent signal, provider mapping, cache round trip, daily/period behavior and presentation state. Validate at least one live provider payload containing or structurally supporting the approved signal; do not fabricate a naturally foggy field observation.
- **Dependencies:** 2.7, 0.6 and D-029/T-13.
- **Non-goals:** Visibility-based comfort advice, unapproved humidity/dew-point thresholds, nowcasting, changing rain/temperature thresholds.
- **Blocking TBDs:** None; the temporary **“Fog is expected.”** reason is approved, while final copy remains part of T-10/3.1.

### 2.9 — Add opt-in local debug diagnostics

- **Type:** Technical settings, diagnostic implementation, testing and device validation.
- **Objective:** Make location, weather, cache and recommendation behavior inspectable without intruding on normal use or adding telemetry.
- **Exact scope:** Add a `Settings.bundle` **Debug Enabled** switch defaulting off and register the default in app code. When enabled, show a subtle main-screen control opening a clean dismissible diagnostics view. Capture structured location/weather/cache triggers, timestamps, durations, outcomes and rejection reasons; normalized remaining-day jacket inputs and per-hour results; final periods; provider/timezone metadata; and errors/timeouts. Keep the latest 20 local diagnostic events, clear them when disabled, and provide a user-initiated readable copy report. Reverse-geocode asynchronously for street when readily returned, otherwise city/region. Include provider-supplied wind speed/gusts as informational diagnostics only; missing wind never affects validity or recommendations.
- **Likely files/components:** `Settings.bundle`, app settings/default registration, diagnostic models/store/recorder, cache lookup diagnostics, providers/view model instrumentation, reverse-geocoding adapter, diagnostics SwiftUI sheet, copy action and tests.
- **Acceptance criteria:** Debug is off by default and the normal UI has no debug affordance; changing the Apple Settings switch is reflected when the app becomes active; enabled diagnostics explain why and when location/weather were reused or fetched and how raw normalized hours became periods; history never exceeds 20 events and is cleared after disabling; debug adds no upload/telemetry and does not change recommendation output or block its delivery; place lookup and copy failure degrade harmlessly.
- **Tests/validation:** Default/setting changes, hidden/visible diagnostics UI, cache hit/expiry/invalid reasons, live fetch/retry/timeout/fallback event sequences, 20-event bound and clear-on-disable, wind present/missing, reverse-geocode success/fallback, copy report content/privacy label, deterministic recommendation equality with debug off/on, and real-iPhone Settings-to-app walkthrough.
- **Dependencies:** 2.7; diagnostic infrastructure may proceed while 2.8 is decided, but final hourly diagnostics include the 2.8 fog/mist field.
- **Non-goals:** Remote logging, analytics, automatic report upload, a general settings screen, recommendation customization, retaining location history beyond the bounded diagnostic need, or making wind a decision rule.
- **Blocking TBDs:** T-09 remains unresolved but does not block strictly local diagnostics; no collection/upload may be added.

**Updated Phase 2 exit:** 2.1–2.9 criteria met. Local debug tooling remains technical and opt-in; fog/mist behavior must be resolved and tested before Phase 3 presentation approval.

## Phase 3 — Core app polish

Goal: remove measured/user-visible friction without adding unapproved features.

### 3.1 — Approve final V1 presentation details

**Approval (D-046/D-047):** The single-item Home Screen reference, YES/MAYBE/NO labels, Guided/Compact modes, hero, daypart cards and segmented hourly timeline are approved for implementation within 3.1.1/3.4/3.5. Existing loading/recovery behavior is preserved. Phase 3 closure is recorded in `TODO.md`; validation items without specific results remain open there as unphased follow-up and are not claimed as passed.

**Implementation progress (2026-10-14):** The approved Home Screen and presentation models are implemented with bundled artwork, raw-hour uncertainty/grouping context, timezone/DST labels and scalable layouts. Validation evidence and any outstanding follow-up are tracked in `TODO.md`.

- **Type:** Product/UX decision.
- **Objective:** Settle the existing screen and state design.
- **Exact scope:** Review concrete result/period/loading/error and enabled-debug examples; obtain approval for exact labels/caution wording, short reasons, semantic palette, layout, permission/stale copy and accessibility behavior. Preserve recommendation-first hierarchy and meaning without color alone; diagnostics remain visually subordinate and absent when disabled.
- **Likely files/components:** `UX.md`, `DECISIONS.md` where material, `TODO.md`, proposed SwiftUI previews/mockups.
- **Acceptance criteria:** T-10/T-11 are resolved for all existing states; no unapproved settings/features are added; approved designs are reviewable before implementation. D-048/D-049 subsequently approved the focused Home presentation switches.
- **Tests/validation:** Review dry/rain/fog/caution/heat/period/error and enabled-debug examples, large-text and non-color interpretation.
- **Dependencies:** 2.9.
- **Non-goals:** New screens/features, final icon/marketing assets, notification/widget design.
- **Blocking TBDs:** T-10, T-11.

### 3.1.1 — Clarify the Home Screen for first-time users

- **Type:** Product/UX decision, focused presentation implementation and review.
- **Objective:** Make the app’s purpose, recommendation labels and relationship between the overall answer and dayparts immediately understandable without redesigning the Home Screen.
- **Approved direction:** Name the centrally configured variants **Guided Home** and **Compact Home**, default to Guided, and add this dismissible first-use explanation card only to Guided Home:

  **How it works**

  **The main result covers today. Dayparts show when it changes, and the reason explains why.**

  **Got it**

- **Exact scope:** `HomePresentationMode` selects Guided or Compact and defaults to Guided. Expose the default-on **Guided Home** presentation preference in Apple system Settings; off selects Compact. Both modes display YES/MAYBE/NO and the data-derived reason without a redundant question or action sentence. Guided adds the item-neutral purpose line, concise card and **When can I wear it?** context. **Got it** disables the default-on **Show How It Works** preference. Turning Guided off also disables Show How It Works; turning Show How It Works on also enables Guided. Tighten the standard layout so primary content fits an iPhone 13. Preserve the existing evaluation, aggregation, weather, cache, provider and daypart rules.
- **Likely files/components:** `ContentView.swift`, `HomeComponents.swift`, `HomePresentation.swift` if presentation labels require it, focused unit/UI tests, and the relevant truth-file decision record when implementation begins.
- **Acceptance criteria:** A first-time Guided Home user can understand what the app evaluates, what each recommendation means, that the hero is overall advice for today, that dayparts show changes and that the short reason explains why. Tapping **Got it** hides the card persistently without removing the other Guided elements; resetting the preference shows it again. Compact omits Guided-only elements. Existing status semantics and mixed-day behavior remain unchanged.
- **Tests/validation:** Unit tests for the three display labels and persisted-card state; UI tests for first presentation, dismissal, relaunch persistence and reset/reappearance; review mixed dayparts such as YES in the morning and NO in the evening.
- **Dependencies:** 3.1 approval and existing Phase 2 presentation/domain outputs.
- **Non-goals:** Changing weather thresholds, recommendation aggregation, daypart splitting, caching, API behavior, onboarding flows beyond this one card, or redesigning the Home Screen layout.
- **Status:** Implemented; automated validation and final review tracked in `TODO.md`.

### 3.2 — Polish permissions and recovery states

- **Type:** UX implementation, testing and real-device validation.
- **Objective:** Make denied access and unavailable data understandable and recoverable.
- **Exact scope:** Apply approved permission/loading/failure/stale copy and interactions; avoid repeated prompts; support approved retry/recovery behavior without redundant requests or misleading retained results.
- **Likely files/components:** Location adapter, presentation model, `ContentView`, permission description, integration/UI tests.
- **Acceptance criteria:** First use, denial, disabled location, no weather and stale-data states are clear; repeated opens do not prompt unnecessarily; recovery does not invent certainty.
- **Tests/validation:** Fake state transitions and real-phone first permission, denial, permission changes, failure/retry and relaunch.
- **Dependencies:** 3.1, 2.9.
- **Non-goals:** Onboarding funnel, broad settings, manual location entry.
- **Blocking TBDs:** None after T-11 approval; any new recovery interaction must be proposed before adding it.

### 3.3 — Measure and remove startup/request friction

- **Type:** Performance implementation and real-device validation.
- **Objective:** Improve responsiveness and battery behavior based on evidence.
- **Exact scope:** Measure first frame, location acquisition, weather fetch and calculation; fix observed duplicate work, unnecessary waits, main-thread work and location lifecycle leaks; keep relevant timeout values centralized.
- **Likely files/components:** App lifecycle, presentation model, adapters/caches, configuration; local device profiling tools and `TODO.md` evidence.
- **Acceptance criteria:** Before/after evidence explains each fix; first frame remains responsive; no unnecessary location/network/background work; no unmeasured performance claims or hidden data collection.
- **Tests/validation:** Real-device cold/warm launch, cached path, slow network, cancellation/background/foreground; targeted regressions for fixed behavior and request counts.
- **Dependencies:** 2.9, 3.2.
- **Non-goals:** Speculative optimization, production telemetry SDK, background refresh, or requests more frequent than the approved D-031 policy.
- **Blocking TBDs:** Any changed behavior-affecting timeout needs approval; T-09 blocks collection, not local measurement without telemetry.

### 3.4 — Implement and verify accessibility

- **Type:** UX implementation and testing.
- **Objective:** Make recommendations and periods usable beyond the default visual presentation.
- **Exact scope:** Apply approved accessible labels/order, Dynamic Type layout, contrast/non-color cues, touch targets and reduced-motion behavior for existing controls/states, including the enabled diagnostics surface.
- **Likely files/components:** `ContentView` and small view components, UI tests, `UX.md` approved guidance.
- **Acceptance criteria:** VoiceOver conveys recommendation, reason and period; large text does not hide essential content; meaning survives color differences; controls remain usable.
- **Tests/validation:** Accessibility inspection/UI checks plus manual VoiceOver, large text, contrast and reduced-motion checks on a phone.
- **Dependencies:** 3.1, 3.2.
- **Non-goals:** New interaction modes or product features, reliance on color alone.
- **Blocking TBDs:** None after accessibility details in T-11 are approved.

### 3.5 — Finish visual and transition polish

- **Type:** Presentation implementation and testing.
- **Objective:** Apply approved final styling without layout jumps or distracting transitions.
- **Exact scope:** Finish spacing, typography, palette and period presentation for existing states; stabilize transitions as loading/results/fallback change; fix visible stutters found in review.
- **Likely files/components:** Existing SwiftUI views/presentation model, preview fixtures, UI checks.
- **Acceptance criteria:** Approved design is reflected in every state; recommendation remains quick to read; accessible layout survives transitions; no placeholders remain in the result experience.
- **Tests/validation:** Visual review of all states and supported size/text configurations; real-phone loading/result/failure transitions and targeted UI regressions.
- **Dependencies:** 3.1–3.4.
- **Non-goals:** New animations/features, marketing screenshots, icon design.
- **Blocking TBDs:** None after T-10/T-11 approval.

## Phase 4 — Predefined multi-item support (first-release requirement)

Goal: expand the already implemented jacket-only experience to a **small user-approved predefined collection** before public release. Preserve the existing jacket engine and its approved rules. Do not introduce custom-item editing or a generic advanced rules builder simply because more items are needed.

### 4.1 — Approve initial item collection and multi-item UX

- **Type:** Product/UX decision gate.
- **Objective:** Confirm which predefined items the first release supports, what each item's recommendation means and how users view several items.
- **Exact scope:** Finish concrete presentation review and identify/validate faithful provider-signal mappings. D-067 approves selection/configuration flow, D-068 chooses layout A, D-069 settles grouping, D-070 settles initial/minimum selection and D-071 applies unchanged Raincoat thresholds to total precipitation. D-063–D-066 settle daily algorithms, useful-hour minimum, launch assignments and missing-input/gap handling; do not reopen these or invent per-item daily algorithms. D-060 approves explicit verdicts/timing without a user-facing taxonomy; exact group labels/configuration explanation remain deferred to 8.1.
- **Acceptance criteria:** Apply D-065's approved catalog assignments with complete hourly/input policies and primary UI interaction; every required weather factor has an identified normalized input and testable behavior; jacket policy remains unchanged. Review the current aggregation examples in `WEATHER_LOGIC.md` for every assigned item, including separated useful hours and qualified single-hour advice. Mixed-day advice must convey its meaning and time scope without requiring knowledge of an item group; streamlined wording must not change aggregation.
- **Tests/validation:** Review sample forecasts and multi-item/no-data scenarios against the explicit-verdict contract in `UX.md`, including a useful sunny interval, a single jacket hazard, all-window suitability and an item useful in some hours but unsuitable in others; approve sensible defaults for each new item.
- **Dependencies:** Phase 3.1/3.5 presentation foundation and Phase 2 domain outputs.
- **Non-goals:** Custom items, user-editable thresholds, saved cities, accounts, notifications, adding unapproved item types.
- **Remaining gate work:** Concrete presentation cases and faithful required-signal mappings/validation. D-071 closes Raincoat solid/mixed-precipitation scope; do not retain it as an unsupported-condition blocker. D-062/D-066 resolve base conditions, optional fallbacks and missing-required-input/gap behavior. D-063–D-071 settle algorithms, useful-hour minimum, assignments, input handling, layout/grouping, initial/minimum selection and Raincoat precipitation scope. Ask only about genuinely undefined material behavior discovered during review, not routine mapping/implementation details. Group-label deferral and D-060's verdict/timing approach are unchanged.

**Decision progress (2026-10-18, D-058/D-060):** The seven-item collection, weather-fit perspective, compact overview, initial temperature bands/input for Warm Coat, Sweater, Gloves and Shorts, and extension of the isolated one-hour gap rule are approved. High-level Raincoat and Sunglasses behavior is recorded. D-060 replaces a universal daily YES/MAYBE/NO with an explicit verdict and timing, supersedes D-059 and defers exact group labels to 8.1. The Phase 4.1 blockers above concern actual behavior and inputs, not group names. Do not begin implementation until the remaining decisions are approved/recorded and the user explicitly gives permission.

**Decision progress (recorded 2026-10-19, D-062):** Initial Raincoat rain/chance/wind conditions and Sunglasses daylight/sky/UV conditions are approved, including optional wind/UV fallback. Their policy boundaries and examples are maintained in `WEATHER_LOGIC.md`, input-normalization constraints in `TECH_SPEC.md`. Do not reopen approved presentation or thresholds, or interpret policy approval as permission to implement. This update does not declare Phase 4.1 complete.

**Decision progress (2026-10-19, D-063, subsequently amended by D-064):** The two shared daily aggregation policies are locked. Their current algorithms, validity safeguards and acceptance matrix are in `WEATHER_LOGIC.md`; the initial established assignments were Leather Jacket and Sunglasses, with the rest subsequently approved in D-065. Shared wording is compatible with distinct daily aggregation; no third combined algorithm is approved. Documentation only; Phase 4.1 remains incomplete and app implementation still needs explicit permission.

**Decision progress (2026-10-19, D-064):** User approved the proposed useful-hour minimum, nonconsecutive counting and qualified single-hour advice, replacing the original best-hour trigger. Apply the current contract in `WEATHER_LOGIC.md`, not the superseded one-hour positive-day rule. Can I wear and existing jacket behavior remain unchanged. This decision did not approve the remaining catalog assignments (subsequently resolved by D-065) or app implementation.

**Decision progress (2026-10-19, D-065):** User approved all five remaining items as Should I wear. All launch assignments are now decided; apply the assignment table in `WEATHER_LOGIC.md`. Remaining Phase 4.1 work is limited to genuine input/gap/grouping/presentation choices, not catalog assignment or algorithm redesign. Documentation only; implementation is not authorized by this approval.

**Decision progress (2026-10-19, D-066):** Required-input validity and the uncertain/MAYBE isolated gap are approved for Should I wear items, with existing coverage limits, optional fallbacks and independent item availability. Acceptance cases live in `WEATHER_LOGIC.md`. This closes the missing-data decision, not an observed live defect; do not turn routine implementation details into further approval rounds. Documentation only; remaining material product/design gates still apply.

**Decision progress (2026-10-19, D-067):** User requested visual prototypes based on the current Guided Home, with item configuration first, header-gear access later and the existing single-item variants for one selection. The prototype is a review artifact, not app implementation or approval of its illustrative defaults, zero-selection rule, final copy or alternative multi-item layouts. Setup flag constraints are in `TECH_SPEC.md`.

**Decision progress (2026-10-20, D-068):** User selected multi-item direction A, the cards with daypart previews and item detail on selection. Do not reopen the A/B choice or implement B as an additional layout. Acceptance includes selected-item cards with meaningful time previews, scalable/non-color advice and full detail access. Illustrative defaults/copy, non-jacket period consolidation and other unresolved Phase 4.1 choices remain separate; app implementation still requires permission.

**Decision progress (2026-10-20, D-069):** User approved contiguous same-advice grouping for all six Should I wear items, preserving short useful intervals without jacket-style expansion/smoothing. Count useful hours from directly evaluated hours, not displayed periods. `WEATHER_LOGIC.md` owns exact rules and future acceptance examples. This closes non-jacket grouping, not remaining precipitation/selector choices or the implementation-permission gate.

**Decision progress (2026-10-20, D-070):** User approved no preselected items on fresh first launch and a minimum of one item to enable Continue or Save selection. These selector behaviors are no longer open choices. Future implementation acceptance must cover the initial disabled button, one-item enablement and inability to save an empty edited selection; prototype behavior already demonstrates these interactions, but no Swift implementation or new app test run is claimed.

**Decision progress (2026-10-20, D-071):** User approved unchanged Raincoat numeric thresholds for all precipitation, using total water-equivalent amount rather than snow depth. Current rules/examples are in `WEATHER_LOGIC.md` and normalized units in `TECH_SPEC.md`. This removes the rain-only/distinct-liquid-input restriction; no provider migration, app implementation or live validation is claimed.

**Provider evidence review (2026-10-20):** Source/docs inspection and a fixed-coordinate live probe confirm the required fields are available in the sampled Open-Meteo response. Sunglasses needs daylight/cloud/UV normalization; source-backed category mapping and references are in `TECH_SPEC.md`. The existing accumulated-precipitation interval mismatch is tracked as **ISS-001**, not an undefined product choice. Provider contract/mapping work is independent of remaining Home copy review, but code work still needs explicit user permission; do not mark 4.1 complete from this read-only check.

**Authorized provider implementation (2026-10-20):** User directed continuation after the explicit implementation offer. The normalized optional signals, interval-alignment fix and cache-compatibility change are implemented; validation status/evidence are maintained in `TODO.md` and ISS-001. No new item decision engine, selector, Home layout or broad Phase 4 implementation is authorized/completed by this focused work. Remaining presentation review and Phase 4.1 closure are separate.

### 4.2 — Implement multi-item rule and domain support

- **Type:** Domain/application implementation and deterministic tests.
- **Objective:** Produce trustworthy recommendations for every approved predefined item for the same current-location weather.
- **Exact scope:** Add only the catalog/model/rule-config support needed; centralize item-specific hourly factors/thresholds, the D-064 useful-hour minimum and D-065's explicit assignments to the two shared algorithms. Share validated evaluation/time-window/cache flow where appropriate, without duplicating end-to-end engines, inverting raw weather thresholds or cross-applying jacket safety grouping.
- **Acceptance criteria:** Each item gets correct independent daily advice, supporting times/reasons and meaningful periods; policies do not depend on display-name or verdict-string matching. Missing inputs fail safely per approved item rules; the existing leather engine passes unchanged regression tests. Do not add a generic rules builder or future custom-item editor to satisfy extensibility.
- **Tests/validation:** The D-063/D-064 daily matrix, D-069 period examples and D-071 Raincoat all-precipitation boundaries in `WEATHER_LOGIC.md`, applied to approved assignments. Verify faithful contiguous periods, preserved one-hour useful intervals, no jacket-style expansion and daily-count independence from period display. For Raincoat, equal water-equivalent amounts must classify identically across precipitation types; cover wind upgrade/non-upgrade and missing-wind fallback. Add item-specific boundary/precedence/coverage tests and unchanged jacket rain/fog/cache/local-day period regressions; tests do not require network/GPS.
- **Dependencies:** Approved 4.1 rules/input contracts; original providers and Phase 2. After the in-context prototype review, the user's continuation on 2026-10-20 authorizes focused domain implementation/testing. Routine copy refinement and remaining screen approval do not change those rules or imply that Phase 4.3 is implemented/approved in full.
- **Non-goals:** User-created items or threshold editing, advanced expression/rule engine, per-city caching.
- **Blocking TBDs:** None once 4.1 decisions are recorded.

### 4.3 — Implement multi-item presentation

- **Type:** App UX implementation and UI testing.
- **Objective:** Make additional item recommendations clear without making the app a weather dashboard.
- **Exact scope:** Implement the reviewed D-067 item selector, persisted setup flag/reset contract, header gear and automatic single-/multi-item Home choice, using D-068's direction A for multiple items, alongside the 4.1-approved explanations, period display and safe unavailable/stale states. Preserve current single-item presentation variants, quick startup and current location. Do not add B as a second app layout. Implement only after the remaining gate/prototype approvals and explicit implementation permission.
- **Acceptance criteria:** Item identity, explicit daily-verdict meaning, relevant timing and weather reason are immediately recognizable without learning an item-group label. Usefulness during one interval must not read as all-day suitability; not-needed must not read as unsafe. Preserve caution/uncertainty and failure handling, accessible/non-color presentation, and D-057's omission of Home freshness status. Switching/overview performs without duplicate network requests.
- **Tests/validation:** Deterministic multi-item UI scenarios with conflicting item recommendations and changing periods; cover the D-060 examples, uncertainty and incomplete coverage; large text/accessibility checks convey the same time scope and meaning.
- **Setup-reset regression:** Exercise the actual Apple Settings control on foreground return (including an open configuration sheet) and cold launch; verify cleared selected items, disabled Continue until a new selection, one-shot consumption, preserved Home preferences/caches and successful confirmation/relaunch without a reset loop. See ISS-002 for current verification state.
- **Post-Phase-4 layout regression (D-074 / ISS-006):** Verify compact jacket-style overview heroes, one non-jacket daypart summary badge under the approved display rule, shared compact hourly timelines and unchanged jacket detail/daily algorithms. Cover all seven items, single useful hours, borderline/inferred hours, missing coverage, standard iPhone 13 card density and accessibility text sizes. This follow-up does not reopen accepted 4.4 or its deferred 6.3 recovery check.
- **Subsequent approved overview refinement (D-075; execution status in TODO):** This supersedes the universal stacked-A/compact-artwork/chevron requirements above. Verify count boundaries 1/2/3/4/7, selected-order preservation, complete two-/three-card standard viewport, scrolling gallery/detail access, all known NO outcomes red without making unavailable advice red, single-item-style text without routine timing duplication, necessary brief/exception/uncertainty qualifications, all three dayparts, and narrow/largest-text light/dark layouts. Keep recommendation/domain and existing single-item/detail layout regressions. Run `bash scripts/verify.sh full` and inspect actual simulator screenshots; prototype assertions do not satisfy app acceptance. No phone installation until the user separately requests it. Handoff: `prototypes/multi-item-layouts/IMPLEMENTATION_HANDOFF.md`.
- **Dependencies:** 4.1–4.2, 3.5.
- **Non-goals:** Widget, saved cities, custom items, broad settings.

**Implementation authorization (2026-10-20):** After the completed domain step, the user directed continuation into item selection and Home integration. Implement the approved D-060/D-063–D-071 behaviors and direction A, handling routine wording in screen context as delegated. This authorizes the focused Phase 4.3 work, not new rules, thresholds, broad settings, alternative layouts or final artwork approval. Run full verification and inspect actual simulator screens; retain physical-iPhone acceptance as 4.4.

### 4.4 — Verify multi-item experience on real iPhone

- **Type:** Device/integration gate.
- **Objective:** Prove approved items work together with real live weather before building widget/release assets.
- **Exact scope:** Real-device current-location flow, all approved items, forecast failures/cached states and UX responsiveness; record evidence and targeted fixes.
- **Acceptance criteria:** Real-device multi-item recommendation is trustworthy, appropriately fast and regression-tested; Phase 5 can safely share its data.
- **Dependencies:** 4.3.
- **Non-goals:** First public release itself, post-release features.

**Closure scope (2026-10-20):** The user accepted 4.4 on the recorded live-flow, all-item detail, selection persistence and cached-offline device checks, and explicitly moved the unperformed failed-fetch/recovery observation to the 6.3 TODO. This permits proceeding to 5.1; it does not represent that observation as passed. Evidence and the deferred checkbox are maintained in `TODO.md`.

## Phase 5 — First-release iOS widget

Goal: ship the iOS widget **before** the first public release; content/design must match the approved predefined multi-item app.

### 5.1 — Approve widget content, form and refresh behavior

- **Type:** Product/UX/technical decision gate.
- **Exact scope:** Review candidate directions expressed by the user: (a) separate per-item widgets plus an overall widget, or (b) a smart combined overview with relevant periods. Decide exact widget forms, supported sizes, widget configuration, tapped destination, refresh limits, permissions, safe stale/no-data states and accessible presentation.
- **Acceptance criteria:** User chooses the actual widget experience; behavior is possible under the currently supported iOS/widget data constraints without inventing background tracking or changing weather rules.
- **Dependencies:** 4.3–4.4.
- **Blocking TBDs:** Final widget variant and UX, supported data refresh/storage behavior.

### 5.2 — Implement approved widget(s)

- **Type:** Widget extension implementation and tests.
- **Exact scope:** Use shared app-owned item recommendations/weather provenance/periods and safe refresh/cache handoff; implement only the user-approved 5.1 widget forms and states.
- **Acceptance criteria:** Correct item identity, reason/timing and safe staleness; no widget-specific rule engine or continuous location tracking; no repeated excessive weather calls.
- **Dependencies:** 5.1, 4.4.
- **Non-goals:** Notifications, custom items, multi-city support.

### 5.3 — Validate widget on device and through failure states

- **Type:** Device/UX/accessibility validation.
- **Exact scope:** Validate widget display, update/refresh, item presentation, cache expiry, permission/network failure, app/widget consistency and supported device/sizes.
- **Acceptance criteria:** Tests plus real-device evidence; widget never fabricates a confident recommendation from stale/unavailable data, and Phase 6 can include it in release-quality regression.
- **Dependencies:** 5.2.

## Phase 6 — First-release validation

Goal: prove the completed **multi-item app and widget**, in addition to the original leather-jacket behavior, under real conditions. Record actual results; tests are not complete merely because a checklist exists. Correct failures in focused changes to the responsible component, then rerun affected checks. Changes to approved policies go through the truth-file decision process.

### 6.1 — Complete the deterministic regression matrix

- **Type:** Testing.
- **Objective:** Close gaps in core rules, periods and failure/fallback coverage.
- **Exact scope:** Audit and supplement existing tests against `WEATHER_LOGIC.md` and `TODO.md`; cover original jacket boundaries, rain/temperature combinations, daily timing, noise, missing inputs and cache validity **plus every approved predefined item and shared-widget state** without live services.
- **Likely files/components:** Existing unit/integration test targets and fixture helpers; `TODO.md` evidence.
- **Acceptance criteria:** Every required jacket, new-item and widget scenario maps to a meaningful passing test; expected outcomes reflect approved rules; test runs need no GPS/network/live weather/time.
- **Tests/validation:** Full deterministic suite plus focused UI state tests; review assertions for behavior rather than implementation mirroring.
- **Dependencies:** 3.5, 2.9, 4.4, 5.3.
- **Non-goals:** Arbitrary coverage target, giant generated suite, duplicate tests without added behavioral value.
- **Blocking TBDs:** None after prerequisite decisions; uncovered ambiguity is surfaced for approval.

### 6.2 — Validate weather behavior across real conditions

- **Type:** Real-device/provider validation.
- **Objective:** Assess whether live forecasts support trustworthy jacket protection.
- **Exact scope:** Check live weather in several **test locations** (not the later multi-city user feature) and observed dry, drizzle, normal/heavy rain, warm/cool, morning-only and later-day rain, and changing forecasts; compare live normalized inputs and recommendations with observed conditions. Review the active provider's accuracy, weather-variable coverage for all launch items, rain resolution, speed, reliability, cost and deployment experience.
- **Likely files/components:** Active weather adapter, rules/config/period engine, `TODO.md` validation evidence; affected truth files only for approved tuning.
- **Acceptance criteria:** Observed scenarios and discrepancies are recorded honestly; mapping/logic defects are fixed; provider limitations and unresolved safety issues are visible. Unobserved conditions remain pending rather than fabricated; fixtures supplement field evidence.
- **Tests/validation:** Real-phone observations, deterministic replay where useful, targeted regression tests for discoveries. If provider suitability fails, propose a decision review rather than silently switch providers.
- **Dependencies:** 1.4, 2.9, 3.5, 4.4, 5.3; provider observation can begin in 0.6 and accumulate earlier.
- **Non-goals:** Guaranteeing forecasts, automatic rule tuning, additional providers without approval, location-history collection.
- **Blocking TBDs:** None after prerequisites; field weather/location availability may limit completion evidence.

### 6.3 — Validate degraded operation and recovery

- **Type:** Integration testing and real-device validation.
- **Objective:** Prove failures do not produce unsafe confidence or frustrating loops.
- **Exact scope:** Exercise weak/no network, denied/disabled/unavailable location, timeout, missing forecast, recent/stale/wrong-location cache, app relaunch and subsequent forecast changes using fixtures and device controls.
- **Likely files/components:** Providers, caches, presentation, integration/UI tests, `TODO.md` evidence.
- **Acceptance criteria:** Approved fallback/expiry behavior holds on device; useful recent data remains clearly represented; unusable data never yields a confident answer; recovery updates the visible result without repeated prompts/request loops.
- **Tests/validation:** Device offline/slow-network and permission checks; deterministic failure injection for cases live services cannot reliably reproduce; regression tests for fixes.
- **Dependencies:** 3.5, 4.4, 5.3, 6.1.
- **Non-goals:** Background delivery, manual cities, adding offline forecast products.
- **Blocking TBDs:** None after prerequisites.

### 6.4 — Validate supported devices and close the V1 quality gate

- **Type:** Real-device validation and release-quality review.
- **Objective:** Confirm reliable operation beyond one successful demo.
- **Exact scope:** Test multiple real iPhones across approved OS/device support; recheck launch, permissions, relaunch, **all predefined items and the widget**, UI/accessibility, network performance and battery/location lifecycle; consolidate evidence and remaining defects.
- **Likely files/components:** Existing app/tests, project deployment settings, `TODO.md` quality evidence.
- **Acceptance criteria:** Core scenarios pass on the recorded device/OS matrix; no unresolved defect undermines trustworthy recommendations, required accessibility or reliable operation; performance claims have measurements; no continuous/background location tracking.
- **Tests/validation:** Real-device matrix, local profiling where needed, full automated suite after necessary fixes; document unavailable matrix coverage explicitly.
- **Dependencies:** 6.1–6.3, 3.3–3.5, 4.4, 5.3, approved T-07.
- **Non-goals:** Declaring App Store submission complete, expanding platform support, invented performance numbers.
- **Blocking TBDs:** None after prerequisites; access to multiple devices is an external prerequisite.

## Phase 7 — First public release / Store readiness

Goal: deliver the validated **multi-item + widget** first public release through TestFlight and the App Store. Verify current Apple/provider requirements when executing these subphases; this plan does not assume a frozen submission checklist. Store/account artifacts are likely involved, but this documentation task does not authorize uploads, submissions or release actions now.

### 7.1 — Finalize release identity and telemetry policy

- **Type:** Product/technical decision and App Store readiness.
- **Objective:** Lock the remaining identity/privacy choices before distribution setup.
- **Exact scope:** Approve final bundle identifiers and reconcile approved OS support; decide telemetry explicitly and reflect its privacy consequences. No telemetry collection may be added while policy is TBD.
- **Likely files/components:** `DECISIONS.md`, `TECH_SPEC.md`, `TODO.md`; eventual project identifiers and App Store Connect identity.
- **Acceptance criteria:** T-08/T-09 are resolved; configured release identity/support matches approved decisions; telemetry approval does not implicitly approve a new SDK/integration.
- **Tests/validation:** Review identity/signing/service implications and actual data flows; build recheck after any approved identifier change.
- **Dependencies:** 0.2, 6.4. Final identity may be decided earlier when necessary for provisioning.
- **Non-goals:** Accounts, sync, adding analytics merely because it is common, changing the locked app name.
- **Blocking TBDs:** Remaining T-08, T-09.

### 7.2 — Prepare the app icon and listing metadata

- **Type:** App Store readiness and asset implementation.
- **Objective:** Replace release placeholders and accurately describe V1.
- **Exact scope:** Produce/review an icon for Can I Wear, populate the asset catalog, and prepare required listing text/metadata for the approved predefined multi-item product with widget.
- **Likely files/components:** `Assets.xcassets/AppIcon.appiconset`, listing text/assets, App Store Connect draft fields.
- **Acceptance criteria:** Approved icon meets requirements verified at execution; listing accurately describes the **actual approved launch-item recommendations and widget** without unsupported guarantees/features; no icon placeholder remains.
- **Tests/validation:** Icon inspection on device/appearance variants as required; metadata review against actual shipped scope.
- **Dependencies:** 3.5, 4.4, 5.3, 6.1.
- **Non-goals:** Renaming, broad branding project, advertising new features.
- **Blocking TBDs:** Icon/metadata designs require review; exact release asset details are not specified by truth files and are not selected here.

### 7.3 — Prepare privacy and provider-compliance material

- **Type:** App Store readiness and verification.
- **Objective:** Make release declarations match actual app behavior.
- **Exact scope:** Review current Apple privacy/submission requirements and the selected production provider's attribution/licensing requirements; prepare privacy information/policy/support material as required, verify purpose descriptions and provider attribution, and reflect approved telemetry/data handling accurately.
- **Likely files/components:** App permission configuration, attribution UI, privacy/support artifacts and listing fields; `TECH_SPEC.md`/`TODO.md` evidence.
- **Acceptance criteria:** Required disclosures and attribution are accurate and complete; no unexpected location history or undeclared collection exists; release materials match approved policy and tested implementation.
- **Tests/validation:** Inspect real data flows/configuration and installed attribution/purpose text; check current authoritative requirements at execution rather than inventing obligations now.
- **Dependencies:** 7.1, 0.6, 3.5.
- **Non-goals:** Adding collection, legal boilerplate unrelated to actual behavior, account infrastructure.
- **Blocking TBDs:** None after T-09 approval; required release contact/support/privacy artifact details need completion/review when preparing materials.

### 7.4 — Capture App Store screenshots

- **Type:** App Store readiness and visual validation.
- **Objective:** Show the final V1 experience accurately.
- **Exact scope:** Capture required supported screenshot sizes from final UI using reviewable weather scenarios; prepare approved captions/assets if needed. Fixtures may stage screenshots but do not replace live validation.
- **Likely files/components:** Final app, deterministic preview/UI fixtures, screenshot artifacts, App Store Connect draft assets.
- **Acceptance criteria:** Screenshots match shipped UI, show item identity, recommendation/period meaning and actual widget capability clearly, and meet currently required sizes; no unfinished states or out-of-scope claims.
- **Tests/validation:** Inspect every screenshot for truncation/layout errors and consistency with current build/scope.
- **Dependencies:** 4.3, 5.3, 7.2.
- **Non-goals:** Product redesign, new marketing features, changing recommendation logic for screenshots.
- **Blocking TBDs:** Screenshot/caption selections require review; no final UI details are chosen here.

### 7.5 — Validate a distribution build through TestFlight

- **Type:** App Store readiness, testing and real-device validation.
- **Objective:** Prove the packaged app works with production distribution settings.
- **Exact scope:** Prepare signed archive/versioning, run distribution checks, upload through the authorized release workflow, install through TestFlight, and test all release-item recommendations, the widget, permissions/fallback. Address release-only defects with focused fixes.
- **Likely files/components:** Xcode signing/release settings, existing targets/assets, App Store Connect/TestFlight, `TODO.md` evidence.
- **Acceptance criteria:** Distribution archive validates and TestFlight installs; live location/weather/multiple-item recommendations and the widget work on a real iPhone; required privacy/assets are present; release-only issues are resolved with appropriate regressions.
- **Tests/validation:** Automated suite, archive validation, TestFlight cold launch/live flow/denial/offline/relaunch/accessibility smoke tests on approved support.
- **Dependencies:** 6.4, 5.3, 7.1–7.3; 7.4 is required before the later submission gate, not to start TestFlight.
- **Non-goals:** Public release, inviting others or uploading without the applicable task authorization, adding beta-only product features.
- **Blocking TBDs:** None after prerequisites; account/distribution access and release-action authorization are external prerequisites.

### 7.6 — Prepare review, submit and release V1

- **Type:** App Store readiness and release validation.
- **Objective:** Complete the roadmap's shipping requirement.
- **Exact scope:** Review final listing/privacy/screenshots/build, prepare review notes explaining permissions and weather dependency, submit through the authorized release workflow, handle review issues, and release the approved build.
- **Likely files/components:** App Store Connect listing/review/release fields, distribution build, `TODO.md` final evidence; narrow source/docs fixes only if required and approved by scope.
- **Acceptance criteria:** Review materials are complete, validated build is accepted and V1 is released; status distinguishes prepared/submitted/accepted/released rather than marking all complete at upload.
- **Tests/validation:** Final release-candidate smoke check; targeted regressions and renewed distribution check after review-driven changes; verify published listing/build after release.
- **Dependencies:** 7.4, 7.5 and all Phase 7 material complete.
- **Non-goals:** V2 scope, feature additions to appease hypothetical review concerns, submission/release without applicable authorization.
- **Blocking TBDs:** Release timing/method and review material must be confirmed when executing the release task; Store review outcome is external, not a locally completed test.

## Phase 8 — Basic custom items (early post-release)

### 8.1 — Approve minimal custom-item model and defaults
- **Decision gate:** Decide minimum fields, how a user-created item gets a valid initial weather policy, edit/delete and persistence UX; do not assume arbitrary rule building, photos, item categorization or an owned-wardrobe inventory.
- **Decision gate (D-060):** Resolve exact names and configuration wording for the different item behaviors, including combined behavior where supported. Users must understand what they are choosing and its effect on daily advice; D-059's historical labels are not approved defaults. This gate does not assume a mandatory group field or a particular editor.
- **Acceptance:** The user approves the simple local-first experience, the behavior-choice explanation and error handling; custom items remain distinct from predefined defaults. Their Home advice follows the same explicit-verdict/timing contract, not a newly ambiguous universal daily YES/NO.
- **Dependencies:** First public release / Phase 7, multi-item architecture from Phase 4.

### 8.2 — Implement and test basic custom-item management
- **Delivery:** Locally create/display/edit/delete supported custom items using the approved initial rule mechanism, without accounts or sync.
- **Tests:** persistence/migration, invalid input, restart, loss prevention and deterministic recommendations; real-iPhone usability.
- **Dependencies:** 8.1.

## Phase 9 — Editable per-item weather thresholds

### 9.1 — Approve rule-threshold editing scope
- **Decision gate:** Decide which item types and which weather thresholds are editable, value bounds/units/default-reset semantics and the smallest usable interface. Basic items must already work.
- **Acceptance:** The edit scope is recorded; preserve a reliable default policy and do not build a complex visual rule composer by assumption.
- **Dependencies:** 8.2.

### 9.2 — Implement tested local per-item overrides
- **Delivery:** Persist approved threshold changes locally and recompute recommendation/periods; keep normalization, versioning and configuration explicit.
- **Tests:** boundary values, migration/reset, default parity, incomplete data, precedence and real-device UI.
- **Dependencies:** 9.1.

## Phase 10 — Multiple locations and a clean overview

### 10.1 — Approve location selection and overview design
- **Decision gate:** Decide city search/selection, favorites, current-location priority, multi-city inclusion, whether active/inactive flags help, and what happens to saved but unselected cities. Confirm unmistakably scannable city differentiation.
- **Acceptance:** Explicitly approved location overview and manual visibility model. **Recurring schedules are a later phase**; a saved favorite does not automatically imply display forever.
- **Dependencies:** 9.2 (preferred sequencing as explicitly stated by the user).

### 10.2 — Implement city search, favorites and current-location coexistence
- **Delivery:** Add approved city lookup, saved places and safe forecast/cache identity per city, while preserving automatic current-location behavior and the existing one-time location/battery policy.
- **Tests:** duplicate city names, timezone differences, wrong-city cache, no location permission, refresh limits, persistence, location switching.
- **Dependencies:** 10.1.

### 10.3 — Implement and device-validate multi-location overview
- **Delivery:** Display approved location selection with crisp differentiation and per-location item recommendations; measure visual scan and performance with several cities.
- **Tests:** multiple cities/items, absent/stale data, content-size/accessibility and device UX.
- **Dependencies:** 10.2.

## Phase 11 — First simple forecast-horizon extension

### 11.1 — Decide minimal extension beyond today's overview
- **Decision gate:** Choose one small understandable future-looking behavior; exact hours/days are TBD. The Bruges/Ghent example does not require trip/date planning or arrival-time scheduling.
- **Dependencies:** 10.3.

### 11.2 — Implement and test the approved extension
- **Delivery:** Safely extend normalized forecast selection and display for approved locations, respecting per-city timezones and unknown-data behavior.
- **Tests:** day boundaries, missing future hours, provider forecast limits, cross-location timezone differences and cached freshness.
- **Dependencies:** 11.1.

## Phase 12 — Recurring location schedules (late; slot order with Phase 13 TBD)

### 12.1 — Approve recurrence, visibility and override UX
- **Decision gate:** Schedule saved cities by selected weekdays each week, nth weekday in month (e.g., second Monday), and every two weeks/other approved repeating intervals. On a matching day the city appears in overview; when it does **not** match, it is not shown automatically. Decide current-location coexistence, optional active/inactive state, manual override, timezone, and schedule editing before implementation.
- **Dependencies:** Phase 10; Phase 11 is the currently assigned intervening milestone.
- **Blocking TBD:** Exact precedence against notification Phase 13 has **not** been approved; review sequencing before starting.

### 12.2 — Implement and test local recurrence scheduling
- **Delivery:** Local schedule persistence and location inclusion evaluation only; background location tracking is not implied.
- **Tests:** second-Monday patterns, week boundaries, fortnight cadence, DST/timezones, inactive/nonmatching visibility, edits/restarts, multi-city overview.
- **Dependencies:** 12.1.

## Phase 13 — Notifications (late; slot order with Phase 12 TBD)

### 13.1 — Approve notification value, timing, data and consent
- **Decision gate:** Notifications are post-release and may be late. Decide specific triggers, opt-in, what to show when data is stale/missing, whether they apply to item/location/day and handling of scheduled cities. Never assume background GPS, automatic push, server or hidden refresh capability.
- **Dependencies:** Core released recommendation/caching system; revisit whether Phase 12 schedules must precede notifications.

### 13.2 — Implement and test approved notifications
- **Delivery:** Implement only approved notification behavior and permission/cancellation flow; reuse app recommendation safety contract.
- **Tests:** denial, opt-out, duplicate prevention, no-data/stale forecast, timezone changes, app relaunch and real device.
- **Dependencies:** 13.1 and any specifically approved schedule integration.

## Phase 14 — Later item properties, photos and settings check

### 14.1 — Review useful details and photos
- **Decision/evaluation gate:** Revisit whether a user-created item needs details (e.g., material) or photos, and whether a settings screen is now warranted by actual approved features. The user prefers to keep items minimal for a long time; there is **no approval to implement a photo library or broad settings screen automatically**.
- **Dependencies:** Phases 8–10 are mature.

### 14.2 — Implement only features approved in 14.1
- **Conditional delivery:** Small, local-first item-properties and/or photo support or coherent feature-specific settings as approved; otherwise close the evaluation without implementing unnecessary controls.
- **Tests:** migration/storage/permissions/privacy/accessibility as applicable.

## Phase 15 — Advanced recommendation rules and flexible forecast horizons

### 15.1 — Approve advanced scope
- **Decision gate:** Choose whether/how to implement more complex user rules/rulesets, additional item-specific weather factors, and flexible forecast periods. Forecast-horizon improvements may have separate subdeliveries within this phase. Do not change jacket wind/fog/rain behavior without approval.
- **Dependencies:** Phases 9 and 11; later refinements to engine only as warranted.

### 15.2 — Implement and validate approved advanced capabilities
- **Conditional delivery:** Build only chosen rule/horizon capabilities, preserving deterministic core tests, data-provider independence, safe incomplete weather and item-specific semantics.
- **Tests:** complex rule precedence/validation, horizons/timezones/provenance and user-controlled overrides, plus regression for all previously supported items.

## Phase 16 — Evaluate wider personal preferences

### 16.1 — Decide whether personal preferences beyond per-item thresholds are useful
- **Decision/evaluation gate:** Identify actual need for cross-item preferences, using Phase 9 behavior as a baseline. If no added value, document the evaluated decision; **do not build features by assumption**.
- **Dependencies:** Phase 9 and real usage of item customization.

### 16.2 — Deliver only approved preference functionality, if any
- **Conditional delivery:** Define UX, local persistence, interaction with per-item overrides and tests only after approval; otherwise phase closes with explicit no-build outcome.

## Phase 17 — User-facing recommendation history (late)

### 17.1 — Approve history scope, privacy and retention
- **Decision gate:** Define which past recommendations are useful to users, per item/location, and appropriate time/retention. Distinguish this from the current last-20-event **diagnostic** log.

### 17.2 — Implement, test and validate approved history
- **Delivery:** Local-first user-facing history with accurate provenance, deletion/privacy and persistence behavior; no account requirement.

## Phase 18 — Accounts and synchronization (very late)

### 18.1 — Approve sync/account model
- **Decision gate:** Consider optionality, synced entities, privacy/auth/data storage and conflicts only after locally functioning items, thresholds and saved-city features are mature.

### 18.2 — Implement and validate if approved
- **Delivery:** Account/sync infrastructure meeting the agreed requirements without breaking existing offline/local behavior; migration and multi-device reconciliation tested.

## Phase 19 — Android (much later, after iOS matures)

### 19.1 — Agree Android product and technical approach
- **Decision gate:** Determine parity priorities and implementation strategy while preserving high-quality native iOS code; Android is explicitly a later goal, not a first-release workstream.

### 19.2 — Implement and validate approved Android scope
- **Delivery:** Android product matching approved scope and accuracy/privacy/UX expectations, with suitable device tests and a separate release gate.

## Milestones and smallest next action

1. **Foundation gate (historical):** 0.1–0.9 complete according to `TODO.md`.
2. **Live real-iPhone first slice (historical):** 1.4 complete according to `TODO.md`.
3. **Daily intelligence, fog and diagnostics (historical):** 2.9 complete according to `TODO.md`.
4. **Current next work:** Phase 3 is closed. Phase 4 begins with 4.1, the user-approval gate for the predefined item list, item-specific rules and multi-item UX.
5. **Pre-release multi-item gate:** 4.4 — approved predefined items built, tested and run on device.
6. **Pre-release widget gate:** 5.3 — approved widget(s) tested with honest stale/no-data states.
7. **First-release validation gate:** 6.4 — regressions, weather scenarios and devices including new items and widget.
8. **First public release gate:** 7.6 — TestFlight, submission, accepted build and actual release.
9. **Approved early post-release sequence:** Phase 8 custom items → Phase 9 thresholds → Phase 10 multi-city overview. Phase 11 modest forecast lookahead is the **assigned provisional next slot**, not an additional approved priority decision.
10. **Later slots (relative placement provisional):** Phases 12–19 cover scheduling, notifications, item details/photos evaluation, advanced rules/horizons, preference evaluation, history, accounts and Android. **Phase 12 vs 13 priority is not user-approved.**

**Handoff to OpenCode:** First read `docs/PROJECT.md`, `docs/DECISIONS.md`, `docs/ROADMAP.md`, `docs/IMPLEMENTATION_PLAN.md`, `docs/TODO.md`, `docs/PRODUCT_SPEC.md`, `docs/WEATHER_LOGIC.md`, `docs/TECH_SPEC.md`, `docs/UX.md`, `docs/AI_RULES.md` and `docs/IMPLEMENTED_RULES_FLOWCHARTS.md`. Treat phase gates marked TBD as decisions to ask the user about at execution time. Do not mark current subphases complete without code/tests/device evidence. No source code has been modified as part of this documentation update.
