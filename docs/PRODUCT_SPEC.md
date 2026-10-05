# Can I Wear — Product Specification

> Status: ACTIVE
> Last updated: 2026-10-05
> Source of truth: YES

## V1 user story

When I open the app, I want to know quickly whether I should wear my leather jacket today, based on the weather where I am, primarily to avoid exposing the jacket to rain and damaging it.

## Product objective

The app is not trying to tell the user whether they will personally feel comfortable in a jacket.

Its primary job is:

**Protect the leather jacket from weather that can ruin it, while avoiding clearly excessive heat.**

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
- hourly forecast;
- timezone/local time.

## Decision output

The app should communicate:
- whether wearing the leather jacket is recommended;
- when the recommendation changes during the day, if applicable;
- the primary reason.

The primary visual result should be understandable almost immediately.

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

## Personalization

No personal settings in V1.

## Failure behavior

If weather cannot be obtained:
- do not invent a recommendation;
- a recent cached weather result may be used if it is still considered reliable.

If location cannot be obtained:
- a recent cached location may be used if it is still considered reliable;
- otherwise do not pretend to know the local weather.

The exact freshness policy is centralized/configurable.

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
