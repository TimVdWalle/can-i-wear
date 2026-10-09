# Can I Wear — TODO

> Status: ACTIVE
> Last updated: 2026-10-09
> Source of truth: YES

This is an execution list, not a source of product decisions.

The numbered review units and their acceptance criteria are in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md). Complete a subphase only after its decision blockers, tests and required device validation are satisfied. The detailed task/scenario lists below retain the original execution context; their subphase references show where each item is delivered or validated.

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
- [x] 2.6 Present daily periods and integrate safe fallback — period ranges/reasons, age-labeled saved results, 15-minute conditional refresh, replacement/fallback, explicit approved expired-forecast state and 10-second timeout integrated and tested
- [x] 2.7 Review daily-intelligence completeness — accepted complete after review of 57 deterministic passing tests, rendered Phase 2 UI scenarios, signed app installation/launch/relaunch and live recommendation evidence; unavailable natural split-weather and additional manual cache/offline observations remain useful later validation rather than a Phase 2 blocker
- [x] 2.8 Add fog and mist protection — normalized explicit fog/mist condition, Open-Meteo WMO 45/48 and WeatherKit fog mapping, Avoid precedence, cache compatibility, periods and approved temporary **“Fog is expected.”** presentation implemented; provider/domain/cache/presentation tests and focused UI test pass on connected iPhone 13, and a live Open-Meteo payload confirmed hourly `weather_code`
- [x] 2.9 Add opt-in local debug diagnostics — off-by-default Apple Settings toggle and active-state refresh, dismissible local report, structured/persisted 20-event bound with disable clearing, cache/fetch/error timing and reasons, asynchronous place lookup, hourly inputs/decisions/periods, diagnostic-only wind and privacy-labeled copy action implemented; its original 74-unit/9-UI-test connected-iPhone validation remains recorded

### Phase 3 — V1 polish

- [ ] 3.1 Approve final V1 presentation details — product/UX decisions
- [ ] 3.2 Polish permissions and recovery states — implementation/testing/device validation
- [ ] 3.3 Measure and remove startup/request friction — implementation/device validation
- [ ] 3.4 Implement and verify accessibility — implementation/testing/device validation
- [ ] 3.5 Finish visual and transition polish — implementation/testing

### Phase 4 — iOS widget

- [ ] 4.1 Approve widget scope and refresh behavior — product/UX decision
- [ ] 4.2 Implement and validate the iOS widget — implementation/testing/device validation

### Phase 5 — V1 validation

- [ ] 5.1 Complete the deterministic regression matrix — testing
- [ ] 5.2 Validate weather behavior across real conditions — provider/device validation
- [ ] 5.3 Validate degraded operation and recovery — integration/device validation
- [ ] 5.4 Validate supported devices and close the V1 quality gate — device/release-quality validation

### Phase 6 — Store readiness

- [ ] 6.1 Finalize release identity and telemetry policy — decisions/Store readiness
- [ ] 6.2 Prepare the app icon and listing metadata — assets/Store readiness
- [ ] 6.3 Prepare privacy and provider-compliance material — Store readiness
- [ ] 6.4 Capture App Store screenshots — Store readiness/visual validation
- [ ] 6.5 Validate a distribution build through TestFlight — testing/device/Store readiness
- [ ] 6.6 Prepare review, submit and release V1 — Store readiness/release

No Swift implementation, build, real-device run, live service validation or release action was performed when creating this plan. Current iOS 26.2, bundle identifier and signing settings are configuration observations, not completed approvals or device evidence.

## Remaining decisions / tuning

- [x] Final app name — **Can I Wear**
- [x] Define measurable "few drops" rain tolerance — any forecast amount/type avoids; probability-only risk is Caution at 10% and Avoid at 20% — D-023, T-01, 0.7
- [x] Decide exact actual-vs-apparent temperature weighting — use the warmer available value, or the sole available value — D-023, T-02, 0.7
- [x] Define relevant local-day window, basic daily summary and incomplete forecast behavior — remaining local day, most-protective summary and conservative single-gap handling approved in D-024 — T-03, 0.7
- [x] Define dynamic period grouping/noise parameters — approved in D-026 — T-04, 0.8
- [x] Define cache freshness and weather/location matching — approved in D-027 — T-05, 0.9
- [x] Define location accuracy, freshness, safe reuse and behavior-affecting timeouts — acquisition policy approved in D-021 and reuse/weather timeout policy in D-027 — T-06, 0.5/0.9
- [x] Define minimum supported OS versions — iOS 26.2 and newer — T-07, 0.2
- [~] Approve development identity and final bundle identifiers — development identifier approved as `mobi.vandewalle.caniwear`; final bundle identity remains TBD — T-08, 0.2/5.1
- [ ] Decide analytics/telemetry policy — T-09, 6.1; before any collection
- [ ] Approve exact result/caution labels, reasons, palette and layout — T-10, basic proposal 1.3; final 3.1
- [~] Approve loading/failure/stale/permission UX and accessibility details — basic loading/failure copy and expired-forecast wording are approved through D-025/D-028; final broader details remain for 3.1
- [x] Define fog/mist protection — explicit provider fog/mist produces Avoid; Open-Meteo WMO codes 45/48 are used, missing fog data alone has no effect, and no humidity/dew-point/visibility inference is allowed — D-029, T-13, 2.8
- [x] Define local debug direction — one Apple Settings switch defaulting off, local-only diagnostics, last 20 events cleared on disable, place fallback, informational wind and user-initiated copy approved in D-030 — 2.9

