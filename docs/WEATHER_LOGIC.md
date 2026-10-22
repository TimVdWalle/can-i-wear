# Can I Wear — Weather Logic

> Status: ACTIVE
> Last updated: 2026-10-22
> Source of truth: YES

## Goal

Convert local weather forecast data into clear, item-specific advice while preserving leather-jacket protection.

This is the rule reference for hourly classification, remaining-day summary and meaningful periods. The leather-jacket foundation follows D-023/D-024/D-026/D-029/D-046/D-055/D-056; additional item policies are specified below. Domain implementation/validation status is in `TODO.md`, separate from pending multi-item Home integration. The logic should be deterministic, testable and easy to tune. `DECISIONS.md` retains the approval and supersession history.

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

The item-level decision is weather fit: “Is today a good day for [item]?” D-060 approves explicit daily verdicts; D-063/D-064 settle the two shared daily algorithms below. D-065 assigns all four temperature items to Should I wear: enough useful hours makes the daily result positive even when other hours are a poor fit. Do not invent a separate daily algorithm for each.

Extend the approved D-024 isolated-gap rule to these items: at most one unusable/missing hour may be inferred, only when valid hours exist immediately before and after it. D-066 fixes this inferred result at uncertain/MAYBE for Should I wear items; it is never observed weather or a useful hour. Two or more gaps, or a gap at either edge, makes daily coverage incomplete and produces no daily answer. Leather Jacket retains its own existing conservative neighbor mapping.

## Approved Raincoat hourly conditions (D-058/D-062/D-071)

Use the forecast **total precipitation** amount for the hour, precipitation chance and optional wind speed. Include rain, snow, sleet, hail and mixed precipitation; amounts are in **water-equivalent millimetres**, not snow depth. D-071 extends the original rain-only scope without changing thresholds. Evaluate in this order:

| Conditions | Hourly advice |
| --- | --- |
| Total precipitation ≥0.5 mm/hour | Useful |
| Otherwise, total precipitation >0 and <0.5 mm/hour, or precipitation chance ≥30% | Maybe useful |
| No precipitation forecast and chance <30% | Not needed |

Wind speed ≥30 km/h upgrades a light-precipitation Maybe useful result to Useful only when the total amount is positive. Wind without precipitation, including chance-only uncertainty with zero forecast amount, does not cause the upgrade. Missing wind leaves the base amount/chance evaluation unchanged. Precipitation protection takes priority over warmth; do not use a warm temperature to cancel this need.

Boundary examples: 0.5 mm/hour is Useful for rain or any other precipitation type; 0.49 mm/hour is Maybe useful without the wind upgrade; 0 mm and exactly 30% chance is Maybe useful; 0 mm and 29% chance is Not needed. Positive light precipitation with exactly 30 km/h wind is Useful. The previously proposed 2.5 mm/hour cutoff is not approved.

D-071 deliberately uses total precipitation: do not require a separate liquid-rain amount, exclude solid/mixed precipitation, or add rain/showers/snow amounts on top of a provider total that already includes them. Use valid total amount/chance as the required base signals; wind is optional. Do not invent a snow-depth-to-water conversion when the provider does not supply a valid water-equivalent amount. Missing required data follows D-066, not an assumed dry/no-need result.

Boundary acceptance requires identical water-equivalent amounts across rain, snow, sleet, hail and mixed-precipitation fixtures, plus positive-light-precipitation wind upgrade, wind-only/chance-only non-upgrade and missing-wind fallback. Executed-test evidence is maintained in `TODO.md`, not inferred from these requirements.

## Approved Sunglasses hourly conditions (D-058/D-062)

During daylight, use forecast sky conditions as a practical proxy for brightness:

| Sky condition | Hourly advice before UV override |
| --- | --- |
| Clear or mainly clear | Useful |
| Partly cloudy | Maybe useful |
| Overcast or fog | Not needed on the sunshine signal alone |

UV Index ≥6 overrides the cloudiness-based result to Useful. Below 6, UV does not independently upgrade the sky-based advice. If UV is unavailable, use the sky signal alone; no UV value or UV reason may be fabricated. Exactly 6 qualifies; 5.9 does not trigger this override. A clear night is not a sunny interval; do not extend a daytime rule to night or use a whole-day UV maximum as an hourly value.

Sky conditions are not a direct brightness measurement. Do not add humidity, visibility, mountain/snow-glare or altitude heuristics under this approval. Provider signal mappings/validity must be explicit, and missing or unrecognized required signals must not become an assumed overcast/dry/no-need result. D-066 requires valid daylight/sky signals before evaluation; available UV does not rescue an hour lacking those required signals.

## Phase 4 input gaps and remaining policy scope

Wind is optional for the Raincoat; UV is optional for Sunglasses. Missing required signals follow the D-066 isolated-hour inference/coverage rule rather than becoming Not needed. The already approved apparent-temperature fallback remains unchanged for the temperature items. Missing-data handling remains item-specific: lack of one item's required signal must not prevent advice for another item with sufficient inputs.

