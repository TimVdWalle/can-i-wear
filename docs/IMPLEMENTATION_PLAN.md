# Can I Wear — V1 Implementation Plan

> Status: ACTIVE — proposed execution breakdown; not new product decisions
> Last updated: 2026-10-09
> Source of truth: execution detail subordinate to the existing truth files

## Authority and execution rules

This plan expands [ROADMAP.md](ROADMAP.md) without changing its phases or strategy. Resolve conflicts using the hierarchy in [PROJECT.md](PROJECT.md): approved decisions, product specification, technical specification, weather logic, UX, then roadmap/execution detail. [DECISIONS.md](DECISIONS.md) remains authoritative for approved decisions. Follow [AI_RULES.md](AI_RULES.md).

Each numbered subphase is a separate implementation/review unit. Complete its acceptance criteria and required validation before marking it done in [TODO.md](TODO.md). Dependencies mean completed subphases unless explicitly described as evidence-gathering that may run earlier. A decision subphase is complete only when the user has approved the material choices and the affected truth files have been updated; this plan does not approve them.

Work stays within the leather-jacket V1. No personal settings, accounts, other clothing, wardrobe, history, Android, background tracking, opaque ML, widgets or notifications are included in implementation scope here. Widgets/notifications remain follow-up scope decisions, not prerequisites for shipping the current core V1.

Keep a single app target and the existing test targets unless an approved requirement needs more. Component separation does not require packages, a dependency-injection framework, a generic rules framework, or a backend. Names and paths below are likely implementation locations, not a mandated file layout. New Swift files would live under `Can I Wear/`, unit tests under `Can I WearTests/`, and UI tests under `Can I WearUITests/`.

All product thresholds, freshness windows, grouping parameters, location accuracy requirements and behavior-affecting timeouts belong in a concentrated configuration area. Only the approved temperature boundaries (15°C and 20°C) are fixed today. Explicit test inputs may exercise candidate values without making those values production defaults.

## Current baseline

- **Verified complete:** native Swift/SwiftUI project scaffold, app entry point, placeholder `ContentView`, unit/UI test targets, asset catalog placeholders.
- **Configured, not approved release decisions:** deployment target iOS 26.2, bundle ID `mobi.vandewalle.Can-I-Wear`, automatic signing/team, iPhone and iPad targeting. Do not infer approval from generated project settings.
- **Not verified:** successful build/test run, signing on a real iPhone, live location/weather, meaningful automated tests, or performance.
- **Not implemented:** provider interfaces, normalized weather model, WeatherKit adapter/capability, location permission description/provider, centralized rules, decision/period engines, cache, and recommendation UI.

## Decision tracking

These identifiers originated as implementation-blocking TBDs. Their current resolution status is authoritative only when recorded in `DECISIONS.md` and `TODO.md`; this table tracks the topic and where it is needed.

| ID | Decision topic/status | Needed by |
| --- | --- | --- |
| T-01 | Measurable “few drops” tolerance; precipitation amount/type/probability interpretation and normal/heavy rain classification | 0.7, 1.1 |
| T-02 | Actual versus apparent temperature selection/weighting, including unavailable selected input | 0.7, 1.1 |
| T-03 | Relevant local-day evaluation window, first-slice whole-day summary policy, and incomplete hourly coverage behavior. These are details not specified by the truth files. | 0.7, 1.2, 2.1 |
| T-04 | Minimum meaningful period duration, material-change/grouping rules, and conservative noise-consolidation parameters | 0.8, 2.2–2.3 |
| T-05 | Weather cache freshness/reliability, expiry behavior, and matching cached forecasts to location | 0.9, 2.5–2.6 |
| T-06 | Location accuracy and freshness, safe reuse, and behavior-affecting acquisition/request timeout values | 0.5, 0.9, 2.4 |
| T-07 | Minimum supported iOS version; current iOS 26.2 setting is not an approved product decision | 0.2, 0.3, 6.5 |
| T-08 | Final bundle identifiers; whether the current identifier can be used for development/provider setup before finalization | 0.2, 0.6, 6.1 |
| T-09 | Analytics/telemetry policy, including whether any collection is allowed | 6.1, 6.3; before any instrumentation that collects data |
| T-10 | Exact recommendation/caution labels, reason copy, semantic palette and final layout | Basic proposal in 1.3; final decisions in 3.1 |
| T-11 | Loading presentation, no-location/no-weather/stale-data wording, permission-denied UX and accessibility details | Basic proposal in 1.3; final decisions in 3.1–3.4 |
| T-12 | Exact V1 inclusion/timing/scope for widget and notifications | Widget: 4.1. Notifications remain follow-up scope |
| T-13 | **Resolved in D-029:** use only an explicit provider fog/mist forecast condition; Open-Meteo WMO codes 45/48 produce Avoid. Do not infer from humidity, dew point or visibility. | 2.8 |

