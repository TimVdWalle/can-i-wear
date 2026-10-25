# Can I Wear — Product Specification

> Status: ACTIVE
> Last updated: 2026-10-25
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

For Leather Jacket, provider-supplied wind speed/gusts remain diagnostic-only; apparent temperature is the approved temperature input that can reflect wind effects. D-062/D-071 approve wind speed as a Raincoat modifier during positive light total precipitation. Raincoat uses hourly total-precipitation amount/chance, including solid/mixed precipitation in water-equivalent millimetres; no separate liquid-rain input is required. Sunglasses additionally needs daylight/sky conditions with optional hourly UV. Detailed item rules are maintained in `WEATHER_LOGIC.md`; these additions do not alter jacket policy.

## Decision output

The app should communicate:
- whether wearing the leather jacket is recommended;
- when the recommendation changes during the day, if applicable;
- the primary reason.

The primary visual result should be understandable almost immediately.

The Phase 3 single-item Home foundation follows D-046/D-047/D-051 and `UX.md`: a Leather Jacket hero, the most-protective remaining-day summary, a short data-derived weather reason, daypart cards, and raw hourly suitability with explicit uncertainty/grouping context. **Guided Home** is the default and adds the item-neutral purpose line, daypart context and a concise dismissible explanation. **Compact Home** omits this guidance and retains the denser presentation. These modes do not change weather rules. Phase 4 keeps that one-item hierarchy while replacing the old universal daily YES/MAYBE/NO with D-060's explicit verdict/timing and adding selected-item Home routing; hourly jacket labels remain unchanged. Actual implementation/verification progress is in `TODO.md`, not inferred from historical Phase 3 evidence.

### Phase 4 daily advice: meaning and time must be explicit (D-060)

**Single-item presentation amendment (D-072):** Restore the earlier artwork-left hero with large YES/MAYBE/NO and a short reason. A small qualifier highlights an exception within displayed dayparts or a qualified brief/uncertain outcome; it is not a recap of every matching period. Omit redundant all-window timing. Detailed schedules remain below; the multi-item overview keeps the explicit-verdict/timing contract. No daily algorithm or item meaning changes.

**Planning-context correction (D-073, all-item clarification):** Every item's single-item Home, overview preview and matching detail shows exactly Morning (06–12) / Afternoon (12–18) / Evening (18–24), subduing past cards instead of removing them. Actual non-jacket advice changes remain identifiable within those cards and hourly detail, not separate wrapping top-level periods. This display context does not contribute past hours to the remaining-day daily answer. Missing earlier inputs cannot invalidate otherwise valid remaining advice or become fabricated past periods.

