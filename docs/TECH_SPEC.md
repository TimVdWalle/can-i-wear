# Can I Wear — Technical Specification

> Status: ACTIVE
> Last updated: 2026-10-22
> Source of truth: YES

## Technical goal

Choose technology in service of the final product.

The important outcomes are:
- correct behavior;
- reliable real-device operation;
- smooth UX;
- no unnecessary delays;
- no stutters;
- no annoying permission/network behavior;
- strong testability;
- maintainable code;
- straightforward App Store delivery;
- a clean path to reconsider Android later without compromising the iOS product.

Implementation elegance is secondary to these outcomes.

## Framework

**DECIDED: native Swift + SwiftUI for the iOS app and first public release.**

Why:
- iOS is the product priority;
- Android is a nice-to-have rather than a V1 requirement;
- native integration is valuable for location, weather services, notifications and widgets;
- SwiftUI provides the shortest path to a polished platform-consistent iOS UX;
- most implementation will be AI-assisted/generated, reducing the cost of the user's limited prior Swift experience.

Android is intentionally outside the V1 implementation path.

## Weather provider

**Development provider: Open-Meteo. Production provider: TBD before distribution.**

Open-Meteo's free open-access endpoint is approved only for evaluation and prototyping. WeatherKit remains the intended production candidate once a paid Apple Developer Program team is available. Neither provider is a permanent lock-in; both remain behind our abstraction.

The architecture must be:

```text
Can I Wear
    ↓
WeatherProvider (our interface)
    ↓
Normalized Weather Model
    ↓
Jacket Decision Engine
```

A concrete provider adapter implements the interface:

```text
OpenMeteoProvider
```

A production or future provider can implement the same interface:

```text
WeatherKitProvider
```

The jacket decision engine, period engine and UI must never consume provider-specific response objects. The same boundary must hold when adding other item engines and multi-city screens.

### Multi-item domain support

`PredefinedItem` assigns the seven-item catalog to the two approved policies without relying on names or UI strings. `ItemDecisionEngine` classifies the approved hourly factors using `AppConfiguration.itemRules`; Leather Jacket delegates to its existing engine/configuration. Temperature items use usable apparent temperature, with usable actual temperature as fallback. Raincoat requires valid total amount/chance and only optionally uses wind; Sunglasses requires daylight/sky before its optional hourly-UV override.

`ForecastEvaluationWindow` shares the existing local-day, timezone, ordered-slot and duplicate validation between the jacket daily evaluator and new usefulness evaluation. Jacket inference/reason precedence and `DayPeriodEngine` remain protective. `MultiItemRecommendationEngine` evaluates one normalized forecast independently for selected items; its six usefulness assignments share one useful-hour-count policy and one contiguous-period implementation, without jacket smoothing. It returns semantic daily verdicts, actual timestamped hours/reasons and periods; an unavailable item's evaluation is nil, not a negative result. Inferred hours stay explicitly identifiable and never count as useful; adjacent same-level periods retain distinct weather reasons and do not hide an inferred gap.

The domain code does not fetch weather, alter cache freshness, persist selection, or generate UI copy. Phase 4.3 connects it through the existing `RecommendationViewModel` load/cache/refresh flow: selected items are reevaluated from the same normalized forecast, not fetched separately. Missing jacket inputs no longer prevent another selected item's advice; unavailable items retain explicit nil evaluations. `DailyRecommendationPresentation` carries selected-item results alongside the existing jacket planning-day/hourly presentation. Refresh/failure copies retain those results. Selection changes and detail navigation do not request weather/location or resurrect expired advice; a selection changed during a cache write is honored when the load completes.

Local hour boundaries also trigger local reevaluation so past useful hours leave the remaining-day count even when weather is younger than 15 minutes. This is not an additional provider request: existing freshness/refresh/concurrency/cooldown gates remain authoritative. If a live response cannot advise on any selected item, retain a still-usable saved forecast that can, rather than overwriting it with unusable advice. A live response usable for some selected items remains independently presentable; do not mix per-item forecasts or let the unavailable item veto the others. Detail sheets read the current model state rather than keeping an indefinitely usable forecast snapshot. Validation progress/evidence belong in `TODO.md`; simulator support is not physical-device validation.

Both evaluated providers supply the required hourly inputs:
- hourly forecasts;
- precipitation chance;
- precipitation amount;
- precipitation type;
- provider fog/mist condition signal where available;
- temperature;
- apparent/feels-like temperature;
- wind speed as an optional Raincoat modifier (diagnostic-only for Leather Jacket), and gusts as diagnostic-only context;
- time and forecast-location timezone context where available.

