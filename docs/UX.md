# Can I Wear — UX

> Status: ACTIVE
> Last updated: 2026-10-20
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
2. Today's answer — Phase 4 uses an explicit item-appropriate daily verdict, timing and weather reason (D-060); the implemented Phase 3 baseline uses YES / MAYBE / NO
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

The following records the approved/implemented Phase 3 baseline. D-060 supersedes its daily YES/MAYBE/NO verdict for the Phase 4 Home Screen, as specified below; unchanged layout/accessibility guidance and the jacket's underlying evaluation still apply. This is not a claim that Phase 4 has been implemented.

Visual reference: `design/home-screen-reference.png` (D-046), extended by D-047 and D-051. Header shows **Can I Wear**, current locality and, only while Guided explanation is active, **“Today’s weather, interpreted for each item.”** No temperature/conditions or fake dropdown. The original no-settings-button restriction is superseded only by D-067's focused item-configuration gear. A prominent rounded hero places a bundled leather-jacket illustration on the left and item name, large **YES / MAYBE / NO** status and a short data-derived reason on the right. Do not add a redundant question or Good/Maybe/Skip sentence. At accessibility text sizes the hero may stack to preserve readability. Use the existing most-protective remaining-day summary, never a majority vote or hardcoded optimistic result.

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
2. **Multiple items, one location** — Phase 4 has an approved compact-overview direction (D-058) and explicit daily-verdict contract (D-060); detailed layout and remaining item behavior stay gated in 4.1.
3. **One item, multiple locations** — part of the future multi-location experience (Phase 10); detailed presentation remains TBD.
4. **Multiple items, multiple locations** — also part of the future multi-location experience (Phase 10); detailed presentation remains TBD.

In every configuration, the primary goal is to tell the user **at a very fast glance whether each relevant item can/should be worn or brought, and when**. Keep recommendation states and timing information consistent and immediately scannable as complexity grows. Reuse visual components and interaction patterns wherever that improves consistency, but **do not force all four configurations into one layout**: separate views or layouts are explicitly acceptable when they improve clarity.

The **one-item/one-location** reference layout is approved. The multiple-item/one-location direction is approved to the extent of D-058/D-060, not as a finished mockup. The two multi-location configurations remain design scenarios rather than approved layouts or commitments to display all combinations simultaneously. Outstanding design choices remain at their Phase 4.1 and Phase 10.1 gates; this principle does not change phase ordering or weather rules.

## First-release multi-item and widget UX

Selected-item Home integration is tracked in `TODO.md` Phase 4.3; widget implementation remains pending. The following requirements are not evidence of physical-device validation.

