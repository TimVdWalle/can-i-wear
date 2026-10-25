# Can I Wear — UX

> Status: ACTIVE
> Last updated: 2026-10-24
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
- **Single-item hero correction (D-072, 2026-10-21):** Restore the larger artwork-left layout with item name, large YES/MAYBE/NO and short reason beside it. Optional small qualifiers highlight actual exceptions within the displayed dayparts, not a list of all matching periods. Omit redundant current-hour-to-midnight timing for uniform advice; retain brief-usefulness and uncertainty qualifications. A raw good hour inside jacket protective avoidance is not a safe exception. At accessibility sizes, keep compact artwork beside identity and prioritize the status before supporting text. Multi-item overview cards and advice semantics remain unchanged. See ISS-004 for validation status.
- **Replay setup for testing:** Enable **Reset Item Setup** under **Item Setup** in Apple system Settings, then return to the app. Clear selected items and show the empty first selector with Continue disabled, not the editing sheet; preserve unrelated Home preferences/caches. The switch turns itself off after being applied so confirming setup does not cause a reset loop.
- The approved Phase 4 collection and compact overview direction are recorded in D-058, refined by D-067: show selected-item answers together, with item detail available on selection.
- Keep the weather-fit perspective **“Is today a good day for [item]?”**, but express the daily answer through the explicit verdict/timing contract below. Do not require that question to be repeated as a heading on every item.
- Exact user-facing group labels and the UX explaining the different item behaviors are deferred to custom-item configuration in Phase 8.1. D-059 is superseded; predefined-item Home advice must be understandable without learning a category taxonomy. D-061's “Can I wear items” / “Should I wear items” are internal working labels only, not UI copy.
- In Phase 5.1, select a widget direction. Possibilities expressed by the user: separate item widgets plus an overall widget, **or** a smart combined overview of items and relevant wearing times. Do not assume both are required.
- Detailed multi-item layout, visual hierarchy, and daily aggregation must follow approved rules; do not invent them during implementation.
- **D-068 chosen multi-item layout:** Use direction A: a vertically scrolling set of selected-item cards, each with item identity/artwork, explicit daily advice, short reason and daypart/time-range previews. Tap an item for full daypart/hourly detail. Retain Guided/Compact and optional introduction behavior; no fixed number of item cards or periods is implied by the sample. Direction B is comparison history, not a second app layout to implement.
- **Multi-item card cleanup (2026-10-21):** Give each card a compact artwork/name/chevron header, followed by a full-width explicit verdict and short reason. Keep actual timing in the daypart previews rather than duplicating a joined time list above them. D-073's all-item correction supersedes the first wrapping-period grid: use three named cards in one standard-size row, retaining actual advice changes within each card. Preserve selected-card navigation, accessible reflow/scrolling and independent unavailable states.
- **D-073 full-day context, all-item correction:** Every item always shows exactly Morning (06–12) / Afternoon (12–18) / Evening (18–24) on single-item Home, overview and matching detail. Reuse the established daypart row, not a wrapping grid of weather-change periods. Dim past metadata/backgrounds, not status text. Daily advice still covers only the remaining day. Unavailable dayparts show no invented status. Larger accessibility text may reflow/scroll while retaining all three dayparts.
- **D-069 within-daypart presentation:** Should I wear items retain actual contiguous advice and short useful/uncertain intervals within the three named cards, with exact clipped ranges when advice changes inside a daypart. Do not replace them with jacket safety expansion or summarize one useful hour as six useful hours. Raw hourly details remain available. Do not show jacket-specific safety-grouping explanations for those items. Leather Jacket's protective grouping/context remains unchanged.
- Visual review artifacts live under `docs/prototypes/item-selection/`; A's layout direction and D-070's selector defaults/minimum-selection behavior are approved. Mock forecasts and unapproved final copy/styling remain illustrative/proposed, not live data or app implementation. Static comparison images predate these approvals. The current source components in `Can I Wear/HomeComponents.swift` are the visual baseline when the historical reference image is unavailable.
- Concrete remaining presentation cases are now shown together in the prototype's **Home advice · in context** section (`index.html#advice-review`); see its README for scenario coverage and browser-only validation. Review wording in the screen context, not as separate approval rounds for routine labels. This artifact does not change the approved rules or itself close Phase 4.1.
- D-063/D-064 settle the two shared daily aggregation policies and the useful-hour minimum. Wording/layout can be streamlined across both; shared presentation must not collapse their distinct daily meaning. The exact algorithms and acceptance examples belong in [WEATHER_LOGIC.md](WEATHER_LOGIC.md#two-shared-daily-aggregation-policies-d-063), not in view copy.

### Phase 4 daily verdicts and timing (D-060)

**Problem being solved:** A positive daily result for sunglasses means enough useful hours under D-064, while a positive daily result for the jacket means no disqualifying weather in the remaining day. Neither a shared bare label nor group names explain that distinction at a glance. D-064 supersedes the earlier one-sunny-hour positive-day example.

**Approved approach:** Replace the universal daily YES/MAYBE/NO label with a concise verdict whose wording states the actual advice. Support it with the relevant timing and weather reason, directly readable in the item summary rather than requiring users to open an explanation of item types. Keep item identity prominent and the overview quick to scan.

**D-072 single-item amendment:** The preceding explicit-verdict/timing layout remains the multi-item overview contract. Single-item Home/matching detail restores the earlier large YES/MAYBE/NO hero, with a short weather reason and an optional exception qualifier rather than a schedule recap. Also identify conflicting early-hour advice before the displayed dayparts start at 06:00. Use MAYBE plus a brief-usefulness qualifier for exactly one useful hour; preserve uncertainty and unavailable states. The jacket's Guided heading returns to **When can I wear it?**. Dayparts/periods and hourly output below retain the detailed time scope.

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

### Shared-layout correction (D-074, 2026-10-22)

- Overview cards use a shorter jacket-style artwork-left hero: item name, prominent YES/MAYBE/NO, short reason and necessary brief-usefulness/uncertainty qualifier. Keep the chevron and full-card navigation. Reduce artwork, spacing and daypart preview height only in the overview; allow natural growth/scrolling at larger text sizes. This supersedes explicit-verdict-only overview copy and the separate compact header/full-width verdict arrangement above.
- Keep the accepted jacket detail. Other items share its hero → fixed dayparts → compact segmented hourly timeline hierarchy, not large scrolling hour tiles.
- Non-jacket fixed dayparts show one equally sized badge: any confirmed YES hour → YES, otherwise any MAYBE → MAYBE, otherwise NO. Missing coverage is unavailable; inferred hours remain uncertain. A YES means useful during some of the daypart. Actual intervals remain in accessible descriptions and the raw hourly timeline rather than stacked inside cards. This supersedes D-073's within-card interval rendering, not domain grouping or daily aggregation.
- Preserve neutral not-needed semantics, dim past metadata rather than badge text, retain all three named dayparts and do not add jacket safety-grouping explanations to other items.

### Approved count-adaptive overview refinement (D-075, 2026-10-24)

`TODO.md` records implementation/verification status; the prototype screenshots are not execution evidence.

- Route by selected-item count: **1 → existing single-item Home; 2–3 → A Mini heroes; 4+ → C Item gallery**, as reviewed in `prototypes/multi-item-layouts/`. A uses larger artwork beside the answer, with the three dayparts beneath. C uses two columns at standard sizes, artwork above the answer, and a compact daypart preview; time ranges may move to its shared Morning 06–12 / Afternoon 12–18 / Evening 18–24 key. Keep every selected item, with vertical scrolling. Narrow/accessibility layouts may use fewer columns and natural card growth rather than clipping or shrinking content.
- Use the single-item text hierarchy and existing presentation values: name, YES/MAYBE/NO, short weather reason. Do not add a second routine verdict/time message or invent a combined weather-and-time replacement. Keep only the established brief-usefulness/exception qualifications and uncertainty notes when required. Natural wrapping is allowed; this is not a one-physical-line limit. Full accessibility summaries retain evaluated meaning and timing.
- **Post-install readability/icon correction:** Reuse the original Leather Jacket artwork and catalog SF Symbols, not prototype illustration replacements. Keep the enlarged overview artwork bounds. Weather reasons use scalable subheadline text; overview supporting copy, daypart metadata and badges use at least scalable footnote text, not the 9-point gallery labels. In the two-column gallery, abbreviated daypart names may accompany the full shared name/range key; accessibility retains full names and exact advice. Allow natural growth/reflow rather than scaling essential text down. Single-item/detail typography stays unchanged.
- Use **green YES, amber MAYBE, red NO for all items**, including not-needed Sunglasses and temperature-mismatch items. Red indicates a negative answer, not necessarily damage/danger. This supersedes grey/blue treatment of known NO outcomes, not their domain semantics. Unavailable/missing data never becomes NO; retain explicit uncertainty and non-colour cues. Single-item/detail layouts and text are not redesigned.
- Remove right chevrons. The full card remains a button opening its existing matching detail, with accessible action semantics and adequate touch targets. The prototype's single shared tap hint is acceptable; do not add repeated navigation decoration.
- Preserve Guided/Compact, the optional introduction, gear/selection, all three fixed dayparts, past-context dimming without weakening status typography, and D-074 summary semantics. Two or three ordinary cards must fit the standard iPhone 13 initial viewport after introduction dismissal. Do not promise no scrolling for large text, introduction/exceptional notes or smaller viewports.
- B and A-for-longer-lists are no longer implementation alternatives. The latest reference PNG/HTML still contains pre-approval blue not-needed colours; **the all-NO-red decision overrides those pixels**. Other mock forecasts, review dropdowns and provisional assets are not executable product logic or new app settings.

## Later multi-location overview UX (Phase 10)

- Search for cities, save favorite cities, use current location automatically, switch destinations and show several relevant locations.
- When multiple locations are displayed, the overview must remain **very clean, immediately scannable, and easy to differentiate by location**.
- The saved-city inclusion model, active/inactive controls, and manual selection behavior remain open until Phase 10.1.
- In the later scheduling phase, show a scheduled city automatically **only on days when its schedule matches**; other saved cities should not be automatically included merely because they are saved. Always retain current-location recommendations where usable. How users manually override that behavior remains open.
- Start with today's forecast. Implement a simple lookahead later and richer horizon configuration later still; do not invent a date-planner UI now.
