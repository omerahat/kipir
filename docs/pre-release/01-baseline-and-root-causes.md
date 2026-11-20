# 01 — Baseline and root causes

Date: 2026-11-20. Starting point: `main` at `12b2220` (Release 0.2.0); untracked `PRODUCT.md`, `docs/PRODUCT_DISCOVERY.md` and `.swiftpm/` were preserved untouched.

## Architecture as found

| Area | Implementation |
|---|---|
| Lifecycle / entry | `Kipir/App/KipirApp.swift`: SwiftUI `App` with `@NSApplicationDelegateAdaptor(AppDelegate)`; `LSUIElement` menu-bar-only app. |
| Deployment | macOS 14.0, Swift 5 mode with `SWIFT_STRICT_CONCURRENCY=complete`, SwiftUI + AppKit, no third-party dependencies. |
| Menu bar item | SwiftUI `MenuBarExtra` with `.menuBarExtraStyle(.window)`; the label is a `Label`/`Image` whose content depends on state. |
| Popover | The `MenuBarExtra` window hosting `MenuBarView` (fixed 330 pt width). |
| Timer / state | `Kipir/Core/BreakScheduler.swift`: monotonic deltas from the single 1 s heartbeat in `AppController`; phases `working/due/onBreak`; `paused`, `meeting`, `suspended` flags; derived `WorkStatus`. |
| Meeting mode | `Checkpoint.meeting` + optional `meetingDeadline`; `setMeeting` in scheduler and controller. |
| Notifications | `Kipir/App/NotificationManager.swift` (`UNUserNotificationCenter`), immediate requests (no scheduled triggers), one per Due episode (`dueID`), persisted `lastNotificationAttempt`. |
| Sound | Notification sound (system) + `NSSound("Tink")` break-completion sound via `BreakCompletionFeedback`. |
| Appearance | `Settings.appearance` (`system/light/dark`) applied with `.preferredColorScheme` on the popover and the SwiftUI `Settings` scene. |
| Persistence | `LocalStore` (UserDefaults JSON for settings/checkpoint), plus `language`, `onboarded`, `lastNotificationAttempt` keys. |
| Localization | `tr.lproj`/`en.lproj` `Localizable.strings`, `L(key)` helper picking the bundle from the `language` default (`tr` unless `en`), `Scripts/test-localization.py`. |
| Exercises | Foundation catalog/playback (`Core/Exercises.swift`), `UI/Exercises/*` raster key poses. |
| Tests / scripts | 157 SPM XCTest cases, 164 Xcode (7 native `NotificationManager` tests extra); release scripts in `Scripts/`. |

### Baseline commands (before any change)
- `swift test --scratch-path <scratchpad>/spm`: **157/157 passed**, exit 0.
- `xcodebuild -project Kipir.xcodeproj -scheme Kipir -configuration Debug -derivedDataPath <scratchpad>/dd CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual CODE_SIGNING_ALLOWED=YES test`: **164/164, TEST SUCCEEDED**, exit 0.
- No pre-existing failures.

## Fix 1 — Countdown ring direction
- **Original behavior:** the ring filled up as work accumulated.
- **Root cause:** `MenuBarView` drew `Circle().trim(from: 0, to: engine.progress)`, and `BreakScheduler.progress` is `activeWork / target` (count-up) for the work interval.
- **Evidence:** `Kipir/UI/MenuBarView.swift` (ring), `Kipir/Core/BreakScheduler.swift` `progress`.
- **Solution:** new authoritative `BreakScheduler.remainingFraction` = clamp(remaining / total, 0, 1), where total is the break length on a break, the snooze length after a snooze, otherwise the target. The ring (`UI/CountdownRing.swift`) draws `trim(0, fraction)` rotated −90°: an arc from 12 o'clock clockwise whose free end recedes counterclockwise. `progress` is kept unchanged for the exercise `ProgressView`.

## Fix 2 — Menu bar width instability / popover jumping
- **Original behavior (user-observed):** item width changes on pause/resume/meeting toggles; the open panel shifts horizontally.
- **Root cause (code-level, confirmed):** `MenuBarStatusFormatter.textKey` returned different content per state: minutes for working/idle, `nil` (icon only) for paused, "Toplantı"/"Meeting" for meeting, "Mola %d dk" on break, "Beklemede", "Mesai dışı". The `MenuBarExtra` label is a variable-length status item sized to that content, so every state change resized it; status items grow leftwards, the item's center moves, and the `MenuBarExtra` window, which is anchored to the item, moves with it. The only guard was `.frame(minWidth: 64)` for the minutes text, which did not cover other states. Icons of different widths contributed too.
- **Evidence:** `Kipir/App/KipirApp.swift` (label), `Kipir/Core/QualityOfLife.swift` (`textKey`, `symbol`).
- **Solution:** AppKit `NSStatusItem` that displays one constant-size template image: an 18 pt icon slot plus a text slot measured at launch over every label string in **both** languages (`MenuBarLabelLayout`). Text is always the remaining minutes (or "Mola"/"Break" when due); the state is shown only by the icon in its fixed slot. The popover is an `NSPopover` anchored to the button bounds with a fixed 330 pt content width.