- The Phase 3 single-jacket screen is the visual foundation; it does not define every multi-item state or override D-060's explicit daily advice.
- **D-067 selection flow:** Show item selection before first Home; use a header gear to reopen configuration. One selected item retains the existing single-item layout, Guided/Compact modes and optional first-use card. Multiple selected items use the new Guided-Home-based overview showing only selected items. Selection completion and Home explanation acknowledgement are separate. This does not override D-060's daily-verdict semantics or move the existing display switches into app configuration.
- **D-070 selector behavior:** No items are preselected on a fresh first launch. Disable Continue until at least one item is selected. When editing the saved selection, disable Save selection while no items are checked; do not save an empty selection. Keep the selected-item count and disabled action clear without relying on color alone.
- **Selector sizing (2026-10-20 user correction):** Keep item artwork and row sizing consistent. At standard text size in portrait on iPhone 13, show all seven choices, guidance, selection count and Continue without scrolling. Retain scrolling for larger text and shorter/landscape viewports, readable text and at least 44-point touch targets. See ISS-003 for validation status.
- **Replay setup for testing:** Enable **Reset Item Setup** under **Item Setup** in Apple system Settings, then return to the app. Clear selected items and show the empty first selector with Continue disabled, not the editing sheet; preserve unrelated Home preferences/caches. The switch turns itself off after being applied so confirming setup does not cause a reset loop.
- The approved Phase 4 collection and compact overview direction are recorded in D-058, refined by D-067: show selected-item answers together, with item detail available on selection.
- Keep the weather-fit perspective **“Is today a good day for [item]?”**, but express the daily answer through the explicit verdict/timing contract below. Do not require that question to be repeated as a heading on every item.
- Exact user-facing group labels and the UX explaining the different item behaviors are deferred to custom-item configuration in Phase 8.1. D-059 is superseded; predefined-item Home advice must be understandable without learning a category taxonomy. D-061's “Can I wear items” / “Should I wear items” are internal working labels only, not UI copy.
- In Phase 5.1, select a widget direction. Possibilities expressed by the user: separate item widgets plus an overall widget, **or** a smart combined overview of items and relevant wearing times. Do not assume both are required.
- Detailed multi-item layout, visual hierarchy, and daily aggregation must follow approved rules; do not invent them during implementation.
- **D-068 chosen multi-item layout:** Use direction A: a vertically scrolling set of selected-item cards, each with item identity/artwork, explicit daily advice, short reason and daypart/time-range previews. Tap an item for full daypart/hourly detail. Retain Guided/Compact and optional introduction behavior; no fixed number of item cards or periods is implied by the sample. Direction B is comparison history, not a second app layout to implement.
- **D-069 period presentation:** Should I wear previews/detail use the contiguous periods specified in `WEATHER_LOGIC.md`, retaining short useful intervals and actual ranges rather than jacket safety expansion. Allow overflow/scrolling without shrinking or hiding advice. Do not show jacket-specific safety-grouping explanations for those items when no such transformation occurs. Leather Jacket's protective grouping/context remains unchanged.
- Visual review artifacts live under `docs/prototypes/item-selection/`; A's layout direction and D-070's selector defaults/minimum-selection behavior are approved. Mock forecasts and unapproved final copy/styling remain illustrative/proposed, not live data or app implementation. Static comparison images predate these approvals. The current source components in `Can I Wear/HomeComponents.swift` are the visual baseline when the historical reference image is unavailable.
- Concrete remaining presentation cases are now shown together in the prototype's **Home advice · in context** section (`index.html#advice-review`); see its README for scenario coverage and browser-only validation. Review wording in the screen context, not as separate approval rounds for routine labels. This artifact does not change the approved rules or itself close Phase 4.1.
- D-063/D-064 settle the two shared daily aggregation policies and the useful-hour minimum. Wording/layout can be streamlined across both; shared presentation must not collapse their distinct daily meaning. The exact algorithms and acceptance examples belong in [WEATHER_LOGIC.md](WEATHER_LOGIC.md#two-shared-daily-aggregation-policies-d-063), not in view copy.

### Phase 4 daily verdicts and timing (D-060)

**Problem being solved:** A positive daily result for sunglasses means enough useful hours under D-064, while a positive daily result for the jacket means no disqualifying weather in the remaining day. Neither a shared bare label nor group names explain that distinction at a glance. D-064 supersedes the earlier one-sunny-hour positive-day example.

**Approved approach:** Replace the universal daily YES/MAYBE/NO label with a concise verdict whose wording states the actual advice. Support it with the relevant timing and weather reason, directly readable in the item summary rather than requiring users to open an explanation of item types. Keep item identity prominent and the overview quick to scan.

| Illustrative forecast | Daily verdict | Supporting timing/reason |
| --- | --- | --- |
| Sunglasses useful only in a sunny interval | **Useful today** | Strong sun, 12:00–15:00 |
| Sunglasses useful for only one forecast hour | **Briefly useful** | Strong sun, 12:00–13:00 |
| No raincoat need in the evaluated window | **Not needed today** | Dry forecast |
| Jacket restricted by a rain interval | **Avoid during rain** | Rain, 16:00–18:00 |
| Jacket suitable throughout the evaluated window | **Good all day** | Throughout the remaining day |

These examples establish the intended meaning, not fabricated live times or a complete list of verdicts. The approved useful-hour threshold belongs in `WEATHER_LOGIC.md` (D-064), not in these illustrative times. Actual supporting times must come from evaluated forecast/advice output. Continue distinguishing raw weather timing from consolidated safety advice: a short rain event may expand into a longer jacket avoidance period under the existing rules, and the summary must not imply the expanded advice is safe to ignore.

**Required semantics:**
- **Useful today** for Should I wear means the approved useful-hour minimum is met during the remaining day, not that the item is needed or suitable every hour. Useful intervals may be separate; the summary identifies when and why.
- **Briefly useful** is representative approved qualified advice for exactly one useful forecast hour, with its actual time. Do not replace it with a normal positive-day result or “Not needed.” Borderline hours do not extend that hour into a second useful hour.
- **Not needed today** means no qualifying need is forecast in the usable evaluated window, not that wearing the item is dangerous, damaging or uncomfortable. Missing data must not be converted into “not needed.”
- **Avoid during rain** communicates a restriction and its scope; it does not claim all other hours are necessarily suitable. Show any additional relevant restrictions through the actual advice rather than hiding them behind this example phrase.
- **Good all day** is an all-window suitability claim: use it only when the approved evaluation supports it throughout the remaining current local day. It must not be derived from one good hour, a majority vote, incomplete coverage or fabricated certainty about an inferred hour. Do not imply the already-past day was evaluated.
- Borderline and uncertain outcomes must remain visibly qualified; do not force them into one of these confident example verdicts. Final wording/mapping for remaining presentation cases is open in Phase 4.1; the two algorithms and useful-hour trigger are already settled by D-063/D-064.

**Preserved behavior and D-063/D-064 clarification:** The jacket's most-protective daily result still applies, including a single hazardous hour. Sunglasses use the enough-useful-hours rule, not “best hour wins.” The presentation can use a common component/vocabulary where clear without changing either algorithm. A negative protective answer still shows any suitable periods; a positive usefulness answer still shows any not-needed periods. Neither claims the same result for every hour. Hourly answers may continue to use YES/MAYBE/NO, inferred hours remain uncertain, and consolidated periods retain their distinct role. Do not reopen the two daily aggregation rules as a wording/design question.

**Accessibility and acceptance:** The spoken and visual summaries must convey item, verdict meaning, relevant time scope and reason without relying on color or a group badge. Review two separate useful hours, exactly one briefly useful hour, MAYBE not counting toward usefulness, not-needed, timed restriction, all-window suitability, conflicting conditions, and incomplete-data scenarios. In particular, one sunny hour must not look like a normal positive day or all-day suitability, and one jacket hazard must not disappear because the rest of the day is dry. Keep the established scrolling, scalable-text and non-color requirements.

## Later multi-location overview UX (Phase 10)

- Search for cities, save favorite cities, use current location automatically, switch destinations and show several relevant locations.
- When multiple locations are displayed, the overview must remain **very clean, immediately scannable, and easy to differentiate by location**.
- The saved-city inclusion model, active/inactive controls, and manual selection behavior remain open until Phase 10.1.
- In the later scheduling phase, show a scheduled city automatically **only on days when its schedule matches**; other saved cities should not be automatically included merely because they are saved. Always retain current-location recommendations where usable. How users manually override that behavior remains open.
- Start with today's forecast. Implement a simple lookahead later and richer horizon configuration later still; do not invent a date-planner UI now.
