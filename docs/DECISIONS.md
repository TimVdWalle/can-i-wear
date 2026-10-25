# Can I Wear — Decisions

> Status: ACTIVE
> Last updated: 2026-10-25
> Source of truth: YES

This file records decisions that AI and developers must not casually reopen.

## Approved decisions

### D-001 — Original real-device milestone clothing scope (historical clarification)
**Decision:** The initial real-phone vertical slice supports only a leather jacket. This remains true for completed Phases 0–2. **Superseded for first public release scope by D-032/D-033:** that release includes multiple predefined items.

### D-002 — Location
**Decision:** V1 uses the user's current location.

### D-003 — Daily evaluation
**Decision:** V1 evaluates the day, not only the current weather.

### D-004 — Dynamic periods
**Decision:** The app may split the day into periods when weather materially changes.

### D-005 — Centralized rules
**Decision:** All decision thresholds and other tunable product constants must live in a concentrated configuration area. No scattered magic numbers.

### D-006 — Easy future tuning
**Decision:** V1 uses fixed initial rules, but they must be easy to tune later without hunting through the codebase.

### D-007 — Personalization in the original core milestone
**Decision:** No personal recommendation settings in the first-release core implementation. Later per-item thresholds are scheduled after release in Phase 9 by D-035; do not infer they are part of the initial release.

### D-008 — Explanation
**Decision:** The result must communicate more than a bare Yes/No, but must remain extremely quick to understand.

### D-009 — Real device
**Decision:** V1 must run on a real phone.

### D-010 — Platform priority
**Decision:** iOS is mandatory for V1. Android is a later nice-to-have and is not a V1 requirement.

### D-011 — Location battery behavior
**Decision:** The app must not continuously drain battery through location tracking. Location should be requested only as needed.

### D-012 — Rain is the dominant product constraint
**Decision:** The primary purpose is protecting the leather jacket from rain. This is not primarily a comfort app. If meaningful rain is expected, the recommendation should be to avoid the jacket even when temperature would otherwise be comfortable.

### D-013 — Temperature bands
**Decision:** The initial temperature interpretation is:
- 15°C or below: okay;
- above 15°C through 20°C: semi-okay / caution zone;
- above 20°C: definitely too hot.

These are initial product rules and must remain centralized so they can be tuned later.

### D-014 — Rain tolerance (historical; measurable policy superseded by D-023)
**Decision:** A few drops may be tolerated, but rain can ruin a leather jacket and should therefore generally be avoided. Normal or heavy rain is an immediate avoid condition.

The measurable hourly policy was subsequently settled by D-023: any forecast precipitation amount above 0 mm or explicit precipitation type produces Avoid. The earlier possibility of tolerating "a few drops" is not an exception to that policy.

### D-015 — Dynamic-period simplification
**Decision:** The app must not create many tiny alternating Wear/Avoid periods. Noisy alternating periods should be consolidated into a larger meaningful period, with safety toward avoiding rain.

### D-016 — App name
**Decision:** The official app/product name is **Can I Wear**. Naming is locked unless explicitly reopened by the user.

## Approved technical direction

### D-019 — Development bundle identifier
**Decision:** Use `mobi.vandewalle.caniwear` for development and provider setup. The final App Store bundle identity remains TBD.

### D-020 — Minimum supported iOS version
**Decision:** V1 supports iOS 26.2 and newer.

### D-021 — One-time location acquisition
**Decision:** Request current location at approximately 1 km accuracy, accept a fix with horizontal accuracy within 5 km, stop location updates after success, and report a timeout if an authorized acquisition does not produce a usable fix within 15 seconds.

The iOS when-in-use permission message is: **“Can I Wear uses your location to check local weather and provide today’s recommendation.”**

### D-017 — Framework and platform implementation
**Decision:** Build V1 as a native iOS app using **Swift + SwiftUI**.

Reason: iOS is the priority, Android is only a nice-to-have, and the product is expected to use Apple-native capabilities such as location, notifications and widgets. Native SwiftUI minimizes platform-integration layers and gives the project the clearest path to a polished iOS UX. The user's limited Swift experience is acceptable because most implementation will be AI-assisted/generated.

Android is not part of the V1 implementation path. It may be reconsidered later without compromising the iOS product.

### D-018 — Weather provider architecture and initial provider
**Decision:** Use **Apple WeatherKit** as the initial weather provider, but isolate it behind our own thin `WeatherProvider` abstraction. The rest of the app must consume a normalized internal weather model and must not depend directly on WeatherKit types.

**Development update:** D-022 temporarily supersedes the initial provider for unpaid development. WeatherKit remains the intended production candidate once a paid Apple Developer Program team is available.

WeatherKit remains a production candidate, not an irreversible product dependency. If another provider proves better, replacing the adapter must not require changing the jacket decision engine, period logic or UI.

Reason for the abstraction: external weather providers are dependencies, while the leather-jacket recommendation is core product logic and should remain independent of the provider. The thin layer also makes deterministic testing with fake weather straightforward.

### D-022 — Free development weather provider
**Decision:** Use Open-Meteo’s free open-access API for evaluation and prototyping while WeatherKit is unavailable to the Personal Team. This is not approval to use the free tier for App Store distribution: it is non-commercial, has usage limits and no uptime guarantee. Open-Meteo attribution is required. Reassess the production provider and applicable terms before distribution.

### D-023 — Initial hourly recommendation policy
**Decision:** V1 uses exactly three recommendation levels: **OK**, **Caution**, and **Avoid**.

For each hour:
- any forecast precipitation amount above 0 mm, or a rain, drizzle, snow, sleet, hail or mixed-precipitation type, means **Avoid**;
- with 0 mm forecast, a precipitation chance from 10% up to but not including 20% means **Caution**;
- with 0 mm forecast, a precipitation chance of 20% or more means **Avoid**;
- with 0 mm forecast and less than 10% chance, temperature determines the result;
- temperature uses the warmer of actual and apparent temperature; if only one is available, use it;
- the approved temperature bands remain: 15°C or below is **OK**, above 15°C through 20°C is **Caution**, and above 20°C is **Avoid**;
- when rain and temperature produce different levels, the more protective level wins.

All thresholds remain centralized and tunable. Invalid or insufficient required hourly data must not produce a recommendation.

### D-024 — Initial relevant-day and summary policy
**Decision:** Evaluate only the remaining hours of the forecast location’s current calendar day, from the current local hour through 23:59. For the temporary single-answer vertical slice, the most protective hourly result wins: **Avoid** over **Caution** over **OK**. Phase 2 replaces this coarse answer with meaningful time segments so later weather is not hidden.

**Later presentation clarification (D-046):** “Replaces” refers to the single-answer-only presentation, not removal of the most-protective summary. The Home hero retains that summary alongside meaningful periods; the daily window, ranking and incomplete-coverage policy below remain in force.

