# Kıpır — Implementation checklist

Status separates implemented/automated evidence from human or device acceptance. Local Homebrew packaging is authorized; publishing, push and signing identity changes require separate authorization.

## Milestone 1 — Foundation
- [x] Native project and identity. Acceptance: shared Kipir scheme, configurable bundle ID, 0.1.0, macOS 14 and LSUIElement; Debug app build passed.
- [x] Populated product, architecture, design, security and maintenance documents. Acceptance: all ten required Markdown documents exist and describe actual behavior.
- [x] App launch. Acceptance: `open` succeeded outside the tool sandbox and process remained running; no startup crash report found.
- [ ] Visually verify menu presence and hidden Dock icon. Acceptance: observed native desktop behavior; UI automation timed out, so this remains pending.

## Milestone 2 — Core engine
- [x] Deterministic monotonic accounting with provisional AFK spans. Acceptance: active/idle/return/fractional/long-gap tests pass (final results in TESTING.md).
- [x] Conservative lifecycle and restart handling. Acceptance: sleep, unknown gap, invalid clock, local-day and restart tests pass; no offline credit.
- [ ] Physical sleep/wake, lock/unlock and fast-user-switch. Acceptance: real-device sequence follows TESTING.md without credited suspension.

## Milestone 3 — Break scheduling
- [x] Short/long completion, active snooze, skip, pause, meeting and reset. Acceptance: deterministic transition tests pass and all panel callers compile.
- [x] Stable due identity and frozen break duration. Acceptance: pause/meeting/restart keep an episode; current break progress survives settings changes.

## Milestone 4 — Native UI
- [x] Compact native menu window and Settings. Acceptance: both compile with Turkish resources, app icon, semantic colors, preference-based appearance and accessible control labels.
- [ ] Visual/keyboard/VoiceOver acceptance. Acceptance: light/dark screenshots, focus order, contrast, Reduce Motion and panel height checked on a real Mac; automation unavailable.

## Milestone 5 — System integration
- [x] Local preferences/checkpoint/day totals. Acceptance: isolated defaults round-trip/corruption tests pass; one heartbeat periodically saves confirmed state.
- [x] Optional notification actions and fallback policy. Acceptance: SDK compilation and denied-delivery policy tests pass; stale callbacks check current due UUID.
- [x] Optional login registration and errors. Acceptance: native ServiceManagement code compiles, no registration occurs automatically.
- [ ] Native notification delivery/actions and login acceptance. Acceptance: real authorized/denied/Focus states plus installed signed login registration tested. Unit tests do not establish these.

## Milestone 6 — Verification and delivery
- [x] Execute SPM and Xcode automated tests. Acceptance: actual results/logs in TESTING.md; initial failures corrected before final runs.
- [x] Final Debug/Release builds, final test rerun and documentation reconciliation. Acceptance: both builds succeeded; SPM and Xcode each passed 25 tests; actual results and device gaps recorded in TESTING.md.
- [ ] Extended resource-use/device acceptance and signing/notarization. Acceptance: measured session and distribution review; these are explicitly unfinished, not required to fabricate a local success claim.

- [x] Independent source review. Acceptance: reported due-state accounting defect reproduced and fixed, regression passed, reviewer confirmed correction; no additional critical/important source finding remained.

## Animated exercise guide
- [x] Implement catalog and playback driven by scheduler deltas; deterministic tests cover ordering/durations, automatic advance, navigation, AFK, pause/sleep, restore and single completion.
- [x] Implement embedded menu bar break guide, native Canvas poses, controls, keyboard shortcuts and reduced-motion key poses; project membership reuses existing compiled source files.
- [x] Final build/test results: SPM and Xcode each passed 31 cases; Debug app builds with the existing target. See TESTING.md for evidence and disk-space interruption.
- [ ] Human acceptance: inspect shoulder/wrist/chest/calf/walking cycles in light/dark; check keyboard/VoiceOver, close/reopen and physical sleep/wake. No exercise accuracy/medical validation claimed.

## Popover exercise presentation
- [x] Revert dataset instructions, provenance and bundled license; preserve original vector guide.
- [x] Replace separate break window with the guide in the existing menu bar popover; retain controls and background countdown.
- [ ] Live light/dark, keyboard and close/reopen acceptance on device.

