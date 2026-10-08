# Can I Wear — Decisions

> Status: ACTIVE
> Last updated: 2026-10-08
> Source of truth: YES

This file records decisions that AI and developers must not casually reopen.

## Approved decisions

### D-001 — V1 clothing scope
**Decision:** V1 supports only a leather jacket.

### D-002 — Location
**Decision:** V1 uses the user's current location.

### D-003 — Daily evaluation
**Decision:** V1 evaluates the day, not only the current weather.

### D-004 — Dynamic periods
**Decision:** The app may split the day into periods when weather materially changes.

### D-005 — Centralized rules
**Decision:** All decision thresholds and other tunable product constants must live in a concentrated configuration area. No scattered magic numbers.

### D-006 — Easy future tuning
**Decision:** V1 uses fixed initial rules, but they must be easy to tune later without hunting through the codebase.

### D-007 — Personalization
**Decision:** No personal settings in V1.

### D-008 — Explanation
**Decision:** The result must communicate more than a bare Yes/No, but must remain extremely quick to understand.

### D-009 — Real device
**Decision:** V1 must run on a real phone.

### D-010 — Platform priority
**Decision:** iOS is mandatory for V1. Android is a later nice-to-have and is not a V1 requirement.

### D-011 — Location battery behavior
**Decision:** The app must not continuously drain battery through location tracking. Location should be requested only as needed.

### D-012 — Rain is the dominant product constraint
**Decision:** The primary purpose is protecting the leather jacket from rain. This is not primarily a comfort app. If meaningful rain is expected, the recommendation should be to avoid the jacket even when temperature would otherwise be comfortable.

### D-013 — Temperature bands
**Decision:** The initial temperature interpretation is:
- 15°C or below: okay;
- above 15°C through 20°C: semi-okay / caution zone;
- above 20°C: definitely too hot.

These are initial product rules and must remain centralized so they can be tuned later.

### D-014 — Rain tolerance
**Decision:** A few drops may be tolerated, but rain can ruin a leather jacket and should therefore generally be avoided. Normal or heavy rain is an immediate avoid condition.

The exact measurable API threshold for "a few drops" remains an implementation/configuration detail to validate.

### D-015 — Dynamic-period simplification
**Decision:** The app must not create many tiny alternating Wear/Avoid periods. Noisy alternating periods should be consolidated into a larger meaningful period, with safety toward avoiding rain.

### D-016 — App name
**Decision:** The official app/product name is **Can I Wear**. Naming is locked unless explicitly reopened by the user.

## Approved technical direction

### D-019 — Development bundle identifier
**Decision:** Use `mobi.vandewalle.caniwear` for development and provider setup. The final App Store bundle identity remains TBD.

### D-020 — Minimum supported iOS version
**Decision:** V1 supports iOS 26.2 and newer.

### D-021 — One-time location acquisition
**Decision:** Request current location at approximately 1 km accuracy, accept a fix with horizontal accuracy within 5 km, stop location updates after success, and report a timeout if an authorized acquisition does not produce a usable fix within 15 seconds.

The iOS when-in-use permission message is: **“Can I Wear uses your location to check local weather and provide today’s recommendation.”**

### D-017 — Framework and platform implementation
**Decision:** Build V1 as a native iOS app using **Swift + SwiftUI**.

Reason: iOS is the priority, Android is only a nice-to-have, and the product is expected to use Apple-native capabilities such as location, notifications and widgets. Native SwiftUI minimizes platform-integration layers and gives the project the clearest path to a polished iOS UX. The user's limited Swift experience is acceptable because most implementation will be AI-assisted/generated.

Android is not part of the V1 implementation path. It may be reconsidered later without compromising the iOS product.

### D-018 — Weather provider architecture and initial provider
**Decision:** Use **Apple WeatherKit** as the initial weather provider, but isolate it behind our own thin `WeatherProvider` abstraction. The rest of the app must consume a normalized internal weather model and must not depend directly on WeatherKit types.

**Development update:** D-022 temporarily supersedes the initial provider for unpaid development. WeatherKit remains the intended production candidate once a paid Apple Developer Program team is available.

WeatherKit remains a production candidate, not an irreversible product dependency. If another provider proves better, replacing the adapter must not require changing the jacket decision engine, period logic or UI.

Reason for the abstraction: external weather providers are dependencies, while the leather-jacket recommendation is core product logic and should remain independent of the provider. The thin layer also makes deterministic testing with fake weather straightforward.

### D-022 — Free development weather provider
**Decision:** Use Open-Meteo’s free open-access API for evaluation and prototyping while WeatherKit is unavailable to the Personal Team. This is not approval to use the free tier for App Store distribution: it is non-commercial, has usage limits and no uptime guarantee. Open-Meteo attribution is required. Reassess the production provider and applicable terms before distribution.

### D-023 — Initial hourly recommendation policy
**Decision:** V1 uses exactly three recommendation levels: **OK**, **Caution**, and **Avoid**.