For incomplete daily coverage, exactly one isolated unusable/missing hour may be inferred only when valid hours exist immediately before and after it. Use the more protective neighboring result, and never infer better than **Caution**. Two or more missing hours, or a gap at either edge without valid data on both sides, means the forecast is incomplete and no daily recommendation may be produced.

### D-025 — Basic first-slice presentation
**Decision:** The temporary Phase 1 result labels are **Wear**, **Maybe**, and **Don’t wear**. The first working screen checks automatically on launch and presents one system icon, a large result label, a short primary reason and required Open-Meteo attribution.

The approved temporary status copy is: **“Checking today’s weather…”**, **“Location access needed”**, **“Couldn’t get your location”**, **“Weather unavailable”**, and **“Today’s forecast is incomplete”**. Failure states provide a retry action. Final wording, palette and visual treatment remain scheduled for Phase 3 review.

### D-026 — Meaningful period and noise policy
**Decision:** A normal recommendation change must last at least 3 consecutive forecast hours to become a separate period. A one-hour **Don’t wear** result is never hidden; expand it into a 2-hour safety period by including the preceding hour, or the following hour when it occurs at the start of the evaluated window.

A short safer interval must not override surrounding risk. Repeated hour-by-hour alternation is consolidated into one period using the most protective result in the noisy span. The period/noise values remain centralized and tunable.

### D-027 — Freshness, reuse and weather timeout policy (superseded in part by D-031)
**Decision:** A recent accepted location may be reused for up to and including 30 minutes. A cached forecast may be used only through 30 minutes after it was fetched and, when a fresh location is available, only when its forecast location is within 5 km of that location.

Any valid cached result up to 30 minutes old should appear immediately with its age while a live refresh runs. Fresh data replaces it when available; if refresh fails, the still-valid cached result remains visibly identified as cached. Forecasts older than 30 minutes must not produce a recommendation.

A live weather request may wait at most 10 seconds before falling back to valid cached data or showing an explicit weather failure. The already approved one-time location acquisition timeout remains 15 seconds.

### D-028 — Basic expired-forecast presentation (age threshold superseded by D-031)
**Decision:** When a saved forecast is over 30 minutes old, no valid newer forecast is available and live weather fails, keep the Phase 1 title **“Weather unavailable”** and show: **“The saved forecast is too old to use. Connect to the internet and try again.”** The state provides the existing retry action and must not show a recommendation from the expired forecast. Final broader failure-state styling remains part of Phase 3.

### D-029 — Fog and mist are leather hazards
**Decision:** Forecast fog or mist is an **Avoid** condition because atmospheric moisture can damage a leather jacket. Comfortable temperature and otherwise dry precipitation inputs do not override it.

The measurable signal is an explicit provider forecast condition identifying fog or mist. For Open-Meteo, WMO weather codes 45 (fog) and 48 (depositing rime fog) produce Avoid. Do not infer fog/mist from humidity, dew point or visibility, and do not invent a chance-of-mist value when the provider supplies none. If a provider omits the fog/mist-specific signal for an hour, that absence alone does not make the hour unusable and the existing rain and temperature rules still apply. The approved temporary Phase 2 reason is **“Fog is expected.”**; final copy remains part of Phase 3.1.

### D-030 — Opt-in local debug diagnostics
**Decision:** Add the technical setting **Debug Enabled** through the Apple system Settings app, off by default. It was the only app setting when introduced; D-048/D-049 later add presentation-only Home Screen switches. Debugging is not a personal recommendation preference.

When enabled, the app exposes a clean, non-intrusive in-app diagnostics view that can be shown and dismissed without changing the recommendation experience. Diagnostics remain on-device and do not approve analytics or telemetry. Keep at most the latest 20 timestamped diagnostic events and clear them when debug is disabled.

Diagnostics cover location/cache source, age, timing, trigger/reason and outcome; weather/cache/provider timing, trigger/reason and outcome; relevant normalized hourly jacket inputs and per-hour/final decisions; resulting periods; and failures/timeouts. Show a reverse-geocoded street when readily available, otherwise city/region, without blocking the recommendation. Include provider-supplied wind information as diagnostic context only; wind does not affect recommendation rules unless separately approved later. Include a user-initiated action to copy the readable local report, and make its place information clear to the user.

### D-031 — Weather refresh, maximum age and home-screen provenance
**Decision:** Separate weather refresh age from maximum usable age. A matching, otherwise valid forecast under 15 minutes old is used without a network request. From 15 minutes through exactly 90 minutes, show the saved recommendation immediately and request current weather. Over 90 minutes, do not show the saved recommendation; request current weather. Apply this policy on app load, foreground activation and while the app remains active. Keep the 30-minute location-reuse, 5 km forecast-location matching and 10-second weather-request timeout from D-027.

The recommendation screen is pull-to-refresh rather than adding a refresh button. Pulling before 15 minutes, while a request is running or during a 30-second post-failure cooldown does not contact the provider. The prior requirement for a normal-screen status explaining refresh availability, updating weather and saved weather after refresh failure is superseded by D-057. A successful request restarts the 15-minute interval. Retry remains for failures with no usable recommendation; a failed user retry applies the same 30-second cooldown. Never run concurrent weather requests.

Show a reverse-geocoded locality on the normal screen. Per D-057, do not show weather age, update, refresh availability or cache status there; weather provenance remains in diagnostics. Do not show exact street, coordinates, location age or accuracy on the normal screen. Locality lookup must not block the recommendation. Universal Clipboard from the existing copy action is sufficient for moving a diagnostic report to a Mac for now.

## Approved roadmap/product decisions (2026-10-13)

These decisions supersede earlier *scope/timing* language where it conflicts; all earlier approved leather-jacket weather logic, cache behavior, device evidence and privacy limits remain in force for the jacket.

### D-032 — First real-phone milestone is not the first public release
**Decision:** Keep the current completed leather-jacket-only real-device milestone. The first public App Store release (Phase 7) must additionally support multiple predefined items and an iOS home-screen widget. Notifications and multiple saved cities are **after** that release.

### D-033 — Predefined items before public release
**Decision:** The first public release includes a predefined collection of supported items, beyond leather jackets. D-058 resolves the initial collection and primary multi-item presentation; remaining item-specific rules and daily summary behavior stay gated in Phase 4.1. Leather-specific rain/fog/temperature policies stay unchanged unless separately approved for leather.

### D-034 — Basic user-created items soon after release
**Decision:** Allow users to add and manage their own **items**, not necessarily a conventional wardrobe. Start simple with predefined items plus basic custom items, with minimal details and local storage. Custom items are Phase 8; item details/photos are deliberately much later and need further approval. A “Can I?” versus “Should I?” item property is a possibility, **not** yet an approved requirement.

### D-035 — Default rules followed by editable thresholds
**Decision:** Each item begins with sensible predefined weather rules. After basic custom items work, let users adjust weather thresholds such as temperature or rain in Phase 9; decide exact editing scope/UX at that phase. More complex rules/rulesets are deferred to Phase 15.

