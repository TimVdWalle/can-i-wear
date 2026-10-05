# Can I Wear — Project Truth

> Status: ACTIVE
> Last updated: 2026-10-05
> Source of truth: YES

## Purpose

Can I Wear is a simple mobile app that answers:

**Should I wear my leather jacket today, given the weather where I am?**

The main user problem is not personal comfort. It is protecting a leather jacket from rain that can damage or ruin it, while also avoiding clearly excessive heat.

## V1

V1:
- supports a leather jacket only;
- uses the user's current location;
- retrieves weather for that location;
- evaluates the day;
- can split the day into meaningful periods when conditions change;
- prioritizes rain protection;
- uses initial fixed thresholds stored in one centralized configuration;
- has no personal settings;
- gives an immediately understandable recommendation;
- must work on a real iPhone;
- is implemented natively for iOS using Swift + SwiftUI;
- uses a weather service through a thin replaceable provider abstraction; Open-Meteo is the development provider and the production provider remains to be confirmed before distribution;
- treats Android as a later nice-to-have, not a V1 requirement;
- targets App Store delivery.

## Product philosophy

This is a decision app, not a weather dashboard.

The user should not have to study weather information.

The product should answer quickly and correctly:
- Wear
- Avoid
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

## Non-goals for V1

- multiple clothing items;
- personal weather preferences;
- accounts/profiles;
- wardrobe management;
- social features;
- recommendation history;
- background location tracking;
- broad settings.

## Near-term platform features

Notifications and an iOS widget are desired relatively early, after the core real-device weather/recommendation flow is working. Their exact inclusion in V1 is still TBD.

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