During unpaid development, V1 uses Open-Meteo over HTTPS. Provider-specific requests, authorization and mapping stay inside each provider integration layer. The free Open-Meteo endpoint must not be assumed suitable for App Store distribution; production terms/provider selection are revisited before release.

Before treating any provider as final, validate:
- forecast accuracy;
- rain resolution;
- speed;
- reliability;
- cost;
- authentication/deployment complexity;
- real-device behavior.

If another provider is better, replacing the adapter must not require rewriting the jacket logic.

## Location

Use current device location when needed.

Do not continuously track location.

Preferred behavior:
- request a sufficiently accurate current location;
- stop location work once a useful fix is obtained;
- cache recent location;
- reuse it when within the configured freshness policy.

Exact accuracy/freshness values should be configurable and tested.

## Caching

Cache:
- recent location;
- recent weather response;
- timestamp and relevant location identity.

Use cache to make startup resilient and reduce unnecessary requests.

Cache freshness is configurable.

Weather has separate centralized thresholds for refresh desirability (15 minutes) and maximum safe reuse (90 minutes inclusive). Load/foreground/active-boundary checks use these thresholds. Pull-to-refresh uses the same 15-minute gate, permits no concurrent request, and applies a centralized 30-second cooldown after failure. Saved weather remains visible during a permitted refresh and after refresh failure only while it remains within the maximum usable age.

## Architecture

Keep these components separated:

1. LocationProvider
2. WeatherProvider
3. WeatherCache
4. JacketRulesConfig
5. JacketDecisionEngine
6. DayPeriodEngine
7. Presentation/UI
8. Local debug diagnostics

The decision engine must not depend on UI.

The weather provider must be replaceable.

The implemented Phase 3 Home Screen presentation carries the existing `DailyEvaluation` hourly results alongside `DayPeriodEngine` output from the same evaluation/request. The jacket hero reuses `HourlyRecommendation.mostProtective`; SwiftUI does not aggregate weather or apply thresholds. It directly presents the mapped status and reason without a question or second action sentence. Raw hours retain timestamps/timezone and inferred-gap identity, distinct from consolidated periods. Bundled item artwork has no remote dependency. `HomePresentationMode` centrally selects Guided or Compact presentation without changing these outputs; Guided is the default.

For Phase 4, D-060 replaces the universal daily YES/MAYBE/NO presentation with an explicit verdict and timing; this is approved future work, not implemented by this documentation. Keep the daily advice's meaning and supporting time intervals distinct from its display wording and from raw hourly levels. SwiftUI must present evaluated item-specific advice, not select a best/worst hour by parsing copy or inspecting an item's display name. Preserve the jacket's most-protective evaluation and the raw-hour/consolidated-period distinction.

D-072 subsequently restores the large YES/MAYBE/NO single-item/detail hero with optional exception qualifiers; the explicit daily verdict/timing remains in multi-item overview cards. Map the existing semantic verdict separately from overview copy. Derive jacket exceptions from evaluated advice compared with the displayed dayparts, respecting protective periods and inferred uncertainty; never alter evaluation or present a raw safe blip inside protective avoidance as a safe interval.

D-073 keeps item planning-display evaluations separate from remaining-day `itemResults`. Derive the planning window using the existing forecast-timezone 06:00 start and each item's unchanged engine/grouping, reusing the same normalized forecast. Every item's Home/overview/detail row reuses the fixed Morning/Afternoon/Evening boundaries and `DayPartsView`. Non-jacket contiguous advice is clipped into those cards without a new aggregation algorithm; preserve short intervals and uncertainty. Jacket daypart evaluation stays unchanged. Carry display context through refresh/fallback/selection updates; never use its daily verdict/count as the current answer. If earlier coverage is unavailable, preserve remaining advice and mark unsupported dayparts unavailable. No new network request, cache schema or freshness policy is needed.

The default-on `home_presentation_guided` and `home_introduction_visible` Settings-bundle preferences use explicit Boolean `TrueValue`/`FalseValue` values in the standard application preference domain. On first use of this contract, migrate stored `guided_home_enabled` and `show_home_introduction` values to the canonical keys. Preserve the separate legacy acknowledgement migration so an already dismissed card is not redisplayed. Synchronize and resolve the standard domain when the app returns active; do not use a cached `@AppStorage` binding or construct a `UserDefaults` suite from the app’s own bundle identifier for these externally edited values. Disabling Guided also disables the introduction, while enabling the introduction also enables Guided. **Got it** turns off the introduction only.

