# 02 — Implementation summary

## Changes
| Requirement | Change | Files |
|---|---|---|
| Fix 1 ring | `remainingFraction` (Core), `CountdownRingMath.clamped`, `CountdownRing` view (12 o'clock anchor, recedes counterclockwise; light-mode track 20 %, dark keeps 12 %) | `Core/BreakScheduler.swift`, `Core/QualityOfLife.swift`, `UI/CountdownRing.swift` (new), `UI/MenuBarView.swift` |
| Fix 2 width | `MenuBarExtra` replaced by `StatusBarController` (`NSStatusItem` + `NSPopover`); constant-size template label image; `MenuBarLabelLayout` measures the text slot over both languages; formatter always shows minutes (or "Break" when due), state via icon | `App/StatusBarController.swift` (new), `App/StatusLabelImage.swift` (new, app + test targets), `App/KipirApp.swift`, `Core/QualityOfLife.swift` |
| Fix 3 meeting | Removed meeting from all timing guards; `breakDueActionable`; `onBreak` outranks `meeting`; setMeeting no longer rebaselines; expiry no longer drops the sample; `markingMeetingSuppressed` (no replay); Tink suppressed in meetings; same-instant samples keep pending credit | `Core/BreakScheduler.swift`, `Core/QualityOfLife.swift`, `App/NotificationManager.swift`, `UI/MenuBarView.swift` |
| Fix 4 appearance | One `applyAppearance()` for popover + Settings window; explicit system resolution + KVO; `preferredColorScheme` removed everywhere | `App/StatusBarController.swift`, `App/KipirApp.swift`, `UI/Exercises/BreakExerciseView.swift`, `App/AppController.swift` |
| Fix 5 click-to-open | `NotificationManager.Route`/`route(...)`, `onOpen`; `AppController.onOpenRequest`; `requestOpen()` with queued pending open; delegate created in `applicationWillFinishLaunching` | `App/NotificationManager.swift`, `App/AppController.swift`, `App/StatusBarController.swift` |
| Feature 6 language | `AppLanguage` (system/tr/en, unsupported → English), `currentLanguage(defaults:)`, `languagePreference`, Settings picker "System Default", `CFBundleLocalizations` tr+en, corrected copy, removed unused keys, extended checker | `Core/QualityOfLife.swift`, `UI/Localization.swift`, `UI/SettingsView.swift`, `Info.plist`, `Resources/*/Localizable.strings`, `Scripts/test-localization.py` |
| Settings window | Own `NSWindow` hosting `SettingsView` (frame autosave `KipirSettings`); the SwiftUI `Settings` scene is empty and its ⌘, command opens the AppKit window | `App/StatusBarController.swift`, `App/KipirApp.swift` |

## Architecture decisions
- **DECISIONS 028**: meeting mode is notification-only.
- **DECISIONS 029**: language "System Default" and English fallback.
- **DECISIONS 030**: AppKit status item, popover and Settings window.

The reasoning behind 030 is that `MenuBarExtra` offers no programmatic presentation (Fix 5), no fixed label geometry (Fix 2) and no appearance control for its window (Fix 4). One small AppKit controller fixes all three root causes, instead of three workarounds around private window internals. `SettingsLink` needs a SwiftUI scene context and `showSettingsWindow:` is unreliable on macOS 14, so Settings moved to an owned window as well.

The single heartbeat, scheduler authority and persistence formats are unchanged. No checkpoint or settings schema change; the `language` key keeps its values, and a missing key now means "system".

## New and changed tests
- **Core (SPM + Xcode)**:
  - `testRemainingFractionStartsFullAndDepletesExactlyToZero`
  - `testRemainingFractionFreezesOnPauseAndSuspensionAndResumesWithoutDrift`
  - `testRemainingFractionForSnoozeBreakSettingsChangeAndMeeting`
  - `testMenuBarTextSlotFitsEveryStateCountdownAndLanguage` (reads the real string tables)
  - `testLanguageResolutionHonorsExplicitChoiceSystemOrderAndFallback`
  - `testAppearancePreferencePersistsAndInvalidValuesRecover`
  - `testTimerReachesZeroDuringMeetingAndBreakRunsSilently`
  - `testMeetingConsumesDueReminderWithoutReplayAndLaterEpisodesNotify`
  - `testMeetingToggleKeepsUnconfirmedCreditAndRapidTogglesAreHarmless`
- **Native (Xcode only)**:
  - `testCountdownRingDrawsRemainingArcClockwiseFromTwelve`: an `ImageRenderer` pixel test at 100/75/25/0 %.
  - `testNotificationClickRoutesToPanelAndActionsToSchedulerOnly`
  - `testLanguagePreferencePersistsAndSystemDefaultFollowsPreferredLanguages`
  - `testMeetingSuppressesReminderAndNeverReplaysItAfterwards`: the real `NotificationManager` with a recording delivery.
  - `testStatusLabelImageIsConstantSizeAndDrawnAtFullScale`: the real menu bar bitmap at 2×, one size for all states.
- **Rewritten to the new invariant**: 9 existing tests that asserted the meeting freeze, and 3 formatter tests. Their sleep, wall-clock and unknown-gap fail-closed assertions were kept.
- **Localization script**: format-argument parity, runtime-built keys, unused keys, and `CFBundleLocalizations` in source and built app.

## Trade-offs
- **Popover arrow:** `NSPopover` shows an arrow; the old `MenuBarExtra` window did not. Size, content and materials are otherwise native.
- **Menu bar text:** a Due episode behind a meeting, pause or off hours reads "Mola"/"Break" (`breakDue`). Otherwise, paused, meeting, suspended, off-hours and break now show minutes plus an icon instead of words. Words in some states and not others are what changed the width. The full status stays in the tooltip and VoiceOver label, and break uses `figure.walk.motion`. The approved app icon (`figure.walk`) is unchanged.
- **Item width:** about 69–72 pt, measured over the widest string, "888 min". The icon-only style is a fixed 18 pt image.
- **Long meetings without input:** these now follow the normal idle and natural-break rules, so a long silent meeting can restart the interval. This follows from meeting mode being orthogonal to timing.
- **Ring after a snooze:** it refills and counts down the snooze length. If the snooze setting changes during a snooze, the fraction clamps at 1 until it falls below the new length.
- **Fallback language:** English for unsupported system languages, chosen because non-Turkish users are more likely to read English. Turkish remains the development region.