- Present an item-appropriate daily verdict, relevant times and a short weather reason. The answer must distinguish an item that is useful at some point today from an item that suits the entire evaluated window, and distinguish not needing an item from conditions making it unsuitable.
- Do not present one universal daily YES/NO whose meaning silently changes between items. A positive usefulness verdict does not imply every hour is positive; a restriction verdict must make the affected times clear rather than implying every hour is unsuitable.
- Keep hourly evaluations and meaningful periods available. Hourly answers can retain YES/MAYBE/NO; the new daily copy does not change the approved classification thresholds, time window, conservative missing-hour handling or jacket safety consolidation.
- Use one of the **two approved shared daily aggregation policies (D-063/D-064)**: Can I wear items use the worst hour; Should I wear items need enough useful hours, not merely the best hour. All launch-item assignments are approved in D-065. Do not force one algorithm onto all items or invent a separate daily algorithm per item. The assignments, approved useful-hour threshold and qualified single-hour outcome are maintained in [WEATHER_LOGIC.md](WEATHER_LOGIC.md#two-shared-daily-aggregation-policies-d-063).
- Streamline/reuse presentation wording across both behaviors where it remains clear. Common wording does not mean common aggregation: dayparts/hourly detail explain suitable/unsuitable or useful/not-needed intervals. A positive daily usefulness result is not an all-day suitability claim.
- No visible item-group labels are required to interpret the predefined collection. Fixed-item behavior can be predefined while remaining separable from UI copy; exact grouping labels and the configuration explanation are deferred to custom items in Phase 8.1, not settled by D-059's historical wording.

The presentation contract and representative verdicts are maintained in [UX.md](UX.md#phase-4-daily-verdicts-and-timing-d-060).

**D-074 presentation amendment:** Multi-item overview now uses shorter artwork-left YES/MAYBE/NO heroes, retaining qualified brief/uncertain outcomes and semantic accessibility descriptions. Non-jacket dayparts show one badge: any YES → YES; otherwise any MAYBE → MAYBE; otherwise NO, with missing coverage unavailable. A positive daypart means useful sometime, not all six hours. Exact hours use the same compact segmented timeline as the jacket on single Home/detail. This supersedes stacked within-card intervals and explicit-verdict-only overview layout above; daily policies and the jacket detail remain unchanged.

**D-075 approved overview refinement:** Keep the existing one-item Home; use **A — Mini heroes for 2–3 selected items** and **C — Item gallery for 4+** from `prototypes/multi-item-layouts/`. Match single-item text rather than adding a separate daily-verdict/timing sentence, retain necessary qualifiers, enlarge/balance artwork and remove chevrons without removing full-card detail access. **Every NO is red**, including not-needed advice; this does not redefine not-needed as dangerous or change evaluation. Unavailable advice remains distinct. Presentation/adaptive/accessibility details belong in `UX.md`; existing single-item/detail layouts and recommendation rules remain unchanged. Execution/verification status is in `TODO.md`.

## Leather-jacket recommendation policy

Protect the jacket from precipitation and explicit forecast fog/mist, even when the temperature is comfortable; also avoid excessive heat. Evaluate the remaining local day, show an overall answer and meaningful changes rather than many tiny alternating periods. Do not apply leather thresholds to other items by default.

The complete current hourly thresholds, valid-input requirements, signal interpretation, conservative missing-hour handling, daily summary and period-grouping policy are in [WEATHER_LOGIC.md](WEATHER_LOGIC.md) (D-023/D-024/D-026/D-029/D-046/D-055/D-056). Keep tunable values centralized; changes to approved rules require a new decision.

The approved temporary Phase 2 fog reason is **“Fog is expected.”** Final reason copy remains part of the Phase 3 presentation review.

## Personalization

No personal recommendation settings in the original first-release core. Adjustable item thresholds come **after release**, once basic custom items work (Phase 9).

The Apple system Settings page contains default-on **Guided Home** and **Show How It Works** presentation switches plus an off-by-default **Debug Enabled** technical switch. Guided Home changes explanation density, Show How It Works controls the Guided introduction card and Debug Enabled only reveals local diagnostics. None changes recommendation rules or weather handling.

**Reset Item Setup** in Apple system Settings clears the selected items and replays first-launch item selection when the app next opens or becomes active. Start with no checked items and Continue disabled. This one-shot testing control preserves Home preferences and weather/location caches (D-067's reset selection amendment).

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

For multiple items, D-066 applies this validity check independently: missing required inputs for one item must not suppress another item's usable advice. The permitted inferred hour remains visibly uncertain and never contributes useful time.

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
- Retain the shared weather-fit perspective “Is today a good day for [item]?”. D-072/D-074/D-075 amend D-060's daily presentation to YES/MAYBE/NO with short reasons and necessary qualifiers, preserving distinct daily meaning and detailed timing/accessibility. Each item has appropriate, testable rules; preserve all original leather-protection policy and provenance/cache guardrails.
- D-067 adds first-launch item selection and a header gear reopening focused item configuration. D-075 retains the single-item Home for one selection, uses mini heroes for 2–3 and an item gallery for 4+, showing only selected items. Select a card for matching item detail. Current presentation requirements are maintained above and in `UX.md`; historical prototype samples are not additional product requirements.
- D-070 starts a fresh first launch with no items preselected. Enable Continue only with at least one selected item; the later configuration page also requires at least one selected item before saving. An empty selection cannot be saved.
- The approved hourly rules, daily algorithms, useful-hour minimum, launch assignments, required-input/gap handling, D-069 grouping and D-071 Raincoat total-precipitation scope are in [WEATHER_LOGIC.md](WEATHER_LOGIC.md). Phase 4 presentation/mapping acceptance is complete as recorded in `TODO.md`; settled rules and D-070 selector behavior are not open choices. Deferred manual checks are not claimed as passed.
- Include an iOS home-screen widget; its form and content remain **TBD in Phase 5.1**.
- Use current device location and today's relevant hours for first release. No user-created items, saved cities, notification feature or editable rules required for release.

## Post-release scope

The approved capabilities, exclusions, provisional ordering and still-open design choices for Phases 8–19 are maintained in [ROADMAP.md](ROADMAP.md). The numbered decision gates and acceptance criteria are in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md). Future scope is not a requirement to implement a feature before its gate is approved.