D-074 supersedes D-073's non-jacket stacked interval rendering: map fully covered fixed dayparts to one usefulness badge (any confirmed YES, otherwise any MAYBE, otherwise NO), keeping clipped periods as accessibility context. Missing coverage is unavailable. Share the compact hourly timeline renderer across item-specific presentation values without converting non-jacket recommendations into jacket domain rules. Overview uses a compact version of the existing hero; daily evaluation and the jacket detail are unchanged.

## Central configuration

There must be one concentrated configuration area for all product-level tunable values.

Examples:
- temperature thresholds;
- rain tolerance;
- probability thresholds;
- period grouping;
- noise suppression;
- cache freshness;
- timeout values where product behavior depends on them.
- Home Screen presentation mode.

No scattered magic numbers.

Infrastructure constants that are not product behavior may remain close to their technical implementation when appropriate.

## Local debug diagnostics

Use `Settings.bundle` preferences for **Guided Home** and **Show How It Works** (both default on) and **Debug Enabled** (default off). The presentation switches follow the D-053 preference-domain and migration contract. The first two control presentation only. Debug state must not alter decision rules, cache validity or normal location/weather request policy.

When enabled, expose a dismissible in-app diagnostics surface and a bounded on-device event store of at most 20 events. Record structured request/cache reasons and outcomes rather than relying on console text. Clear retained diagnostics when the setting is disabled. Detailed reverse geocoding for a readable street/place runs only for diagnostics. The normal screen independently resolves only a concise locality. Neither lookup may block recommendation delivery. A copied report is initiated by the user and visibly includes place information.

No diagnostics are uploaded. This feature does not resolve or authorize analytics/telemetry. Exact coordinates do not need to be displayed when street/city/region is sufficient to verify the forecast area.

## Testing architecture

The core decision engine must be testable without:
- GPS;
- live weather;
- network;
- real time.

Use deterministic weather fixtures.

The most important test suite is the jacket decision and period grouping logic.

Add integration tests for:
- location permission;
- weather fetch;
- caching;
- startup;
- error states;
- real-device flows.

### Local verification tooling

Install the development-only tools with `bash scripts/setup-tools.sh` from the repository root. It installs ShellCheck (verification-script static analysis) via `Brewfile` and downloads the official universal SwiftLint **0.65.1** binary (Swift correctness/code-smell checks), verifying its SHA-256 before installation under `.build/tools/bin/`. This avoids Homebrew source builds on Intel Macs. The verification script prefers this local binary. Python 3 runs the verification script's standard-library regression tests; full Xcode and an installed compatible iOS simulator runtime are required for build/test profiles. No app dependency, paid service, or network-backed code-analysis service is added.

| Command | Checks |
| --- | --- |
| `bash scripts/verify.sh docs` | Staged and unstaged diff whitespace. |
| `bash scripts/verify.sh static` | Diff checks, ShellCheck, verification-script regression tests, focused SwiftLint rules, and bundled plist validity. |
| `bash scripts/verify.sh` | Static checks, Debug simulator build and all unit/integration tests, compiler warnings as errors, and coverage. |
| `bash scripts/verify.sh full` | Static checks, Release simulator build, Debug build and all unit/integration/UI tests, compiler warnings as errors, and coverage. |

The default destination is `platform=iOS Simulator,name=iPhone 17,OS=latest`. Set `VERIFY_DESTINATION` to an installed compatible simulator destination when needed. Test execution is serial to avoid UI/Settings interference. The script does not install tools, rewrite source, delete old results, or automatically retry failing tests. Missing tools and failed commands return a nonzero exit status. Independent checks continue after a finding so a lint failure does not hide test evidence, but the overall gate still fails. Coverage is collected only after a successful test run.

SwiftLint uses a focused rule set in `.swiftlint.yml`, including its default complexity limit with switch cases excluded from the count. `redundant_nil_coalescing` is intentionally not enabled: a Swift type probe confirms the provider's `?? nil` converts `Double??` to `Double?`, and the syntactic rule flags this necessary flattening. Tooling regression tests check both defect detection and this legitimate case. Do not baseline or suppress genuine findings merely to make the gate pass.

