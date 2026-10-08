# Can I Wear — UX

> Status: ACTIVE
> Last updated: 2026-10-08
> Source of truth: YES

## Core UX goal

The user should understand the recommendation almost immediately.

This is not a weather app. Weather is supporting information for a jacket-protection decision.

## Desired interaction

1. Open app.
2. App efficiently obtains/uses an appropriate recent location.
3. App efficiently obtains/uses appropriate weather data.
4. Show the recommendation prominently.
5. If the day changes materially, show meaningful periods.
6. Give a very short reason.

## Information hierarchy

1. Wear / Avoid
2. Time period, if relevant
3. Main reason, especially rain
4. Supporting weather information

Do not lead with a weather dashboard.

## Visual language

A small number of semantic colors may make the recommendation immediately recognizable.

Candidate:
- green = Wear;
- yellow/orange = caution;
- red = Avoid.

This is approved as a direction, but exact palette/design remains a design task.

Accessibility must not depend on color alone.

## Text

Keep text extremely short.

Examples:

**WEAR**
`Dry and cool`

**AVOID**
`Rain expected`

These are examples, not final copy.

## Dynamic periods

Example:

Morning
**AVOID**

11:00 onward
**WEAR**

Do not render many tiny alternating periods. Consolidate noisy forecasts into meaningful periods.

## UX quality requirements

Avoid:
- unnecessary spinners;
- blocking the first frame;
- repeated permission prompts;
- unnecessary location requests;
- unnecessary network requests;
- layout jumps;
- stutters;
- tiny interaction targets;
- long explanations.

## Failure states

If the app cannot make a trustworthy recommendation, say so clearly.

Never display a confident recommendation from missing data.

Recent cached data may be used according to the centralized freshness policy.

## Open UX decisions

- exact labels;
- exact color palette;
- final layout;
- loading presentation;
- stale-data wording;
- permission-denied wording;
- accessibility details.

## Debug diagnostics

Debugging is off by default and enabled through the app's single switch in Apple system Settings. When enabled, a subtle control on the main screen opens a clean, dismissible diagnostics view; diagnostics must not be mixed into the normal recommendation hierarchy.

The view should be readable rather than a raw log dump: summarize location, weather/cache state, fetch reasons/timing and final periods first, with remaining-hour inputs and the bounded event history available below. It may scroll, so optional provider-supplied wind context does not compete with the recommendation. Place information and the copy-report action must be clearly identified. Exact visual treatment follows the delegated implementation review and Phase 3 polish.
