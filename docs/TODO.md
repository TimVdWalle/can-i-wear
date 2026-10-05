# Can I Wear — TODO

> Status: ACTIVE
> Last updated: 2026-10-05
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
- [~] 0.7 Approve first-slice recommendation policies — three-level rain/temperature rules and remaining-day/worst-result summary approved in D-023/D-024; incomplete daily-coverage behavior remains TBD
- [ ] 0.8 Approve dynamic-period parameters — product decisions
- [ ] 0.9 Approve freshness and safe-reuse policies — product/technical decisions

### Phase 1 — First real-device vertical slice

- [~] 1.1 Implement centralized hourly jacket rules — centralized three-level engine and 8 focused boundary/validity/precedence tests pass on iPhone 13/iOS 26.6.2; completion awaits the remaining 0.7 dependency
- [ ] 1.2 Implement the basic daily summary — implementation/testing
- [ ] 1.3 Connect providers to a basic result screen — implementation/integration testing
- [ ] 1.4 Prove the complete vertical slice on a real iPhone — first major product milestone

### Phase 2 — V1 daily intelligence

- [ ] 2.1 Expose per-hour daily evaluation — implementation/testing
- [ ] 2.2 Group contiguous meaningful periods — implementation/testing
- [ ] 2.3 Consolidate noisy forecasts conservatively — implementation/testing
- [ ] 2.4 Add recent-location reuse — implementation/testing
- [ ] 2.5 Add weather cache and validity checks — implementation/testing
- [ ] 2.6 Present daily periods and integrate safe fallback — implementation/integration testing
- [ ] 2.7 Review daily-intelligence completeness — testing/device validation

### Phase 3 — V1 polish

- [ ] 3.1 Approve final V1 presentation details — product/UX decisions
- [ ] 3.2 Polish permissions and recovery states — implementation/testing/device validation
- [ ] 3.3 Measure and remove startup/request friction — implementation/device validation
- [ ] 3.4 Implement and verify accessibility — implementation/testing/device validation
- [ ] 3.5 Finish visual and transition polish — implementation/testing

### Phase 4 — V1 validation

- [ ] 4.1 Complete the deterministic regression matrix — testing
- [ ] 4.2 Validate weather behavior across real conditions — provider/device validation
- [ ] 4.3 Validate degraded operation and recovery — integration/device validation
- [ ] 4.4 Validate supported devices and close the V1 quality gate — device/release-quality validation

### Phase 5 — Store readiness

- [ ] 5.1 Finalize release identity and telemetry policy — decisions/Store readiness
- [ ] 5.2 Prepare the app icon and listing metadata — assets/Store readiness
- [ ] 5.3 Prepare privacy and provider-compliance material — Store readiness
- [ ] 5.4 Capture App Store screenshots — Store readiness/visual validation
- [ ] 5.5 Validate a distribution build through TestFlight — testing/device/Store readiness
- [ ] 5.6 Prepare review, submit and release V1 — Store readiness/release

No Swift implementation, build, real-device run, live service validation or release action was performed when creating this plan. Current iOS 26.2, bundle identifier and signing settings are configuration observations, not completed approvals or device evidence.

## Remaining decisions / tuning

- [x] Final app name — **Can I Wear**
- [x] Define measurable "few drops" rain tolerance — any forecast amount/type avoids; probability-only risk is Caution at 10% and Avoid at 20% — D-023, T-01, 0.7
- [x] Decide exact actual-vs-apparent temperature weighting — use the warmer available value, or the sole available value — D-023, T-02, 0.7
- [~] Define relevant local-day window, basic daily summary and incomplete forecast behavior — remaining local day and most-protective summary approved in D-024; incomplete coverage remains TBD — T-03, 0.7
- [ ] Define dynamic period grouping/noise parameters — T-04, 0.8
- [ ] Define cache freshness and weather/location matching — T-05, 0.9
- [~] Define location accuracy, freshness, safe reuse and behavior-affecting timeouts — acquisition accuracy/timeout approved in D-021; freshness/reuse remains for 0.9 — T-06, 0.5/0.9
- [x] Define minimum supported OS versions — iOS 26.2 and newer — T-07, 0.2
- [~] Approve development identity and final bundle identifiers — development identifier approved as `mobi.vandewalle.caniwear`; final bundle identity remains TBD — T-08, 0.2/5.1
- [ ] Decide analytics/telemetry policy — T-09, 5.1; before any collection
- [ ] Approve exact result/caution labels, reasons, palette and layout — T-10, basic proposal 1.3; final 3.1
- [ ] Approve loading/failure/stale/permission UX and accessibility details — T-11, basic proposal 1.3/2.6; final 3.1

All unchecked decisions remain **TBD**. T-12 (widget/notification timing/scope) is retained in the follow-up list below. Icon, listing, screenshots, required support/privacy material and release timing/method require review during Phase 5; no final release details are chosen by the plan.

## Technical foundation