### D-036 — Multiple cities, after custom items/thresholds
**Decision:** After release and after the early custom-items/threshold milestones, support searching cities, saving favorites, automatically using the current location, switching location and viewing several locations in a particularly clean, easily distinguishable and scannable overview. Exact selection and display controls are TBD in Phase 10.

### D-037 — Recurring schedules for saved locations
**Decision:** Later than basic multi-location support, allow selected weekdays each week, nth weekday in a month (e.g. second Monday), and every-two-week/other repeat intervals. A location with a schedule should appear automatically on the days it matches alongside the current location; on days it doesn't match, do **not** automatically show it in the recommendation overview. Whether cities have active/inactive flags and whether manually showing an unscheduled city is allowed are **TBD**. Phase 12 is the provisional scheduled slot for schedules; its order relative to notifications is **not approved**.

### D-038 — Forecast horizon expands in stages
**Decision:** Today's overview remains the initial presentation; first add a simple lookahead extension in Phase 11, then explore more configurable horizons in Phase 15. Exact hours, dates, views and behavior remain TBD. The earlier mention of visiting Ghent was an example of why multiple cities are needed, **not** a commitment to a trip/date planner.

### D-039 — Widget in first release, exact multi-item form unresolved
**Decision:** Deliver the widget in Phase 5 before public release. The desired possibilities include per-item widgets plus an overall widget or a smart combined overview showing recommendations and relevant times for several items. Which option, sizes and rendering behavior are **TBD in 5.1**, not silently decided by AI.

### D-040 — Notifications after release, timing can be late
**Decision:** Notifications are no longer part of the first release. They can be implemented late; assigned to Phase 13 as a planning slot. Their order relative to recurring location schedules is **TBD**, not an approved dependency.

### D-041 — Long-term items and platform priorities
**Decision:** User-facing recommendation history is wanted much later (Phase 17). Accounts and syncing are much later (Phase 18); until then the app must work locally. Android belongs much later once iOS is mature (Phase 19). Social functionality is **excluded**, not an implementation candidate.

### D-042 — Incremental factors and later complex logic
**Decision:** Add extra weather factors incrementally only when supported items need them; do not introduce them without appropriate policy approval and tests. A more advanced recommendation/rule capability belongs in a dedicated later phase (Phase 15). Previously approved jacket behavior remains unchanged.

### D-043 — Other personal preferences are evaluation-only
**Decision:** Other personal preferences beyond per-item thresholds should be investigated in a later evaluation milestone (Phase 16), not assumed to be useful or automatically implemented.

### D-044 — Item details/photos are deliberately late
**Decision:** Keep item information minimal for a long time. Review additional details/photos in Phase 14; exact scope is not yet decided.

### D-045 — General settings remain undecided
**Decision:** Do not create an assumed broad settings feature. Revisit only as needed for approved item, location, notification and forecast features; no dedicated settings phase has been requested. This does not change the approved off-by-default technical Debug Enabled switch.

### D-046 — Approved single-item Home Screen (Phase 3)
**Decision:** `design/home-screen-reference.png` is the approved visual direction for one leather jacket and current location. It supersedes D-025's temporary result labels/layout: use **OK / CAUTION / AVOID**, a jacket-image hero with one short data-derived reason, one horizontal row of actual consolidated periods, then a segmented **Hourly suitability** timeline. Header: **Can I Wear** and locality, without weather values or unsupported controls. Preserve diagnostics, attribution, underlying freshness/refresh behavior, retry and all failure states. D-057 clarifies that this does not include a normal-screen weather age/update status.

Reuse D-024's existing most-protective remaining-day summary and reason precedence for the hero; do not introduce majority-of-day optimism. Periods still follow D-026, with accurate local time ranges when fixed day-part names would misrepresent their boundaries. The timeline shows raw evaluated hours, explicitly explains differences from consolidated advice, and marks the approved inferred gap as uncertain rather than fabricating a forecast status. Timezone/DST and coverage rules remain unchanged. Accessible labels, non-color cues, adaptive colors, scalable text and scrolling are required.

This approval is limited to the single-item Home Screen. Detail screens, multi-item/multi-location design and broader recovery-state refinements remain open at their existing gates.

### D-047 — Guided and Compact Home Screen modes
**Decision:** Name the two single-item variants **Guided Home** and **Compact Home**. Select them through the centralized `HomePresentationMode` configuration, with **Guided Home** as the default. D-048 clarifies that users can select this presentation preference in Apple system Settings.

Both modes replace the D-046 user-facing labels with **YES / MAYBE / NO** while preserving the existing OK/Caution/Avoid domain levels, thresholds, most-protective daily aggregation and daypart logic. The hero continues to show one short, data-derived weather reason. This decision originally added a natural-language recommendation sentence in Guided Home; D-050 removed that sentence, and D-051 removes its replacement question from the hero. Guided Home retains the heading **“When can I wear it?”** above dayparts.

**Phase 4 presentation update:** D-060 supersedes the universal YES/MAYBE/NO daily-verdict presentation, not the jacket's domain levels or protective evaluation. This paragraph otherwise records the approved Phase 3 baseline.

Guided Home includes a first-use **How it works** card. It explains that the main answer is the overall advice for today, that **When can I wear it?** shows when the advice changes, and that the short reason identifies the weather behind the answer. **Got it** dismisses only this card and persists the acknowledgement; Guided Home's other explanatory elements remain. Compact Home never presents the card. This change does not alter weather evaluation or add a broader onboarding flow.

### D-048 — Guided Home system setting
**Decision:** Add a **Guided Home** toggle under **Home Screen** in the app’s Apple system Settings page. It defaults on; turning it off selects Compact Home. The app reflects the preference when it becomes active. This is a presentation preference only: it does not change recommendation levels, weather rules, aggregation, dayparts, cache behavior or provider requests. It is a focused addition to the existing Settings bundle, not approval for a broad settings surface.

### D-049 — Re-enable the Guided Home introduction
**Decision:** Add a default-on **Show How It Works** toggle under **Home Screen** in Apple system Settings. The enabled preference presents the **How it works** card. Tapping **Got it** disables the preference; a user can later turn it on to show the card again. D-051 clarifies how this setting stays consistent with Guided Home. This setting does not affect recommendation behavior.

### D-050 — State the Home Screen’s purpose before the answer
**Decision:** Remove the redundant **“Good to wear today.” / “Maybe wear it today.” / “Skip it today.”** recommendation sentence from every state. The initially approved purpose wording and direct hero question are superseded by D-051. Recommendation logic and reasons are unchanged.

### D-051 — Concise, mode-aware Home guidance
**Decision:** Show the item-neutral purpose line **“Today’s weather, interpreted for each item.”** only while Guided explanation is active; Compact Home shows neither that line nor a hero question. The hero directly presents item identity, YES/MAYBE/NO and its weather-derived reason. Tighten standard-size spacing and component heights so the primary recommendation and dayparts fit on an iPhone 13 without scrolling; retain scrolling for hourly details, exceptional notes and accessibility text sizes.

