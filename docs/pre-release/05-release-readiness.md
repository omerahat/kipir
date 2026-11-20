# 05 — Release readiness

## Build status
- Debug and Release builds: **BUILD SUCCEEDED**. A clean Release build in fresh derived data reported 0 Swift warnings (grep `\.swift:N:N: warning:`).
- Project membership is complete: `StatusBarController.swift` is in the app target; `CountdownRing.swift` is in the app and test targets.
- Signing identity, bundle identifier and entitlements are unchanged.
- No new permissions or dependencies.

## Automated tests
- SPM: **165/165**. The baseline was 157; there are 8 new tests and the meeting-freeze tests were rewritten.
- Xcode: **177/177**. The baseline was 164. The 165 shared tests are joined by 4 native tests (ring pixels, label bitmap pixels, click routing, language persistence) and 8 `NotificationManager` tests, one of them new.
- Localization script: **6/6**.

## Manual tests
Only partial on-device evidence exists:
- An isolated verification copy launched.
- Its status item width stayed constant across a Turkish/English/System language switch.
- The popover opened once at 330 pt wide.

Scripted clicking was abandoned on the owner's live desktop, so the following were **not** manually verified:
- Pause, meeting and state transitions with the popover open (popover position)
- Light/Dark on both surfaces
- A real notification click
- Full bilingual walkthrough
- Restart behavior
- VoiceOver and keyboard use

**Open risk for Fix 5 (first manual check):** AX-press opening of the popover in the scripted session closed it again almost immediately. This may be an artifact of scripted activation, because macOS 14's cooperative activation can refuse `activate(ignoringOtherApps:)` when no user event is behind it. If the cause is refused activation, a notification click while Kıpır is inactive could flash the popover and close it, which would look like a dead click. The cause is unknown; verify first with a real notification click while another app is frontmost.

## Release gates
| # | Gate | State |
|---|---|---|
| 1 | Countdown direction | Fixed; automated pass (math + pixel render). Manual look pending. |
| 2 | Width change → popover jump | Root cause removed by construction; automated pass; language-switch width verified on device. Popover-position check during state changes pending. |
| 3 | Meeting stops/corrupts timer | Fixed; automated pass. |
| 4 | Meeting notifications delivered | Fixed (suppressed, consumed, no replay); automated pass with the real manager. Device banner check pending. |
| 5 | Light mode not on popover | Fixed at root (single appearance source); **manual verification pending**. |
| 6 | Notification click doesn't open | Fixed (routing + queued open); routing automated; **real click pending**. |
| 7 | Untranslated major interface | Tables complete and checked; System Default added; **bilingual walkthrough pending**. |
| 8 | Timer regressions | None in the 165/177 suites; intentional meeting-behavior changes documented (DECISIONS 028). |
| 9 | Popover operation broken | Presentation layer was replaced (DECISIONS 030); **open/close, transient dismissal, ⌘, Settings, keyboard shortcuts in the break guide need manual confirmation**. Highest regression risk. |
| 10 | Build/tests fail | Pass. |

## Regression risks (highest first)
1. **New AppKit presentation layer.** Watch for the transient popover reopening or closing on an item click (guarded by a 0.3 s window), activation and focus for the exercise view's arrow and Space shortcuts, `.onAppear` per open (a fresh hosting controller each time), the popover arrow being new, and the Settings window frame autosave.
2. **Template label rendering** on non-Retina displays and with Increase Contrast. The menu bar font size is read once at launch.
3. **Status item under forced Light/Dark.** `NSApp.appearance` is deliberately not set, so it should follow the menu bar; confirm.
4. **Behavior changes users will notice.** Meeting mode no longer pauses, English Macs now default to English, and the menu bar shows minutes with an icon instead of words.

## Remaining bugs / known gaps
- No confirmed open bugs.
- Unverified on device: everything marked NOT TESTED or BLOCKED in 03.
- The language picker does not react to a macOS language change while the app runs; this takes effect at the next launch or Settings change.

## Final recommendation
**Not release-ready yet.** All six mandatory changes are implemented and pass automated tests. But gates 5, 6, 7 and 9 need on-device verification that this session could not perform without driving the owner's live desktop. Run the manual checklist in `03-test-matrix.md` with an isolated build (`PRODUCT_BUNDLE_IDENTIFIER=com.omerahat.kipir.verify`), then do the independent Codex review (`06-codex-review-handoff.md`). If both are clean, the build can be considered release-ready.
