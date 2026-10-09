# Can I Wear — Technical Specification

> Status: ACTIVE
> Last updated: 2026-10-09
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

**DECIDED: native Swift + SwiftUI for V1.**

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

The jacket decision engine, period engine and UI must never consume provider-specific response objects.

Both evaluated providers supply the required hourly inputs:
- hourly forecasts;
- precipitation chance;
- precipitation amount;
- precipitation type;
- provider fog/mist condition signal where available;
- temperature;
- apparent/feels-like temperature;
- wind speed/gusts as optional diagnostic-only context;
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

No scattered magic numbers.

Infrastructure constants that are not product behavior may remain close to their technical implementation when appropriate.

## Local debug diagnostics

Use a `Settings.bundle` switch backed by app preferences for the sole initial setting, **Debug Enabled**, defaulting to false. Debug state must not alter decision rules, cache validity or normal location/weather request policy.

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