The two Settings controls remain consistent: turning **Guided Home** off also turns **Show How It Works** off, while turning **Show How It Works** on also enables **Guided Home**. **Got it** turns off only Show How It Works. The card is reduced to: **“The main result covers today. Dayparts show when it changes, and the reason explains why.”**

### D-052 — Consistent daypart status typography
**Decision:** Render every daypart YES/MAYBE/NO with the same non-shrinking font and minimum badge height. Do not dim the status text when a daypart is past; dim only its background, icon, label and time metadata. This preserves past-state context without making an equivalent recommendation appear smaller or weaker.

### D-053 — Reliable system Settings preference contract
**Decision:** Use `home_presentation_guided` and `home_introduction_visible` as the canonical Apple system Settings keys for Guided Home and Show How It Works. Both switches store explicit Boolean ON/OFF values in the standard application preference domain. Migrate the earlier `guided_home_enabled` and `show_home_introduction` values once so an existing user’s choices are preserved; retain the existing acknowledgement migration so a dismissed explanation is not redisplayed.

The app synchronizes and resolves these externally edited preferences when it becomes active rather than relying on cached `@AppStorage` state or a `UserDefaults` suite named after the app bundle identifier. The D-051 relationship between the switches remains unchanged. This contract was verified on the physical iPhone 13: Settings wrote Guided Home from on to off while the app was terminated, and launching the app left the stored off value unchanged.

### D-054 — Persistent issue ledger
**Decision:** Track observed bugs, regressions and reliability problems in `ISSUES.md`, including status, priority, expected/observed behavior, acceptance criteria and validation evidence. AI must review relevant active issues during implementation work and may fix them without a new decision only when the expected behavior is already established by higher-priority truth files. Issues that require changed or undefined product behavior must be marked **NEEDS DECISION** and brought to the user before implementation. Resolved entries remain as regression history.

### D-055 — Missing versus unknown precipitation type
**Decision:** For a leather-jacket hour with otherwise valid required precipitation amount, chance and temperature, an absent precipitation type does not block evaluation: use the available amount and chance. An explicitly **unknown** type makes that hour unusable for a direct recommendation, even if the other inputs are present, because an unrecognized condition could represent rain or another moisture hazard. Do not treat unknown as dry or guess its meaning. The approved D-024 rule for conservatively inferring at most one isolated unusable hour still applies to daily evaluation.

### D-056 — Reason precedence for equal recommendation levels
**Decision:** Preserve the existing same-level reason order when selecting one overall leather-jacket reason. Highest priority first: **precipitation (including rain)**, fog/mist, excessive heat, precipitation chance, incomplete forecast, warm temperature, suitable temperature. Rain remains the primary protection concern. This breaks ties between results of the same level; it does not override the approved level order (**Avoid > Caution > OK**) or change hourly thresholds.

### D-057 — Omit weather freshness status from the Home Screen
**Decision:** Do not display a normal Home Screen line for weather age, refresh availability, updating state, or saved-weather/cache provenance. Keep locality, provider attribution, recommendation, existing failure/retry states and pull-to-refresh behavior. This supersedes only D-031's normal-screen status/explanation requirements and clarifies D-046's preservation of freshness: the freshness and refresh policies remain unchanged, but their status is not shown on the Home Screen. Detailed weather age, cache source and request status remain available in opt-in local diagnostics. This decision does not change recommendation logic, cache validity, provider requests, refresh cadence, cooldowns or failure behavior.

### D-058 — Phase 4 initial item collection and approved item rules
**Decision:** The approved Phase 4 collection contains seven items: **Leather Jacket, Warm Coat, Sweater, Raincoat, Sunglasses, Shorts, and Gloves**. The existing Leather Jacket rules remain unchanged.

Use one weather-fit framing for every item: **“Is today a good day for [item]?”** YES means the weather is a good fit, MAYBE means mixed/borderline conditions, and NO means a poor fit. The short reason explains the weather basis. The main multi-item screen is a compact overview showing each item's answer together, with item detail available on selection.

**Later clarification:** D-060 retains the shared weather-fit perspective and compact overview, but supersedes a universal YES/MAYBE/NO daily verdict with an explicit, item-appropriate verdict and timing. The temperature bands below remain approved hourly classifications, not a universal daily aggregation rule.

For Warm Coat, Sweater, Gloves and Shorts, use apparent/feels-like temperature when available, otherwise actual temperature. The approved initial bands are:

| Item | YES | MAYBE | NO |
| --- | --- | --- | --- |
| Warm Coat | ≤5°C | >5°C through 12°C | >12°C |
| Sweater | ≤12°C | >12°C through 18°C | >18°C |
| Gloves | ≤5°C | >5°C through 10°C | >10°C |
| Shorts | ≥22°C | ≥17°C and <22°C | <17°C |

Raincoat: precipitation takes priority; light precipitation alone does not necessarily make it needed, more substantial precipitation does. Wind strengthens the recommendation only with positive precipitation, not wind alone. D-062 settles the initial thresholds; D-071 subsequently extends them unchanged from rain to all precipitation.

Sunglasses: brightness/sunshine is the primary signal. Exceptionally high UV may make them a good fit even without bright conditions. If UV data is unavailable, use brightness alone. D-062 settles the initial sky-condition proxy, daylight scope and UV threshold; provider normalization must preserve these signals.

Extend D-024's isolated one-hour missing/unusable-hour inference rule to every Phase 4 item: inference is allowed only for one isolated hour with valid immediate neighbors; infer conservatively and never more favorably than MAYBE; two or more gaps or a gap at either edge make coverage incomplete and do not produce a daily answer. For non-jacket items, the inferred recommendation must respect the item's approved behavior; do not assume the jacket's level ordering determines other items' daily aggregation.

Remaining item-specific conditions and missing-signal behavior beyond the approved one-hour inference remain TBD in Phase 4.1. D-063/D-064 subsequently settle the two shared daily algorithms and useful-hour minimum; D-065 settles every launch-item assignment. Assigning user-facing group names is not a Phase 4 blocker. This decision does not authorize implementation before the Phase 4.1 gate is complete.

### D-059 — Clear wording for the item distinction
**Status:** Superseded by D-060. The wording below is historical, not the current configuration contract or approved final group labels.

**Decision:** Where the item distinction needs to be presented, including future item configuration, use the question **“What should the app help you decide?”** with these choices:
- **Can I wear it?**
- **Will I need it?**
- **Both**

These choices describe different purposes, not alternative names for the same behavior. This approves the user-facing wording, not the assignment of every predefined item, the daily aggregation/conflict policy, or implementation of custom-item configuration in Phase 4. The shared recommendation-screen framing from D-058 remains unchanged.

