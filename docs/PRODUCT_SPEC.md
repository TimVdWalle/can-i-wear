# Can I Wear — Product Specification

> Status: ACTIVE
> Last updated: 2026-10-19
> Source of truth: YES

## Initial real-device user story (historical foundation)

When I open the app, I want to know quickly whether I should wear my leather jacket today, based on the weather where I am, primarily to avoid exposing the jacket to rain and damaging it.

## Product objective

The app recommends whether weather suits particular **items**, without turning into a weather dashboard. The original leather-jacket decision remains protective rather than primarily about personal comfort:

**Protect the leather jacket from weather that can ruin it, while avoiding clearly excessive heat.**

The jacket rules below are specific to leather, **not** defaults for every future clothing/accessory item.

## Required inputs

### Location
Use the device's current location.

Requirements:
- accurate enough to select the appropriate local weather forecast;
- obtained without continuous location tracking;
- fast enough that normal app startup does not feel blocked unnecessarily;
- if a sufficiently recent location can safely be reused, it may be used instead of obtaining a new fix.

Exact freshness policy is intentionally configurable and can be tuned later.

### Weather
The weather data must support at least:
- temperature;
- apparent/feels-like temperature;
- precipitation amount;
- precipitation/rain type;
- precipitation timing/probability;
- forecast fog/mist condition when the provider supplies it;
- hourly forecast;
- timezone/local time.

Weather reuse and refresh policy:
- under 15 minutes old: use matching valid saved weather without fetching;
- from 15 minutes through exactly 90 minutes: show saved weather immediately and refresh;
- over 90 minutes: do not recommend from saved weather; fetch current weather;
- apply the policy at launch, on foreground activation and when an active screen crosses a boundary;
- never run concurrent weather requests.

For Leather Jacket, provider-supplied wind speed/gusts remain diagnostic-only; apparent temperature is the approved temperature input that can reflect wind effects. D-062 separately approves wind speed as a Raincoat modifier during forecast light rain. Phase 4 also needs hourly liquid-rain/chance inputs for Raincoat and daylight/sky conditions with optional hourly UV for Sunglasses. The detailed item rules are maintained in `WEATHER_LOGIC.md`; these additions do not alter jacket policy.

## Decision output

The app should communicate:
- whether wearing the leather jacket is recommended;
- when the recommendation changes during the day, if applicable;
- the primary reason.

The primary visual result should be understandable almost immediately.

The implemented Phase 3 single-item Home Screen follows D-046/D-047/D-051 and `UX.md`: a Leather Jacket hero with **YES / MAYBE / NO**, the existing most-protective remaining-day summary, a short data-derived weather reason, daypart cards, and raw hourly suitability with explicit uncertainty/grouping context. **Guided Home** is the default and adds the item-neutral purpose line, **When can I wear it?** context and a concise dismissible explanation. **Compact Home** omits this guidance and retains the denser presentation. These presentation modes do not change weather rules. For Phase 4, D-060 replaces the universal daily YES/MAYBE/NO presentation with the explicit verdict and timing requirements below; the Phase 3 evidence is not evidence that this new presentation is implemented.

### Phase 4 daily advice: meaning and time must be explicit (D-060)

- Present an item-appropriate daily verdict, relevant times and a short weather reason. The answer must distinguish an item that is useful at some point today from an item that suits the entire evaluated window, and distinguish not needing an item from conditions making it unsuitable.
- Do not present one universal daily YES/NO whose meaning silently changes between items. A positive usefulness verdict does not imply every hour is positive; a restriction verdict must make the affected times clear rather than implying every hour is unsuitable.
- Keep hourly evaluations and meaningful periods available. Hourly answers can retain YES/MAYBE/NO; the new daily copy does not change the approved classification thresholds, time window, conservative missing-hour handling or jacket safety consolidation.
- Use the item-specific daily policy, not a universal best-hour/worst-hour algorithm. Jacket hazards remain protective; sunglasses may be useful for a sunny interval even if unnecessary elsewhere. Policies for conflicting usefulness/unsuitability within the same item remain to be approved.
- No visible item-group labels are required to interpret the predefined collection. Fixed-item behavior can be predefined while remaining separable from UI copy; exact grouping labels and the configuration explanation are deferred to custom items in Phase 8.1, not settled by D-059's historical wording.

