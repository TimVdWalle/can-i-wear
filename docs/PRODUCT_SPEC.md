# Can I Wear — Product Specification

> Status: ACTIVE
> Last updated: 2026-10-18
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

Provider-supplied wind speed/gusts may be retained for diagnostics, but wind is not currently a direct recommendation input. Apparent temperature remains the approved temperature input that can reflect wind effects.

## Decision output

The app should communicate:
- whether wearing the leather jacket is recommended;
- when the recommendation changes during the day, if applicable;
- the primary reason.

The primary visual result should be understandable almost immediately.

The Phase 3 single-item Home Screen follows D-046/D-047/D-051 and `UX.md`: a Leather Jacket hero with **YES / MAYBE / NO**, the existing most-protective remaining-day summary, a short data-derived weather reason, daypart cards, and raw hourly suitability with explicit uncertainty/grouping context. **Guided Home** is the default and adds the item-neutral purpose line, **When can I wear it?** context and a concise dismissible explanation. **Compact Home** omits this guidance and retains the denser presentation. These presentation modes do not change weather rules or decide the later multi-item screen.

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
- pull-to-refresh is available from 15 minutes, remains blocked while a request is active, and waits 30 seconds after failure; blocked attempts do not contact the provider and the screen explains the wait.

Incomplete hourly coverage follows the conservative missing-hour policy in [WEATHER_LOGIC.md](WEATHER_LOGIC.md); beyond its single permitted inference, no daily recommendation may be shown.

If location cannot be obtained:
- a recent cached location may be used if it is still considered reliable;
- otherwise do not pretend to know the local weather.

The exact freshness policy is centralized/configurable.

The normal recommendation screen shows concise weather age/update status and a city/locality so the user can verify the forecast context. It does not show an exact street, coordinates, location age, accuracy or cache implementation details.

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

- Support a user-approved predefined collection of items in addition to the original leather jacket; exact set **TBD in Phase 4.1**.
- Each item must have its own appropriate, testable weather recommendation rules; preserve all original leather-protection policy and provenance/cache guardrails.
- Present multiple item recommendations clearly; **overview versus item switching TBD** in Phase 4.1.
- Include an iOS home-screen widget; its form and content remain **TBD in Phase 5.1**.
- Use current device location and today's relevant hours for first release. No user-created items, saved cities, notification feature or editable rules required for release.

## Post-release scope

The approved capabilities, exclusions, provisional ordering and still-open design choices for Phases 8–19 are maintained in [ROADMAP.md](ROADMAP.md). The numbered decision gates and acceptance criteria are in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md). Future scope is not a requirement to implement a feature before its gate is approved.
