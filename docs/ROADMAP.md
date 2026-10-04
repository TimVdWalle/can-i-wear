# Can I Wear — Implementation Phases & Roadmap

> Status: ACTIVE
> Last updated: 2026-10-04
> Source of truth: YES

## Version rule

Until the first working real-phone version exists, the project is V1.

Do not call unfinished work V2, V3, etc.

## Phase 0 — Decisions & technical foundation

Goal:
Lock only the decisions needed to build the first quality version.

Tasks:
- initialize native Swift + SwiftUI Xcode project;
- establish iOS real-device development;
- integrate WeatherKit behind the WeatherProvider abstraction;
- implement current-location acquisition;
- define centralized configuration;
- define exact measurable rain tolerance;
- define dynamic period/noise handling;
- define cache freshness;
- establish test strategy.

Exit:
The first vertical slice can be built without major unresolved product decisions.

## Phase 1 — First real-device vertical slice

Goal:
A real phone can answer the leather-jacket question.

Must include:
- current location;
- weather fetch;
- centralized jacket rules;
- deterministic recommendation;
- basic result UI;
- real-device execution.

Keep it intentionally small.

## Phase 2 — V1 daily intelligence

Goal:
Make the daily recommendation genuinely useful.

Add:
- hourly/day forecast evaluation;
- meaningful dynamic periods;
- rain protection behavior;
- temperature bands;
- conservative noise consolidation;
- safe cache/fallback behavior.

Still V1.

## Phase 3 — V1 polish

Goal:
Remove user friction.

Focus:
- startup speed;
- smooth transitions;
- no unnecessary spinners;
- permission UX;
- clear empty/error states;
- accessibility;
- visual polish;
- edge cases;
- battery behavior.

Still V1.

## Phase 4 — V1 validation

Goal:
Prove the app works in real conditions.

Test:
- multiple locations;
- dry days;
- drizzle;
- normal/heavy rain;
- warm days;
- cool days;
- morning-only rain;
- later-day rain;
- rapidly changing/noisy forecasts;
- weak/no network;
- location failures;
- stale cache;
- multiple real devices.

## Phase 5 — Store readiness

Goal:
Ship V1.

Tasks:
- app icon and metadata;
- privacy information;
- App Store screenshots;
- TestFlight testing;
- App Store review preparation;
- release.

## Early follow-up candidates

Desired relatively early after the core app works, with exact V1 inclusion still TBD:
- iOS widget;
- notifications.

## Later candidates

Not commitments:
- more clothing types;
- personal preferences;
- configurable thresholds;
- wardrobe;
- richer context;
- accounts/sync;
- Android.

These must not leak into the core V1 vertical slice without explicit approval.

## App naming

The official app/product name is **Can I Wear**. It is locked unless explicitly reopened by the user.