### D-060 — Explicit daily verdicts and timing; defer group labels
**Decision:** For the Phase 4 Home Screen, replace the universal daily YES/MAYBE/NO answer with a concise, item-appropriate verdict that states what the advice means, supported by the relevant timing and weather reason. A user must not need to know an internal item type to understand the answer. The compact overview and the shared “Is today a good day for [item]?” perspective remain; this does not require adding that question as a heading on every card.

This supersedes only the daily-label presentation requirements of D-047/D-051/D-058 and the group wording of D-059. The explicit verdict replaces the ambiguous daily label; it is not an extra redundant action sentence of the kind removed by D-050. Historical Phase 3 implementation/validation records remain valid for that baseline, not evidence of D-060 implementation.

The approved presentation direction is **“Useful today”** with the useful times, **“Not needed today”** when no need is forecast, **“Avoid during rain”** with the relevant avoidance times, and **“Good all day”** when the item suits the whole evaluated remaining-day window. These are representative verdicts, not an exhaustive state list or a mapping of every item to a fixed group. Detailed UX requirements and illustrative examples belong in `UX.md`.

Different item behaviors are intentional: a disqualifying hour still makes the leather jacket's protective daily result Avoid; qualifying sunny intervals can make sunglasses useful without making them useful every hour. **D-064 subsequently sets the minimum useful-hour count and distinguishes a single briefly useful hour from a positive daily result.** Do not force one daily algorithm onto every item. “Not needed” is not equivalent to “unsafe/unsuitable,” and “useful today” is not an all-day suitability claim. Hourly answers can retain YES/MAYBE/NO. Existing jacket thresholds, reason precedence, conservative coverage, period consolidation and most-protective daily evaluation are unchanged; only their daily presentation changes under this decision.

For the fixed collection, item-specific daily behavior may be explicitly defined in code/configuration; no user-facing group taxonomy or generic rule builder is required. Keep the behavior separable from item display names and UI wording so future custom items can use supported behaviors. Exact group labels and the configuration UX explaining the distinction are **deferred to Phase 8.1**, where users will need to understand their choice. D-059's labels are no longer locked. Do not implement custom-item creation or assume its data fields now.

**Subsequent clarification (D-063/D-064/D-065):** Daily aggregation now uses two approved shared algorithms with explicit launch-item assignments, not a newly invented algorithm for each item. This supersedes the earlier open question about which hourly result wins within either behavior. The historical proposed assignment of Warm Coat/Sweater/Gloves to “Both” was not approved and is not a third algorithm; their approved assignment is now in D-065. Raincoat/Sunglasses thresholds were not decided by this presentation approval; their subsequent approval is recorded in D-062. Missing-signal details and unsupported outcomes must not be silently invented. Implementation still requires explicit user permission.

### D-061 — Internal working labels for different item behaviors
**Decision:** Use **“Can I wear items”** and **“Should I wear items”** as internal working labels only, in project discussions/documentation and implementation terminology where useful.

- **Can I wear items:** Check whether conditions make wearing an item unsuitable; the leather jacket is the established example where a hazardous hour retains the protective daily Avoid result.
- **Should I wear items:** Check whether conditions make an item useful/needed; sunglasses are the established example where a qualifying sunny interval can make them useful today without implying all-day need.

These are not approved UI labels, Home headings, configuration choices or final names for users. D-060's explicit daily verdicts and timing remain the Home contract, and user-facing group naming/configuration remains deferred to Phase 8.1. **D-063 subsequently locks the two daily aggregation behaviors behind these internal names; D-065 explicitly assigns the launch catalog.** No third/combined algorithm is approved. No app implementation is authorized by this naming decision.

### D-062 — Initial Raincoat and Sunglasses conditions
**Decision:** Approve the proposed hourly conditions for Raincoat and Sunglasses, with the D-060 explicit daily-verdict/timing presentation. These rules do not change the Leather Jacket policy.

**Raincoat:** Rain at or above **0.5 mm/hour** makes it Useful. Below that, positive rain or a forecast rain chance at or above **30%** makes it Maybe useful. With no rain forecast and chance below **30%**, it is Not needed. Wind speed at or above **30 km/h** upgrades light-rain advice (positive rain below 0.5 mm/hour) from Maybe useful to Useful; wind alone or wind with chance-only uncertainty does not. Rain protection takes priority over warmth. These are initial product thresholds, not a universal meteorological boundary for needing a coat; the earlier 2.5 mm/hour draft is not the approved cutoff.

**Scope amendment (D-071):** The preceding paragraph records the original rain-only policy. D-071 replaces its rain-only input scope with total precipitation (water-equivalent amount for snow/sleet/hail), retaining every numeric threshold, precedence and optional-wind fallback. Use the current rules in `WEATHER_LOGIC.md`, not a rain-only filter.

**Sunglasses:** During daylight, clear/mainly-clear conditions make them Useful, partly-cloudy conditions make them Maybe useful, and overcast/fog conditions mean Not needed on the sunshine signal alone. **UV Index ≥6** makes them Useful regardless of cloudiness. Forecast sky conditions are the approved practical brightness proxy, not a direct measurement of brightness. UV is optional: when unavailable, use the sky-condition signal alone. Do not apply the daytime sky rule to a clear night or spread a daily UV maximum across all hours.

Missing wind does not invalidate the Raincoat's base rain recommendation or justify a wind upgrade. Missing UV does not invalidate the Sunglasses' sky-based recommendation. Missing required signals follow the already approved conservative coverage/gap policy; they must not be converted into “Not needed.” Detailed rules, precedence and boundary examples are maintained in `WEATHER_LOGIC.md`; normalized-input constraints belong in `TECH_SPEC.md`.

This records policy approval only, not implementation permission, a provider migration or a change to freshness/location/coverage rules. Phase 4.1 is not declared complete by this decision.

### D-063 — Two shared daily aggregation policies
**Decision (2026-10-19):** There are **two shared daily aggregation policies**, identified internally as **Can I wear items** and **Should I wear items**. The user explicitly reconfirmed this distinction and requested durable guidance so agents do not reopen it. It is **DECIDED**, not a proposal or an open question to revisit for each item.

**Amendment (D-064, 2026-10-19):** The initial Should I wear rule was “best hour wins,” with one useful hour sufficient. The user explicitly replaced that trigger with a minimum useful-hour count. The table below reflects the current contract; the original one-hour positive-day trigger is superseded, not an alternative implementation.

| Internal behavior | Shared daily rule | Established example |
| --- | --- | --- |
| Can I wear items | **Worst hour wins.** One bad hour makes the overall day not OK, even if other hours are OK. | Leather Jacket |
| Should I wear items | **Enough useful hours.** A positive daily result requires the useful-hour count approved in D-064; a single useful hour gets qualified advice. | Sunglasses |

