# Can I Wear — Weather Logic

> Status: ACTIVE
> Last updated: 2026-10-08
> Source of truth: YES

## Goal

Convert local weather forecast data into a simple leather-jacket recommendation.

The logic should be deterministic, testable and easy to tune.

## Core rule priorities

1. Protect the leather jacket from rain and atmospheric moisture hazards such as fog/mist.
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

Even the smallest forecast precipitation amount or explicit precipitation type produces **Avoid**. When the forecast amount is 0 mm, probability handles forecast uncertainty: below 10% has no rain effect, 10% through less than 20% produces **Caution**, and 20% or more produces **Avoid**. These initial values remain centralized and tunable.

## Fog and mist are protection constraints

An hour identified as foggy or misty produces **Avoid**, regardless of temperature or otherwise dry precipitation inputs. The concern is moisture exposure, not reduced visibility.

Use only an explicit provider forecast condition identifying fog or mist. For Open-Meteo, WMO weather codes 45 (fog) and 48 (depositing rime fog) produce Avoid. Do not infer fog/mist from humidity, dew point or visibility, and do not invent a probability when the provider supplies none. If the fog/mist-specific signal is absent, that absence alone has no effect and does not invalidate the hour.

## Temperature

Initial product rules:

```text
temperature <= 15°C          -> OK
15°C < temperature <= 20°C  -> SEMI_OK / caution
temperature > 20°C           -> TOO_HOT
```

These values are centralized configuration, not literals scattered through the application.

Use the warmer of actual and apparent temperature. If only one value is available, use it. If neither is available, do not produce an hourly recommendation.

## Recommendation precedence

Initial conceptual precedence:

1. Data validity
2. Rain/fog/mist protection
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

Normal recommendation changes require 3 consecutive forecast hours to form a separate period. A one-hour Avoid result expands into a 2-hour safety period, preferably including the preceding hour. Short safer intervals do not override surrounding risk. Repeated hour-by-hour alternation is consolidated into one period using the most protective result in the noisy span. These parameters remain centralized and fixture-tested.

For the temporary single-answer vertical slice, evaluate the current local hour through the end of the forecast location's calendar day and return the most protective hourly result. Phase 2 replaces this coarse result with meaningful periods.

One isolated missing/unusable hour may be inferred only when it has valid immediate neighbors. Use the more protective neighbor and never infer better than Caution. Multiple gaps or a gap at either edge make the daily forecast incomplete, so no daily recommendation is produced.

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
- forecast fog/mist + any reasonable temperature -> AVOID;
- missing fog/mist signal with otherwise valid inputs -> use the existing rain/temperature result;
- morning rain then dry -> meaningful split;
- alternating noisy hourly rain -> consolidated conservative period;
- missing precipitation data;
- missing temperature data;
- stale forecast;
- no location;
- cached recent location/weather.
