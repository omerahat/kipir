# 06 — Handoff for independent (Codex) review

No independent review agent was available in this session. This is a handoff, **not** a completed review. The author's own checks are in 03/05 and are not independent.

## Scope
Working tree on `main` (uncommitted), relative to `12b2220`.
- **Source:**
  - `Kipir/Core/BreakScheduler.swift`
  - `Kipir/Core/QualityOfLife.swift`
  - `Kipir/App/StatusBarController.swift` (new)
  - `Kipir/App/StatusLabelImage.swift` (new)
  - `Kipir/App/KipirApp.swift`
  - `Kipir/App/AppController.swift`
  - `Kipir/App/NotificationManager.swift`
  - `Kipir/UI/CountdownRing.swift` (new)
  - `Kipir/UI/MenuBarView.swift`
  - `Kipir/UI/SettingsView.swift`
  - `Kipir/UI/Localization.swift`
  - `Kipir/UI/Exercises/BreakExerciseView.swift`
  - `Kipir/Info.plist`
  - `Kipir/Resources/{tr,en}.lproj/Localizable.strings`
  - `Kipir.xcodeproj/project.pbxproj`
- **Tests:** `KipirTests/*.swift`, `Scripts/test-localization.py`.
- **Docs:** `docs/pre-release/*`, `DECISIONS.md` (028–030), `CHANGELOG.md`, `TASKS.md`, `TESTING.md`, `ARCHITECTURE.md`, `DESIGN.md`, `README.md`.

## Intended behavior
See 01 (root causes) and 02 (changes). Key invariants:
1. **Meeting mode** never affects time. `!meeting` remains only in `reminderID`. The current Due episode is marked as attempted while a meeting runs.
2. **Menu bar label** is a constant-size image per style; its content is never variable-width.
3. **Popover** comes from one `showPopover()` for both the item click and a notification click. It is idempotent, and an open request is queued before install.
4. **Appearance** has one source, applied to both surfaces.

## Please scrutinize
- `BreakScheduler.tick()`: removal of the meeting early-return on expiry, and the new `delta == 0` no-op. Check that no sample can now be credited twice or across an unknown gap.
- `NotificationManager.sync`: interaction of `markingMeetingSuppressed` with `visible`, `lastAttempted` persistence and in-flight `add` tasks.
- `StatusBarController`:
  - transient-close vs. item-click race and the 0.3 s guard
  - `NSApp.activate(ignoringOtherApps:)` on macOS 14+ (deprecated; cooperative activation)
  - popover `contentViewController = nil` on close
  - `$revision` (willSet) subscription deferral
  - KVO closure isolation
  - status-item highlight
- Whether `status` precedence `suspended > paused > onBreak > meeting > offHours > due` is right for every UI consumer (`breakDueActionable`, exercise `frozen`).
- The pixel test's robustness (fixed geometry, scale 1).

## Known limitations
See 05: on-device verification is pending for the popover position, appearance, notification click and bilingual walkthrough.
