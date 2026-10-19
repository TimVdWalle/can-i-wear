# Can I Wear — Weather Logic

> Status: ACTIVE
> Last updated: 2026-10-19
> Source of truth: YES

## Goal

Convert local weather forecast data into a simple leather-jacket recommendation.

This is the current leather-jacket rule reference for hourly classification, remaining-day summary and meaningful periods (D-023/D-024/D-026/D-029/D-046/D-055/D-056). The logic should be deterministic, testable and easy to tune. `DECISIONS.md` retains the approval and supersession history.

## Core rule priorities

1. Protect the leather jacket from rain and atmospheric moisture hazards such as fog/mist.
2. Avoid clearly excessive heat.
3. Use the daily forecast rather than only current conditions.
4. When conditions materially change, represent the change with meaningful periods.
5. Never invent certainty from missing/stale required data.

## Rain is the primary constraint

The app is fundamentally a leather-jacket protection tool.

A comfortable temperature does not override meaningful rain risk.

Any forecast precipitation amount above 0 mm, or an explicit rain, drizzle, snow, sleet, hail or mixed-precipitation type, produces **Avoid**. With 0 mm and no type indicating precipitation, probability handles forecast uncertainty: below 10% has no rain effect, 10% through less than 20% produces **Caution**, and 20% or more produces **Avoid**. These initial values remain centralized and tunable. A comfortable temperature cannot override precipitation risk.

## Fog and mist are protection constraints

An hour identified as foggy or misty produces **Avoid**, regardless of temperature or otherwise dry precipitation inputs. The concern is moisture exposure, not reduced visibility.

Use only an explicit provider forecast condition identifying fog or mist. For Open-Meteo, WMO weather codes 45 (fog) and 48 (depositing rime fog) produce Avoid. Do not infer fog/mist from humidity, dew point or visibility, and do not invent a probability when the provider supplies none. If the fog/mist-specific signal is absent, that absence alone has no effect and does not invalidate the hour.

## Temperature

Initial product rules:

```text
temperature <= 15°C          -> OK
15°C < temperature <= 20°C  -> CAUTION
temperature > 20°C           -> AVOID (excessive heat)
```

These values are centralized configuration, not literals scattered through the application.

Use the warmer of actual and apparent temperature. If only one value is available, use it. If neither is available, do not produce an hourly recommendation.

## Required hourly data

An hourly recommendation requires valid, sufficient precipitation amount and probability and at least one usable actual/apparent temperature. A **missing** precipitation type means no type was supplied: it does not block evaluation when those other inputs are valid, so use their amount/chance signals. An explicitly **unknown** type means a supplied condition could not be classified; it might indicate rain or another moisture hazard, so the hour cannot receive a direct recommendation even when amount/chance are present (D-055). Do not guess that unknown means dry. Daily evaluation may still apply D-024's one-isolated-hour conservative inference. An absent fog/mist-specific signal alone does not invalidate an otherwise usable hour.

## Recommendation precedence

The only recommendation levels are **OK**, **Caution** and **Avoid**. Precedence:

1. Data validity: no answer from insufficient required inputs.
2. Precipitation or explicit fog/mist: Avoid regardless of temperature.
3. Excessive heat: Avoid even if precipitation chance alone would produce Caution.
4. Remaining precipitation chance and temperature: use the more protective level.

When results of the same level compete for one displayed reason, choose in this order, highest first: precipitation (including rain), fog/mist, excessive heat, precipitation chance, incomplete forecast, warm temperature, suitable temperature (D-056). This selects a reason; it does not change the recommendation level or let a lower-level rain chance override a higher-level hazard.

This means:

- Rain + 18°C -> AVOID
- Rain + 12°C -> AVOID
- Dry + 24°C -> AVOID
- Dry + 18°C -> CAUTION
- Dry + 12°C -> OK

These examples express the product intent and should become automated tests.

## Day evaluation

1. Evaluate only the forecast location's remaining current calendar day, from its current local hour through day end, using its timezone (including DST boundaries).
2. Classify every relevant hour; an incomplete window follows the missing-hour rule below.
3. The jacket's daily evaluation uses the most-protective hourly result: Avoid over Caution over OK, with the existing approved reason precedence. It is not a majority vote. D-060 changes the Phase 4 Home verdict wording/timing, not this evaluation.
4. Group the hours into meaningful, non-overlapping periods; do not present noisy alternation as many tiny changes.

Normal recommendation changes require 3 consecutive forecast hours to form a separate period. A one-hour Avoid result expands into a 2-hour safety period by including the preceding hour, or the following hour if it is at the start of the evaluated window. Short safer intervals do not override surrounding risk. Repeated hour-by-hour alternation is consolidated into one period using the most protective result in the noisy span. These parameters remain centralized and fixture-tested.

Exactly one isolated missing/unusable hour may be inferred only when it has valid immediate neighbors. Use the more protective neighbor and never infer better than Caution; mark the raw hour uncertain rather than presenting it as observed weather. Two or more gaps or a gap at either edge make the daily forecast incomplete, so no daily recommendation is produced. Meaningful periods are consolidated advice; raw hourly classifications remain distinct.

## Central configuration

All tunable values must live in one concentrated configuration area.

This includes:
- temperature boundaries;
- precipitation amount and probability thresholds;
- minimum meaningful period duration;
- noise/alternation consolidation;
- other product-level magic values.

Do not scatter these through UI, networking or domain logic. Weather/location cache freshness is specified in `PRODUCT_SPEC.md` and its technical contract in `TECH_SPEC.md`.

## Test cases

At minimum:
- dry + 12°C -> OK;
- dry + 18°C -> CAUTION;
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

