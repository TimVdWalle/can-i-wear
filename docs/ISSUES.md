# Issues

> Last updated: 2026-10-25

Keep stable IDs, priority, expected/observed behavior, acceptance and validation. Use **NEEDS DECISION** when expected behavior is undefined, **AWAITING VERIFICATION** while checks remain, and **RESOLVED** only after acceptance passes. Preserve resolved entries as regression history. Detailed run/install chronology is retained in [TODO.md](TODO.md).

## ISS-007 [RESOLVED] — Interrupted verification can print a misleading PASS

- **Priority:** P1 tooling/evidence; app behavior unaffected.
- **Observed:** `full.D6p5qd` received SIGTERM during UI execution. Its log ends `BUILD INTERRUPTED` and its incomplete xcresult lacks Info.plist, yet the EXIT trap wrote `PASS: full profile`. That historical run remains failed/interrupted, never a coverage pass.
- **Cause:** The EXIT trap used the last command's status; unhandled termination could enter it with zero. A shell-only INT could also allow the script to continue collecting coverage.
- **Expected/acceptance:** Interruption returns nonzero, never writes PASS and cannot claim successful-run coverage. Add a failing signal-handling regression before fixing the script.
- **Implementation (2026-10-25):** Explicit HUP/INT/TERM traps exit 129/130/143; the EXIT footer receives and preserves the exit status.
- **Validation:** New regression reproduced the pre-fix defect. All 24 combinations of four profiles, three signals and shell-only/process-group targets now pass, including a successful child after shell-only interruption. All 10 orchestration tests pass; no interrupted case collects coverage or writes PASS. Required `bash scripts/verify.sh` passed in `code.OFybpT/`: static checks, all 14 tooling tests, Debug simulator build, 175 unit/integration tests in 17 suites and coverage collection. No Swift/app UI changed; Release/UI/device checks were not rerun for this tooling-only correction.

## ISS-006 [RESOLVED] — Inconsistent multi-item/daypart/hourly layouts and overview readability

- **Priority:** P2.
- **Observed/cause:** Separate overview/header layouts, stacked non-jacket intervals and large hourly tiles diverged from the accepted jacket layout. Later overview-only replacement artwork, caption reasons and 9-point gallery labels caused the user's icon/readability rejection.
- **Expected/implementation:** D-074 shares compact hourly rendering and one non-jacket daypart badge (any YES, otherwise any MAYBE, otherwise NO; unavailable coverage stays unavailable). D-075 supersedes the universal compact-card layout with 2–3 mini heroes / 4+ gallery, original catalog artwork, larger scalable reasons/daypart text, red known NO outcomes and full-card matching detail. Preserve all three dayparts, uncertainty, actual raw hours and unchanged evaluation.
- **Acceptance:** Appropriate count-adaptive density on standard iPhone 13, readable/scrollable accessibility and narrow layouts, all seven detail destinations, original icons and larger text. D-075 supersedes the original universal two-card composition, not D-074's daypart/hourly semantics.
- **Validation:** `shared-layout-focused.xcresult` passed 31 unit/integration tests and three UI cases. Final D-075 `full.rbzwsV/` passed; final icon/readability `full.7CyXhj/` passed Release/static/tooling checks, 175 unit/integration tests and 42 UI executions. Native light/dark, narrow and larger-text captures reviewed. Latest signed correction installed/launched on iPhone 13 at 2026-10-24 22:39 (`icons-readability-device.5ObvSo/`); selection/setup/Home settings preserved, only diagnostic history changed.
- **Closure (2026-10-25):** User approved the latest visual correction and confirmed selection/detail interactions. This closes physical visual acceptance; it is not a manual VoiceOver or deferred recovery pass.

## ISS-005 [RESOLVED] — Home/detail drops or replaces established dayparts

- **Priority:** P2.
- **Observed/cause:** Physical screenshots exposed missing earlier periods, four dynamic jacket periods, then inconsistent Sunglasses ranges at 23:47. Remaining-day/domain periods were used as the display schedule; the initial restoration was incorrectly jacket-only.
- **Expected/implementation:** D-073 applies to every item on single Home, overview and detail: Morning 06–12 / Afternoon 12–18 / Evening 18–24, retaining subdued past context without weakening badge text. Planning display stays separate from remaining-day advice; missing past inputs do not invalidate current advice or become fabricated weather. D-074 subsequently summarizes non-jacket dayparts while preserving exact hours and uncertainty in detail/accessibility.
- **Acceptance:** All seven items and all three surfaces retain the same named dayparts, valid remaining advice and unchanged weather/cache/selection/jacket rules.
- **Validation:** All-item focused run passed 27 unit/integration tests and three UI cases; final row-sizing check passed two unchanged UI cases after a clean Debug build (`all-item-dayparts-clean-layout.xcresult`). Screenshots reviewed; signed correction installed/launched with preferences preserved. Subsequent passing `full.rbzwsV/` and latest `full.7CyXhj/` include the automated daypart regressions. Failed/interrupted/fixture-clock investigations remain historical evidence in TODO.
- **Closure (2026-10-25):** User approved the latest on-phone presentation and confirmed interactions. Physical visual acceptance is complete.

