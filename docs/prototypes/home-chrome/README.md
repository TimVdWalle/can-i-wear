# Home chrome — changes 4–6

For the complete compaction/resume index, read `../../UI_POLISH_HANDOFF.md`. D-086 resolves location alignment; implementation still waits for the user's final go.

`changes-456-proposal.png` is an edited-native-capture review board. Approval is **partial** on 2026-10-28:

- **5 approved (D-084):** optional debug left, configuration rightmost in the shared Home footer, including single-item Home. Debug shown enabled only for review.
- **6 approved (D-085):** remove the shared daypart/hour key above the gallery and its space. Keep per-item dayparts and accessible timing.
- **4 not approved:** multi-item location beside the section heading remains under trailing-alignment review. Do not treat its placement in this image as locked. Single-item header remains unchanged.

Previously approved artwork-background removal is included; the independently approved D-080 daypart restyle is not applied in this comparison. This is not an implemented app screenshot, live forecast, new native validation or implementation permission. **Wait for the final implementation go.** Requirements belong in `../../DECISIONS.md` and `../../UX.md`.

## Selected location alignment — D-086

The user subsequently selected the exact placement from the blue-guide prototype **without the blue guides**, rejecting the later outer-card-edge trial. This resolves the pending location review above; the initial combined board remains only partially approved.

- `location-inset-clean-proposal.png`: selected clean mini-hero/gallery review board.
- `mini-location-inset-clean.png` / `gallery-location-inset-clean.png`: individual edited captures with exactly that locality placement.

Align locality/pin beside the existing multi-item section heading with the inset content/daypart edge, not the outer rounded card edge. No additional optical adjustment; no guides in the app. Single-item locality stays unchanged. D-080's independent daypart styling and the final implementation hold remain in force. These are image edits, not app implementation or native validation.