All unchecked decisions remain **TBD**. T-12 covers the widget decision in Phase 4; notifications remain follow-up scope. Icon, listing, screenshots, required support/privacy material and release timing/method require review during Phase 6; no final release details are chosen by the plan.

## Technical foundation

- [x] Initialize native Swift + SwiftUI Xcode project — 0.1; app and test-target scaffold exists
- [x] Establish iOS real-device build/run — 0.3 baseline complete; 1.4 complete live flow remains
- [ ] Configure WeatherKit capability — deferred until a paid Apple Developer Program team is available; Open-Meteo is approved for unpaid prototyping in D-022
- [x] Implement location provider — one-time acquisition plus latest-only 30-minute reuse implemented and device-tested
- [x] Implement weather provider abstraction — 0.4
- [x] Define normalized internal weather model independent of provider — 0.4
- [~] Implement thin WeatherKit provider adapter — mapping/error adapter implemented and compiling; focused tests and live capability validation remain
- [x] Implement Open-Meteo development adapter — request, decoding, normalization and focused tests complete; live location-to-forecast probe passed on iPhone 13/iOS 26.6.2
- [ ] Validate the production weather provider against accuracy, rain resolution, speed, reliability, cost and deployment complexity — Open-Meteo development setup/live fetch observed in 0.6; field validation remains for 5.2 and the production provider remains to be selected before release
- [x] Implement cache — recent location, normalized weather, validity checks and fallback integration complete
- [x] Create centralized product configuration — acquisition, jacket rules, period/noise values, location/weather freshness, refresh interval/failure cooldown, distance and weather timeout are concentrated in `AppConfiguration`
- [x] Create deterministic jacket decision engine — 1.1 hourly engine and 1.2 daily summary implemented and device-tested
- [x] Create period grouping engine — ordered daily inputs, contiguous grouping and D-026 consolidation complete
- [x] Normalize and evaluate fog/mist — explicit Open-Meteo WMO 45/48 and WeatherKit fog mapping, deterministic Avoid rule, cache round trip/backward decoding, periods and presentation complete in 2.8
- [x] Add local diagnostic recorder/store and Apple Settings switch — structured local event persistence, 20-event bound, disable clearing, default registration and packaged `Settings.bundle` complete in 2.9

## V1 UX

- [~] Main recommendation screen — 1.3 basic screen complete; 3.5 final polish remains
- [x] Weather provenance and refresh interaction — D-031 status/locality, guarded pull-to-refresh, active/foreground checks, 15/90-minute policy, no-concurrency guard and 30-second failure cooldown implemented with deterministic boundary coverage
- [~] Fast first-frame/loading state — 1.3 automatic loading state complete; 3.2/3.3 refinement and measurements remain
- [~] Short explanation — 1.3 basic reason mapping complete; 3.1 final copy and 3.5 polish remain
- [~] Dynamic periods — 2.6 basic presentation complete; final visual treatment remains in 3.1/3.5
- [~] No-location state — 1.3 basic denied/unavailable states and retry complete; 2.6 fallback and 3.2 polish remain
- [~] No-weather state — 1.3 basic unavailable/incomplete states and retry complete; 2.6 fallback and 3.2 polish remain
- [~] Stale-data state — expired data is rejected with the approved D-028 explanation/retry and valid cached age is visible; final styling remains in 3.1/3.2
- [~] Permission UX — 0.5 provider behavior and 1.3 integrated state complete; 1.4 denied-screen device proof and 3.2 polish remain
- [ ] Accessibility — 3.1 approved details, 3.4 implementation/device checks
- [ ] Visual polish — 3.5
- [~] Opt-in diagnostics sheet — 2.9 implementation and real-device UI checks complete; final visual/accessibility polish remains in 3.1/3.4/3.5

## Early follow-up features

- [ ] Decide exact V1 timing/scope for iOS widget — T-12; Phase 4.1
- [ ] Decide exact V1 timing/scope for notifications — T-12; follow-up after Phase 4, not a core-plan prerequisite
- [ ] Implement widget when approved — Phase 4.2
- [ ] Implement notifications when approved for the active phase — outside numbered execution scope pending approval

## Tests