Each invocation saves logs and a PASS/FAIL status under a unique `.build/verification/` directory. Successful test profiles also save `Tests.xcresult`, a target coverage summary, and per-file/function data in `coverage.json`. Inspect changed recommendation, grouping, cache, and provider logic for uncovered branches; no arbitrary global percentage is treated as proof of correctness. `.build/` is ignored by Git. Simulator/fixture success is not live-provider, visual, or physical-device acceptance. The agent's completion gate is maintained in [AI_RULES.md](AI_RULES.md#13-run-the-verification-gate-before-completion).

## UX performance

Optimize for perceived responsiveness:
- show useful loading state immediately;
- start location/weather work efficiently;
- avoid blocking the first frame unnecessarily;
- avoid redundant requests;
- keep domain calculations lightweight;
- never make the user wait for avoidable work.

Do not claim performance targets without measurement.

## App Store

The native iOS app is built and released using Xcode, TestFlight and App Store Connect.

App Store delivery is a V1 acceptance requirement, not a later nice-to-have.

## Privacy

Do not collect location history unless explicitly required later.

V1 has no account requirement and no need for a personal profile.

## Current technical unknowns

- analytics/telemetry policy;
- final bundle identifiers;
- production weather provider and terms for distribution.

## Technical constraints for approved future work (not yet implemented)

Scope, ordering and open choices are maintained in [ROADMAP.md](ROADMAP.md); implementation gates are in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md). These constraints apply only when the relevant work is approved:

- Multiple item rules must stay centrally defined and testable. Do not change jacket thresholds or introduce a general-purpose rules engine without approval.
- D-067 setup is stored by `ItemSelectionStore`: **`item_selection_completed`**, Boolean, centrally registered default false, and **`selected_item_ids`**, an array of `PredefinedItem.rawValue` strings in catalog order. Fresh installs select nothing. Only a nonempty confirmed selection sets completion true; unknown/duplicate saved IDs are filtered, and an empty valid selection cannot bypass setup even with a true flag. Editing uses a local draft; Cancel or sheet dismissal does not save it. No location/weather load starts before first confirmation. The header gear reopens selection; Home routes by the saved selected-item count.
- Setting `item_selection_completed` false alone replays selection on the next launch without clearing saved items, weather/location caches or Guided Home preferences; the standard launch override `-item_selection_completed NO` can be used for that limited test launch and omitted afterward. This key is distinct from `home_introduction_visible`; no new broad Settings surface is introduced. The browser prototype's namespaced state/replay controls affect only the browser, never these app preferences.
- Apple system Settings exposes **Reset Item Setup**, keyed by `reset_item_setup`, with explicit Boolean values and a centrally registered false default. `ItemSelectionStore` synchronizes the preference domain and consumes a true request once on initialization or foreground activation: `replaySetup()` clears in-memory items, removes `selected_item_ids`, sets completion false, and the request turns off. Dismiss any open item selector/detail/diagnostics when routing back to setup. The first selector starts empty with Continue disabled until an item is chosen (D-067's reset selection amendment). This does not clear Home preferences/caches or bypass normal request gating.
- D-060 permits predefined-item policies without requiring a user-facing taxonomy. D-063/D-064 lock two shared daily algorithms and D-065 approves all launch-item assignments. Keep these assignments explicit in centralized catalog/configuration, independent of display names and localized verdicts; do not infer them in SwiftUI or invent per-item daily algorithms. Exact public group labels/configuration UX remain a Phase 8.1 gate; no custom-item schema/editor or generic rule builder is approved.
- D-061's internal “Can I wear items” / “Should I wear items” terminology has the D-063/D-064 daily contract in [WEATHER_LOGIC.md](WEATHER_LOGIC.md#two-shared-daily-aggregation-policies-d-063). Keep the implementation simple: shared validated hourly evaluation flow with item-specific thresholds and the selected daily aggregation policy, not two duplicated end-to-end engines. The Should I wear useful-hour minimum belongs in centralized product configuration; count directly evaluated hours, not expanded/consolidated presentation periods, and retain the qualified single-hour outcome. Do not invert weather values or thresholds. No particular enum/API layout is mandated, and no third/combined behavior is approved. Shared UI wording must not select or change aggregation; SwiftUI presents domain output.
- D-058 approves apparent/feels-like temperature with actual-temperature fallback for Warm Coat, Sweater, Gloves and Shorts. D-062/D-071 approve Raincoat total-precipitation amount/chance conditions and an optional wind modifier, plus Sunglasses daylight/sky-condition advice with optional hourly UV override; exact thresholds belong in `WEATHER_LOGIC.md`, not provider code. Do not make wind or UV affect Leather Jacket recommendations.
- Raincoat consumes normalized **total precipitation in water-equivalent millimetres** and precipitation chance, including solid/mixed precipitation; a separate liquid-rain field is not required by D-071. Do not double-count rain/showers/snow components alongside a provider total or invent snow-depth conversion ratios. Open-Meteo retains the provider total unchanged while aligning its accumulation interval as described below; validation evidence belongs in `TODO.md`.
- `HourlyWeather` now retains optional app-owned `isDaylight`, `skyCondition` and `uvIndex` values. Open-Meteo requests/normalizes hourly `is_day`, `cloud_cover` and `uv_index`; recognized explicit sky/fog codes take precedence, otherwise valid cloud cover uses the source-backed categories below. Invalid/missing daylight or sky remains nil; invalid/missing UV remains nil for the approved optional fallback. Provider-specific codes stay inside the adapter. Never assume missing means dry/overcast/night/zero UV or substitute a daily maximum. The deferred WeatherKit adapter still supplies nil for these new optional fields; no live WeatherKit support is claimed.
- **Interval-start normalization (ISS-001):** For an app hour starting at UTC T, Open-Meteo's amount/chance, rain/showers/snow components and preceding-hour gust maximum come from the unique provider row at T+3600. Actual/apparent temperature, instantaneous condition/fog, wind speed, daylight, sky and hourly UV retain their row at T. Match timestamps rather than array positions or local wall-clock labels, preserving DST behavior. Missing/ambiguous following-hour accumulations remain unavailable, including the provider's final slot; never borrow a different interval. This changes mapping, not jacket thresholds/grouping or provider request cadence.
- **Weather-cache compatibility:** `WeatherCache` now uses `latestNormalizedForecastV2`; pre-fix `latestNormalizedForecast` entries are not eligible for reuse and are removed on the next successful default-cache save. This prevents the old interval error surviving relaunch. Current-schema payloads can omit new optional weather fields and decode them as nil. Location cache/settings and all freshness/distance/cooldown values are unchanged; injected/custom cache keys do not delete unrelated data.
- Open-Meteo's WMO `weather_code` represents the overall condition: rain/drizzle codes do not independently describe cloudiness. Request/preserve `cloud_cover` with `is_day` and hourly `uv_index` for Sunglasses rather than treating a rain code as missing sky data or inventing cloudiness from the precipitation type. Upstream's own cloud-category ranges are 0–<20% clear, 20–<50% mainly clear, 50–<80% partly cloudy and 80–100% overcast ([pinned source](https://github.com/open-meteo/open-meteo/blob/3a64572c7797738300a5d1d87081a7cbd8f35b3c/Sources/App/Helper/WeatherCode.swift)). These provide a source-backed adapter mapping to the already approved categorical rules, not new item thresholds. Preserve explicit forecast fog/mist and required-signal validity; do not copy upstream visibility-based fog inference into the app. A 24-hour fixed-Brussels-coordinate probe returned non-null arrays for these fields; this is availability evidence for that sample, not app integration or global reliability validation.
- Missing wind/UV preserves the approved base Raincoat/Sunglasses evaluation respectively. Required-input validity and conservative isolated-hour inference remain separate from optional-field absence. Add mapping, cache compatibility and deterministic boundary/fallback tests during implementation; the provider probe recorded in `TODO.md` is not validation of an implemented adapter or production-provider approval.
- D-066 settles missing-required-input handling and non-jacket isolated-gap mapping in `WEATHER_LOGIC.md`. Preserve unavailable inputs through normalization/cache; do not fabricate weather for an inferred hour. Validate per item rather than making every item depend on every weather signal. Available UV does not bypass missing required Sunglasses daylight/sky validity. Existing nullable-field fixtures are defensive coverage, not evidence about live-provider failure rates.
- A widget must use app-owned recommendation/cache contracts; its data sharing, staleness and refresh need a decision before implementation. Do not add background location tracking.
- Custom items remain local-first with minimal, migratable storage; editable item thresholds need defaults and validation. Neither requires accounts/sync.
- Multi-location weather and caches must be location-aware so cities cannot cross-contaminate recommendations; current/active location selection must be deterministic.
- Forecast extensions must define provider limits, temporal boundaries, incomplete-coverage safety and per-location timezones before implementation.
- Recurring schedules do not imply background GPS, server processing or push. Notifications require their own permission/architecture decision; neither implies remote push or background location.

Preserve real-device test evidence and approved cache/provider behavior as the app evolves. Later features are not authorized merely by appearing here.