For each hour:
- any forecast precipitation amount above 0 mm, or a rain, drizzle, snow, sleet, hail or mixed-precipitation type, means **Avoid**;
- with 0 mm forecast, a precipitation chance from 10% up to but not including 20% means **Caution**;
- with 0 mm forecast, a precipitation chance of 20% or more means **Avoid**;
- with 0 mm forecast and less than 10% chance, temperature determines the result;
- temperature uses the warmer of actual and apparent temperature; if only one is available, use it;
- the approved temperature bands remain: 15°C or below is **OK**, above 15°C through 20°C is **Caution**, and above 20°C is **Avoid**;
- when rain and temperature produce different levels, the more protective level wins.

All thresholds remain centralized and tunable. Invalid or insufficient required hourly data must not produce a recommendation.

### D-024 — Initial relevant-day and summary policy
**Decision:** Evaluate only the remaining hours of the forecast location’s current calendar day, from the current local hour through 23:59. For the temporary single-answer vertical slice, the most protective hourly result wins: **Avoid** over **Caution** over **OK**. Phase 2 replaces this coarse answer with meaningful time segments so later weather is not hidden.

For incomplete daily coverage, exactly one isolated unusable/missing hour may be inferred only when valid hours exist immediately before and after it. Use the more protective neighboring result, and never infer better than **Caution**. Two or more missing hours, or a gap at either edge without valid data on both sides, means the forecast is incomplete and no daily recommendation may be produced.

### D-025 — Basic first-slice presentation
**Decision:** The temporary Phase 1 result labels are **Wear**, **Maybe**, and **Don’t wear**. The first working screen checks automatically on launch and presents one system icon, a large result label, a short primary reason and required Open-Meteo attribution.

The approved temporary status copy is: **“Checking today’s weather…”**, **“Location access needed”**, **“Couldn’t get your location”**, **“Weather unavailable”**, and **“Today’s forecast is incomplete”**. Failure states provide a retry action. Final wording, palette and visual treatment remain scheduled for Phase 3 review.

### D-026 — Meaningful period and noise policy
**Decision:** A normal recommendation change must last at least 3 consecutive forecast hours to become a separate period. A one-hour **Don’t wear** result is never hidden; expand it into a 2-hour safety period by including the preceding hour, or the following hour when it occurs at the start of the evaluated window.

A short safer interval must not override surrounding risk. Repeated hour-by-hour alternation is consolidated into one period using the most protective result in the noisy span. The period/noise values remain centralized and tunable.

### D-027 — Freshness, reuse and weather timeout policy
**Decision:** A recent accepted location may be reused for up to and including 30 minutes. A cached forecast may be used only through 30 minutes after it was fetched and, when a fresh location is available, only when its forecast location is within 5 km of that location.

Any valid cached result up to 30 minutes old should appear immediately with its age while a live refresh runs. Fresh data replaces it when available; if refresh fails, the still-valid cached result remains visibly identified as cached. Forecasts older than 30 minutes must not produce a recommendation.

A live weather request may wait at most 10 seconds before falling back to valid cached data or showing an explicit weather failure. The already approved one-time location acquisition timeout remains 15 seconds.

### D-028 — Basic expired-forecast presentation
**Decision:** When a saved forecast is over 30 minutes old, no valid newer forecast is available and live weather fails, keep the Phase 1 title **“Weather unavailable”** and show: **“The saved forecast is too old to use. Connect to the internet and try again.”** The state provides the existing retry action and must not show a recommendation from the expired forecast. Final broader failure-state styling remains part of Phase 3.

### D-029 — Fog and mist are leather hazards
**Decision:** Forecast fog or mist is an **Avoid** condition because atmospheric moisture can damage a leather jacket. Comfortable temperature and otherwise dry precipitation inputs do not override it.

The measurable signal is an explicit provider forecast condition identifying fog or mist. For Open-Meteo, WMO weather codes 45 (fog) and 48 (depositing rime fog) produce Avoid. Do not infer fog/mist from humidity, dew point or visibility, and do not invent a chance-of-mist value when the provider supplies none. If a provider omits the fog/mist-specific signal for an hour, that absence alone does not make the hour unusable and the existing rain and temperature rules still apply. The approved temporary Phase 2 reason is **“Fog is expected.”**; final copy remains part of Phase 3.1.

### D-030 — Opt-in local debug diagnostics
**Decision:** Add one technical setting, **Debug Enabled**, through the Apple system Settings app. It is off by default and is the only app setting initially. This is diagnostic tooling, not a personal recommendation preference.

When enabled, the app exposes a clean, non-intrusive in-app diagnostics view that can be shown and dismissed without changing the recommendation experience. Diagnostics remain on-device and do not approve analytics or telemetry. Keep at most the latest 20 timestamped diagnostic events and clear them when debug is disabled.

Diagnostics cover location/cache source, age, timing, trigger/reason and outcome; weather/cache/provider timing, trigger/reason and outcome; relevant normalized hourly jacket inputs and per-hour/final decisions; resulting periods; and failures/timeouts. Show a reverse-geocoded street when readily available, otherwise city/region, without blocking the recommendation. Include provider-supplied wind information as diagnostic context only; wind does not affect recommendation rules unless separately approved later. Include a user-initiated action to copy the readable local report, and make its place information clear to the user.

## Not yet decided

The following are intentionally NOT decisions:
- exact UI labels;
- exact UI color palette;
- analytics/telemetry;
- final bundle identifiers;

## Rule for AI

If a change would affect an approved decision above, stop and ask for approval.

If a required detail is not decided, mark it `TBD` or present a proposal. Do not silently choose it.