The initial predefined collection is Leather Jacket, Warm Coat, Sweater, Raincoat, Sunglasses, Shorts and Gloves. D-071 settles Raincoat's total-precipitation scope; it is no longer an open Phase 4.1 policy. D-063–D-066 settle the daily algorithms, useful-hour minimum, launch assignments and required-input/gap handling; D-069 settles non-jacket grouping. Provider mappings must faithfully preserve these approved signals; genuinely undefined behavior, if found, still requires clarification rather than invented rules. Do not apply the jacket's thresholds or rain/fog policies to other items by default.

## Two shared daily aggregation policies (D-063)

**Approved Phase 4 domain contract; multi-item Home integration remains separate. D-064 amends the Should I wear trigger below; “best hour wins” is superseded.** Classify hours using item-specific weather rules, then choose the daily result with one of two shared policies:

| Behavior | Daily selection | Meaning |
| --- | --- | --- |
| **Can I wear** — worst hour wins | Any NO → NO; otherwise any MAYBE → MAYBE; otherwise YES. | Any unsuitable hour makes the overall day not OK. A wholly positive answer requires all evaluated hours to be suitable. |
| **Should I wear** — enough useful hours (D-064) | At least 2 directly evaluated YES hours → positive daily advice; exactly 1 → qualified brief-usefulness advice; 0 YES with any MAYBE → MAYBE; otherwise NO. | Enough useful time makes the day a good day to use the item. A lone useful hour remains visible but does not yield the normal positive-day verdict. NO means not needed, not hazardous. |

YES/MAYBE/NO here describe semantic levels, **not approved final daily UI strings**. Should I wear also retains the qualified single-hour outcome; do not flatten it into the normal positive or not-needed result. Leather Jacket retains its existing OK/Caution/Avoid domain levels and protective reason precedence; in this table they correspond to YES/MAYBE/NO respectively. Hourly Useful/Maybe useful/Not needed correspond to YES/MAYBE/NO for usefulness evaluation.

**Approved launch-item assignments (D-065):**

| Item | Daily algorithm |
| --- | --- |
| Leather Jacket | Can I wear |
| Warm Coat | Should I wear |
| Sweater | Should I wear |
| Gloves | Should I wear |
| Shorts | Should I wear |
| Raincoat | Should I wear |
| Sunglasses | Should I wear |

All six Should I wear items use the same daily aggregation policy above, applied to their own hourly thresholds. No launch-item assignment remains open; the approved hourly thresholds stay unchanged.

**Shared flow and safeguards:**
- Use the same remaining-local-day window, validated normalized inputs and coverage checks before either aggregation. The useful-hour count never bypasses an incomplete forecast, even when the positive threshold has already been reached.
- Missing/unusable data is not NO, not dry weather and not a positive qualifying hour. Under D-066, the single permitted isolated gap is always uncertain/MAYBE for Should I wear, regardless of neighboring levels. Valid immediate neighbors remain required. It never counts toward the useful-hour minimum; keep the missing-weather reason distinct from a directly evaluated borderline-weather reason. Leather Jacket's existing neighbor mapping remains unchanged.
- For Should I wear, centralize the initial **2-useful-forecast-hour minimum** (D-064). Count distinct directly evaluated YES hours within the existing remaining-day window, whether consecutive or separated by NO/MAYBE hours. Do not count past hours, duplicate records, MAYBE or inferred hours toward the minimum, lower it when only one hour remains, or replace it with a majority/average/day-percentage rule. This counts forecast hours under the existing current-local-hour window, not a newly introduced minute-level duration calculation.
- Exactly one qualifying hour produces qualified brief-usefulness advice with that time. With no qualifying hours, preserve the existing MAYBE-if-borderline / otherwise-not-needed distinction; the useful-hour threshold does not turn borderline hours into YES.
- Do not invert hourly thresholds or raw weather values to implement the two algorithms. Item-specific hourly classification and shared daily aggregation are separate operations.
- Keep daily aggregation separate from period grouping. Use D-069's contiguous grouping below for all six Should I wear items, not jacket safety expansion/noise rules. Grouping must neither erase useful hours nor create additional ones; jacket grouping is unchanged.
- Dayparts/hourly output retain the actual changes: a negative protective day can contain suitable periods, and a positive usefulness day can contain not-needed periods. Neither daily result is an assertion that every hour has that level.

### Daily acceptance examples

Assume complete, valid remaining-day coverage; these sequences are illustrative levels, not live forecasts or new weather thresholds.

| Hourly sequence | Can I wear daily result | Should I wear daily result |
| --- | --- | --- |
| YES, YES, YES | YES | YES |
| YES, NO, YES | NO | YES |
| NO, NO, YES, NO | NO | Briefly useful — one useful hour is below the daily threshold |
| NO, YES, NO, YES | NO | Positive — two useful hours need not be consecutive |
| NO, YES, YES, NO | NO | Positive — exactly two consecutive useful hours qualify |
| YES, MAYBE, NO | NO | Briefly useful — MAYBE does not count as a second useful hour |
| YES, MAYBE, YES | MAYBE | YES |
| NO, MAYBE, NO | NO | MAYBE |
| MAYBE, MAYBE, MAYBE | MAYBE | MAYBE |
| NO, NO, NO | NO | NO — not needed, not unsafe |
| YES (only one hour remains) | YES | Briefly useful — do not lower the minimum at day end |
| YES, inferred MAYBE, NO | NO | Briefly useful — inference is not a second useful hour |
| YES, inferred MAYBE, YES | MAYBE | Positive — 2 confirmed useful hours; middle hour remains uncertain |
| NO, inferred MAYBE, NO | NO | Qualified/uncertain MAYBE — do not assume the gap means no need |
| Incomplete coverage beyond the permitted inference | No daily answer | No daily answer, even with 2 known YES hours |

