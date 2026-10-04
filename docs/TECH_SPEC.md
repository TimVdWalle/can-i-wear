# Can I Wear — Technical Specification

> Status: ACTIVE
> Last updated: 2026-10-04
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
- native integration is valuable for location, WeatherKit, notifications and widgets;
- SwiftUI provides the shortest path to a polished platform-consistent iOS UX;
- most implementation will be AI-assisted/generated, reducing the cost of the user's limited prior Swift experience.

Android is intentionally outside the V1 implementation path.

## Weather provider

**Initial implementation provider: Apple WeatherKit.**

WeatherKit is not a permanent lock-in and must remain behind our abstraction.

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
WeatherKitAdapter
```

A future provider can implement the same interface:

```text
OtherWeatherProviderAdapter
```

The jacket decision engine, period engine and UI must never consume provider-specific response objects.

WeatherKit is the initial provider because it provides:
- hourly forecasts;
- precipitation chance;
- precipitation amount;
- precipitation type;
- temperature;
- apparent/feels-like temperature;
- up to 500,000 API calls/month included with Apple Developer Program membership.

V1 should use WeatherKit through Apple's native iOS framework. Provider-specific setup, authorization and mapping stay inside the WeatherKit integration layer.

Before treating WeatherKit as final, validate:
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

## Architecture

Keep these components separated:

1. LocationProvider
2. WeatherProvider
3. WeatherCache
4. JacketRulesConfig
5. JacketDecisionEngine
6. DayPeriodEngine
7. Presentation/UI

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

- minimum supported iOS version;
- exact cache freshness;
- exact location accuracy/freshness;
- analytics/telemetry policy;
- final bundle identifiers.