## ISS-004 [RESOLVED] — Single-item Home hero is crowded

- **Priority:** P2.
- **Observed/cause:** Physical screenshots on 2026-10-21 showed long verdicts/timing/reasons competing in a narrow column.
- **Expected/implementation:** D-072 restores larger artwork-left YES/MAYBE/NO and a short reason, qualifying meaningful exceptions/brief usefulness/uncertainty rather than recapping the schedule. Compare jacket exceptions with displayed dayparts, including conflicting pre-06:00 advice; never present an absorbed raw green blip as safe. Weather logic unchanged.
- **Acceptance:** Readable positive/wet/fog advice, standard iPhone 13 hero/daypart fit, large-text scrolling, clear early/late exceptions and no redundant schedule or overview regression.
- **Validation:** Revised focused check passed 15 presentation tests and two UI cases (`home-polish-focused.xcresult`); screenshots inspected. Combined `full.D4Xhp7/` passed 164 unit/integration tests and 32 UI executions. Later `full.rbzwsV/` and latest `full.7CyXhj/` include the hero regressions. Signed builds installed/launched in place without reset/fixtures; detailed chronology is in TODO. Superseded full-width-layout results are not evidence for the restored hero.
- **Closure (2026-10-25):** User approved the latest visual presentation and confirmed detail-return interactions. Physical visual acceptance is complete.

## ISS-003 [RESOLVED] — Initial selector artwork is oversized and content requires scrolling

- **Priority:** P2.
- **Observed/cause:** User's iPhone 13 report on 2026-10-20 identified oversized jacket artwork and content below the initial viewport. SF Symbols alone received internal padding; seven 68-point rows pushed guidance below the viewport.
- **Expected/implementation:** Common 24×28-point artwork bounds, 52-point standard rows and multiline larger-text labels, without shrinking text. All seven options, full guidance, count and Continue fit standard portrait iPhone 13; larger text/landscape remains scrollable with ≥44-point touch targets.
- **Validation:** Final `full.K43ryP/` passed Release/static/tooling checks, 158 unit/integration tests and 28 UI executions; ItemHomeViews had 100% line coverage. Checks include equal-height rows, complete unclipped guidance, Continue enablement and all choices at largest text. Reviewed light/dark, largest-text and landscape captures. Earlier baseline bounds checks missed clipped guidance; the final assertion checks the full line. Signed build installed in place (`selector-device.Xa6H1m/`); initial launch was blocked by the locked phone, not counted as acceptance.
- **Closure (2026-10-25):** User approved the latest visual presentation and confirmed selection/count/cancel/save interactions. Physical visual acceptance is complete.

## ISS-002 [RESOLVED] — Item setup replay has no accessible configuration setting

- **Priority:** P2.
- **Observed/cause:** Only a code method/launch override existed for D-067's resettable setup.
- **Expected/implementation:** One-shot Reset Item Setup in Apple Settings, applied on launch/activation. Clear selected items and setup completion, dismiss open sheets, show empty setup with Continue disabled until selection, preserve Home preferences/caches, consume once and retain the newly confirmed selection after relaunch. The user's clear-selection amendment supersedes the earlier selection-preserving implementation.
- **Validation:** Actual Settings foreground/cold-reset, open-sheet dismissal, empty selector, new confirmation and relaunch regressions passed in `full.N0rUjo/`: Release/static/tooling checks, 158 unit/integration tests and 26 UI executions. ItemSelectionStore/reset helpers had 100% line coverage; unrelated-storage checks and empty-selector visual review passed. Revised signed build installed (`item-setup-reset-device.WAyu97/*clear-selection*`); initial automatic launches were blocked by the locked phone, not counted as behavioral acceptance.
- **Closure (2026-10-25):** User confirmed the Settings setup-reset and selection interaction checks. The physical Settings/reset acceptance is complete; no new automated run is inferred from that confirmation.

## ISS-001 [RESOLVED] — Open-Meteo precipitation is assigned to the following hour

- **Priority:** P1.
- **Observed/cause:** Source inspection on 2026-10-20 and a failing regression showed precipitation/chance stamped 10:00 (representing 09:00–10:00) attached to the interval starting at 10:00.
- **Expected/implementation:** Match preceding-hour accumulated fields to their interval start; do not shift instantaneous temperature/condition/wind/daylight. Reject pre-fix cached normalization. This corrects mapping, not product thresholds, precedence, grouping or freshness.
- **Acceptance/validation:** Baseline `provider-baseline.S8FvT3/` executed five tests and reproduced the alignment defect (the earlier zero-test filter is not baseline evidence). All 23 focused provider/cache tests passed (`provider-focused.z5hu4N/`), covering dry/wet transitions, current/day-end coverage, timezone/DST and cache compatibility. `full.IIvHCq/` passed Release/static checks, 112 unit/integration tests and 19 UI tests. Changed mapping helpers/cache-save logic had 100% line coverage; a fixed-coordinate macOS probe returned 168 normalized hours (`provider-live.2Fgy4M/`). No physical-device reproduction/verification or global reliability claim.
- **Reference:** https://open-meteo.com/en/docs