No row is resolved by creating this plan. Record approved material choices in `DECISIONS.md` and affected specifications before implementing them. When a blocker covers only part of a subphase, independent evidence gathering or contract work may proceed, but the subphase cannot be marked complete with invented defaults.

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
- **Acceptance criteria:** T-07 is approved; T-08 either finalized or explicitly permits a development identifier with finalization still tracked in 5.1.
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

## Phase 3 — V1 polish

Goal: remove measured/user-visible friction without adding features.

### 3.1 — Approve final V1 presentation details

- **Type:** Product/UX decision.
- **Objective:** Settle the existing screen and state design.
- **Exact scope:** Review concrete result/period/loading/error and enabled-debug examples; obtain approval for exact labels/caution wording, short reasons, semantic palette, layout, permission/stale copy and accessibility behavior. Preserve recommendation-first hierarchy and meaning without color alone; diagnostics remain visually subordinate and absent when disabled.
- **Likely files/components:** `UX.md`, `DECISIONS.md` where material, `TODO.md`, proposed SwiftUI previews/mockups.
- **Acceptance criteria:** T-10/T-11 are resolved for all existing states; no settings/features are added; approved designs are reviewable before implementation.
- **Tests/validation:** Review dry/rain/fog/caution/heat/period/error and enabled-debug examples, large-text and non-color interpretation.
- **Dependencies:** 2.9.
- **Non-goals:** New screens/features, final icon/marketing assets, notification/widget design.
- **Blocking TBDs:** T-10, T-11.

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

## Phase 4 — iOS widget

Goal: add an approved, glanceable widget without duplicating recommendation logic.

### 4.1 — Approve widget scope and refresh behavior

- **Type:** Product/UX decision.
- **Objective:** Define the widget’s supported content, freshness, stale-data and interaction behavior.
- **Exact scope:** Approve widget states, refresh policy, privacy treatment and accessibility expectations; reuse the app’s recommendation/cache contracts.
- **Acceptance criteria:** Widget scope is recorded in the truth files and does not introduce personal settings, background location or new recommendation rules.
- **Dependencies:** 3.5.
- **Blocking TBDs:** T-12.

### 4.2 — Implement and validate the iOS widget

- **Type:** Extension implementation, testing and device validation.
- **Objective:** Show the current approved recommendation and safe fallback state at a glance.
- **Exact scope:** Implement the approved widget, shared data handoff, refresh behavior, stale/no-data states and accessibility; keep widget refresh independent of continuous location tracking.
- **Acceptance criteria:** The widget reflects the app’s deterministic result, never fabricates stale confidence, and works on the approved device/OS matrix.
- **Dependencies:** 4.1, 3.5.
- **Non-goals:** Notifications, new clothing types, personal settings or separate recommendation logic.

## Phase 5 — V1 validation

Goal: prove existing V1 behavior under real conditions. Record actual results; tests are not complete merely because a checklist exists. Correct failures in focused changes to the responsible component, then rerun affected checks. Changes to approved policies go through the truth-file decision process.

### 5.1 — Complete the deterministic regression matrix

