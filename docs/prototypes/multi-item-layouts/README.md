# Multi-item Home — post-Phase-4 layout studies

**Layout/text direction approved in D-075; app implementation/verification is tracked in `docs/TODO.md`.** This remains a browser review artifact, not the app. Open `index.html` locally; no dependencies, network, location, app build, installation or app preferences are involved. [IMPLEMENTATION_HANDOFF.md](IMPLEMENTATION_HANDOFF.md) preserves the pre-implementation handoff.

Latest review board: [A for short lists; A/C comparison for longer lists, using single-item text](refined-comparison.png). The user subsequently chose **C for 4+ and all NO red**. Existing HTML/PNGs still show pre-approval blue NO outcomes and the longer-list A comparison; these are not current implementation instructions. Screenshots show the same 390×844 CSS-pixel phone frames, scaled together for comparison.

Initial exploration, retained as history: [original A/B/C comparison](comparison.png) · [original two-item dark board](two-items-dark.png). These older images contain the superseded two-message text and B; they do not show the current revision.

This new exploration was explicitly requested by the user; D-075 now records its approved changes to D-068/D-074. The A/B/C labels below apply only to this study, not the historical A/B selection. The single-item Home layout remains unchanged.

## Compare

- **A — Mini heroes:** selected for 2–3 items; larger artwork, answer and short weather reason; three named dayparts underneath. Its longer-list comparison is historical, not an implementation alternative.
- **B — Split cards:** initial exploration only, no longer shown in the active prototype; retained in the original screenshots.
- **C — Item gallery:** selected for 4+ items; two columns at standard sizes, with more visible items but narrower text. Daypart ranges may move to the shared key. The older three-item gallery example is not the approved routing for three selected items.

Final user choices: **A for 2–3 items, C for 4+, all NO red.** No layout-choice blocker remains. This handoff step records approval only; implementation waits until the user resumes after compaction. No new app setting, sorting or hidden not-needed items.

All cards open illustrative matching detail without a right chevron. The one shared “Tap a card for hourly detail” hint replaces repeated arrows. Existing header configuration is shown only for context, not redesigned or interactive.

## Visual proposals, not recommendation changes

- **User's text correction:** follow the single-item view: item name → YES/MAYBE/NO → short weather reason. Remove the extra daily-verdict/timing message. Do not replace it with the unaccepted combined weather-and-time proposal. Retain the existing brief-usefulness, jacket-exception and uncertainty qualifications only where needed; full semantic meaning remains in accessible descriptions. This is one reason, not a requirement to force it onto one physical line. Source reference: `ItemSummaryView` and `ItemHomePresentation.heroQualifier`.
- Warm artwork backgrounds and original coloured illustrations remain visible regardless of advice. Jacket artwork adapts the bundled SVG; other art adapts the earlier project prototype and is not a new app asset.
- **Final colour correction:** all known NO outcomes are red, including not-needed Sunglasses, too-warm Sweater and too-cold Shorts. The initial blue-for-not-needed proposal was not chosen. Do not copy its colours from the unchanged review HTML/PNGs. Missing data remains explicitly unavailable, never NO; recommendation semantics are unchanged.
- Every available item keeps Morning 06–12 / Afternoon 12–18 / Evening 18–24. A YES summary does not claim all six hours are useful. Daily advice still refers to remaining hours, not past planning context.
- The small-selection fit target concerns the 390×844 CSS-pixel phone at standard text size with first-use explanation dismissed. Large text, long qualifications, first-use guidance and shorter screens may scroll; do not shrink essential text just to force a fit.

The scenario selector covers mixed advice, not-needed Sunglasses, one useful hour, one uncertain hour, unavailable advice, and late-night planning context. All forecasts and hourly strings are hand-authored review fixtures; the Swift engines are not executed or validated. Detail illustrates the familiar hierarchy only, not a faithful SwiftUI rendering or approved detail redesign. The larger-text option is a stress preview, not native Dynamic Type validation.

## Approval boundary

D-075 and the owning specifications now record the approved presentation changes. This browser artifact is not their authority and does not execute the algorithms or alter Phase 4 acceptance, recommendation rules, grouping, provider/caching, selection, the single-item app layout or the phone installation. Existing issue verification remains separate; resume with the handoff before implementation.

## Current refinement validation — 2026-10-24

- **795 layout/state assertions passed** across the three active previews, six scenarios, 320/390-pixel outer phone widths, standard/larger text and 2/3/4/7-item controls. Covers horizontal overflow, counts, no extra verdict/timing sentence in ordinary cards, one weather-reason message, brief qualifiers, unavailable schedules and complete two-/three-item standard-width cards in every scenario.
- **102 interaction assertions passed** for matching detail, daypart/hourly availability, return focus, all seven item destinations on both longer layouts, dark appearance and introduction visibility.
- Visually inspected the current comparison board. JavaScript syntax/static artifact checks and the documentation verification gate are recorded separately from native app verification; no Swift changes, app build, simulator run or phone installation were made.

## Initial exploration validation — 2026-10-24 (historical)

- Final **1,356 layout/state assertions passed** across six mock scenarios, 320/390-pixel outer phone widths, standard/larger text and the 2/3/4/7-item controls. Checks cover horizontal overflow, card counts, qualified single-hour advice, unavailable-item independence and standard 390-pixel two-/three-item initial-viewport fit for the mixed example. Narrow gallery previews intentionally fall back to one column. Early checks exposed narrow two-item overflow and larger-text missing-data wrapping; those prototype issues were corrected before this final run.
- **202 additional assertions passed** for matching Sunglasses detail in every scenario/layout, all seven catalog detail destinations in each longer overview, return/focus, uncertain-hour markers, unavailable detail without fabricated schedules, first-use visibility, dark mode, larger-text vertical scrolling and four complete gallery cards at the standard width.
- Visually inspected the final light comparison and dark not-needed/two-item board. Also inspected the larger-text scrolling composition. These are browser previews, not native Dynamic Type, VoiceOver or physical-device acceptance.
- Inline JavaScript syntax, unique static IDs, absence of remote assets and new-file whitespace checks passed. `bash scripts/verify.sh docs` passed; no Swift, simulator or phone checks were run for this prototype-only task.
