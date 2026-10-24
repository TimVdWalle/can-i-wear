# Multi-item Home — ready for implementation after compaction

**Saved 2026-10-24. Design choices resolved; no app implementation started.**

**Historical handoff:** The user subsequently requested implementation. Current app verification and remaining physical-device acceptance are recorded in `docs/TODO.md`; the not-started statements below describe the original handoff, not current status.

The user asked to compact before implementation. The next session should read root `AGENTS.md`, follow the `caniwear-truth` skill, and read [D-075](../../DECISIONS.md#d-075--count-adaptive-multi-item-home-single-item-text-and-all-no-red) plus the linked owning specifications. Resume when the user asks to continue; do not treat this handoff as a phone-install request.

## Locked user choices

- **1 item:** keep current single-item Home.
- **2–3 items:** **A — Mini heroes** from this folder.
- **4+ items:** **C — Item gallery**, two columns at standard sizes, scrolling longer list; adaptive reflow for narrow/accessibility sizes.
- **All NO red**, including not-needed Sunglasses, too-hot Sweater and too-cold Shorts. YES green, MAYBE amber. Red is not a new hazard classification. Unavailable/missing data is not NO.
- **Text exactly follows the single-item structure:** name → YES/MAYBE/NO → short weather reason. No additional routine timing/verdict sentence. The suggested combined “Rain 15:00–18:00” replacement was explicitly rejected. Keep only the existing necessary brief-usefulness, jacket-exception and uncertainty qualifiers.
- Larger/balanced overview artwork, no right chevrons, whole-card navigation to current matching detail. All three fixed dayparts remain, including past context. No sorting/filtering/hidden not-needed cards, new app settings or review dropdowns.

## References and approval boundary

- Approved behavior: `docs/DECISIONS.md` D-075, `docs/UX.md` “Approved count-adaptive overview refinement,” `docs/PRODUCT_SPEC.md` D-075 amendment; pending acceptance is in `docs/IMPLEMENTATION_PLAN.md` 4.3.
- Visual direction: `refined-comparison.png` and `index.html` in this folder. **Both predate the all-NO-red correction and still include A as a longer-list comparison. D-075 overrides them: C for 4+, no blue NO.** B is rejected comparison history, not a third layout to implement.
- Prototype artwork is original project review art, not existing SwiftUI catalog assets. The jacket has a bundled SVG; other app items currently use SF Symbols. Review/integrate the illustration treatment as focused overview work, without silently redesigning the single-item/detail screens. Exact mock wording/weather is not new product logic.
- Existing single-item/detail layouts and text are not to be redesigned. Keep the existing recommendation algorithms, useful-hour minimum, grouping, providers, cache, selected IDs/preferences and request cadence unchanged. All-NO-red is a presentation mapping, not a change to not-needed semantics.

## Inspect before editing

- `Can I Wear/ContentView.swift` — count-based Home routing, overview cards/detail navigation.
- `Can I Wear/ItemHomeViews.swift` — `ItemSummaryView`, `ItemArtwork`, shared text/qualifier arrangement.
- `Can I Wear/HomeComponents.swift` — `HomeStyle`, daypart layout/colour, shared timeline.
- `Can I Wear/ItemHomePresentation.swift` — hero titles, reasons, exception qualifiers, accessibility and neutral/unavailable distinction.
- Existing tests: `Can I WearUITests/ItemHomeUITests.swift`, `Can I WearTests/ItemHomePresentationTests.swift`, `Can I WearTests/ItemHomeIntegrationTests.swift`.
- `docs/ISSUES.md` — ISS-004/005/006 still have pending verification; ISS-007 is an independent verification-script interruption defect. Do not claim them resolved by prototype checks or broaden this task into tooling repair.

Do not globally make `.neutral` red: known not-needed NO and unavailable advice currently share neutral presentation. Map known NO separately from unavailable/uncertain data. Reuse evaluated presentation values; never derive weather advice from wording or item names.

## Required implementation checks

1. Test 1/2/3/4/7 selected items and count-boundary changes; preserve order and preferences. Verify correct detail for each item and no additional provider requests.
2. At standard iPhone 13 size, two/three ordinary A cards fit after introduction dismissal. C shows a readable two-column overview and scrolls to every selected item. Test largest text, narrow/landscape, light/dark and accessible full-card actions without clipping or shrinking essential text.
3. Known NO daily/daypart outcomes are red, including not-needed Sunglasses; unavailable advice does not become red NO. Preserve MAYBE, single-hour usefulness, inferred uncertainty, late-night past context and jacket exceptions. All three fixed dayparts remain; exact hours/accessibility semantics remain faithful.
4. Inspect actual simulator screenshots and existing single-item/detail regressions, then run **`bash scripts/verify.sh full`**. Read results honestly: older full-gate failures/interruption history is not a current pass. Prototype/browser assertions are not Swift/app evidence.
5. No phone installation unless the user explicitly asks. Do not reset/uninstall or discard selection/preferences. Do not mark physical acceptance passed without actual evidence.

## Worktree/evidence at handoff

- No Swift, Xcode project or app test files were edited in this design task. Changes are specifications/status and new `docs/prototypes/multi-item-layouts/` review artifacts.
- Existing unrelated work at task start: modified `docs/TODO.md` (one prior evidence entry) and untracked `.idea/`. Preserve both. The new TODO handoff entry is additive; do not overwrite older evidence.
- Latest refinement passed **795 browser layout/state assertions + 102 interaction assertions** and documentation/static artifact checks. These results predate the final colour approval and are browser-only. Full evidence/history is in this folder's README.
- App implementation, full app verification and installation of D-075 remain **not started**. The accepted Phase 4 scope and deferred recovery check are unchanged. Older “running” gate notes in TODO are historical; inspect actual processes/evidence rather than assuming they are still active.
