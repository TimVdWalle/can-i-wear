# Can I Wear — TODO

> Status: ACTIVE
> Last updated: 2026-10-19
> Source of truth: YES

This is an execution list, not a source of product decisions.

Observed defects and their investigation/verification state are tracked in [ISSUES.md](ISSUES.md). Keep roadmap/subphase work here and avoid duplicating the live issue ledger.

The numbered review units and acceptance criteria are in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md). Complete a subphase only after its decision blockers, tests and required device validation are satisfied. Keep results and outstanding checks here; approved behavior lives in the specifications and decisions.

## Current focus

- **Phase 3 is complete** by user acceptance on 2026-10-18. Validation items without recorded results are retained under [Unphased follow-up](#unphased-follow-up), not represented as passed.
- **Next product gate:** Phase 4.1 is partially decided by D-058/D-060/D-062/**D-063–D-067**. Algorithms, useful-hour minimum, launch assignments and missing-input/gap handling are locked. D-067 adds first-launch item selection, header-gear configuration, single-/multi-item Home routing and a resettable setup flag; **current review: visual prototypes in `docs/prototypes/item-selection/`**, not app implementation. Other unsupported condition/precipitation cases, non-jacket period consolidation and concrete presentation cases still need resolution; provider normalization must support approved signals. Exact user-facing group labels/configuration explanation are deferred to 8.1, not Phase 4 blockers. Widget form/refresh is still open at 5.1. Phases 6–7 are validation and release gates; Phases 8–19 are pending, with their scope in [ROADMAP.md](ROADMAP.md).
- **Other release blockers:** production weather provider/terms, final bundle identity and telemetry/privacy policy remain undecided. Do not infer approval from a planned phase; see the open decisions below and 7.1/7.3.

## Subphase status

### Phase 0 — Decisions & technical foundation

- [x] 0.1 Record the existing scaffold — verified by source inspection; build/device behavior is not verified
- [x] 0.2 Confirm development platform and identity — iOS 26.2+ and development bundle ID approved
- [x] 0.3 Establish a real-iPhone development baseline — signed scaffold launched on iPhone 13 running iOS 26.6.2; focused test harness also runs on device
- [x] 0.4 Define normalized contracts and fixture harness — app-owned contracts and deterministic fixtures; 3 focused tests pass on iPhone
- [x] 0.5 Implement one-time location acquisition — policy, provider, permission description and 5 focused tests complete; allowed live fix and denied-permission behavior verified on iPhone 13/iOS 26.6.2
- [x] 0.6 Implement and probe the weather adapter — Open-Meteo request/normalization/error tests and the complete focused suite pass on iPhone 13/iOS 26.6.2; a live current-location forecast returned required normalized hourly fields. WeatherKit is deferred until a paid team is available
- [x] 0.7 Approve first-slice recommendation policies — three-level rain/temperature rules, remaining-day/worst-result summary, and conservative single-gap handling approved in D-023/D-024
- [x] 0.8 Approve dynamic-period parameters — 3-hour normal periods, 2-hour isolated Avoid expansion, safer-blip absorption and conservative noisy-span consolidation approved in D-026
- [x] 0.9 Approve freshness and safe-reuse policies — original policy approved in D-027; weather timing is superseded by D-031’s 15-minute refresh and inclusive 90-minute usable limit, while 30-minute location reuse, 5 km forecast matching and the 10-second weather timeout remain

### Phase 1 — First real-device vertical slice

- [x] 1.1 Implement centralized hourly jacket rules — centralized three-level engine and 8 focused boundary/validity/precedence tests pass on iPhone 13/iOS 26.6.2
- [x] 1.2 Implement the basic daily summary — remaining-local-day summary, most-protective result selection, and conservative gap handling implemented; 9 focused tests pass on iPhone 13/iOS 26.6.2
- [x] 1.3 Connect providers to a basic result screen — approved basic presentation, automatic provider flow, explicit failures/retry, attribution and 4 focused presentation tests complete; live screen smoke check passed on iPhone
- [x] 1.4 Prove the complete vertical slice on a real iPhone — live location → Open-Meteo → daily recommendation displayed Wear; relaunch, integrated denied-location, live offline failure and retry recovery all passed on iPhone 13/iOS 26.6.2. A privacy-safe warm timing probe measured 0.007 s location, 0.030 s weather and 0.038 s provider-to-result total

### Phase 2 — V1 daily intelligence

- [x] 2.1 Expose per-hour daily evaluation — ordered remaining-day classifications retain timestamps, timezone and conservative inferred gaps; DST and ordering fixtures pass
- [x] 2.2 Group contiguous meaningful periods — ordered, non-overlapping period output and stable/change fixtures implemented
- [x] 2.3 Consolidate noisy forecasts conservatively — D-026 duration, isolated Avoid expansion, safer-gap absorption and alternating-span rules centralized and tested
- [x] 2.4 Add recent-location reuse — latest-only persistent cache applies the inclusive 30-minute and accepted-accuracy policy without location history
- [x] 2.5 Add weather cache and validity checks — normalized persistent cache enforces the inclusive 90-minute usable limit, current-day coverage and 5 km matching
- [x] 2.6 Present daily periods and integrate safe fallback — period ranges/reasons, age-labeled saved results, D-031 status/locality and guarded pull-to-refresh, 15-minute conditional refresh, no-concurrency/30-second failure cooldown, replacement/fallback, explicit approved expired-forecast state and 10-second timeout integrated and tested
- [x] 2.7 Review daily-intelligence completeness — accepted complete after review of 57 deterministic passing tests, rendered Phase 2 UI scenarios, signed app installation/launch/relaunch and live recommendation evidence; unavailable natural split-weather and additional manual cache/offline observations remain useful later validation rather than a Phase 2 blocker
- [x] 2.8 Add fog and mist protection — normalized explicit fog/mist condition, Open-Meteo WMO 45/48 and WeatherKit fog mapping, Avoid precedence, cache compatibility, periods and approved temporary **“Fog is expected.”** presentation implemented; provider/domain/cache/presentation tests and focused UI test pass on connected iPhone 13, and a live Open-Meteo payload confirmed hourly `weather_code`
- [x] 2.9 Add opt-in local debug diagnostics — off-by-default Apple Settings toggle and active-state refresh, dismissible local report, structured/persisted 20-event bound with disable clearing, cache/fetch/error timing and reasons, asynchronous place lookup, hourly inputs/decisions/periods, diagnostic-only wind and privacy-labeled copy action implemented; its original 74-unit/9-UI-test connected-iPhone validation remains recorded

Historical note: the first plan was written before implementation. The completed Phase 0–2 checkboxes above retain the real-device and test evidence. This documentation-only update did not run Swift code, build, validate a device or perform release actions.

### Phase 3 — Core UI polish

- [x] 3.1 Approve final V1 presentation details — D-046/D-047–D-057 establish the approved single-item Home Screen and presentation behavior; Phase 3 closed by user acceptance on 2026-10-18
- [x] 3.1.1 Clarify the Home Screen for first-time users — D-047–D-053 Guided/Compact implementation, synchronized explanation settings, physical-device Settings persistence, consistent daypart statuses and simulator automation complete; unrecorded individual validation results are listed under Unphased follow-up
- [x] 3.2 Polish permissions and recovery states — approved failure states, retry and recovery behavior covered by the existing automated checks and Phase 0.5/1.4 device evidence; on 2026-10-18 the user confirmed that restoring While Using the App access (Exact Location on) returned to the recommendation, and force-close/relaunch returned to the recommendation without another permission prompt on the paired iPhone 13. The user had previously validated the denied-location state; the optional repeat was skipped. Any walkthrough without a recorded result is in Unphased follow-up.
- [x] 3.3 Measure and remove startup/request friction — implementation and available startup evidence recorded below; any measurement without a specific recorded result is in Unphased follow-up
- [x] 3.4 Implement and verify accessibility — scalable layouts, non-color cues and VoiceOver descriptions implemented; any manual check without a recorded result is in Unphased follow-up
- [x] 3.5 Finish visual and transition polish — approved hero, bundled jacket illustration, horizontal dynamic periods and hourly segments implemented; any check without a recorded result is in Unphased follow-up

**Phase 3 closure (2026-10-18):** Closed by user direction. This records phase acceptance, not a claim that every individual manual or performance check passed. Checks lacking specific results have been moved to Unphased follow-up and remain open.

#### D-046 Home Screen implementation — 2026-10-14

- Implemented `HomePresentation.swift` and focused SwiftUI components in `HomeComponents.swift`; `ContentView` retains lifecycle refresh, retries, the approved no-status-line Home presentation (D-057), attribution and diagnostics. `RecommendationViewModel` carries raw evaluated hours through live, refreshing and fallback presentations from the existing evaluation pass.
- The hero uses the existing most-protective daily answer and reason precedence. Period cards retain the unchanged consolidation engine, with exact local ranges. Raw hourly segments distinguish inferred gaps and explain differences from period advice. No weather thresholds, provider/cache policy or future feature gates changed.
- New deterministic coverage includes status mapping, summary precedence, raw-versus-consolidated output, one/two/four/six periods, missing data, remaining-day timestamps and both DST transitions. Updated integration assertions cover hourly delivery without additional requests and preservation during refresh. UI coverage includes recommendation semantics, loading/failures, diagnostics and largest-text scrolling.
- Validation resumed after the interrupted run: **90 unit/integration tests passed in 11 suites on iPhone 16e simulator (iOS 26.3.1)**. Four focused Home Screen simulator UI tests pass, covering mixed/single/variable periods, largest-text scrolling and no fabricated recommendation in loading/failure states. The existing Settings-to-app diagnostics-toggle test also passes after making its Settings navigation resilient to duplicate app/test-runner rows. The signed build and **3 focused Home Screen UI tests passed on iPhone 13 / iOS 26.6.2**, including mixed/single periods and largest-text vertical/horizontal scrolling; the final mixed-layout rerun also passes. Final device screenshots were reviewed, including the corrected unbroken CAUTION badge and status-first accessibility layout. The interrupted aggregate run is not counted as passed; its two failures were each rerun successfully after focused fixes.
- Phase 3 implementation and automated/device evidence are recorded above. Individual manual/performance checks without specific results are tracked under Unphased follow-up; no result is inferred from their transfer.

#### D-047 Guided/Compact Home implementation — 2026-10-18

- Added `HomePresentationMode.guided` and `.compact`, with Guided as the default. D-048 exposes a default-on **Guided Home** switch under **Home Screen** in Apple system Settings; turning it off selects Compact and also turns off Show How It Works. D-049/D-051 add the concise **Show How It Works** card; enabling it also enables Guided, while **Got it** turns off only the card. D-051 limits the item-neutral purpose line to guidance, removes the hero question and redundant Good/Maybe/Skip sentence, and tightens the iPhone 13 primary layout. Guided adds **When can I wear it?** context.
- Updated short reasons and accessibility output without changing weather thresholds, most-protective daily aggregation, daypart calculation, caching or provider behavior. Corrected container test identifiers so individual dayparts and hours remain independently addressable by assistive UI automation.
- The complete 11-suite unit/integration target passes on iPhone 17 simulator (iOS 26.3.1). Guided dismissal/relaunch/reset, Compact omission, mixed dayparts, non-color semantics and updated large-text/attribution checks pass in focused UI runs. In the complete 18-test UI run, the other 16 tests passed; the two failures were outdated test assumptions and both corrected tests pass on focused rerun. Any remaining real-phone visual and VoiceOver checks without recorded results are listed under Unphased follow-up.
- D-053 replaces the two stale presentation preference identifiers with canonical keys, explicit Boolean switch values and one-time migration of existing choices. Manual preference-domain verification on iPhone 13 confirmed that Apple Settings changed Guided Home from `1` to `0` while Can I Wear was terminated, and that launching Can I Wear preserved `0`. This closes the physical Settings persistence defect; final visual and assistive-technology acceptance remains open.

## Unphased follow-up

These checks have no phase assignment and no specific result recorded here. They remain open follow-up, not Phase 3 blockers or completed validations:

- [ ] Record outcomes for manual VoiceOver navigation/pronunciation, Increase Contrast/Differentiate Without Color, and Reduce Motion checks on a real iPhone.
- [ ] Record outcomes for live location/weather, pull-to-refresh, and failure/recovery walkthroughs using the final Home Screen.
- [ ] Record a permitted live-refresh duration and cold location-acquisition timing; the recorded 2026-10-18 cold relaunch used cached location and skipped weather refresh.
- [ ] Record slow-network and loading/result/failure transition observations.

### Phase 4 — Predefined multi-item support (before public release)

- D-060 records the approved explicit daily-verdict + timing approach and supersedes D-059's group wording. The presentation contract/examples and acceptance cases are in `UX.md`; exact group naming/configuration is deferred to Phase 8.1. Actual remaining item policies are still open. Documentation only; no app implementation or test run. Explicit user permission is required before beginning implementation.
- D-061 records “Can I wear items” / “Should I wear items” as internal working labels only, not user-facing copy or approval of catalog assignments/conflict policies.
- D-062 records approved Raincoat/Sunglasses hourly conditions and optional-input fallback (documentation updated 2026-10-19). Read-only inspection found existing rain/showers/wind requests but no retained distinct liquid-rain/daylight/sky/UV fields in the normalized model. Open-Meteo documentation confirms rain/wind/sky/daylight variables; a live Brussels-coordinate sample returned hourly `is_day`, `cloud_cover` and `uv_index`. This verifies that sample's data availability, not app integration, global/provider reliability or production approval. No app code, build or test run from this work.
- **D-063 (2026-10-19):** User reconfirmed and locked the two shared daily aggregation behaviors behind those internal labels. Updated the authoritative decision, owning specifications, gates and agent entry/routing rules so this is not asked again as an open distinction. Full contract/examples are in `WEATHER_LOGIC.md`; catalog assignments were still open at this point and subsequently resolved by D-065, while genuine input/grouping/presentation gaps remain open. Reviewed the documentation diff and searched for contradictory open-policy wording. `bash scripts/verify.sh docs` passed; evidence: `.build/verification/docs.YBSZtv/`. No app code, build, simulator or device run is claimed.
- **D-064 (2026-10-19):** User approved the proposed useful-hour minimum, separated useful hours counting and qualified “Briefly useful” single-hour advice. Amended D-063 and updated weather logic, presentation requirements, implementation acceptance cases and agent routing; superseded best-hour/one-hour positive-day wording is marked historical. Reviewed current decision/acceptance examples and searched documentation for stale triggers. `bash scripts/verify.sh docs` passed; evidence: `.build/verification/docs.jArNRa/`. No remaining catalog assignments or app code changed; no build, simulator or device testing is claimed.
- **D-065 (2026-10-19):** User approved Warm Coat, Sweater, Gloves, Shorts and Raincoat as Should I wear, completing all launch-item assignments. Updated the owning decision/assignment contract, specifications, agent routing and remaining Phase 4.1 gates; reviewed assignments and searched for stale open-assignment wording. `bash scripts/verify.sh docs` passed; evidence: `.build/verification/docs.mEa8XT/`. No algorithm, hourly threshold or app code changed; no build/simulator/device tests claimed. This is not implementation permission or Phase 4.1 completion.
- **D-066 (2026-10-19):** User approved missing-required-input handling and uncertain/MAYBE isolated-gap advice. Read-only inspection confirmed existing nullable Open-Meteo decoding and a null-field fixture in `OpenMeteoProviderTests.swift`; this is not an observed live failure or a new test run. Updated/reviewed the owning policies and removed the closed missing-data decision from Phase 4.1 blockers; searched for stale gap-mapping blockers. `bash scripts/verify.sh docs` passed; evidence: `.build/verification/docs.rEblqL/`. No app code changed or build/simulator/device testing claimed.
- **D-067 prototypes (2026-10-19):** First-launch item selection and header-gear access approved through one-at-a-time questions. Added a dependency-free interactive HTML review artifact plus Guided/first-use/Compact comparison PNGs under `docs/prototypes/item-selection/`, based on current SwiftUI Home components. One selected item retains the single-item hierarchy; alternatives A/B compare daypart-preview cards with a compact multi-item overview. The prototype includes replay/reset controls and documents the planned app key `item_selection_completed`; no Swift preference key or app flow is implemented yet. Final browser checks: 19 DOM assertions and a separate reload-persistence check passed; all three boards visually inspected. Static artifact checks passed for unique IDs, no remote assets, new-file whitespace and PNG validity. `bash scripts/verify.sh docs` passed; evidence: `.build/verification/docs.juR6KF/`. Sample weather/advice, initial selection/defaults, zero-selection behavior and final layouts/copy remain proposed; no app build, simulator suite or physical-device validation is claimed.
- [ ] 4.1 Approve the predefined launch-item list, item-specific rules and main multi-item UX — **decision gate; partially decided in D-058/D-060/D-062/D-063–D-067; current selection/Home prototypes await review; remaining choices listed above and in IMPLEMENTATION_PLAN.md, not algorithms/assignments/missing-input handling**
- [ ] 4.2 Implement and deterministically test multiple predefined items without changing jacket rules
- [ ] 4.3 Implement approved multi-item UI and accessibility states
- [ ] 4.4 Validate approved items on real iPhone

### Phase 5 — First-release iOS widget

- [ ] 5.1 Approve widget form/content/refresh (per-item + overview **or** smart overview; not decided)
- [ ] 5.2 Implement widget extension and safe data handoff
- [ ] 5.3 Validate widget accuracy, safety, accessibility and real-device behavior

### Phase 6 — First-release validation

- [ ] 6.1 Complete the deterministic regression matrix — testing
- [ ] 6.2 Validate weather behavior across real conditions — provider/device validation
- [ ] 6.3 Validate degraded operation and recovery — integration/device validation
- [ ] 6.4 Validate supported devices and close the first-release quality gate — device/release-quality validation

### Phase 7 — First public Store release readiness

- [ ] 7.1 Finalize release identity and telemetry policy — decisions/Store readiness
- [ ] 7.2 Prepare the app icon and listing metadata — assets/Store readiness
- [ ] 7.3 Prepare privacy and provider-compliance material, including attribution/submission requirements — Store readiness
- [ ] 7.4 Capture App Store screenshots — Store readiness/visual validation
- [ ] 7.5 Validate a distribution build through TestFlight — testing/device/Store readiness
- [ ] 7.6 Prepare review, submit and release V1 — complete only after an accepted build and release, not upload/submission

### Post-release phases 8–19 (all pending; do not implement before their gates)

- [ ] 8.1 Approve minimal custom item model/defaults plus clear names/configuration explanation for different item behaviors (D-060); 8.2 implement local basic custom items
- [ ] 9.1 Approve which item weather thresholds can be edited; 9.2 implement local overrides
- [ ] 10.1 Approve city search, favorites, current-location and multi-city visibility UX; 10.2 implement city model/weather/cache; 10.3 validate clear overview
- [ ] 11.1 Approve simple forecast lookahead; 11.2 implement it
- [ ] 12.1 Approve recurring saved-city schedule/visibility rules; 12.2 implement weekly/nth-weekday/repeating schedules — **slot order versus Phase 13 TBD**
- [ ] 13.1 Approve notification timing/permission/staleness; 13.2 implement notifications — **late, slot order versus Phase 12 TBD**
- [ ] 14.1 Evaluate later item details/photos and any needed settings; 14.2 implement only if explicitly approved
- [ ] 15.1 Approve advanced rules and/or configurable forecast horizons; 15.2 implement approved scope
- [ ] 16.1 Evaluate cross-item personal preferences; 16.2 implement only if approved
- [ ] 17.1 Approve user-facing history policy; 17.2 implement recommendation history
- [ ] 18.1 Approve accounts/sync model; 18.2 implement very late, preserving local-first use
- [ ] 19.1 Approve Android scope/architecture; 19.2 implement much later once iOS is mature

## Open decisions / tuning

The completed T-01–T-07 and T-13 decisions remain recorded in `DECISIONS.md` and the completed Phase 0–2 subphases above. Still open:

- [~] Approve development identity and final bundle identifiers — development identifier approved as `mobi.vandewalle.caniwear`; final bundle identity remains TBD — T-08, 0.2/7.1
- [ ] Decide analytics/telemetry policy — T-09, 7.1; before any collection
- [~] Approve exact result/caution labels, reasons, palette and layout — D-046/D-047 approve the single-item reference layout, YES/MAYBE/NO labels and Guided/Compact modes; review remaining states in 3.1
- [~] Approve loading/failure/stale/permission UX and accessibility details — basic loading/failure copy and expired-forecast wording are approved through D-025/D-028; final broader details remain for 3.1

T-12 widget form/design is Phase 5.1 (first-release inclusion decided); notification design is Phase 13.1 (post-release timing decided, exact priority TBD). Icon, listing, screenshots, required support/privacy material and release timing/method require review during Phase 7; no final release details are chosen by the plan.

## Outstanding technical integration

- [ ] Configure WeatherKit capability — deferred until a paid Apple Developer Program team is available; Open-Meteo is approved for unpaid prototyping in D-022
- [~] Implement thin WeatherKit provider adapter — mapping/error adapter implemented and compiling; focused tests and live capability validation remain
- [ ] Validate the production weather provider against accuracy, rain resolution, speed, reliability, cost and deployment complexity — Open-Meteo development setup/live fetch observed in 0.6; field validation remains for 6.2 and the production provider remains to be selected before release

## Test coverage and remaining validation

- [~] **Hourly jacket rules (1.1, 2.8):** focused tests pass for dry <=15°C, 15–20°C (15°C OK, 20°C Caution), >20°C, any positive precipitation amount, 10%/20% chance boundaries, normal/heavy rain, rain+cold/warm (including rain over excessive heat), fog/mist Avoid and absent fog signal. Provider/domain/cache/presentation fog tests and real-device UI fixtures pass. Audit in 6.1; real-weather rain/fog observations remain in 6.2.
- [x] **D-055/D-056 clarification (2026-10-18):** the existing nil-versus-unknown precipitation-type behavior and same-level reason order are now explicitly approved and documented in code. Focused `JacketDecisionEngineTests` passed (14 tests, iPhone 17 simulator / iOS 26.3), including new missing/unknown type and rain-first tie-break cases; no physical-device run or full-suite claim from this change.
- [~] **Periods (2.1–2.3):** morning-only and later-day rain, noisy alternation and conservative grouping pass deterministic/device fixtures. Audit grouping, timezone/day/DST and coverage boundaries in 6.1; observe changing real weather in 6.2.
- [~] **Missing inputs and recovery (0.5, 1.3, 2.6):** hourly weather rejection, missing-location/provider and failure-state presentation, fallback, live offline failure and retry recovery are covered. Audit in 6.1/6.3; unrecorded manual walkthrough results are in Unphased follow-up.
- [~] **Cache and refresh (2.4–2.6):** under-15 skip, inclusive 15/90 boundaries, relaunch storage, foreground/active checks, pull-to-refresh, replacement and failed-refresh fallback pass. Expired, malformed, wrong-day and wrong-location cache rejection tests pass; expired-state UI coverage is implemented but awaits simulator-runtime recovery. Audit in 6.1/6.3 and validate degraded operation on device.
- [~] **Device startup and permissions (0.3, 0.5, 1.4):** signed scaffold/live flow, allowed/denied provider and integrated denied-screen checks passed on iPhone 13; permission restoration and relaunch without a repeated prompt were user-confirmed on 2026-10-18. Unrecorded cold/perceived startup follow-up is listed under Unphased follow-up; device matrix remains in 6.4 and degraded-operation audit in 6.3.

Audit provider mapping, exact threshold/freshness/grouping boundaries, timezone/DST/day gaps and wrong-location cache in 6.1; accessibility checks without recorded outcomes are listed under Unphased follow-up. Fixtures do not complete real-device or natural-weather acceptance.

## Quality validation

- [x] **Local agent verification tooling (2026-10-19):** SwiftLint 0.65.1 and ShellCheck 0.11.0 installed; setup, static checks and failure-handling tests validated. In the initial `bash scripts/verify.sh full`, all **13 tooling regression tests**, ShellCheck, plist validity, Release build, **100 unit/integration tests in 11 suites**, and **19 UI test executions** passed on iPhone 17 / iOS 26.3.1 simulator. App-target line coverage was **83.26%** (JacketDecisionEngine 99.20%, DayPeriodEngine 97.33%); local evidence is under `.build/verification/full.QRowhX/`. That initial gate correctly failed on the pre-existing `RecommendationViewModel.performLoad` complexity finding, subsequently fixed below without baselining or suppression. No app code was changed during tooling setup. No physical-device or manual visual validation is claimed. Tool scope and usage are in `TECH_SPEC.md#local-verification-tooling`.
- [x] **Complexity follow-up (2026-10-19):** extracted cached/live location acquisition and its existing failure handling into one private `loadLocation` helper; request ownership, diagnostics, cache/refresh rules and user-visible behavior are unchanged. Added regression coverage for permission denial, cancellation, unavailable location and timeout, checking that weather is not requested and retry remains possible. `bash scripts/verify.sh` **passes**: zero SwiftLint findings, **101 unit/integration tests in 11 suites**, all **13 tooling tests**, ShellCheck and plist/diff checks on iPhone 17 / iOS 26.3.1 simulator. The extracted helper has **100% line coverage**, and `performLoad` has 94.29%; evidence is under `.build/verification/code.nJxsy1/`. Release/UI/device/manual visual checks were not rerun for this behavior-preserving refactor; the preceding full-run evidence remains historical.
- [~] Measure startup/perceived startup — 1.4 warm provider-to-result path measured 0.038 s, excluding process/UI startup; user-timed iPhone 13 cold relaunch on 2026-10-18 showed first screen under 1 s and recommendation under 2 s. Diagnostics showed location reuse and a skipped weather refresh; outstanding measurements are listed under Unphased follow-up and supported-device validation in 6.4
- [~] Measure location acquisition — 1.4 warm authorized acquisition measured 0.007 s; any cold/slow measurement without a result is listed under Unphased follow-up
- [~] Measure weather fetch — 0.6 live fetch succeeded and 1.4 warm fetch measured 0.030 s; 2026-10-18 diagnostics confirmed the under-15-minute cached path skipped a request; outstanding live-refresh timing is listed under Unphased follow-up; provider field evaluation remains in 6.2
- [ ] Verify no unnecessary location/background work — 0.5/1.4; 6.4
- [~] Test on real iPhone — the earlier 74 unit tests and all 9 UI tests passed on the connected iPhone 13, including fog, diagnostics copy/dismissal and the real Apple Settings on/off walkthrough; the expanded 82-unit/9-UI-test suite passes on iPhone 17 simulator and awaits renewed connected-device validation
- [ ] Test multiple real devices across approved support — 6.4
- [ ] Test slow network — 6.3; live offline failure/recovery passed in 1.4 but is not a slow-network measurement. Unrecorded observation is listed under Unphased follow-up.
- [~] Test denied permissions — 0.5 provider/device and 1.4 integrated-screen checks complete; 3.2 permission-restoration/relaunch recovery confirmed on 2026-10-18; degraded-operation audit remains in 6.3
- [~] Test app relaunch — Phase 1 live relaunch and Phase 2 signed install/launch/relaunch passed; visible cached-state walkthrough and 6.3/6.4 remain
- [~] Test forecast changes — Phase 2 live replacement flow is covered; real changing-forecast validation remains in 6.2/6.3
- [x] Test debug off/on equivalence and diagnostics — deterministic output equality, hidden/visible UI, packaged Settings default, active-state changes, cache rejection reasons, live/timeout/fallback sequences, 20-event bound/clearing, wind neutrality, place success/fallback, report privacy/copy and real-iPhone Settings walkthrough pass in 2.9
- [ ] Test App Store/TestFlight build — 7.5

## Explicit rule

Do not mark a decision/tuning item complete by making an assumption. Ask for approval when the choice materially affects product behavior.
