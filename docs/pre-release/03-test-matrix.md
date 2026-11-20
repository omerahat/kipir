# 03 — Test matrix

Legend: **PASS** verified; **AUTO** automated pass, manual verification pending; **PARTIAL** partly observed on device; **NOT TESTED**; **BLOCKED** by environment. Logs are in the session scratchpad (`logs/final-*.log`).

GUI context: a verification copy was built with `PRODUCT_BUNDLE_IDENTIFIER=com.omerahat.kipir.verify`, so the installed Kıpır and its preferences were never touched. It was launched and its status item was read through the accessibility API.

Scripted clicking was stopped for two reasons. It triggered a macOS screen-recording permission prompt on the owner's live desktop. Also, the item sat on a secondary display whose foreground app was full screen. Only read-only geometry checks were done after that. The verification copy was quit and its preferences domain deleted.

## Fix 1 — Countdown ring
| Scenario | Expected | Actual | Status |
|---|---|---|---|
| 100/75/50/25/0 % remaining | full → ¾ → ½ → ¼ → empty | fractions exact (`testRemainingFractionStartsFull…`) | AUTO |
| Direction / 12 o'clock anchor | 9–12 quadrant empties first at 75 %; only 12–3 left at 25 % | pixel samples of the rendered `CountdownRing` match (`testCountdownRingDrawsRemainingArcClockwiseFromTwelve`) | AUTO |
| Empty state keeps track | track visible, no accent | alpha > 0 and < 0.5 at all samples | AUTO |
| Pause / resume | freezes, resumes from same point | `…FreezesOnPauseAndSuspension…` | AUTO |
| Sleep/wake | no credit, same position | suspension test + restore | AUTO (physical sleep NOT TESTED) |
| Snooze, break, work-duration change, meeting | refill on snooze; break countdown; recomputed on change; keeps moving in meeting | `…ForSnoozeBreakSettingsChangeAndMeeting` | AUTO |
| Due / past zero | stays 0, never wraps | asserted | AUTO |
| Reopen popover | ring reflects scheduler state | fresh hosting view per open reads `remainingFraction` | NOT TESTED on device |
| Visual smoothness on screen | unchanged per-second steps | — | NOT TESTED on device |

## Fix 2 — Menu bar geometry
| Scenario | Expected | Actual | Status |
|---|---|---|---|
| Every state × countdown (240 min…0) × tr/en fits the slot | no clipping | `testMenuBarTextSlotFitsEveryStateCountdownAndLanguage` (real string tables) | AUTO |
| Width independent of state/language | constant | constant image size by construction; `testStatusLabelImageIsConstantSizeAndDrawnAtFullScale` renders the real bitmap (2×, same size for every state, text reaches the slot end); PNG inspected offscreen | AUTO |
| Due behind meeting/pause | label reads "Mola"/"Break", not "0 dk" | formatter `breakDue` test | AUTO |
| Turkish → English → System → Turkish on device | width/x unchanged | AX read: `1169,-1139,69,24` all four times | PASS |
| Width at first launch vs later | — | read 72 pt at x 1167 at launch, 69 pt at x 1169 later, unrelated to Kıpır state. Consistent with macOS changing status item spacing when the crowded menu bar re-laid out; not caused by label content | PARTIAL (noted) |
| Running ↔ Paused, Meeting on/off, Work → Break, 60→59, 10→9, 1 min → due, dark ↔ light, rapid toggles, with popover open | no horizontal movement | needs clicks | BLOCKED (manual pending) |
| Display scaling / multiple monitors | sharp, stable | image rendered at max backing scale (≥2×); item seen on secondary display | PARTIAL |
| Before/after popover position evidence | — | one open observed: popover window 330×553 at x 1168 | PARTIAL |

## Fix 3 — Meeting mode
| Scenario | Expected | Actual | Status |
|---|---|---|---|
| Running + meeting | work, stats, countdown continue | `testPauseFreezesButMeetingKeepsCounting`, `testTimedMeetingKeepsCounting…` | AUTO |
| Paused + meeting | stays paused | asserted | AUTO |
| Resume while meeting | counts | asserted | AUTO |
| Timer hits zero in meeting | normal Due transition, no notification, break/snooze available | `testTimerReachesZeroDuringMeetingAndBreakRunsSilently` | AUTO |
| Break completes in meeting | credited, no Tink, not replayed | same test | AUTO |
| Meeting disabled after completion | no replay; next episode notifies | `testMeetingConsumesDueReminder…`, native `testMeetingSuppressesReminderAndNeverReplaysItAfterwards` | AUTO |
| Reminder already shown, then meeting | withdrawn from Notification Center | native test + existing in-flight test | AUTO |
| Rapid toggles | no credit loss, no stuck state | `testMeetingToggleKeepsUnconfirmedCredit…` | AUTO |
| Restart with persisted meeting | restored / expired by deadline; suppressed episode remembered (`lastNotificationAttempt`) | existing restart tests + persisted marker | AUTO |
| Idle / natural break during meeting | ordinary rules | `testMeetingModeKeepsNormalIdleAndNaturalBreakRules` | AUTO |
| Real banner suppression on device | no banner/sound | — | NOT TESTED |

## Fix 4 — Appearance
| Scenario | Expected | Actual | Status |
|---|---|---|---|
| Preference persistence / invalid value | persisted; invalid → system | `testAppearancePreferencePersistsAndInvalidValuesRecover` | AUTO |
| Light/Dark/System on popover + Settings | both match, immediately | single `applyAppearance()` on every publish | NOT TESTED on device |
| Light-mode visual quality / contrast | readable, intentional | track tint raised in light mode only; other colors semantic | NOT TESTED on device |
| Status item under forced Light with dark menu bar | still matches menu bar | `NSApp.appearance` deliberately not changed | NOT TESTED on device |

## Fix 5 — Notification click
| Scenario | Expected | Actual | Status |
|---|---|---|---|
| Body click routing (reminder + test notification) | open panel | `testNotificationClickRoutesToPanel…` | AUTO |
| Action buttons | scheduler actions for the matching episode only | same test | AUTO |
| Already open / multiple clicks | idempotent | `showPopover` returns early if shown | NOT TESTED on device |
| Cold launch / before status item | queued and shown after install | `pendingOpen` path | NOT TESTED on device |
| Settings open | popover shows; Settings stays | — | NOT TESTED on device |
| Real Notification Center click (**first: Kıpır inactive, another app frontmost**) | panel opens and stays open | requires notification permission for a build. The scripted AX-press opening closed almost immediately, cause unknown; refused activation would make this click look dead | BLOCKED (manual pending, top risk) |

## Feature 6 — Localization
| Scenario | Expected | Actual | Status |
|---|---|---|---|
| Key parity, formats, runtime-built keys, unused keys, bundle localizations | complete | `Scripts/test-localization.py` 6/6 OK against the built app | PASS |
| System Default / explicit / fallback resolution | as designed | Core and native tests | AUTO |
| Language switch keeps state | no reset | language is not part of scheduler state; on device the width stayed constant | PARTIAL |
| Every screen in both languages, no truncation | — | — | NOT TESTED on device |
| Native Turkish copy review of the 3 changed strings | — | — | NOT TESTED |

## Regression suites
| Suite | Result |
|---|---|
| `swift test` | 165/165 PASS |
| `xcodebuild … Debug … test` | 177/177 TEST SUCCEEDED |
| `xcodebuild … Release … build` (fresh derived data) | BUILD SUCCEEDED, 0 Swift warnings |
| `python3 -I Scripts/test-localization.py` (`KIPIR_BUILT_APP` = scratchpad Debug app) | 6/6 OK |