These are acceptance requirements; actual implementation/test evidence is recorded in `TODO.md`. Apply the Can I wear column to Leather Jacket and the Should I wear column independently to each of the other six catalog items, using valid item-specific weather fixtures. In particular, mixed warm/cold temperature hours or alternating rain/dry hours must not silently switch a Should I wear item to jacket-style worst-hour aggregation.

For D-066, additionally test missing required Sunglasses daylight/sky with available UV, unchanged optional wind/UV fallbacks, edge/multiple-gap rejection and independent item availability. These are defensive acceptance cases, not claims that live weather failures have been observed.

## Should I wear period grouping (D-069)

**Approved Phase 4 domain contract; multi-item Home integration remains separate.** For each of the six Should I wear items:
- Group adjacent, temporally consecutive evaluated hours with the same advice level into one period. Preserve actual time boundaries and ordered, non-overlapping coverage; do not bridge a different-level hour or erase an inferred hour's uncertainty.
- Keep a one-hour useful interval visible. Do not expand it, absorb it into its neighbors, require a three-hour change, or smooth alternation using the jacket's safety policy. A sequence of changes can therefore produce several short periods; scrolling is preferable to fabricated advice.
- Keep the daily calculation independent: D-064 counts directly evaluated useful hours, including separate intervals, before presentation grouping. Never count a period's display width or a safety-expanded span as useful forecast hours.
- Retain per-hour inputs/reasons and D-066 uncertainty identity; grouping is not permission to fabricate a common weather reason or treat inferred MAYBE as observed weather.

Leather Jacket continues using the already approved D-026 safety expansion, noise consolidation and protective grouping. No existing jacket behavior changes.

### Period acceptance examples

Assume consecutive hourly slots with valid coverage unless an allowed inferred gap is explicitly shown. Numbers below are forecast-hour counts, not new policy thresholds.

| Hourly advice | Should I wear periods | Daily result |
| --- | --- | --- |
| YES, YES, YES | YES ×3 | Positive |
| YES, YES, NO, YES | YES ×2; NO ×1; YES ×1 | Positive; preserve the final useful hour |
| YES, NO, YES | YES ×1; NO ×1; YES ×1 | Positive; 2 separate useful hours qualify |
| NO, YES, NO | NO ×1; YES ×1; NO ×1 | Briefly useful; do not expand the useful hour |
| MAYBE, MAYBE, NO | MAYBE ×2; NO ×1 | MAYBE |
| YES, inferred MAYBE, YES | YES ×1; uncertain MAYBE ×1; YES ×1 | Positive from 2 confirmed hours; do not merge across the gap |

These are deterministic acceptance requirements. Implementation progress and executed-test evidence belong in `TODO.md`, not this policy table.

## Fixed daypart display summaries (D-074)

This is a presentation summary, not a replacement for either daily algorithm or D-069 periods. For the six Should I wear items, a fully covered fixed daypart displays YES if any directly evaluated hour is YES; otherwise MAYBE if any hour is MAYBE (including the permitted uncertain inference); otherwise NO. One useful hour is enough for the daypart badge, but still only brief-usefulness advice for the daily answer when it is the only remaining useful hour. Missing coverage remains unavailable. Raw hours retain actual classifications, reasons and uncertainty; Leather Jacket daypart evaluation is unchanged.

## Daily behavior versus daily wording (D-060)

The daily presentation contract is maintained in [UX.md](UX.md#phase-4-daily-verdicts-and-timing-d-060). Shared wording/layout does not replace the two algorithms above with one universal ordering:
- **Leather Jacket:** Any hazardous hour retains its protective daily Avoid result under the existing rules. Describing the restriction and affected times does not remove the hazard, change the most-protective daily result or bypass period expansion/consolidation.
- **Sunglasses:** At least 2 useful sunny/high-UV hours under D-062/D-064 support a positive daily usefulness result, even when other hours do not call for them. One useful hour gets brief-usefulness advice with its time. Neither is an all-day suitable/needed claim.
- **Other items:** Use D-065's explicit assignments above. Mixed hours follow the shared enough-useful-hours policy for Warm Coat, Sweater, Gloves, Shorts and Raincoat; these assignments and algorithms are not open per-item choices to redesign. No third/combined algorithm or historical proposed “Both” assignment is approved.

All-window suitability and no-need verdicts require the approved coverage/validity checks; missing data is not dry weather, no need, or suitability. The extended isolated-gap inference remains conservative. These decisions do not change existing jacket thresholds, hourly evaluation, reason precedence, cache validity or the remaining-local-day window.
