# 04 — Future UX proposals (not implemented)

## Custom color palettes
- **Current state:** the color architecture is almost entirely semantic (`.primary`, `.secondary`, `.quaternary`, system materials) plus one accent used as the literal `.teal` in about 10 places. These are the ring, the capsule, prominent buttons and onboarding icons. The exercise card is intentionally white.
- **Feasibility:** high. Replace the literal `.teal` with one `Color.kipirAccent` read from a single place. A palette would then be one stored key (for example `accent = teal|indigo|orange`) validated like `appearance`.
- **Light/Dark integration:** define each palette as an asset-catalog color set with Any/Dark variants. Then `NSPopover.appearance` and `NSWindow.appearance` (already the single appearance source, DECISIONS 030) resolve it automatically. Check contrast per variant for the ring track (12 % dark, 20 % light today) and for prominent button text.
- **Useful preparation now:** none required. The literal-to-token swap is a 10-line mechanical change and is best done together with the feature.
- **Defer:** a picker UI, per-surface colors, and any user-defined colors (contrast cannot be guaranteed).

## Dynamic menu bar character icons
- **Geometry:** fully compatible with Fix 2 if each pose is drawn into the existing fixed 18 pt icon slot of the constant-size template image (`StatusBarController.labelImage`). The item width cannot change by construction. Requirement: every pose must be authored on the same canvas (for example 18×18 pt, same baseline) so the figure doesn't jitter inside the slot.
- **Monochrome:** menu bar art must be template (alpha-only). Character poses need solid silhouettes, no interior shading, and strokes of at least 1.5 pt at 1× to survive 16 px rendering. Color is not available, so state must be legible from silhouette alone.
- **Clarity:** at 16–18 px, four poses (working, break, paused, meeting) are distinguishable only with strong silhouette differences. A small corner badge (pause bars, two-person glyph) on one base character is more legible than four whole-body poses.
- **Accessibility:** state is already in the tooltip and VoiceOver summary, so icons can stay decorative. Avoid animation in the menu bar; if any, respect Reduce Motion and keep it out of the heartbeat path.
- **Recommendation:** feasible next release. Keep `figure.walk` as the working pose and prototype badge variants first.

## Exercise animation replacement considerations
Out of scope, so no changes were made.
- Playback contract to preserve: the visual clock follows only scheduler-accepted elapsed time (`ExerciseVisualClock`, `exerciseVisualNeedsResync`), TimelineView is rendering-only (≤30 fps, paused when frozen), and Reduce Motion shows still poses.
- A new direction (for example short looping clips or a vector rig) should plug in behind `ExerciseAnimationView(movement:elapsed:duration:frozen:)` without touching the scheduler.
- **Observed issue to carry over:** `frozen` is `status != .onBreak`. This was correct only because meeting used to freeze breaks. It now relies on `onBreak` outranking `meeting` in `status` (Fix 3), which is covered by tests.
- The white card in dark mode remains a design decision pending review (TESTING manual item 4).
