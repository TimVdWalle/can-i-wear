# Item selection and adaptive Home — visual review

**Status: Direction A selected on 2026-10-20 (D-068); review artifact, not app implementation.**

Open `index.html` in a browser. No build, network, dependencies or live location/weather are needed. The vector illustrations, colors, rounded cards, typography hierarchy, guidance and daypart treatment draw from the existing Guided Home source. Additional item illustrations are prototype-only.

Static comparison boards: [Guided](guided.png) · [Guided with first-use explanation](first-use.png) · [Compact](compact.png). Each compares the selector, single-item Home and multi-item alternatives A/B side by side.

**Chosen:** A, the item cards with daypart previews and full detail on selection. B remains comparison history; it is not an additional layout to implement. The static images show the original pre-selection review board.

## Approved flow versus proposed visuals

D-067 approves item selection before first Home, a header gear to reopen configuration, the existing single-item layout/presentation variants for one selected item, and a new Home for multiple selected items. D-063–D-066 remain the recommendation contract. The prototype does not execute those engines: every weather/recommendation example is illustrative.

D-069 subsequently approves contiguous same-advice periods for Should I wear items, preserving short useful intervals without jacket-style expansion. The mock data is not an implementation or validation of that grouping contract; its owning rules/examples are in `WEATHER_LOGIC.md`.

This board compares:
1. First-launch item selection.
2. Single-item Home: Guided with introduction, Guided without introduction, and Compact.
3. Multi-item A: larger item cards with daypart previews.
4. Multi-item B: denser overview with advice/timing and item detail on selection.

Use the board's **Try the flow** section to select items, continue, reopen configuration, compare layouts, dismiss guidance and open item detail. Controls outside the phone are review/testing controls, not proposed app settings. A's layout direction and D-070's default unchecked rows/minimum of one selected item to continue or save are approved. Unapproved final copy/artwork remains proposed. Do not infer fixed card/period counts or grouping rules from the mock data.

## Reset contract

The app key is `item_selection_completed`; its separate Swift implementation/validation is tracked in `TECH_SPEC.md` and `TODO.md`. This artifact does not control the iOS app. The browser prototype's namespaced `caniwear.prototype.item-selection.v1` storage contains its own `item_selection_completed` flag. **Replay first selection** sets only that browser flag false and shows the selection page, preserving selected items and guidance. **Reset prototype** clears only this prototype's state. Neither control touches the app, Apple Settings, real weather or caches.

## Home advice review

The **Home advice · in context** section (`index.html#advice-review`) shows seven switchable mock forecasts in direction A: mixed jacket/sun advice, exactly one useful hour, two separated useful hours, borderline weather, one permitted isolated missing hour, insufficient coverage for one item, and all-window suitability versus not-needed advice. Cards open their matching detail; these review examples do not change the saved flow selection or execute recommendation engines.

Timing and reasons are visible in the card and its accessible summary. Short useful periods remain visible; uncertain hours are explicitly marked, not described as observed borderline weather. An unavailable item has no fabricated daily/period/hourly answer, while the other item retains its advice. The proposed “Good for the rest of today” wording limits suitability to the remaining-day window. These are concrete presentation proposals, not new product approvals or app implementation. Scenario controls are outside the app; no new app settings are proposed.

## Validation scope

Browser interaction and visual inspection validate this artifact only. Documentation verification checks diff whitespace. No Swift build, app UI test, engine execution or physical-device evidence is implied.

Checked the final artifact with 19 browser-DOM assertions covering empty/one/several/all-seven selections, layout switching, gear access, item detail, Guided/Compact/introduction behavior, saving versus cancelling draft selection, reset behavior, button visibility and horizontal overflow. A separate reload check confirmed that the reset setup flag and saved selection persist. Visually reviewed all three comparison boards and corrected a clipped picker footer. These are browser-prototype checks, not the app's XCTest/UI suite or a full accessibility audit.

After adding the in-context review, 50 browser-DOM assertions passed across all seven scenarios, detail/back navigation, timing in accessible summaries, exact one/two useful-hour display, explicit uncertainty, unavailable-item independence, and original empty/single/multiple-selection flow. Fourteen additional overflow checks passed for the seven overview/detail pairs with the review phone constrained to 320 CSS pixels (not a mobile-device test). Visually inspected mixed-day and brief-usefulness screenshots. No iOS code changed or app/device checks were rerun for this artifact update.