- **Type:** Testing.
- **Objective:** Close gaps in core rules, periods and failure/fallback coverage.
- **Exact scope:** Audit and supplement existing tests against `WEATHER_LOGIC.md` and `TODO.md`; cover all boundaries, rain/temperature combinations, daily timing, noise, missing inputs and cache validity without live services.
- **Likely files/components:** Existing unit/integration test targets and fixture helpers; `TODO.md` evidence.
- **Acceptance criteria:** Every required core scenario maps to a meaningful passing test; expected outcomes reflect approved rules; test runs need no GPS/network/live weather/time.
- **Tests/validation:** Full deterministic suite plus focused UI state tests; review assertions for behavior rather than implementation mirroring.
- **Dependencies:** 3.5, 2.9.
- **Non-goals:** Arbitrary coverage target, giant generated suite, duplicate tests without added behavioral value.
- **Blocking TBDs:** None after prerequisite decisions; uncovered ambiguity is surfaced for approval.

### 5.2 — Validate weather behavior across real conditions

- **Type:** Real-device/provider validation.
- **Objective:** Assess whether live forecasts support trustworthy jacket protection.
- **Exact scope:** Check multiple locations and observed dry, drizzle, normal/heavy rain, warm/cool, morning-only and later-day rain, and changing forecasts; compare live normalized inputs and recommendations with observed conditions. Review the active provider's accuracy, rain resolution, speed, reliability, cost and deployment experience.
- **Likely files/components:** Active weather adapter, rules/config/period engine, `TODO.md` validation evidence; affected truth files only for approved tuning.
- **Acceptance criteria:** Observed scenarios and discrepancies are recorded honestly; mapping/logic defects are fixed; provider limitations and unresolved safety issues are visible. Unobserved conditions remain pending rather than fabricated; fixtures supplement field evidence.
- **Tests/validation:** Real-phone observations, deterministic replay where useful, targeted regression tests for discoveries. If provider suitability fails, propose a decision review rather than silently switch providers.
- **Dependencies:** 1.4, 2.9, 3.5; provider observation can begin in 0.6 and accumulate earlier.
- **Non-goals:** Guaranteeing forecasts, automatic rule tuning, additional providers without approval, location-history collection.
- **Blocking TBDs:** None after prerequisites; field weather/location availability may limit completion evidence.

### 5.3 — Validate degraded operation and recovery

- **Type:** Integration testing and real-device validation.
- **Objective:** Prove failures do not produce unsafe confidence or frustrating loops.
- **Exact scope:** Exercise weak/no network, denied/disabled/unavailable location, timeout, missing forecast, recent/stale/wrong-location cache, app relaunch and subsequent forecast changes using fixtures and device controls.
- **Likely files/components:** Providers, caches, presentation, integration/UI tests, `TODO.md` evidence.
- **Acceptance criteria:** Approved fallback/expiry behavior holds on device; useful recent data remains clearly represented; unusable data never yields a confident answer; recovery updates the visible result without repeated prompts/request loops.
- **Tests/validation:** Device offline/slow-network and permission checks; deterministic failure injection for cases live services cannot reliably reproduce; regression tests for fixes.
- **Dependencies:** 3.5, 5.1.
- **Non-goals:** Background delivery, manual cities, adding offline forecast products.
- **Blocking TBDs:** None after prerequisites.

### 5.4 — Validate supported devices and close the V1 quality gate

- **Type:** Real-device validation and release-quality review.
- **Objective:** Confirm reliable operation beyond one successful demo.
- **Exact scope:** Test multiple real iPhones across approved OS/device support; recheck launch, permissions, relaunch, UI/accessibility, network performance and battery/location lifecycle; consolidate evidence and remaining defects.
- **Likely files/components:** Existing app/tests, project deployment settings, `TODO.md` quality evidence.
- **Acceptance criteria:** Core scenarios pass on the recorded device/OS matrix; no unresolved defect undermines trustworthy recommendations, required accessibility or reliable operation; performance claims have measurements; no continuous/background location tracking.
- **Tests/validation:** Real-device matrix, local profiling where needed, full automated suite after necessary fixes; document unavailable matrix coverage explicitly.
- **Dependencies:** 5.1–5.3, 3.3–3.5, approved T-07.
- **Non-goals:** Declaring App Store submission complete, expanding platform support, invented performance numbers.
- **Blocking TBDs:** None after prerequisites; access to multiple devices is an external prerequisite.

