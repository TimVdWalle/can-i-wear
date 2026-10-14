# Can I Wear — Product Specification

> Status: ACTIVE
> Last updated: 2026-10-14
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

The Phase 3 single-item Home Screen follows D-046 and `UX.md`: Leather Jacket hero, existing most-protective remaining-day summary, actual consolidated period cards, and raw hourly suitability with explicit uncertainty/grouping context. This presentation approval does not change weather rules or decide the later multi-item screen.

## Initial temperature interpretation

- **15°C or below:** okay.
- **Above 15°C through 20°C:** semi-okay / caution zone.
- **Above 20°C:** definitely too hot.

These are initial rules, not permanent truths. They must be centralized and easy to tune.

Temperature logic may later be refined using apparent temperature and real-world testing.

## Rain interpretation

Rain is the dominant constraint.

- No rain: preferred.
- Any forecast precipitation amount or explicit precipitation type: avoid.
- At 0 mm, a 10% to less than 20% precipitation chance: caution.
- At 0 mm, a 20% or greater precipitation chance: avoid.
- Normal/heavy rain: avoid.
- If rain is expected to materially expose the jacket, the recommendation should be Avoid regardless of otherwise comfortable temperature.

The app should optimize for **not ruining the jacket**, not for maximizing time spent wearing it.

These initial probability thresholds are centralized and may be tuned after real-world validation.

## Fog and mist interpretation

Fog or mist is an Avoid condition because moisture in the air can damage leather. It is a protection rule, not a visibility-comfort rule.

Use only an explicit provider forecast condition identifying fog or mist. For Open-Meteo, WMO weather codes 45 (fog) and 48 (depositing rime fog) are Avoid. Do not infer fog/mist from humidity, dew point or visibility, and do not invent a probability when the provider supplies none. A missing fog/mist-specific signal does not by itself invalidate an otherwise usable hour; existing rain and temperature rules still apply.

The temporary Phase 2 user-facing reason is **“Fog is expected.”** Final reason copy remains part of the Phase 3 presentation review.

## Dynamic day periods

Preferred behavior:
- evaluate the forecast across the relevant part of the day;
- if conditions are effectively the same, show one recommendation;
- if conditions materially change, split the day;
- do not show many tiny alternating periods.

Example:

Morning — AVOID
11:00 onward — WEAR

If a forecast creates noisy alternating hourly results, consolidate them into a larger meaningful period. The safe recommendation should win when rain risk is the meaningful difference.

Initial V1 grouping uses 3 hours for a normal meaningful change. A one-hour Don't wear risk expands into a 2-hour safety period rather than being hidden. Short safer intervals are absorbed into surrounding risk, and repeated hourly alternation is consolidated using the most protective result.

## Personalization

No personal recommendation settings in the original first-release core. Adjustable item thresholds come **after release**, once basic custom items work (Phase 9).

The Apple system Settings app contains one off-by-default **Debug Enabled** technical switch. It only reveals local diagnostics and does not personalize or alter recommendations.

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

For the initial daily evaluation, one isolated unusable hour may be inferred conservatively from valid immediate neighbors and never as better than Caution. Multiple missing hours or an unbounded edge gap produce no daily recommendation.

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
- Include an iOS home-screen widget. Candidate directions: per-item widgets + combined widget, or a smart combined overview with meaningful time windows; exact scope **TBD in Phase 5.1**.
- Use current device location and today's relevant hours for first release. No user-created items, saved cities, notification feature or editable rules required for release.

## Approved post-release capabilities and reserved decisions

| Phase | Capability | Scope constraints / still undecided |
| --- | --- | --- |
| 8 | Create/manage basic custom items | Predefined items remain available; minimal item details, local-first; template and validation TBD |
| 9 | Adjust per-item weather thresholds | Sensible defaults; temperature/rain etc.; exact editor/items TBD |
| 10 | Search/save/select multiple cities, automatic current location, multi-city overview | The overview must be very clean and scannable; active/inactive and default visibility TBD |
| 11 | Simple forecast lookahead extension | Start with today; exact horizon TBD |
| 12 | Recurring location schedules | Weekly weekdays, nth weekday monthly, repeating intervals; only scheduled cities appear automatically on matching days; manual override TBD |
| 13 | Notifications | Optional, after release, may be late; exact timing and order versus Phase 12 TBD |
| 14 | Evaluate later item details/photos and minimal settings needs | Do not assume photos/schema or general settings screen |
| 15 | Flexible horizon/advanced configurable rules | Dedicated later scope; add item-specific weather inputs earlier only as actually needed |
| 16 | Evaluate general personal preferences | Evaluation first, not approved implementation |
| 17 | User-facing recommendation history | Much later, separate from debug log |
| 18 | Accounts and sync | Much later; everything works locally until then |
| 19 | Android | Much later once iOS is mature |

Social features are explicitly excluded. A generic “Should I?”/“Can I?” item classification is optional for later design, not mandated. Exact trip planning, arrivals and date picking are not yet approved.
