# Testing

## Suites

| Suite | Command | Environment | What it proves |
|---|---|---|---|
| Unit | `npm test` | Node, fake clock (`tests/unit/sim.ts`) | Engine semantics ported from the native `KipirTests`. Boundaries at −1/0/+1 s; AFK retraction; gaps at exactly `GAP_LIMIT` and one second past it; backward and forward clock jumps; same-instant idempotency; lock suspension; day rollover; the short/long cycle; skip and snooze; pause drift over 100 rapid toggles; meeting suppression, expiry and backward-clock cancel; natural-break threshold, locked accrual, taint and restart taint; working-hours exit, entry and Friday→Monday; settings changes; wake scheduling; persistence round-trip and corrupted or malformed recovery; status priority; ring fraction. Also the exercise catalog (native break-1 sequence, sums, focus, cursor, pose blend), settings validation, presets, working hours, the badge, notices, the notification plan, language resolution, the `.strings` parser, tr/en key parity, and every UI key present in both languages. |
| Integration | `npm test` | Node; `Controller` over a fake Chrome platform (storage, alarms, idle, notifications, sound, badge, two views) | A full cycle driven only by alarms. No duplicate reminder under repeated or delayed alarms. Worker restarts mid-session (new `Controller` over the same storage). Browser restart and sleep gaps. Meeting suppression and no replay. Preference and permission gating. Stale notification buttons. Idle retraction and AFK interval updates. A missed idle event caught at the next heartbeat. 21 concurrent intents serialized with both views consistent. A quick browser restart or extension update inside the gap limit credits nothing, even when another event wakes the worker before `onStartup`. Corrupted-storage recovery. Prefs, notice lifetime, icon-only badge. Malformed-message rejection. |
| E2E | `npm run test:e2e` | **Real Chromium 159** (Playwright bundled, headless) with the unpacked `dist-e2e` build | Installation, manifest and permissions, the badge, the tooltip and both alarms. Onboarding. The timer running with the popup closed, and **a real service-worker stop via CDP** followed by correct restoration. Pixel-equal positions of the ring, Pause/Resume and Start break across pause, resume and meeting toggles. A short cycle: the due notification exists, meeting withdraws it and it is not replayed, the break opens exercises, both pose images load into identical boxes, ← → navigation, pause freezes the break, completion counts once with the notice, and the offscreen sound document opens and closes itself. Popup height ≤ 600 px in the due, meeting and break states. Two views stay in sync. Idle freezes the timer. The settings page persists across reload, presets apply, the test notification runs, the notifications-off state, English, dark mode. Locked → suspended; reset. No horizontal overflow in English dark mode. |
| Production smoke | `npm run test:e2e` (`production.spec.ts`) | Real Chromium loading the **unzipped release ZIP** with live `chrome.idle` | The worker registers. The popup and options pages render with no page or console errors. The tooltip format. The production build ignores debug messages. Writes the 1280×800 store screenshots to `test-results/store/`. |
| Packaging | `npm run package` | Node, against `dist/` | MV3; manifest/package version match; exactly five permissions; no host access or content scripts; icons present; no e2e hook, `eval` or inline scripts; no remote URLs. |

The e2e build adds one debug message (an absolute clock offset and a forced idle state), because headless `chrome.idle` reflects the real machine's input. It is compiled out of production, and the packager fails if it is present.

## Latest results (2026-11-23, macOS, Node 26.7, Playwright 1.65.1, Chromium 159.0.8154.6)

| Check | Result |
|---|---|
| `npm run typecheck` | passed, 0 errors |
| `npm run lint` | passed, 0 problems |
| `npm test` | **96 passed** (3 files: engine 52, support 26, controller integration 18) |
| `npm run package` | passed; `release/kipir-chrome-0.2.1.zip` (1550 KB, 41 files) |
| `npm run test:e2e` | **12 passed** in real Chromium: 10 on the e2e build, 2 on the unzipped production ZIP |
| Native `swift test` | 166 + 26 tests, 0 failures (unchanged native app) |
| Native `python3 Scripts/test-localization.py` | OK |
| Native `xcodebuild … build` | BUILD SUCCEEDED |

Screenshots of the verified states are written to `test-results/screenshots/` by the e2e run:

- 00 onboarding
- 01 ready
- 03 work paused
- 04 meeting
- 05 due
- 05b due + meeting
- 06 break
- 07 break paused
- 08 completed
- 09 idle
- 10 settings
- 11 notifications off
- 12 settings dark (English)
- 13 popup dark (English)
- 14 dark meeting (English)

## Not verified automatically

These need a person with Google Chrome on a real machine (checklist in [CHROME_WEB_STORE.md](CHROME_WEB_STORE.md)):

- **OS notification presentation.** E2E proves `chrome.notifications` holds the reminder, not that macOS showed a banner.
- **Notification clicks and buttons.** They cannot be triggered from automation; the routing is covered by integration tests only.
- **`chrome.action.openPopup` and the window fallback** from a notification click.
- **Audible sound.** E2E proves the offscreen document is created and closed, not that sound reached the speakers.
- **Real idle, lock and sleep behavior of `chrome.idle` on macOS.** It is simulated in e2e and modelled in unit tests.
- **The real toolbar badge rendering**, including the width of `Mola`/`Move`. Headless Chromium has no toolbar.
- **Packed-extension alarm timing.** All browser runs load unpacked builds; Chrome documents alarms as at most once per second with possible delay, which is not measured here.
- **Keyboard-only and screen reader (VoiceOver) passes.** The semantics are in place: buttons, `role="timer"`, `role="progressbar"`, `role="switch"`, labelled menus and dialogs, focus rings.
- **A visual comparison against the running macOS app.** The design was taken from DESIGN.md and the SwiftUI source.
- **Browser quit/reopen in a real profile.** Modelled in integration tests (`startup()` after a gap).