## Phase 6 — Store readiness

Goal: deliver the validated V1 through TestFlight and the App Store. Verify current Apple/provider requirements when executing these subphases; this plan does not assume a frozen submission checklist. Store/account artifacts are likely involved, but this documentation task does not authorize uploads, submissions or release actions now.

### 6.1 — Finalize release identity and telemetry policy

- **Type:** Product/technical decision and App Store readiness.
- **Objective:** Lock the remaining identity/privacy choices before distribution setup.
- **Exact scope:** Approve final bundle identifiers and reconcile approved OS support; decide telemetry explicitly and reflect its privacy consequences. No telemetry collection may be added while policy is TBD.
- **Likely files/components:** `DECISIONS.md`, `TECH_SPEC.md`, `TODO.md`; eventual project identifiers and App Store Connect identity.
- **Acceptance criteria:** T-08/T-09 are resolved; configured release identity/support matches approved decisions; telemetry approval does not implicitly approve a new SDK/integration.
- **Tests/validation:** Review identity/signing/service implications and actual data flows; build recheck after any approved identifier change.
- **Dependencies:** 0.2, 5.4. Final identity may be decided earlier when necessary for provisioning.
- **Non-goals:** Accounts, sync, adding analytics merely because it is common, changing the locked app name.
- **Blocking TBDs:** Remaining T-08, T-09.

### 6.2 — Prepare the app icon and listing metadata

- **Type:** App Store readiness and asset implementation.
- **Objective:** Replace release placeholders and accurately describe V1.
- **Exact scope:** Produce/review an icon for Can I Wear, populate the asset catalog, and prepare required listing text/metadata for the existing leather-jacket product.
- **Likely files/components:** `Assets.xcassets/AppIcon.appiconset`, listing text/assets, App Store Connect draft fields.
- **Acceptance criteria:** Approved icon meets requirements verified at execution; listing accurately describes rain-first daily recommendations without unsupported guarantees/features; no icon placeholder remains.
- **Tests/validation:** Icon inspection on device/appearance variants as required; metadata review against actual shipped scope.
- **Dependencies:** 3.5, 5.1.
- **Non-goals:** Renaming, broad branding project, advertising new features.
- **Blocking TBDs:** Icon/metadata designs require review; exact release asset details are not specified by truth files and are not selected here.

### 6.3 — Prepare privacy and provider-compliance material

- **Type:** App Store readiness and verification.
- **Objective:** Make release declarations match actual app behavior.
- **Exact scope:** Review current Apple privacy/submission requirements and the selected production provider's attribution/licensing requirements; prepare privacy information/policy/support material as required, verify purpose descriptions and provider attribution, and reflect approved telemetry/data handling accurately.
- **Likely files/components:** App permission configuration, attribution UI, privacy/support artifacts and listing fields; `TECH_SPEC.md`/`TODO.md` evidence.
- **Acceptance criteria:** Required disclosures and attribution are accurate and complete; no unexpected location history or undeclared collection exists; release materials match approved policy and tested implementation.
- **Tests/validation:** Inspect real data flows/configuration and installed attribution/purpose text; check current authoritative requirements at execution rather than inventing obligations now.
- **Dependencies:** 5.1, 0.6, 3.5.
- **Non-goals:** Adding collection, legal boilerplate unrelated to actual behavior, account infrastructure.
- **Blocking TBDs:** None after T-09 approval; required release contact/support/privacy artifact details need completion/review when preparing materials.

### 6.4 — Capture App Store screenshots