## Fix 3 — Meeting mode paused time
- **Original behavior:** meeting mode froze work credit, the countdown, the break, the exercise playback, statistics and natural-break accrual.
- **Root cause:** `!meeting` guards in `BreakScheduler.tick()` (credit and break countdown), `canAccrueAway`, `perform(.startBreak/.snooze)`, plus `baseline()` and `pending = 0` on toggling/expiry. The UI also disabled "Start break" in a meeting, and `status` ranked `.meeting` above `.onBreak`, which froze the exercise animation. In addition, a Due episode that began during a meeting was delivered when the meeting ended (the episode was only postponed).
- **Evidence:** `Kipir/Core/BreakScheduler.swift`; tests that asserted freezing (e.g. `testTimedMeetingStartsFreezesAndExpiresAtDeadline`, `testMeetingSuppressesDueAndRestoresSameReminderAfterExpiration`).
- **Solution:** all `!meeting` timing guards removed; `!meeting` kept only in `reminderID`. `NotificationPolicy.markingMeetingSuppressed` makes the manager record the current Due episode as attempted while a meeting runs, so it is never replayed; later episodes get new IDs and notify normally. The break-completion sound is suppressed but still consumed. `onBreak` outranks `meeting` in `status`. The manual break and snooze stay available.

## Fix 4 — Light appearance not applied to the main panel
- **Original behavior:** Settings turned light; the menu bar panel stayed dark.
- **Root cause:** `.preferredColorScheme` reaches the SwiftUI `Settings` window, but the `MenuBarExtra` window's appearance follows the menu bar/status item it is attached to, not the hosted SwiftUI preference. `.preferredColorScheme(nil)` also does not reliably revert a forced scheme. Two independent mechanisms, no single source.
- **Evidence:** `KipirApp.swift` (`preferredColorScheme` on both scenes), `BreakExerciseView` (a third copy).
- **Solution:** one function (`StatusBarController.applyAppearance`) applies `Settings.appearance` to the popover (`NSPopover.appearance`) and the Settings window (`NSWindow.appearance`). "System" resolves the system appearance explicitly for the popover (left unset, a popover inherits the menu bar's appearance) and re-resolves on `NSApp.effectiveAppearance` changes. All `preferredColorScheme` uses were removed.

## Fix 5 — Notification click did nothing
- **Original behavior:** clicking a delivered notification did not show Kıpır.
- **Root cause:** `didReceive` mapped only the action buttons; `UNNotificationDefaultActionIdentifier` (body click) fell into `default: nil`. The test notification's `kipir.test.<uuid>` identifier failed the `UUID(uuidString:)` gate entirely. `MenuBarExtra` also has no public API to present its window.
- **Evidence:** `NotificationManager.userNotificationCenter(_:didReceive:)`.
- **Solution:** `NotificationManager.route` maps a body click on any Kıpır notification to `.openPanel`; `onOpen` → `AppController.onOpenRequest` → `StatusBarController.requestOpen()`, which calls the same `showPopover()` as a click on the item. It is idempotent if already shown, and requests that arrive before the status item exists are queued (`pendingOpen`). The controller and the delegate are created in `applicationWillFinishLaunching`, so a launch-by-click response has a delegate.

## Feature 6 — Localization gaps found
- The language default was Turkish even on an English Mac: no "System Default".
- `Info.plist` `CFBundleLocalizations` listed only `tr`.
- Two strings became false with Fix 3 (`ui.status.note.meeting`, `settings.accounting`).
- Four menu bar keys became unused with Fix 2.
- The check script did not cover runtime-built keys (`status.*`, `ui.status.note.*`, `ui.notif.state.*`, `exercise.*`) or detect unused keys.
- Otherwise every visible string already went through `L()` with complete tr/en tables, including exercises, notifications, accessibility labels and dialogs.

## Other observations (not changed)
- A sample at the same instant (`delta == 0`) used to zero the pending unconfirmed span. Fixed (now a no-op), because back-to-back meeting toggles could lose a few seconds of credit.
- Exercise artwork/animation: out of scope; see 04.