The presentation contract and representative verdicts are maintained in [UX.md](UX.md#phase-4-daily-verdicts-and-timing-d-060).

## Leather-jacket recommendation policy

Protect the jacket from precipitation and explicit forecast fog/mist, even when the temperature is comfortable; also avoid excessive heat. Evaluate the remaining local day, show an overall answer and meaningful changes rather than many tiny alternating periods. Do not apply leather thresholds to other items by default.

The complete current hourly thresholds, valid-input requirements, signal interpretation, conservative missing-hour handling, daily summary and period-grouping policy are in [WEATHER_LOGIC.md](WEATHER_LOGIC.md) (D-023/D-024/D-026/D-029/D-046/D-055/D-056). Keep tunable values centralized; changes to approved rules require a new decision.

The approved temporary Phase 2 fog reason is **“Fog is expected.”** Final reason copy remains part of the Phase 3 presentation review.

## Personalization

No personal recommendation settings in the original first-release core. Adjustable item thresholds come **after release**, once basic custom items work (Phase 9).

The Apple system Settings page contains default-on **Guided Home** and **Show How It Works** presentation switches plus an off-by-default **Debug Enabled** technical switch. Guided Home changes explanation density, Show How It Works controls the Guided introduction card and Debug Enabled only reveals local diagnostics. None changes recommendation rules or weather handling.

## Local debug diagnostics

When enabled, diagnostics should make a recommendation and its data flow explainable without intruding on the normal experience. They include:
- the latest place used for weather, preferring street when readily available and otherwise city/region;
- location source, reading/fetch time, age, accuracy, cache status and reason for reuse or acquisition;
- weather provider, fetch time, request reason/outcome, cache age/status and location matching;
- remaining-day actual/apparent/selected temperature, precipitation amount/type/chance, fog/mist signal and informational wind when supplied;
- per-hour recommendation/reason, final periods and relevant failures/timeouts;
- a bounded local history of the latest 20 diagnostic events.

Turning debug off clears retained diagnostics. A deliberate copy action may copy a readable report containing the displayed place information. Debugging remains local and does not settle the separate telemetry-policy TBD.

## Failure behavior

If weather cannot be obtained:
- do not invent a recommendation;
- a recent cached weather result may be used if it is still considered reliable.
- if the saved forecast is over 90 minutes old and live weather fails, show **“Weather unavailable”** with **“The saved forecast is too old to use. Connect to the internet and try again.”** and provide retry without showing the expired recommendation.
- pull-to-refresh is available from 15 minutes, remains blocked while a request is active, and waits 30 seconds after failure; blocked attempts do not contact the provider. Per D-057, the Home Screen does not display a weather age/update/refresh-availability status line.

Incomplete hourly coverage follows the conservative missing-hour policy in [WEATHER_LOGIC.md](WEATHER_LOGIC.md); beyond its single permitted inference, no daily recommendation may be shown.

If location cannot be obtained:
- a recent cached location may be used if it is still considered reliable;
- otherwise do not pretend to know the local weather.

The exact freshness policy is centralized/configurable.

The normal recommendation screen shows a city/locality so the user can verify the forecast context, but no weather age, update, refresh-availability or cache-status line (D-057). Exact street, coordinates, location age, accuracy and cache implementation details remain hidden from the normal screen; relevant provenance remains in local diagnostics.

## Quality requirements

Success is primarily judged by:
- correct recommendation;
- reliable weather/location behavior;
- real-device performance;
- smooth UX;
- no unnecessary delays;
- no annoying permission/request behavior;
- no stutters;
- no micro-frustrations;
- good tests;
- successful App Store delivery.

Implementation details are secondary to these outcomes.

## First public release: multiple predefined items and widget (Phases 4–7)

- The approved initial seven-item collection is Leather Jacket, Warm Coat, Sweater, Raincoat, Sunglasses, Shorts and Gloves (D-058).
- Retain the shared weather-fit perspective “Is today a good day for [item]?”, expressed through explicit daily verdicts and timing (D-060), not a universal daily YES/MAYBE/NO label. Each item has its own appropriate, testable rules; preserve all original leather-protection policy and provenance/cache guardrails.
- The approved main presentation is a compact overview showing item answers together, with item detail available on selection. Detailed layout remains subject to UX implementation review.
- The approved initial temperature bands/input selection and the D-062 Raincoat/Sunglasses hourly conditions and optional-input fallbacks are in [WEATHER_LOGIC.md](WEATHER_LOGIC.md). Remaining item policies and unsupported cases are still gated in Phase 4.1; the explicit daily-verdict/timing approach is already approved.
- Include an iOS home-screen widget; its form and content remain **TBD in Phase 5.1**.
- Use current device location and today's relevant hours for first release. No user-created items, saved cities, notification feature or editable rules required for release.

## Post-release scope

The approved capabilities, exclusions, provisional ordering and still-open design choices for Phases 8–19 are maintained in [ROADMAP.md](ROADMAP.md). The numbered decision gates and acceptance criteria are in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md). Future scope is not a requirement to implement a feature before its gate is approved.