## Scope of existing rules and later items

All rain, fog/mist, temperature, grouping and precedence thresholds above apply to the **leather jacket**, not automatically to other items. Introduce new weather factors only with approved item-specific policy, provider normalization and deterministic tests; wind remains diagnostic-only for leather unless separately changed. Future item rules and forecast-horizon scope are tracked in [ROADMAP.md](ROADMAP.md).

## Approved Phase 4 temperature rules for other items (D-058)

These rules apply only to the named items; they do not alter Leather Jacket behavior. Use apparent/feels-like temperature when available, otherwise actual temperature.

| Item | YES — good fit | MAYBE — transitional | NO — poor fit |
| --- | --- | --- | --- |
| Warm Coat | ≤5°C | >5°C through 12°C | >12°C |
| Sweater | ≤12°C | >12°C through 18°C | >18°C |
| Gloves | ≤5°C | >5°C through 10°C | >10°C |
| Shorts | ≥22°C | ≥17°C and <22°C | <17°C |

The item-level decision is weather fit: “Is today a good day for [item]?” D-060 approves an explicit daily-verdict presentation, but does not settle how every item's changing hourly bands combine. Do not infer a daily algorithm from these hourly bands or from a proposed group label.

Extend the approved D-024 isolated-gap rule to these items: at most one unusable/missing hour may be inferred, only when valid hours exist immediately before and after it. The inferred result must be conservative and no more favorable than MAYBE. Two or more gaps, or a gap at either edge, makes daily coverage incomplete and produces no daily answer. The exact conservative mapping must respect the item's approved behavior; jacket aggregation must not be assumed for other items.

## Approved Raincoat hourly conditions (D-058/D-062)

Use the forecast rain amount for the hour, forecast chance and optional wind speed. Evaluate in this order:

| Conditions | Hourly advice |
| --- | --- |
| Rain ≥0.5 mm/hour | Useful |
| Otherwise, rain >0 and <0.5 mm/hour, or rain chance ≥30% | Maybe useful |
| No rain forecast and chance <30% | Not needed |

Wind speed ≥30 km/h upgrades a light-rain Maybe useful result to Useful only when the rain amount is positive. Wind without rain, including chance-only uncertainty with no forecast amount, does not cause the upgrade. Missing wind leaves the base rain/chance evaluation unchanged. Rain protection takes priority over warmth; do not use a warm temperature to cancel this need.

Boundary examples: 0.5 mm/hour is Useful; 0.49 mm/hour is Maybe useful without the wind upgrade; 0 mm and exactly 30% chance is Maybe useful; 0 mm and 29% chance is Not needed. Positive light rain with exactly 30 km/h wind is Useful. The previously proposed 2.5 mm/hour cutoff is not approved.

These are rain rules: do not silently treat snow-water equivalent or every precipitation type as liquid rain. Handling other precipitation types is not established by these numeric thresholds.

## Approved Sunglasses hourly conditions (D-058/D-062)

During daylight, use forecast sky conditions as a practical proxy for brightness:

| Sky condition | Hourly advice before UV override |
| --- | --- |
| Clear or mainly clear | Useful |
| Partly cloudy | Maybe useful |
| Overcast or fog | Not needed on the sunshine signal alone |

UV Index ≥6 overrides the cloudiness-based result to Useful. Below 6, UV does not independently upgrade the sky-based advice. If UV is unavailable, use the sky signal alone; no UV value or UV reason may be fabricated. Exactly 6 qualifies; 5.9 does not trigger this override. A clear night is not a sunny interval; do not extend a daytime rule to night or use a whole-day UV maximum as an hourly value.

Sky conditions are not a direct brightness measurement. Do not add humidity, visibility, mountain/snow-glare or altitude heuristics under this approval. Provider signal mappings/validity must be explicit, and missing or unrecognized required signals must not become an assumed overcast/dry/no-need result.

## Phase 4 input gaps and remaining policy scope

Wind is optional for the Raincoat; UV is optional for Sunglasses. Missing required signals follow the approved isolated-hour inference/coverage rule rather than becoming Not needed. The already approved apparent-temperature fallback remains unchanged for the temperature items. Missing-data handling must remain item-specific rather than requiring every item to have every other item's weather inputs.

The initial predefined collection is Leather Jacket, Warm Coat, Sweater, Raincoat, Sunglasses, Shorts and Gloves. Remaining daily policies and unsupported signal/condition cases stay subject to Phase 4.1 approval. Do not apply the jacket's thresholds or rain/fog policies to other items by default.

## Daily behavior versus daily wording (D-060)

The daily presentation contract is maintained in [UX.md](UX.md#phase-4-daily-verdicts-and-timing-d-060). It does not replace item-specific evaluation with one universal level ordering:
- **Leather Jacket:** Any hazardous hour retains its protective daily Avoid result under the existing rules. Describing the restriction and affected times does not remove the hazard, change the most-protective daily result or bypass period expansion/consolidation.
- **Sunglasses:** A qualifying sunny/high-UV hour under D-062 can make them useful today even if other hours do not call for them. This is a usefulness claim with timing, not an all-day suitable/needed claim.
- **Other items and combined conditions:** Their daily policy must be explicit and testable. The previous proposed item-to-group table is not approved. Which condition wins when an item is useful in some hours but unsuitable in others remains open; do not silently use a best-hour/worst-hour/majority algorithm to fill that gap.

All-window suitability and no-need verdicts require the approved coverage/validity checks; missing data is not dry weather, no need, or suitability. The extended isolated-gap inference remains conservative. These decisions do not change existing jacket thresholds, hourly evaluation, reason precedence, cache validity or the remaining-local-day window.
