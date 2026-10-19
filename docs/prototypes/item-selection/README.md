# Item selection and adaptive Home — visual review

**Status: PROPOSED visual artifact; not app implementation.**

Open `index.html` in a browser. No build, network, dependencies or live location/weather are needed. The vector illustrations, colors, rounded cards, typography hierarchy, guidance and daypart treatment draw from the existing Guided Home source. Additional item illustrations are prototype-only.

Static comparison boards: [Guided](guided.png) · [Guided with first-use explanation](first-use.png) · [Compact](compact.png). Each compares the selector, single-item Home and multi-item alternatives A/B side by side.

## Approved flow versus proposed visuals

D-067 approves item selection before first Home, a header gear to reopen configuration, the existing single-item layout/presentation variants for one selected item, and a new Home for multiple selected items. D-063–D-066 remain the recommendation contract. The prototype does not execute those engines: every weather/recommendation example is illustrative.

This board compares:
1. First-launch item selection.
2. Single-item Home: Guided with introduction, Guided without introduction, and Compact.
3. Multi-item A: larger item cards with daypart previews.
4. Multi-item B: denser overview with advice/timing and item detail on selection.

Use the board's **Try the flow** section to select items, continue, reopen configuration, change layouts, dismiss guidance and open item detail. Controls outside the phone are review/testing controls, not proposed app settings. `Continue` requiring at least one selection, default unchecked rows, final copy/artwork, and both multi-item layouts are proposals for visual review.

## Reset contract

The future app's planned key is `item_selection_completed`; see `TECH_SPEC.md`. It is **not implemented in the iOS app by this artifact**. The browser prototype's namespaced `caniwear.prototype.item-selection.v1` storage contains an `item_selection_completed` flag. **Replay first selection** sets only that flag false and shows the selection page, preserving selected items and guidance. **Reset prototype** clears only this prototype's state. Neither control touches the app, Apple Settings, real weather or caches.

## Validation scope

Browser interaction and visual inspection validate this artifact only. Documentation verification checks diff whitespace. No Swift build, app UI test, engine execution or physical-device evidence is implied.

Checked the final artifact with 19 browser-DOM assertions covering empty/one/several/all-seven selections, layout switching, gear access, item detail, Guided/Compact/introduction behavior, saving versus cancelling draft selection, reset behavior, button visibility and horizontal overflow. A separate reload check confirmed that the reset setup flag and saved selection persist. Visually reviewed all three comparison boards and corrected a clipped picker footer. These are browser-prototype checks, not the app's XCTest/UI suite or a full accessibility audit.