- [~] Dry + <=15°C — 1.1 focused boundary tests pass; 4.1 regression audit remains
- [~] Dry + 15–20°C — 1.1 focused boundary tests pass, including exactly 15°C as OK and exactly 20°C as Caution; 4.1 audit remains
- [~] Dry + >20°C — 1.1 focused boundary tests pass; 4.1 audit remains
- [~] Few drops — any positive amount avoids and 10%/20% probability boundaries pass in 1.1 tests; 4.1/4.2 remain
- [~] Normal rain — 1.1 focused test passes; 4.1/4.2 remain
- [~] Heavy rain — 1.1 focused test passes; 4.1/4.2 remain
- [~] Fog/mist Avoid — 2.8 provider/domain/cache/presentation and real-device UI fixtures pass; naturally observed fog validation remains in 4.2
- [~] Missing fog/mist signal — 2.8 proves existing rain/temperature evaluation continues per D-029; 4.1 regression audit remains
- [~] Rain + cold — 1.1 focused test passes; 4.1 remains
- [~] Rain + warm — 1.1 focused tests pass, including rain precedence over excessive heat; 4.1 remains
- [~] Morning rain only — deterministic period fixtures pass; real-condition validation remains in 4.2
- [~] Later-day rain only — deterministic period fixtures pass; real-condition validation remains in 4.2
- [~] Noisy alternating forecast — conservative period fixtures pass on device; 4.1 audit remains
- [~] Missing weather — hourly rejection, explicit presentation and Phase 2 fallback coverage exist; 4.1/4.3 audit and device validation remain
- [~] Missing location — provider, presentation and Phase 2 fallback coverage exist; 4.1/4.3 audit and recovery validation remain
- [~] Network unavailable — provider mapping, presentation mapping, live offline/recovery and Phase 2 fallback coverage are complete; 4.3 degraded-operation validation remains
- [~] Recent cached data — under-15 skip, inclusive 15/90 boundaries, relaunch storage, foreground/active checks, pull-to-refresh, replacement and failed-refresh fallback tests pass; 4.1/4.3 remain
- [~] Stale cached data — expiry, malformed, wrong-day and wrong-location rejection tests pass; expired-state UI coverage is implemented but awaits simulator-runtime recovery; 4.1/4.3 remain
- [x] Real-device startup — 0.3 scaffold baseline complete; 1.4 live flow and 3.3/4.4 measurements remain
- [~] Real-device permission flow — 0.5 allowed/denied provider checks and 1.4 allowed/relaunch/integrated-denied checks complete; 3.2/4.3 polish/recovery remain

Additional required checks: exact temperature/rain/freshness/grouping boundaries (1.1/2.3–2.5), provider mapping (0.6), timezones/day boundaries/coverage gaps (1.2/2.1), wrong-location cache (2.5/2.6), and accessibility (3.4). Audit completeness in 4.1; do not mark device observations complete from fixtures alone.

## Quality validation

- [~] Measure startup/perceived startup — 1.4 warm provider-to-result path measured 0.038 s, excluding process/UI startup; cold/perceived measurements remain for 3.3/4.4
- [~] Measure location acquisition — 1.4 warm authorized acquisition measured 0.007 s; cold/slow measurements remain for 3.3
- [~] Measure weather fetch — 0.6 live fetch succeeded and 1.4 warm fetch measured 0.030 s; broader 3.3/4.2 measurements remain
- [ ] Verify no unnecessary location/background work — 0.5/1.4; 3.3/4.4
- [~] Test on real iPhone — the earlier 74 unit tests and all 9 UI tests passed on the connected iPhone 13, including fog, diagnostics copy/dismissal and the real Apple Settings on/off walkthrough; the expanded 82-unit/9-UI-test suite passes on iPhone 17 simulator and awaits renewed connected-device validation
- [ ] Test multiple real devices across approved support — 4.4
- [ ] Test slow network — 3.3/4.3; live offline failure/recovery passed in 1.4 but is not a slow-network measurement
- [~] Test denied permissions — 0.5 provider/device and 1.4 integrated-screen checks complete; 3.2/4.3 recovery/polish checks remain
- [~] Test app relaunch — Phase 1 live relaunch and Phase 2 signed install/launch/relaunch passed; visible cached-state walkthrough and 4.3/4.4 remain
- [~] Test forecast changes — Phase 2 live replacement flow is covered; real changing-forecast validation remains in 4.2/4.3
- [x] Test debug off/on equivalence and diagnostics — deterministic output equality, hidden/visible UI, packaged Settings default, active-state changes, cache rejection reasons, live/timeout/fallback sequences, 20-event bound/clearing, wind neutrality, place success/fallback, report privacy/copy and real-iPhone Settings walkthrough pass in 2.9
- [ ] Test App Store/TestFlight build — 5.5

## Store delivery details

- [ ] Final release identity and telemetry/privacy policy — 5.1
- [ ] App icon and listing metadata — 5.2
- [ ] Privacy information and required support material — 5.3
- [ ] Verify current provider attribution/submission requirements against actual app behavior — 0.6/5.3
- [ ] App Store screenshots — 5.4
- [ ] Signed archive and TestFlight testing — 5.5
- [ ] App Store review preparation and submission — 5.6
- [ ] Accepted build and V1 release — 5.6; do not mark complete at upload/submission

## Explicit rule

Do not mark a decision/tuning item complete by making an assumption. Ask for approval when the choice materially affects product behavior.
