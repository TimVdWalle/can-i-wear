# Can I Wear — Project Truth

> Status: ACTIVE
> Last updated: 2026-10-13
> Source of truth: YES

## Purpose

Can I Wear is a simple, recommendation-first mobile app answering weather-based questions about **items**. Its **first real-device milestone** focuses on “Can I wear my leather jacket today?” The broader app supports other predefined items by the first public release, and custom items later. “Can I?” and “Should I wear/bring?” are possible item semantics, not a design distinction we must settle now.

For the leather jacket specifically, the main concern is avoiding rain/fog damage and excessive heat, not maximizing comfort.

## Original leather-jacket foundation (Phases 0–3)

The initial vertical slice and its already approved rules:
- supports a leather jacket only;
- uses the user's current location;
- retrieves weather for that location;
- evaluates the day;
- can split the day into meaningful periods when conditions change;
- prioritizes rain protection;
- treats forecast fog/mist as an avoid condition because atmospheric moisture can damage leather;
- uses initial fixed thresholds stored in one centralized configuration;
- has no personal recommendation settings;
- has default-on Guided Home and Show How It Works presentation switches and an off-by-default Debug Enabled switch in Apple system Settings;
- gives an immediately understandable recommendation;
- must work on a real iPhone;
- is implemented natively for iOS using Swift + SwiftUI;
- uses a weather service through a thin replaceable provider abstraction; Open-Meteo is the development provider and the production provider remains to be confirmed before distribution;
- defers Android until the mature-iOS stage;
- targets App Store delivery.

## Product philosophy

This is a decision app, not a weather dashboard.

The user should not have to study weather information.

The product should answer quickly and correctly:
- Yes
- Maybe
- No
- or a small number of meaningful periods

with a very short reason.

## Primary product rule

**Rain protection beats comfort.**

The jacket should not be recommended simply because the temperature is good if meaningful rain is expected.

## Initial temperature interpretation

- <=15°C: okay
- >15°C and <=20°C: semi-okay/caution
- >20°C: definitely too hot

These values are configurable and may be tuned after real-world testing.

## Quality bar

The project is judged by the final user experience:
- correct recommendations;
- reliable weather/location;
- real-device reliability;
- fast startup;
- no unnecessary delays;
- no stutters;
- no annoying permission flows;
- no micro-frustrations;
- strong automated tests;
- successful App Store delivery.

## First public release and deferred features

The first App Store release (Phases 4–7) **adds multiple predefined items and the iOS widget** to the already working leather-jacket foundation. The initial item collection, item-specific rules, multi-item screen and exact widget form are subject to user approval in Phases 4–5.

**Not required for the first public release:**
- custom/user-created items;
- multiple saved cities and recurring location schedules;
- notifications;
- adjustable per-item thresholds;
- recommendation history, accounts/sync or Android.

**Original core milestone non-goals (historical context):**
- multiple clothing items;
- personal weather preferences;
- accounts/profiles;
- wardrobe management;
- social features;
- recommendation history;
- background location tracking;
- broad settings.

The approved Guided Home and Show How It Works display preferences plus the technical debug switch form a focused system Settings surface; none alters recommendation policy.

## Future product scope

After release, the approved priority sequence begins **basic custom items → editable thresholds → saved/multiple locations → simple forecast extension**. Recurring location schedules and notifications are later, with their relative ordering still open. Additional item details/photos, advanced rules/flexible horizons, preference evaluation, user-facing history, accounts/sync and Android have explicit later phases. Social features are excluded. See [ROADMAP.md](ROADMAP.md).

## Product name

**Can I Wear** is the locked official product/app name.

## Truth hierarchy

When sources conflict:
1. Approved decisions in `DECISIONS.md`
2. Current requirements in `PRODUCT_SPEC.md`
3. Technical constraints in `TECH_SPEC.md`
4. Weather logic in `WEATHER_LOGIC.md`
5. UX guidance in `UX.md`
6. Roadmap/TODO

AI must not convert a proposal or assumption into a decision.