Both use the same conceptual flow: validate weather/coverage → classify each hour with the item's own thresholds → apply the selected daily aggregation policy → present advice with dayparts/hourly detail. They are closely related rulesets, **not seven independent daily algorithms**, and not one universal algorithm forced onto all items. Per-item weather conditions remain different: rain can disqualify a jacket while making a raincoat useful. Different daily aggregation does **not** mean numerically inverting temperatures, precipitation thresholds or provider inputs.

The exact daily selection, examples and validity safeguards are maintained in [WEATHER_LOGIC.md](WEATHER_LOGIC.md#two-shared-daily-aggregation-policies-d-063). Apply D-064's approved useful-hour threshold; do not invent a different minimum, majority vote, percentage-of-day score or third “Both”/combined daily algorithm. Missing data never counts as useful time.

**Presentation is separate from aggregation.** The app can streamline/reuse wording and layout across both behaviors; shared text does not imply shared daily selection direction. D-060's explicit meaning, timing and reason remain required. A positive usefulness result does not mean good every hour; a negative protective result does not mean bad every hour. Dayparts/hourly detail explain when each result applies. This decision does not approve final common status strings, a bare ambiguous daily YES/NO, or public group labels.

**Scope and supersession:** This resolves the daily-direction uncertainty left in D-058/D-060/D-061. Leather Jacket is Can I wear; Sunglasses is Should I wear, with all other launch-item assignments subsequently approved in D-065 and non-jacket grouping subsequently settled in D-069. Unsupported input/precipitation and remaining presentation cases stay Phase 4.1 work; they do not make these two algorithms undecided again. Future combined behavior would require a separate decision, not an assumed third type. Existing jacket thresholds, reason precedence, period safety, day window, conservative coverage, caching and provider behavior remain unchanged. This is a documentation/policy decision, not permission to implement Phase 4 or a claim of implementation/test/device evidence.

### D-064 — Minimum useful hours for Should I wear items
**Decision (2026-10-19):** Approve **at least 2 useful forecast hours total in the remaining local day** for a positive daily result under the Should I wear algorithm. The hours **do not need to be consecutive**. Only directly evaluated genuinely good/useful (YES) hours count; MAYBE, missing/unusable and conservatively inferred hours do not.

With exactly **1 useful hour**, show qualified advice such as **“Briefly useful”**, with its actual time, rather than the normal positive-day verdict or “Not needed.” This is a qualified outcome of the same Should I wear algorithm, not a third algorithm. Zero-useful-hour borderline/no-need handling remains as specified in `WEATHER_LOGIC.md`. The threshold is an initial centralized product constant, not a user-editable preference in Phase 4.

**Supersession:** This replaces D-063's original “best hour wins” / one-useful-hour positive-day trigger and any earlier Sunglasses example implying that one hour yields the normal positive daily result. D-063's two-behavior structure, common evaluation/presentation flow and separation from per-item hourly thresholds remain approved. **Can I wear is unchanged: one bad hour makes the overall day not OK.** Existing coverage validity, remaining-day window, jacket safety/precedence, caching and provider policies remain unchanged; known useful hours never override incomplete coverage.

This approval did not assign the remaining catalog items; D-065 subsequently resolves those assignments. It does not resolve unrelated precipitation/missing-signal cases or authorize app implementation. Detailed boundaries and future test examples belong in `WEATHER_LOGIC.md`; presentation semantics belong in `UX.md`.

### D-065 — Approved daily algorithm assignments for all launch items
**Decision (2026-10-19):** Approve Warm Coat, Sweater, Gloves, Shorts and Raincoat as **Should I wear items**, alongside the already established Sunglasses assignment. Leather Jacket retains **Can I wear** behavior. This completes the assignments for the seven-item launch collection:

| Daily algorithm | Approved items |
| --- | --- |
| Can I wear — worst hour wins | Leather Jacket |
| Should I wear — enough useful hours | Warm Coat, Sweater, Gloves, Shorts, Raincoat, Sunglasses |

Every Should I wear item uses the **same D-064 daily aggregation policy**, including the centralized useful-hour minimum and qualified single-hour advice, applied to that item's own approved hourly weather classifications. Unsuitable/not-useful hours elsewhere in the day do not veto a positive result once enough useful hours exist, subject to valid coverage. Do not introduce a separate daily algorithm for a temperature item or Raincoat, revive the historical “Both” proposal, or silently move an item to the other behavior.

**Scope:** This resolves the catalog-assignment gaps in D-058/D-060/D-061/D-063/D-064. It does not change hourly thresholds, the two algorithms, coverage, jacket protection, caching or provider policy. D-066 subsequently settles required-signal validity and non-jacket isolated-gap mapping; D-069 subsequently settles non-jacket grouping. Other unsupported condition/precipitation and remaining presentation cases stay Phase 4.1 work. This is policy approval only, not app implementation permission or completion of Phase 4.1.

### D-066 — Missing required inputs and uncertain hours for Should I wear items
**Decision (2026-10-19):** For all six Should I wear items, missing required weather inputs make an hour unusable. Apply the already approved coverage rule: only one isolated unusable hour with valid immediate neighbors can be inferred; mark it **uncertain/MAYBE**, never as observed conditions or a useful hour. This settles the previously open non-jacket gap mapping; Leather Jacket retains its existing conservative neighbor mapping.

Missing/unrecognized required Sunglasses daylight/sky data makes the hour unusable even when UV is available. Optional wind/UV absence retains the D-062 base-rule fallbacks. Two or more gaps, or an edge gap without valid neighbors on both sides, still prevent a daily answer for the affected item. Other items with sufficient inputs remain independently evaluable. Detailed rules and acceptance examples belong in `WEATHER_LOGIC.md`.

This is defensive handling, not evidence of an observed live-provider failure or a claim about its frequency. Existing nullable-field fixtures are not live observations. The approval does not authorize app implementation, change hourly weather thresholds or broaden into unrelated speculative safeguards; routine implementation details should follow the working rules without additional product approval rounds.

### D-067 — Selected items, first-launch configuration and adaptive Home
**Decision (2026-10-19):** Add a focused in-app configuration page where users select which predefined items they want recommendations for. Show item selection **before Home on first launch**. After setup, a **gear in the Home header** reopens configuration.

- With **one selected item**, use the existing single-item Home layout, retaining Guided/Compact modes and the optional first-use explanation. Apply the selected item's own approved rules; do not make every item behave like Leather Jacket.
- With **multiple selected items**, use a new multi-item Home based on the current Guided Home visual language. Only selected items appear in its recommendation overview.
- Provide a resettable configuration flag so the first selection screen can be replayed during testing. Keep selection-setup completion separate from the Home explanation's acknowledgement/preferences; the planned key contract is in `TECH_SPEC.md`.

**Reset access clarification (2026-10-20):** The user reconfirmed that this must be an accessible config setting, not only a code method or launch argument. Expose **Reset Item Setup** in Apple system Settings; consume it once on launch/return to the app to replay setup, preserving saved items, Home preferences and weather/location caches.

**Reset selection amendment (2026-10-20):** The user explicitly requested that switching this setting also reset the items themselves. **Reset Item Setup clears saved selected items as well as setup completion**, returning to an empty first selector with Continue disabled until an item is chosen. This supersedes the saved-item preservation in the preceding clarification; preserve Home preferences and weather/location caches, and keep the switch one-shot.

This approves focused item selection, not broad settings, custom items or threshold editing. It supersedes D-046/UX's prohibition on a normal Home settings control **only for the approved header gear**, and refines D-058's overview to the selected items rather than always showing the full catalog. D-060's daily verdict/time semantics and D-063–D-066's item behavior remain unchanged. Keeping the current single-item Home means retaining its layout/presentation variants, not silently restoring superseded daily labels.

**Prototype review:** Visual prototypes were produced before app implementation; D-068 subsequently approves multi-item direction A and D-070 approves the initial selection/minimum-selection behavior. Exact selector styling and proposed guidance copy are not approved merely by appearing in a prototype. This is not completion of Phase 4.1 or permission to implement the app flow.

### D-068 — Multi-item Home direction A: cards with daypart previews
**Decision (2026-10-20):** Choose **A — daypart-preview cards** from `docs/prototypes/item-selection/` for the multi-item Home. Each selected item's card shows item identity/artwork, an explicit daily verdict, a short weather reason and a preview of the relevant dayparts/time ranges. Selecting a card opens the item's full daypart/hourly detail. Retain the current Guided Home visual language and D-067's configuration/single-item flow.

**B — compact overview** is retained as a historical comparison, not an approved alternative to implement or a choice to ask again. The prototype's three-card/three-period examples are illustrative, not fixed counts or new grouping rules. Existing approved algorithms, selected-item filtering, daily meaning/timing and presentation variants remain unchanged.

This selects the multi-item layout direction, not every sample string or mock forecast. Non-jacket grouping and selector defaults/zero-selection behavior were subsequently approved in D-069/D-070, not by the visual sample alone. Other still-open Phase 4.1 choices remain separate. No app implementation is authorized by this selection alone.

### D-069 — Faithful contiguous periods for Should I wear items
**Decision (2026-10-20):** For Warm Coat, Sweater, Gloves, Shorts, Raincoat and Sunglasses, merge consecutive hours with the same advice into one period. Keep short useful intervals visible; do not apply Leather Jacket's protective period expansion or noise/short-interval consolidation to these items. The daily useful-hour count comes from directly evaluated hourly results, never expanded or grouped periods.

This approves the shared grouping approach for all six Should I wear items, not a new daily algorithm or a per-item duration threshold. Leather Jacket retains its approved protective grouping unchanged. Exact rules and acceptance examples belong in `WEATHER_LOGIC.md`; presentation remains the selected A layout. This resolves non-jacket grouping as a Phase 4.1 decision, without approving remaining selector/precipitation choices or authorizing app implementation.

### D-070 — Empty initial item selection; at least one item to continue or save
**Decision (2026-10-20):** Approve the item-selector behavior shown in the prototype:
- On a fresh first launch, no items are preselected.
- **Continue** is disabled until the user selects at least one item.
- When configuration is reopened later, at least one item must be selected before **Save selection** is available; an empty selection cannot be saved.

This closes the initial-selection and zero-selection choices. It does not change D-067's one-/multi-item Home routing, reset-flag contract or the existing saved selection when configuration is reopened. Exact remaining styling/copy is separate. This approves behavior only; it does not authorize app implementation or declare Phase 4.1 complete.

### D-071 — Raincoat uses total precipitation with unchanged thresholds
**Decision (2026-10-20):** Apply the existing Raincoat amount/chance/wind rules to **all forecast precipitation**, including rain, snow, sleet, hail and mixed precipitation. Use total precipitation in **water-equivalent millimetres**, not snow depth. The existing **0.5 mm/hour**, **30% chance** and **30 km/h wind** thresholds remain unchanged.

The optional wind upgrade now applies to positive light total precipitation, not only liquid rain; wind alone or chance-only uncertainty with zero amount still cannot trigger that upgrade. Missing wind retains the base evaluation. Required-input validity, conservative coverage, the Should I wear daily algorithm/grouping and all Leather Jacket rules remain unchanged.

This explicitly supersedes D-062's rain-only scope and closes the Raincoat non-liquid-precipitation decision. It does not approve invented snow-depth conversion ratios, a provider migration or app implementation. Exact rules/examples belong in `WEATHER_LOGIC.md`; normalized units belong in `TECH_SPEC.md`.

### D-072 — Restore the clear single-item hero; qualify exceptions, not every period
**Decision (2026-10-21):** In the post-Phase-4 screenshot review, the user preferred the earlier single-item card with larger artwork on the left and item name, large **YES / MAYBE / NO**, and short weather reason on the right. The user accepted a small qualifier but clarified that it should highlight exceptions within the displayed dayparts, not recap all periods or enumerate the daily verdict's matching times. Different item algorithms do not justify a cluttered layout.

This supersedes D-060's explicit-verdict/timing layout **for the single-item Home and matching detail hero only**. Multi-item overview cards retain their explicit daily advice. Keep the two daily algorithms and their meanings unchanged: YES for usefulness does not assert all-day need; NO for not-needed is neutral, not a hazard. The single-useful-hour outcome remains qualified MAYBE/briefly useful, unavailable advice must not become NO, and inferred data remains uncertain.

Do not add a qualifier for uniform advice or merely repeat the current-hour-to-midnight window. For the jacket, compare remaining advice with the displayed dayparts and highlight an actual exception, e.g. **“Suitable 22:00–24:00”** when Evening is NO but the remaining late evening is suitable. Also explain conflicting advice before the displayed dayparts start at 06:00, e.g. **“Avoid 00:00–06:00”** while all displayed dayparts are YES. Retain protective consolidation: a raw green hour inside an avoidance period is not a safe exception. Periods and hourly details remain the detailed schedule; avoid a long list in the hero. Should I wear detail retains exact contiguous advice (inside fixed cards after D-073's all-item correction); retain brief-usefulness/uncertainty qualifications rather than duplicate that schedule.

This is a presentation correction, not approval to alter weather thresholds, aggregation, useful-hour counts, period grouping, coverage, cache/provider behavior or Phase 4 acceptance. Physical-device and final visual verification remain separately tracked in ISS-004/TODO.

### D-073 — Keep full-day context in multi-item period previews
**Decision (2026-10-21):** The user's post-install screenshots and correction require earlier periods to remain visible on multi-item Home, rather than dropping them as the current hour advances. Use the same **06:00–24:00 planning-day context** as the established single-jacket screen, with past periods visibly subdued but their status readable. Matching item detail retains that context too.

**Explicit jacket clarification:** Leather Jacket must keep exactly **Morning (06–12), Afternoon (12–18), Evening (18–24)** in its visible Home/overview/detail row. The user rejected the four weather-change periods produced by the first attempted correction. Reuse the established `FixedDayPartPresentation`/`DayPartsView`; do not substitute dynamic engine periods or invent a different visible count. Jacket protective grouping remains internal to evaluated advice/qualifiers and hourly safety explanations. Other items retain their approved contiguous display periods; this clarification does not authorize changing their hourly/daily/grouping policies.

**All-item correction (2026-10-21):** The user's subsequent Sunglasses screenshot and explicit correction establish that this applies to **every item**, not only Leather Jacket or the example shown. Every single-item Home, overview preview and matching detail uses the same three named daypart cards in one standard-size row, retaining past cards dimmed. This supersedes the jacket-only visible-row exception above. For non-jacket items, show their actual contiguous advice clipped within those named cards; a short useful or uncertain interval must remain identifiable, not become an all-daypart claim. Hourly classifications, D-069 domain grouping and D-063/D-064 daily aggregation are unchanged. Missing daypart inputs remain unavailable, not NO. Accessibility text can reflow/scroll without dropping a daypart.

This changes the displayed schedule, not the daily answer: daily aggregation/useful-hour counting still uses only the remaining local day. Evaluate planning display data separately from the same normalized forecast, with no extra provider/location request. Never fabricate unavailable earlier inputs or let missing past data suppress valid remaining-day advice; explicitly identify unavailable earlier context when only the remaining schedule can be shown. For one or two actual periods, use the available preview width rather than reserving empty columns. Preserve Dynamic Type/scrolling and distinguish forecast/advice context from recorded historical observations.

### D-074 — Compact shared heroes, summarized dayparts and shared hourly timeline
**Decision (2026-10-22):** The user requested consistent jacket-style layouts across the multi-item overview and other items' detail pages, retaining the accepted Leather Jacket detail. On clarification, the user chose artwork-left **YES / MAYBE / NO** overview heroes, made shorter so more items fit on screen. This supersedes D-060/D-072's explicit-verdict-only overview layout; preserve daily semantic meaning in accessibility, short reasons and brief-usefulness/uncertainty qualifiers. Daily algorithms and the two-useful-hour daily minimum are unchanged.

For all six non-jacket items, each fixed daypart has **one summary badge**: any directly evaluated YES hour makes it YES; otherwise any MAYBE (including the permitted uncertain inference) makes it MAYBE; otherwise NO. The user explicitly chose to retain MAYBE. This supersedes D-073's stacked within-card intervals, not D-069's underlying contiguous periods. A daypart YES means useful sometime in that daypart, not useful throughout it. Missing coverage remains unavailable rather than NO; exact per-hour advice and uncertainty remain available below and in accessibility descriptions. Leather Jacket's daypart policy remains unchanged.

Reuse the jacket's compact segmented hourly layout for other items on single Home and detail, with item-specific advice/reasons, neutral not-needed semantics, past-hour dimming and explicit uncertain hours. Retain all three fixed dayparts and remaining-day versus planning-context separation. No weather thresholds, domain grouping, provider/cache behavior, selection or Phase 4 acceptance changes.

### D-075 — Count-adaptive multi-item Home, single-item text and all NO red
**Decision (2026-10-24):** After reviewing `docs/prototypes/multi-item-layouts/`, the user chose **A — Mini heroes for 2–3 selected items** and **C — Item gallery for 4 or more**, and explicitly confirmed **“all no red.”** These labels refer to this new prototype, not the historical A/B comparison in D-068.

- One selected item retains the existing single-item Home. Two or three use the artwork-left A cards; four or more use C's two-column gallery at standard phone/text sizes, with scrolling for the longer collection. Adapt naturally at narrow/accessibility sizes rather than shrinking essential text. Retain all three named dayparts; C may show their time ranges in the shared key illustrated by the prototype.
- Match the single-item text structure: **item name → YES / MAYBE / NO → short weather reason**. No extra routine “Avoid from … to …”/“Useful from … to …” sentence, and no replacement combined weather-and-time line. Retain the existing brief-usefulness, jacket-exception and uncertainty qualifiers when actually required. Preserve full semantic meaning and timing in accessible descriptions and detail.
- Use **green YES / amber MAYBE / red NO for every item**, including too-hot Sweater, too-cold Shorts and not-needed Sunglasses. Red is a negative weather-fit answer, not a claim of damage or danger. Not-needed semantics and the daily algorithms remain unchanged. Missing/unavailable advice is not NO and must not become red merely because it shares a neutral domain/presentation tone. Keep the single-item and detail layouts/text; consistent NO colouring is not permission to redesign them.
- Increase overview artwork and improve card balance following the reviewed A/C direction. Remove the right chevrons; the whole card still opens matching detail. Keep current configuration/selection, Guided/Compact and first-use behavior. Do not add a user-facing layout switch, sorting, filtering or hidden not-needed items.

This supersedes D-068's universal stacked-A overview and D-074's compact-artwork/chevron direction where they conflict. It rejects the prototype's proposed blue not-needed palette. Approved recommendation thresholds, aggregation, daypart summaries, raw-hour uncertainty, protective grouping, remaining-day/planning-context separation and provider/cache behavior remain unchanged. Prototype controls/forecasts are review tools only. Exact asset integration must remain focused on this overview work, without a single-item redesign.

**Execution boundary:** The user requested a saved handoff so the session can be compacted before implementation. This records the final design choices; no app implementation or phone installation was performed or is to start as part of this handoff step. Resume from `docs/prototypes/multi-item-layouts/IMPLEMENTATION_HANDOFF.md` when the user continues.

**Post-install correction (2026-10-24):** The user rejected the substituted overview illustrations and requested restoring the original icons, also reporting that some text is too small. Reuse the existing Leather Jacket asset and catalog SF Symbols throughout; enlarge overview weather reasons and supporting/daypart text rather than shrinking them for density. Keep the approved A/C routing, larger artwork bounds, red NO palette and recommendation behavior. Compact gallery daypart labels may abbreviate the names alongside the full shared name/range key and full accessibility descriptions.

## Not yet decided

The following are intentionally NOT decisions:
- detailed labels/palette/layout beyond the approved Home directions, including outcomes not specified by D-060;
- analytics/telemetry;
- final bundle identifiers;
- exact first widget design;
- specific creation/template mechanism for basic custom items;
- exact user-facing item-group labels and the configuration UX explaining their different daily behaviors (Phase 8.1; D-060 supersedes D-059; D-061 approves internal working labels only);
- threshold editing UX and affected item types;
- saved-location visibility controls, including possible active/inactive state and manual overrides;
- precise lookahead/horizon behavior and later trip/date ideas;
- exact location-schedule UX and notification timing/relative order;
- later item details/photos, other personal preferences, advanced rules and accounts/sync design;
- general settings placement beyond feature-specific configuration;

## Rule for AI

If a change would affect an approved decision above, stop and ask for approval.

If a required detail is not decided, mark it `TBD` or present a proposal. Do not silently choose it.
