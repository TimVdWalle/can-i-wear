# Can I Wear — Weather Logic

> Status: ACTIVE
> Last updated: 2026-10-04
> Source of truth: YES

## Goal

Convert local weather forecast data into a simple leather-jacket recommendation.

The logic should be deterministic, testable and easy to tune.

## Core rule priorities

1. Protect the leather jacket from rain.
2. Avoid clearly excessive heat.
3. Use the daily forecast rather than only current conditions.
4. When conditions materially change, represent the change with meaningful periods.
5. Never invent certainty from missing/stale required data.

## Rain is the primary constraint

The app is fundamentally a leather-jacket protection tool.

A comfortable temperature does not override meaningful rain risk.

Conceptually:

```text
meaningful rain -> AVOID
otherwise -> evaluate temperature
```

"A few drops" is an allowed concept but should be treated conservatively because even rain can damage leather.

The exact numerical threshold for "few drops" is TBD and must be validated against provider data and real-world forecasts.

## Temperature

Initial product rules:

```text
temperature <= 15°C          -> OK
15°C < temperature <= 20°C  -> SEMI_OK / caution
temperature > 20°C           -> TOO_HOT
```

These values are centralized configuration, not literals scattered through the application.

Whether the final comparison uses actual temperature, apparent temperature, or a combination remains a tuning decision. The implementation must make that easy to change.

## Recommendation precedence

Initial conceptual precedence:

1. Data validity
2. Rain protection
3. Excessive heat
4. Temperature comfort/caution

This means:

- Rain + 18°C -> AVOID
- Rain + 12°C -> AVOID
- Dry + 24°C -> AVOID
- Dry + 18°C -> SEMI_OK
- Dry + 12°C -> OK

These examples express the product intent and should become automated tests.

## Day evaluation

1. Get hourly forecast for the relevant local day.
2. Classify each relevant hour.
3. Detect contiguous/meaningful recommendation periods.
4. Suppress noisy rapid alternation.
5. Prefer a conservative larger period when tiny periods alternate between Wear/Avoid.
6. Display only meaningful changes.

Exact grouping parameters are configurable and should be determined through tests.

## Central configuration

All tunable values must live in one concentrated configuration area.

This includes:
- temperature boundaries;
- rain tolerance;
- precipitation probability thresholds, if used;
- minimum meaningful period duration;
- noise/alternation consolidation;
- cache freshness;
- other product-level magic values.

Do not scatter these through UI, networking or domain logic.

## Test cases

At minimum:
- dry + 12°C -> OK;
- dry + 18°C -> SEMI_OK;
- dry + 24°C -> AVOID;
- rain + 12°C -> AVOID;
- rain + 18°C -> AVOID;
- heavy rain + any reasonable temperature -> AVOID;
- morning rain then dry -> meaningful split;
- alternating noisy hourly rain -> consolidated conservative period;
- missing precipitation data;
- missing temperature data;
- stale forecast;
- no location;
- cached recent location/weather.
