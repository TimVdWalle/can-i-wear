# Can I Wear — UX

> Status: ACTIVE
> Last updated: 2026-10-25
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
2. Today's answer — YES / MAYBE / NO, a short weather reason and necessary brief-usefulness/exception/uncertainty qualifications, preserving item-specific meaning
3. Morning / Afternoon / Evening planning context
4. Hourly suitability

Do not lead with a weather dashboard.

## Visual language

A small number of semantic colors may make the recommendation immediately recognizable.

Current palette (D-075):
- green = YES;
- yellow/orange = MAYBE;
- red = NO.

Use adaptive, accessible shades on soft rounded cards, strong typography and a white/system-adaptive background. Every known NO is red, including not-needed advice; red does not redefine not-needed as dangerous. Missing/unavailable advice stays distinct and must not become NO.

Accessibility must not depend on color alone.

## Approved Home Screen — one item + one location

These are current requirements, incorporating the accepted Phase 4 follow-ups. Approval/supersession history is in `DECISIONS.md`; execution evidence and deferred manual checks are in `TODO.md`. Neither this consolidation nor phase acceptance claims a new device/accessibility/recovery pass.

The Phase 3 reference `design/home-screen-reference.png` is the visual foundation, not an override of current requirements. Header shows **Can I Wear**, current locality and the focused item-configuration gear. Only while Guided explanation is active, show **“Today’s weather, interpreted for each item.”** No weather values, fake dropdown or broad settings control. A prominent rounded hero places original catalog artwork on the left and item name, large **YES / MAYBE / NO**, short data-derived reason and any necessary qualifier on the right (D-072). At accessibility sizes, use compact artwork beside identity and prioritize the status before supporting text. Do not add a redundant question, Good/Maybe/Skip sentence or routine schedule recap. Apply the selected item's own daily policy, preserving the jacket's most-protective summary rather than a majority vote.

The variants are **Guided Home** (default) and **Compact Home**. Both retain the same advice. Guided Home adds the item-neutral purpose line, daypart context (**When can I wear it?** for the jacket) and, when requested, a concise **How it works** card: **“The main result covers today. Dayparts show when it changes, and the reason explains why.”** Tapping **Got it** turns off **Show How It Works**. Turning Guided Home off also turns Show How It Works off; turning Show How It Works on also enables Guided Home. Compact Home omits the purpose, heading and card. Standard-size spacing keeps the primary result and dayparts visible on an iPhone 13; scrolling remains available for details and accessibility layouts.

