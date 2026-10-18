# Can I Wear — UX

> Status: ACTIVE
> Last updated: 2026-10-18
> Source of truth: YES

## Core UX goal

The user should understand the recommendation almost immediately.

This is not a weather dashboard. Weather supports a quick **item recommendation**; the original jacket-protection decision remains a particularly important case.

## Desired interaction

1. Open app.
2. App efficiently obtains/uses an appropriate recent location.
3. App efficiently obtains/uses appropriate weather data.
4. Show the recommendation prominently.
5. If the day changes materially, show meaningful periods.
6. Give a very short reason.

The recommendation screen shows a concise locality. Per D-057, it does not show a weather age, update, refresh-availability or saved-weather/cache-status line. Weather provenance remains available in opt-in diagnostics.

The standard pull-down gesture refreshes weather once it is at least 15 minutes old. Pulling sooner, during a request or during the 30-second post-failure cooldown performs no network request. There is no separate Refresh button. Failure states without a usable recommendation retain **Try Again**, with a visible cooldown after a failed retry. The Home Screen omits refresh-availability status per D-057.

## Information hierarchy

1. Item identity — Leather Jacket
2. Today's answer — YES / MAYBE / NO and one data-derived reason
3. Meaningful consolidated periods
4. Hourly suitability

Do not lead with a weather dashboard.

## Visual language

A small number of semantic colors may make the recommendation immediately recognizable.

Approved (D-046/D-047):
- green = YES;
- yellow/orange = MAYBE;
- red = NO.

Use adaptive, accessible shades on soft rounded cards, strong typography and a white/system-adaptive background.

Accessibility must not depend on color alone.

## Approved Home Screen — one item + one location

Visual reference: `design/home-screen-reference.png` (D-046), extended by D-047 and D-051. Header shows **Can I Wear**, current locality and, only while Guided explanation is active, **“Today’s weather, interpreted for each item.”** No temperature/conditions, fake dropdown or settings button. A prominent rounded hero places a bundled leather-jacket illustration on the left and item name, large **YES / MAYBE / NO** status and a short data-derived reason on the right. Do not add a redundant question or Good/Maybe/Skip sentence. At accessibility text sizes the hero may stack to preserve readability. Use the existing most-protective remaining-day summary, never a majority vote or hardcoded optimistic result.

The variants are **Guided Home** (default) and **Compact Home**. Both use the direct status and weather reason without a redundant Good/Maybe/Skip sentence. Guided Home adds the item-neutral purpose line, a **When can I wear it?** heading above dayparts and, when requested, a concise **How it works** card: **“The main result covers today. Dayparts show when it changes, and the reason explains why.”** Tapping **Got it** turns off **Show How It Works**. Turning Guided Home off also turns Show How It Works off; turning Show How It Works on also enables Guided Home. Compact Home omits the purpose, heading and card. Standard-size spacing keeps the primary result and dayparts visible on an iPhone 13; scrolling remains available for details and accessibility layouts.

Immediately below, show actual D-026 periods in **one horizontal row**, scrolling when necessary. Each card contains only a minimal time-of-day icon, label/time range and status. Prefer exact local ranges when a named day-part would imply different boundaries. Do not force four periods. No rain/heat meters, temperatures, start-hour subtitles or explanations inside cards; cards are not buttons.

Daypart YES/MAYBE/NO badges use identical non-shrinking typography and height. For a past daypart, dim the card background, icon, label and time, but keep the status itself at full typographic weight so it does not appear smaller than current or future statuses.

Below a quiet divider, **Hourly suitability** uses small rounded colored segments and a local time axis. These are **raw hourly evaluations**, whereas the cards are consolidated advice. When their levels differ, explain: “Hourly conditions shown; period advice groups brief changes for safety.” Mark an inferred missing/unusable hour with a neutral `?` segment and “? Forecast uncertain”; the daily/period engines retain their approved conservative inference. Do not fill any other gaps. Repeated DST hours must be distinguishable by UTC offset; do not assume 24 hours or the device timezone.

Use text statuses and check/exclamation/cross cues, including on timeline segments, plus per-hour VoiceOver time/status/reason labels. Allow vertical scrolling, Dynamic Type and horizontal overflow without shrinking text to illegibility. At accessibility text sizes, use compact item artwork and place the main status before the explanation so the answer remains prominent. Keep card status words unbroken; scroll the row rather than cramping them. The **Got it** control has at least a 44-point target. Support dark/increased-contrast appearances, introduce no decorative motion, and keep provider attribution below the main content; do not add a weather freshness/status line to the Home Screen (D-057). Preserve opt-in diagnostics and pull-to-refresh.