- [x] Initialize native Swift + SwiftUI Xcode project — 0.1; app and test-target scaffold exists
- [x] Establish iOS real-device build/run — 0.3 baseline complete; 1.4 complete live flow remains
- [ ] Configure WeatherKit capability — deferred until a paid Apple Developer Program team is available; Open-Meteo is approved for unpaid prototyping in D-022
- [~] Implement location provider — 0.4 interface and 0.5 adapter/tests/device validation complete; 2.4 reuse remains
- [x] Implement weather provider abstraction — 0.4
- [x] Define normalized internal weather model independent of provider — 0.4
- [~] Implement thin WeatherKit provider adapter — mapping/error adapter implemented and compiling; focused tests and live capability validation remain
- [x] Implement Open-Meteo development adapter — request, decoding, normalization and focused tests complete; live location-to-forecast probe passed on iPhone 13/iOS 26.6.2
- [ ] Validate the production weather provider against accuracy, rain resolution, speed, reliability, cost and deployment complexity — Open-Meteo development setup/live fetch observed in 0.6; field validation remains for 4.2 and the production provider remains to be selected before release
- [ ] Implement cache — 2.4 recent location, 2.5 weather, 2.6 fallback integration
- [~] Create centralized product configuration — 0.5 acquisition parameters added; extend for 1.1 rules and approved period/cache settings in 2.3–2.5
- [~] Create deterministic jacket decision engine — 1.1 hourly engine implemented and device-tested; 1.2 daily summary remains
- [ ] Create period grouping engine — 2.1 daily inputs, 2.2 grouping, 2.3 consolidation

## V1 UX

- [ ] Main recommendation screen — 1.3 basic; 3.5 final polish
- [ ] Fast first-frame/loading state — 1.3 basic; 3.2/3.3 refinement and measurements
- [ ] Short explanation — 1.3 basic; 3.1 approved copy, 3.5 polish
- [ ] Dynamic periods — 2.6
- [ ] No-location state — 1.3 basic; 2.6 fallback; 3.2 polish
- [ ] No-weather state — 1.3 basic; 2.6 fallback; 3.2 polish
- [ ] Stale-data state — 2.6; 3.2 polish
- [ ] Permission UX — 0.5 functional; 1.4 device proof; 3.2 polish
- [ ] Accessibility — 3.1 approved details, 3.4 implementation/device checks
- [ ] Visual polish — 3.5

## Early follow-up features

- [ ] Decide exact V1 timing/scope for iOS widget — T-12; follow-up after 1.4, not a core-plan prerequisite
- [ ] Decide exact V1 timing/scope for notifications — T-12; follow-up after 1.4, not a core-plan prerequisite
- [ ] Implement widget when approved for the active phase — outside numbered execution scope pending approval
- [ ] Implement notifications when approved for the active phase — outside numbered execution scope pending approval

## Tests

- [~] Dry + <=15°C — 1.1 focused boundary tests pass; 4.1 regression audit remains
- [~] Dry + 15–20°C — 1.1 focused boundary tests pass, including exactly 15°C as OK and exactly 20°C as Caution; 4.1 audit remains
- [~] Dry + >20°C — 1.1 focused boundary tests pass; 4.1 audit remains
- [~] Few drops — any positive amount avoids and 10%/20% probability boundaries pass in 1.1 tests; 4.1/4.2 remain
- [~] Normal rain — 1.1 focused test passes; 4.1/4.2 remain
- [~] Heavy rain — 1.1 focused test passes; 4.1/4.2 remain
- [~] Rain + cold — 1.1 focused test passes; 4.1 remains
- [~] Rain + warm — 1.1 focused tests pass, including rain precedence over excessive heat; 4.1 remains
- [ ] Morning rain only — 1.2 summary, 2.1/2.2 periods; 4.1/4.2
- [ ] Later-day rain only — 1.2 summary, 2.1/2.2 periods; 4.1/4.2
- [ ] Noisy alternating forecast — 2.3/2.7; 4.1
- [~] Missing weather — 1.1 rejects missing/invalid required hourly inputs; 1.3, 2.6/2.7 and 4.1/4.3 remain
- [ ] Missing location — 0.5/1.3, 2.6/2.7; 4.1/4.3
- [~] Network unavailable — 0.6 provider error mapping test complete; 1.3 integration, 2.6/2.7 and 4.3 recovery checks remain
- [ ] Recent cached data — 2.4–2.7; 4.1/4.3
- [ ] Stale cached data — 2.4–2.7; 4.1/4.3
- [x] Real-device startup — 0.3 scaffold baseline complete; 1.4 live flow and 3.3/4.4 measurements remain
- [~] Real-device permission flow — 0.5 allowed and denied provider checks complete; 1.4 integrated flow and 3.2/4.3 polish/recovery remain

Additional required checks: exact temperature/rain/freshness/grouping boundaries (1.1/2.3–2.5), provider mapping (0.6), timezones/day boundaries/coverage gaps (1.2/2.1), wrong-location cache (2.5/2.6), and accessibility (3.4). Audit completeness in 4.1; do not mark device observations complete from fixtures alone.

## Quality validation

- [ ] Measure startup/perceived startup — 1.4 initial evidence; 3.3/4.4
- [ ] Measure location acquisition — 0.5/1.4 initial evidence; 3.3
- [~] Measure weather fetch — 0.6 live fetch succeeded; timing measurement remains for 1.4, 3.3 and 4.2
- [ ] Verify no unnecessary location/background work — 0.5/1.4; 3.3/4.4
- [~] Test on real iPhone — 0.3 scaffold, focused 0.4–0.6 tests, 0.5 allowed/denied location checks, and 0.6 live location-to-weather probe complete on iPhone 13/iOS 26.6.2; 1.4 recommendation flow and 2.7 daily flow remain
- [ ] Test multiple real devices across approved support — 4.4
- [ ] Test slow network — 3.3/4.3
- [~] Test denied permissions — 0.5 provider/device check complete; 1.4 integration and 3.2/4.3 recovery checks remain
- [ ] Test app relaunch — 1.4/2.7; 4.3/4.4
- [ ] Test forecast changes — 2.6/2.7; 4.2/4.3
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