- **Type:** App Store readiness and visual validation.
- **Objective:** Show the final V1 experience accurately.
- **Exact scope:** Capture required supported screenshot sizes from final UI using reviewable weather scenarios; prepare approved captions/assets if needed. Fixtures may stage screenshots but do not replace live validation.
- **Likely files/components:** Final app, deterministic preview/UI fixtures, screenshot artifacts, App Store Connect draft assets.
- **Acceptance criteria:** Screenshots match shipped UI, show recommendation/period meaning clearly, and meet currently required sizes; no unfinished states or out-of-scope claims.
- **Tests/validation:** Inspect every screenshot for truncation/layout errors and consistency with current build/scope.
- **Dependencies:** 3.5, 5.2.
- **Non-goals:** Product redesign, new marketing features, changing recommendation logic for screenshots.
- **Blocking TBDs:** Screenshot/caption selections require review; no final UI details are chosen here.

### 6.5 — Validate a distribution build through TestFlight

- **Type:** App Store readiness, testing and real-device validation.
- **Objective:** Prove the packaged app works with production distribution settings.
- **Exact scope:** Prepare signed archive/versioning, run distribution checks, upload through the authorized release workflow, install through TestFlight, and test the core flow plus permissions/fallback. Address release-only defects with focused fixes.
- **Likely files/components:** Xcode signing/release settings, existing targets/assets, App Store Connect/TestFlight, `TODO.md` evidence.
- **Acceptance criteria:** Distribution archive validates and TestFlight installs; live location/weather/recommendation works on a real iPhone; required privacy/assets are present; release-only issues are resolved with appropriate regressions.
- **Tests/validation:** Automated suite, archive validation, TestFlight cold launch/live flow/denial/offline/relaunch/accessibility smoke tests on approved support.
- **Dependencies:** 5.4, 6.1–6.3; 6.4 is required before the later submission gate, not to start TestFlight.
- **Non-goals:** Public release, inviting others or uploading without the applicable task authorization, adding beta-only product features.
- **Blocking TBDs:** None after prerequisites; account/distribution access and release-action authorization are external prerequisites.

### 6.6 — Prepare review, submit and release V1

- **Type:** App Store readiness and release validation.
- **Objective:** Complete the roadmap's shipping requirement.
- **Exact scope:** Review final listing/privacy/screenshots/build, prepare review notes explaining permissions and weather dependency, submit through the authorized release workflow, handle review issues, and release the approved build.
- **Likely files/components:** App Store Connect listing/review/release fields, distribution build, `TODO.md` final evidence; narrow source/docs fixes only if required and approved by scope.
- **Acceptance criteria:** Review materials are complete, validated build is accepted and V1 is released; status distinguishes prepared/submitted/accepted/released rather than marking all complete at upload.
- **Tests/validation:** Final release-candidate smoke check; targeted regressions and renewed distribution check after review-driven changes; verify published listing/build after release.
- **Dependencies:** 6.4, 6.5 and all Phase 6 material complete.
- **Non-goals:** V2 scope, feature additions to appease hypothetical review concerns, submission/release without applicable authorization.
- **Blocking TBDs:** Release timing/method and review material must be confirmed when executing the release task; Store review outcome is external, not a locally completed test.

## Milestones and smallest next action

1. **Foundation gate:** 0.1–0.9. Scaffold exists; device/provider/decision readiness still needs evidence and approvals.
2. **First major product milestone:** 1.4, the full live real-iPhone vertical slice.
3. **Daily-intelligence and diagnostics gate:** 2.9, meaningful periods, trustworthy fallback, fog/mist protection and opt-in local diagnostics.
4. **Polish gate:** 3.5, approved presentation, accessible states and measured friction fixes.
5. **Widget gate:** 4.2, approved and validated widget.
6. **Validation gate:** 5.4, regression coverage and real-condition/device evidence.
7. **Shipping gate:** 6.6, accepted and released V1.

The next review unit is **3.1**, the explicit approval review for final V1 presentation details. Subphase 2.9 is complete with the packaged Apple Settings switch, local bounded diagnostics, cache/fetch/evaluation explanations, place and copy behavior, diagnostic-only wind, deterministic coverage and a connected-iPhone Settings-to-app walkthrough. Unresolved product choices must remain explicit.
