# Can I Wear — Decisions

> Status: ACTIVE
> Last updated: 2026-10-04
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

### D-017 — Framework and platform implementation
**Decision:** Build V1 as a native iOS app using **Swift + SwiftUI**.

Reason: iOS is the priority, Android is only a nice-to-have, and the product is expected to use Apple-native capabilities such as location, notifications and widgets. Native SwiftUI minimizes platform-integration layers and gives the project the clearest path to a polished iOS UX. The user's limited Swift experience is acceptable because most implementation will be AI-assisted/generated.

Android is not part of the V1 implementation path. It may be reconsidered later without compromising the iOS product.

### D-018 — Weather provider architecture and initial provider
**Decision:** Use **Apple WeatherKit** as the initial weather provider, but isolate it behind our own thin `WeatherProvider` abstraction. The rest of the app must consume a normalized internal weather model and must not depend directly on WeatherKit types.

WeatherKit is the implementation choice for the first working version, not an irreversible product dependency. If another provider later proves better, the provider adapter must be replaceable without changing the jacket decision engine, period logic or UI.

Reason for the abstraction: external weather providers are dependencies, while the leather-jacket recommendation is core product logic and should remain independent of the provider. The thin layer also makes deterministic testing with fake weather straightforward.

## Not yet decided

The following are intentionally NOT decisions:
- exact measurable "few drops" threshold;
- exact dynamic-period grouping parameters;
- whether actual or apparent temperature should dominate;
- exact cache freshness;
- exact UI labels;
- exact UI color palette;
- minimum supported OS versions;
- analytics/telemetry;
- final bundle identifiers.

## Rule for AI

If a change would affect an approved decision above, stop and ask for approval.

If a required detail is not decided, mark it `TBD` or present a proposal. Do not silently choose it.