Immediately below, retain the [three fixed dayparts](#fixed-dayparts-and-shared-hourly-detail-d-073d-074) in one standard-size row; do not substitute dynamic engine periods or force four cards. Each contains only a minimal time-of-day icon, label/time range and status. No rain/heat meters, temperatures, start-hour subtitles or explanations inside cards; daypart cards are not buttons.

Daypart YES/MAYBE/NO badges use identical non-shrinking typography and height. For a past daypart, dim the card background, icon, label and time, but keep the status itself at full typographic weight so it does not appear smaller than current or future statuses.

Below a quiet divider, **Hourly suitability** uses the shared compact segmented timeline and a local time axis. These are **raw hourly evaluations**, not daypart summaries or consolidated safety periods. For Leather Jacket, when raw conditions differ from protective advice, explain: “Hourly conditions shown; period advice groups brief changes for safety.” Do not show jacket safety-grouping explanations for other items. Mark an inferred missing/unusable hour with a neutral `?` segment and “? Forecast uncertain”; the daily/period engines retain their approved conservative inference. Do not fill any other gaps. Repeated DST hours must be distinguishable by UTC offset; do not assume 24 hours or the device timezone.

Use text statuses and check/exclamation/cross cues, including on timeline segments, plus per-hour VoiceOver time/status/reason labels. Allow vertical scrolling, Dynamic Type and horizontal overflow without shrinking text to illegibility. At accessibility text sizes, use compact item artwork and place the main status before the explanation so the answer remains prominent. Keep card status words unbroken; scroll the row rather than cramping them. The **Got it** control has at least a 44-point target. Support dark/increased-contrast appearances, introduce no decorative motion, and keep provider attribution below the main content; do not add a weather freshness/status line to the Home Screen (D-057). Preserve opt-in diagnostics and pull-to-refresh.

No comfort meter, chart curve or info button. Matching item detail is available from multi-item overview cards; multi-location UX remains a future gate.

## Text

Keep text extremely short.

Examples:

**YES**
`Dry and cool`

**NO**
`Rain expected`

These are examples, not final copy.

## Periods versus displayed dayparts

The visible schedule uses three fixed dayparts, not a changing number of engine periods. Leather Jacket retains protective noise consolidation; the six Should I wear items retain actual contiguous advice without that smoothing. Exact domain rules belong in `WEATHER_LOGIC.md`; qualifiers, hourly detail and accessible descriptions preserve relevant changes without replacing the fixed daypart row.

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

The existing Home and recovery presentation is accepted through Phases 3–4; historical descriptions above are not new decision blockers. Outstanding UX choices concern future surfaces (especially the Phase 5.1 widget) and genuinely unspecified outcomes beyond approved behavior. Deferred manual accessibility/recovery observations remain in `TODO.md`, not silently passed or reopened product decisions.

## Debug diagnostics

Debugging is off by default and enabled through **Debug Enabled** in Apple system Settings. This is separate from the presentation-only **Guided Home** and **Show How It Works** switches. When debugging is enabled, a subtle control on the main screen opens a clean, dismissible diagnostics view; diagnostics must not be mixed into the normal recommendation hierarchy.

The view should be readable rather than a raw log dump: summarize location, weather/cache state, fetch reasons/timing and final periods first, with remaining-hour inputs and the bounded event history available below. It may scroll, so optional provider-supplied wind context does not compete with the recommendation. Place information and the copy-report action must be clearly identified. Exact visual treatment follows the delegated implementation review and Phase 3 polish.

The implemented diagnostic detail view uses compact same-day times, minute-based ages after the first minute, structured period rows and grouped hourly inputs. Only recommendation status text and weather values that cross Caution/Avoid thresholds receive semantic green/orange/red color; labels and reasons preserve meaning without color. The activity history is newest-first and labels category, outcome, detail and duration so it reads as an explanation of app work rather than a raw log.

## Home Screen configurations (current and future)

The Home Screen has two accepted current-location configurations and two future multi-location scenarios:

1. **One item, one location** — the accepted single-item Home described above.
2. **Multiple items, one location** — the accepted D-075 count-adaptive overview described below, with matching detail.
3. **One item, multiple locations** — part of the future multi-location experience (Phase 10); detailed presentation remains TBD.
4. **Multiple items, multiple locations** — also part of the future multi-location experience (Phase 10); detailed presentation remains TBD.

In every configuration, the primary goal is to tell the user **at a very fast glance whether each relevant item can/should be worn or brought, and when**. Keep recommendation states and timing information consistent and immediately scannable as complexity grows. Reuse visual components and interaction patterns wherever that improves consistency, but **do not force all four configurations into one layout**: separate views or layouts are explicitly acceptable when they improve clarity.

The two multi-location configurations remain design scenarios rather than approved layouts or commitments to display all combinations simultaneously. Their outstanding choices belong to Phase 10.1; accepted Phase 4 behavior is not an open design gate.

## First-release multi-item and widget UX

Phase 4 is accepted; evidence and deferred manual checks are maintained in `TODO.md`. Widget design/implementation remains pending at Phase 5.1–5.3.

- **D-067 selection flow:** Show item selection before first Home; use a header gear to reopen configuration. Home shows only selected items, with count-adaptive routing below and retained Guided/Compact/optional-introduction behavior. Selection completion and Home explanation acknowledgement are separate; existing display switches remain in Apple system Settings.
- **D-070 selector behavior:** No items are preselected on a fresh first launch. Disable Continue until at least one item is selected. When editing the saved selection, disable Save selection while no items are checked; do not save an empty selection. Keep the selected-item count and disabled action clear without relying on color alone.
- **Selector sizing (2026-10-20 user correction):** Keep item artwork and row sizing consistent. At standard text size in portrait on iPhone 13, show all seven choices, guidance, selection count and Continue without scrolling. Retain scrolling for larger text and shorter/landscape viewports, readable text and at least 44-point touch targets. See ISS-003 for validation status.
- **Replay setup for testing:** Enable **Reset Item Setup** under **Item Setup** in Apple system Settings, then return to the app. Clear selected items and show the empty first selector with Continue disabled, not the editing sheet; preserve unrelated Home preferences/caches. The switch turns itself off after being applied so confirming setup does not cause a reset loop.
- Keep the weather-fit perspective **“Is today a good day for [item]?”**, with the short-answer/semantic contract below. Do not repeat that question as a heading on every item.
- Exact user-facing group labels and the UX explaining the different item behaviors are deferred to custom-item configuration in Phase 8.1. D-059 is superseded; predefined-item Home advice must be understandable without learning a category taxonomy. D-061's “Can I wear items” / “Should I wear items” are internal working labels only, not UI copy.
- In Phase 5.1, select a widget direction. Possibilities expressed by the user: separate item widgets plus an overall widget, **or** a smart combined overview of items and relevant wearing times. Do not assume both are required.
- Prototypes under `docs/prototypes/item-selection/` and `docs/prototypes/multi-item-layouts/` retain design-review history. Earlier layouts, mock forecasts, replaced artwork and pre-approval colours are not current requirements or app/device evidence. `DECISIONS.md` records supersession; the consolidated requirements here govern presentation. Current source components are the visual baseline when the historical reference image is unavailable.

### Phase 4 daily verdicts and timing (D-060)

**Current short-answer contract (D-060 as amended by D-072/D-074/D-075):** Use item name → YES/MAYBE/NO → short weather reason throughout Home/overview/detail. Preserve explicit item-specific meaning and evaluated timing in accessible summaries and daypart/hourly detail. Do not add a routine second verdict/timing sentence or require users to learn an item taxonomy. A positive usefulness result is not an all-day claim; not-needed is not unsafe.

Use small qualifiers only for necessary brief-usefulness, jacket exceptions or uncertainty, not a schedule recap. Exactly one useful hour is MAYBE plus its brief-usefulness qualifier and actual time. For jacket exceptions, compare evaluated protective advice with the displayed dayparts, including conflicting advice before 06:00. For example, explain suitable late hours when Evening is NO, or early avoidance when all displayed dayparts are YES. Never call a raw good hour inside protective avoidance a safe exception. Uniform advice needs no redundant current-hour-to-midnight qualifier.

The following D-060 examples describe semantic meaning and time scope, **not mandatory extra visual verdict lines**. The earlier long-verdict layouts are superseded; these examples neither change aggregation nor prescribe fabricated live times.

| Illustrative forecast | Advice meaning | Supporting timing/reason |
| --- | --- | --- |
| Sunglasses useful only in a sunny interval | **Useful today** | Strong sun, 12:00–15:00 |
| Sunglasses useful for only one forecast hour | **Briefly useful** | Strong sun, 12:00–13:00 |
| No raincoat need in the evaluated window | **Not needed today** | Dry forecast |
| Jacket restricted by a rain interval | **Avoid during rain** | Rain, 16:00–18:00 |
| Jacket suitable throughout the evaluated window | **Good all day** | Throughout the remaining day |

The approved useful-hour threshold belongs in `WEATHER_LOGIC.md` (D-064), not in these illustrative times. Actual supporting times must come from evaluated forecast/advice output. Distinguish raw weather timing from consolidated safety advice: a short rain event may expand into a longer jacket avoidance period, and the summary must not imply the expanded advice is safe to ignore.

**Required semantics:**
- **Useful today** for Should I wear means the approved useful-hour minimum is met during the remaining day, not that the item is needed or suitable every hour. Useful intervals may be separate; the summary identifies when and why.
- **Briefly useful** is representative approved qualified advice for exactly one useful forecast hour, with its actual time. Do not replace it with a normal positive-day result or “Not needed.” Borderline hours do not extend that hour into a second useful hour.
- **Not needed today** means no qualifying need is forecast in the usable evaluated window, not that wearing the item is dangerous, damaging or uncomfortable. Missing data must not be converted into “not needed.”
- **Avoid during rain** communicates a restriction and its scope; it does not claim all other hours are necessarily suitable. Show any additional relevant restrictions through the actual advice rather than hiding them behind this example phrase.
- **Good all day** is an all-window suitability claim: use it only when the approved evaluation supports it throughout the remaining current local day. It must not be derived from one good hour, a majority vote, incomplete coverage or fabricated certainty about an inferred hour. Do not imply the already-past day was evaluated.
- Borderline and uncertain outcomes remain visibly qualified; do not force them into confident example verdicts. Unavailable advice is distinct from NO. Existing presentation is accepted, not an open Phase 4.1 wording gate.

**Preserved behavior and D-063/D-064 clarification:** The jacket's most-protective daily result still applies, including a single hazardous hour. Sunglasses use the enough-useful-hours rule, not “best hour wins.” The presentation can use a common component/vocabulary where clear without changing either algorithm. A negative protective answer still shows any suitable periods; a positive usefulness answer still shows any not-needed periods. Neither claims the same result for every hour. Hourly answers may continue to use YES/MAYBE/NO, inferred hours remain uncertain, and consolidated periods retain their distinct role. Do not reopen the two daily aggregation rules as a wording/design question.

**Accessibility and acceptance:** The spoken and visual summaries must convey item, verdict meaning, relevant time scope and reason without relying on color or a group badge. Review two separate useful hours, exactly one briefly useful hour, MAYBE not counting toward usefulness, not-needed, timed restriction, all-window suitability, conflicting conditions, and incomplete-data scenarios. In particular, one sunny hour must not look like a normal positive day or all-day suitability, and one jacket hazard must not disappear because the rest of the day is dry. Keep the established scrolling, scalable-text and non-color requirements.

### Fixed dayparts and shared hourly detail (D-073/D-074)

- Every item retains exactly Morning (06–12) / Afternoon (12–18) / Evening (18–24) on single Home, overview and matching detail. Keep one standard-size row, with accessible reflow/scrolling rather than dropping cards. Dim past metadata/backgrounds, not badge typography.
- Planning display is separate from the remaining-day daily answer. Missing earlier inputs cannot suppress valid remaining advice or become fabricated past weather; unsupported dayparts stay unavailable and missing earlier context is identified.
- Non-jacket fixed dayparts show one equally sized badge under the [approved display rule](WEATHER_LOGIC.md#fixed-daypart-display-summaries-d-074): any confirmed YES, otherwise any MAYBE, otherwise NO. Missing coverage is unavailable and inferred hours remain uncertain. A YES means useful sometime, not throughout the daypart. Actual contiguous intervals remain in accessible descriptions and the raw hourly timeline, not stacked inside cards; domain grouping and daily useful-hour counting are unchanged.
- All item details share the accepted jacket hero → fixed dayparts → compact segmented hourly timeline hierarchy, not large hour tiles. Preserve item-specific reasons, past-hour dimming and explicit uncertainty. Do not apply jacket safety expansion or its grouping explanations to other items.

### Approved count-adaptive overview refinement (D-075, 2026-10-24)

`TODO.md` records implementation/verification status; the prototype screenshots are not execution evidence.

- Route by selected-item count: **1 → existing single-item Home; 2–3 → A Mini heroes; 4+ → C Item gallery**, as reviewed in `prototypes/multi-item-layouts/`. A uses larger artwork beside the answer, with the three dayparts beneath. C uses two columns at standard sizes, artwork above the answer, and a compact daypart preview; time ranges may move to its shared Morning 06–12 / Afternoon 12–18 / Evening 18–24 key. Keep every selected item, with vertical scrolling. Narrow/accessibility layouts may use fewer columns and natural card growth rather than clipping or shrinking content.
- Use the single-item text hierarchy and existing presentation values: name, YES/MAYBE/NO, short weather reason. Do not add a second routine verdict/time message or invent a combined weather-and-time replacement. Keep only the established brief-usefulness/exception qualifications and uncertainty notes when required. Natural wrapping is allowed; this is not a one-physical-line limit. Full accessibility summaries retain evaluated meaning and timing.
- Reuse the original Leather Jacket artwork and catalog SF Symbols, not prototype illustration replacements. Keep the enlarged overview artwork bounds. Weather reasons use scalable subheadline text; overview supporting copy, daypart metadata and badges use at least scalable footnote text, not the former 9-point gallery labels. In the two-column gallery, abbreviated daypart names may accompany the full shared name/range key; accessibility retains full names and exact advice. Allow natural growth/reflow rather than scaling essential text down. Single-item/detail typography stays unchanged.
- Apply the shared green YES / amber MAYBE / red NO palette to every item, preserving not-needed versus hazard semantics and distinct unavailable/uncertain states. Single-item/detail layouts and text are not redesigned.
- Remove right chevrons. The full card remains a button opening its existing matching detail, with accessible action semantics and adequate touch targets. The prototype's single shared tap hint is acceptable; do not add repeated navigation decoration.
- Preserve Guided/Compact, the optional introduction, gear/selection, all three fixed dayparts, past-context dimming without weakening status typography, and D-074 summary semantics. Two or three ordinary cards must fit the standard iPhone 13 initial viewport after introduction dismissal. Do not promise no scrolling for large text, introduction/exceptional notes or smaller viewports.
- B and A-for-longer-lists are comparison history, not implementation alternatives. Historical reference PNG/HTML may contain pre-approval blue not-needed colours; **the all-NO-red decision overrides those pixels**. Mock forecasts, review dropdowns and provisional assets are not executable product logic or new app settings.

## Later multi-location overview UX (Phase 10)

- Search for cities, save favorite cities, use current location automatically, switch destinations and show several relevant locations.
- When multiple locations are displayed, the overview must remain **very clean, immediately scannable, and easy to differentiate by location**.
- The saved-city inclusion model, active/inactive controls, and manual selection behavior remain open until Phase 10.1.
- In the later scheduling phase, show a scheduled city automatically **only on days when its schedule matches**; other saved cities should not be automatically included merely because they are saved. Always retain current-location recommendations where usable. How users manually override that behavior remains open.
- Start with today's forecast. Implement a simple lookahead later and richer horizon configuration later still; do not invent a date-planner UI now.