No comfort meter, chart curve, info button or new detail navigation. Future detail screens and multi-item/multi-location UX remain open.

## Text

Keep text extremely short.

Examples:

**YES**
`Dry and cool`

**NO**
`Rain expected`

These are examples, not final copy.

## Dynamic periods

Example:

Morning
**NO**

11:00 onward
**YES**

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

- labels/palette/layout beyond this approved Home Screen;
- loading presentation;
- stale-data wording;
- permission-denied wording;
- accessibility details.

## Debug diagnostics

Debugging is off by default and enabled through **Debug Enabled** in Apple system Settings. This is separate from the presentation-only **Guided Home** and **Show How It Works** switches. When debugging is enabled, a subtle control on the main screen opens a clean, dismissible diagnostics view; diagnostics must not be mixed into the normal recommendation hierarchy.

The view should be readable rather than a raw log dump: summarize location, weather/cache state, fetch reasons/timing and final periods first, with remaining-hour inputs and the bounded event history available below. It may scroll, so optional provider-supplied wind context does not compete with the recommendation. Place information and the copy-report action must be clearly identified. Exact visual treatment follows the delegated implementation review and Phase 3 polish.

The implemented diagnostic detail view uses compact same-day times, minute-based ages after the first minute, structured period rows and grouped hourly inputs. Only recommendation status text and weather values that cross Caution/Avoid thresholds receive semantic green/orange/red color; labels and reasons preserve meaning without color. The activity history is newest-first and labels category, outcome, detail and duration so it reads as an explanation of app work rather than a raw log.

## Future Home Screen configurations (design principle; layouts TBD)

The Home Screen must eventually support four item/location configurations:

1. **One item, one location** — the approved D-046 reference-based Home Screen (Phase 3).
2. **Multiple items, one location** — planned with predefined multi-item support (Phase 4); the presentation needs separate approval in Phase 4.1.
3. **One item, multiple locations** — part of the future multi-location experience (Phase 10); detailed presentation remains TBD.
4. **Multiple items, multiple locations** — also part of the future multi-location experience (Phase 10); detailed presentation remains TBD.

In every configuration, the primary goal is to tell the user **at a very fast glance whether each relevant item can/should be worn or brought, and when**. Keep recommendation states and timing information consistent and immediately scannable as complexity grows. Reuse visual components and interaction patterns wherever that improves consistency, but **do not force all four configurations into one layout**: separate views or layouts are explicitly acceptable when they improve clarity.

Only the **one-item/one-location** layout is currently approved. The other three are **design scenarios, not approved mockups, interaction choices, or commitments to display all combinations simultaneously**. Their detailed designs remain open for the existing Phase 4.1 and Phase 10.1 decision gates. This principle does not change phase ordering, initial item/location scope, weather/recommendation logic, or the approved single-item Home Screen.

## First-release multi-item and widget UX (not yet implemented)

- The current Phase 3 single-jacket screen is the foundation, not a final multiple-item design.
- In Phase 4.1, obtain explicit user approval for the initial multi-item presentation. The user has **not** chosen between all-item overview, one-item-at-a-time, or another layout.
- In Phase 5.1, select a widget direction. Possibilities expressed by the user: separate item widgets plus an overall widget, **or** a smart combined overview of items and relevant wearing times. Do not assume both are required.
- No invented visual hierarchy or default item selection should be treated as approved ahead of those gates.

## Later multi-location overview UX (Phase 10)

- Search for cities, save favorite cities, use current location automatically, switch destinations and show several relevant locations.
- When multiple locations are displayed, the overview must remain **very clean, immediately scannable, and easy to differentiate by location**.
- The saved-city inclusion model, active/inactive controls, and manual selection behavior remain open until Phase 10.1.
- In the later scheduling phase, show a scheduled city automatically **only on days when its schedule matches**; other saved cities should not be automatically included merely because they are saved. Always retain current-location recommendations where usable. How users manually override that behavior remains open.
- Start with today's forecast. Implement a simple lookahead later and richer horizon configuration later still; do not invent a date-planner UI now.
