# Daypart refinement — proposal

**Approved and authorized (2026-11-02, D-087).** These remain edited review
artifacts, not proof of native implementation or validation; see `../../TODO.md`.
The subsequent no-scroll follow-up keeps these tile interiors but rebalances
mini-hero outer vertical padding and hero-to-daypart gaps to 6 points (D-087 / UX).
These older edited full-screen PNGs do not depict that final parent-card spacing.

`comparison.png` shows current versus proposed dark-mode mini heroes and gallery.
`mini-proposed.png` and `gallery-proposed.png` are full-screen edited captures.

- Proposed finished card/pill: visible neutral grays, not near-black; readable muted text.
- Proposed overview spacing: 4-point stack gaps, 8-point vertical tile padding,
  and 3-point vertical status-pill padding. Approximate row growth: 16 points
  for mini heroes and 14 points for gallery.
- Native artwork, hero copy, fonts, active colors, daypart values and horizontal
  placement are retained. Parent cards grow; following content moves down.
- Review artifacts only, not native layout or accessibility validation.
  D-087 refines D-080, not recommendation behavior.

`generate.py` creates the image edits from the existing local D-080 native
captures in `.build/verification/ui-polish-focused-3-attachments/`. The gallery
capture's transient blank header is replaced with the matching native mini
header for both comparison sides. Saved PNGs do not require these local inputs
to view. Full-screen proposals retain the phone's viewport and may move footer
content below it; actual viewport fit must be verified if implemented.
