# UI polish — resume after compaction

> Saved: 2026-10-28
> Handoff/index only; decisions and owning specifications remain authoritative.
> **Execution update (2026-10-28):** D-080–D-086 are implemented, full gate `full.SxhByS/` passed (186 unit/integration tests; 49 UI executions), native visuals reviewed, and the signed update installed/launched in place on the user's iPhone 13 (`ui-polish-device.btacQ8/`) after the conditional gate. The final review also corrected ISS-009's extreme-text MAYBE truncation. See `docs/TODO.md` for authoritative execution evidence/limitations. Review-time hold/install-permission wording below is the preserved pre-authorization snapshot, not a continuing blocker. Approved visual scope/references are unchanged; do not reimplement from this historical starting-point list.

## Resume instructions

Read root `AGENTS.md`, `docs/PROJECT.md`, `docs/AI_RULES.md`, the caniwear-truth skill, relevant `docs/ISSUES.md`, **D-080–D-086 in `docs/DECISIONS.md`**, current `docs/UX.md`, and `docs/TODO.md`. Use Phase 4.3's follow-up acceptance checks in `docs/IMPLEMENTATION_PLAN.md`; consult other owning specs when touched. Do not reopen approved design choices or interpret an older pending-review entry as the latest status.

Phase 4 remains accepted. This is a focused post-Phase-4 presentation follow-up, not widget implementation or a new recommendation-policy task. No material design decision remains open for the six requested changes. Light/dark, long-locality and accessibility adaptation still require implementation/visual verification, not invented product changes.

## Approved scope and references

| User request | Locked decision | Saved reference / scope reminder |
| --- | --- | --- |
| 1–2. Finished/active daypart appearance | D-080 | `docs/prototypes/daypart-polish/daypart-proposal.png`; apply to all seven items on single Home/detail, mini heroes and gallery, adapting density rather than enlarging gallery tiles. |
| 3. No separate item-image background | D-081–D-083 | `docs/prototypes/hero-polish/single-only-comparison.png`, `mini-only-comparison.png`, `gallery-only-comparison.png` (approved right sides); retain original artwork, bounds, main cards, alignment, text and spacing. Both semantic and neutral image backgrounds go. |
| 4. Multi-item locality beside section heading | D-086 | `docs/prototypes/home-chrome/location-inset-clean-proposal.png`; exact **blue-guide prototype placement without the guides**, using the inset content/daypart trailing edge. The later outer-card-edge variant was rejected. **Single-item locality stays unchanged.** |
| 5. Config rightmost | D-084 | `docs/prototypes/home-chrome/changes-456-proposal.png` (footer portion only); optional debug left, config right, on the shared single-/multi-item Home footer. Debug remains opt-in. |
| 6. Remove gallery shared hours key | D-085 | Same combined reference (gallery key removal only); remove the complete shared Morning/Afternoon/Evening name/hour row and its space. Keep each item's dayparts, accessible timing, matching detail and existing narrow inline ranges. |

Individual edited captures are saved beside the comparison boards. All review-critical images are in the repository, **not dependent on temporary files or chat attachments**.

### Important review history

- The initial three-layout Proposal 02 was rejected for changing too much, including misaligned reconstructed status icon/text. It is **not** an implementation reference.
- D-081 locks the existing single-item/detail hero, changing only its image background. Do not reconstruct or shift its check/cross-circle and answer text.
- Background-removal and header/footer prototypes deliberately retained old native daypart pixels to isolate those changes. They do **not** undo D-080. Combine the independent approved changes in implementation.
- The combined changes-4–6 board was approved only for 5 and 6. Use **D-086's clean reference**, not that board's locality placement.
- Earlier pending-gallery/pending-location notes in the decision/status history describe those earlier moments. D-083 and D-086 resolve them.
- Do not restore the uploaded screenshot's entire old header/layout, add guides/legends or rename the current section heading. Only the approved scoped changes apply.

## Implementation boundary and starting points

No app/test source has been changed for D-080–D-086 in this review session. Only documentation and prototype images were saved; these image edits are not native app implementation or validation. The previously installed/passed **D-079** baseline remains the app baseline recorded in `docs/TODO.md`.

**Preserve existing uncommitted work.** At this handoff, the working tree already contains app/test edits in `ContentView.swift`, `HomeComponents.swift`, `ItemHomePresentation.swift`, `ItemHomeViews.swift`, `ItemOverviewView.swift`, `UITestScenario.swift`, `ItemHomeUITests.swift`, and untracked `DayPartAppearanceTests.swift`, plus documentation/prototype changes and `.idea/`. Inspect the current diff; do not reset, replace or discard this baseline. These source edits predate this prototype-only review.

After explicit final implementation permission:

1. Inspect current views and existing tests. Likely presentation targets: `Can I Wear/HomeComponents.swift` (`DayPartCardView`), `ItemHomeViews.swift` (shared daypart colors and `ItemSummaryView` artwork), `ItemOverviewView.swift` (compact dayparts, heading/key), `ContentView.swift` (locality placement/footer order), and the artwork-tone helper in `ItemHomePresentation.swift` if no longer needed after background removal. Remove obsolete code only where directly required; no unrelated cleanup.
2. Implement only D-080–D-086. Keep recommendation thresholds, daily aggregation, coverage/uncertainty, planning/remaining-day separation, daypart boundaries, provider/cache/request behavior, selection persistence, Guided/Compact and navigation unchanged. Keep the existing 1 / 2–3 / 4+ routing and adaptive/viewport requirements.
3. Review `Can I WearTests/DayPartAppearanceTests.swift`, `ItemHomePresentationTests.swift`, `HomePresentationTests.swift`, and `Can I WearUITests/ItemHomeUITests.swift`. Superseded stronger-fill/artwork-background assertions need replacement with the new approved appearance assertions; preserve meaningful behavior, readability/contrast, exact finished boundaries, uncertainty, accessible meaning and viewport/navigation coverage. Do not weaken unrelated tests to pass.
4. Inspect actual native captures across single/detail, mini heroes and gallery, light/dark and larger/narrow layouts. Run **`bash scripts/verify.sh full`** before claiming implementation complete, review results/changed-code coverage, and update execution evidence. Prototype image checks are not app tests or physical acceptance.

**No automatic phone installation, preference resets, commits or pushes.** Phone installation needs a separate explicit request; app data and user preferences must be preserved.

## Suggested continuation message

> Read `docs/UI_POLISH_HANDOFF.md` and D-080–D-086. Keep implementation on hold until I explicitly give the final implementation go.
