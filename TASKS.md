# Kıpır — Implementation checklist

Status separates implemented/automated evidence from human or device acceptance. No release, push or distribution is authorized.

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