- [x] Popover verification: app compiled; Xcode and SPM each passed 31 tests, 0 failures.

## Homebrew preview distribution
- [x] Native Release ZIP packaging script and generated SHA-256 cask; use existing GitHub repository as an explicit-URL tap.
- [x] Turkish installation, update, uninstall and Gatekeeper guidance; no quarantine bypass, dependency or runtime network code.
- [x] Published immutable v0.1.0 Release assets and cask; verified the existing public GitHub release on 2026-10-31.
- [ ] Test downloaded Homebrew install/upgrade/uninstall and OS integrations on a separate Mac, including macOS 14 and Intel.
- [ ] Developer ID/notarization remain outside the free preview path.

## Turkish and English — 2026-10-30
- [x] Add persistent local language picker, immediate view updates and complete English resources.
- [x] Refresh notification action titles and local permission/error copy without changing due identity or retry policy.
- [x] Include both languages in the Xcode app resources; check key coverage.
- [ ] Human acceptance: switch languages in work/due/break states, reopen Settings and relaunch; check English layout, VoiceOver and new notification actions.

## Exercise illustration v2
- [x] Add original native vector artwork and five movement renderers; preserve scheduler and controls.
- [x] Add monotonic pause-aware visual clock and regression coverage.
- [ ] Human review of anatomical clarity, walking foot contact, wrist switching and all poses; verify motion, light/dark, Reduce Motion and VoiceOver in the running app.

## Exercise visual QA — 2026-10-30
- [x] Generate and inspect light/dark six-phase production-renderer sheets and sampled loop GIFs; correct walking foot contact and calf support hand.
- [x] Add deterministic Meeting Mode and navigation regression coverage; run SPM and Xcode build/test.
- [ ] Verify live popover, pause/resume, closing/reopening, sleep/wake, Reduce Motion, VoiceOver, resource usage and unknown-gap visual clock behavior.
- [ ] Human movement review, particularly shoulder rotation, wrist anatomy, hand-switch timing and in-place walking; animation is not yet accepted as user-ready.

## Quality of life — 2026-10-31
- [x] Menu bar formatter/label through existing heartbeat, localized frozen-state symbols and ceiling rounding.
- [x] Test notification in existing manager with refreshed authorization, separate identifier/category and submitted/error guidance.
- [x] Atomic six-value presets and derived Custom selection; preserve break budget/snooze/cycle/totals.
- [x] Explicit timed/indefinite meeting transitions, persisted deadline, restore/wake expiration and invalid deadline recovery.
- [x] Independent default-off completion sound; consumable natural event and deterministic injected playback tests.
- [x] Backward-compatible missing-field migration tests and Turkish/English resources.
- [ ] Human/device acceptance: menu label actual width/tint, all meeting controls and preset layouts, notification appearance/actions isolation, audible Tink/mute, physical sleep/wake, keyboard/VoiceOver, and sustained CPU/energy.
- [x] Final verification: 52 Foundation SPM tests; 55 Xcode tests; Debug and Release builds passed, plus localization/project/whitespace checks. Commands, logs and failed environment attempts are recorded in TESTING.md; human/device items above remain pending.

## Notification banners — 2026-10-31
- [x] Inspect early delegate registration/lifetime, foreground options, background OS ownership and isolated test path.
- [x] Read all five notification settings; distinguish desktop eligibility, center-only, provisional, denied and unknown.
- [x] Request foreground banner/list and content-dependent sound; respect system sound availability.
- [x] Add localized warning, notification settings action with fallback/manual directions, refresh on activation and honest test submission copy.
- [x] Deterministic settings matrix, native mapping/presentation, delegate/category retention, quiet test isolation and settings-navigation tests: 54 SPM / 61 Xcode tests passed; Debug build passed.
- [ ] Live checks: Banners enabled, alert style None, Focus enabled, Settings foreground test and background test; actual on-screen appearance remains unverified.
- [x] Final banner-fix Release build and localization/whitespace checks passed. Detailed command results and six manual acceptance procedures are in TESTING.md.
