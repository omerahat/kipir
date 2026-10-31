# Kıpır — Changelog

## 0.1.0 — 2026-10-30

Initial native macOS menu bar implementation: confirmed active-work accounting, conservative AFK exclusion, short/long breaks, active snooze, skip, pause, Meeting Mode and reset. Local validated settings/session/day totals; optional actionable notifications and login registration. Turkish localized native panel/settings and generated icon. Deterministic core tests and Xcode project. See TESTING.md for executed evidence and open device acceptance gates.

Verification: Debug and Release builds succeeded; 25 XCTest cases passed in each of SPM and Xcode on the development Mac. Application launch/process was checked; visual UI, physical lifecycle, notification delivery and distribution acceptance remain pending. Added regression coverage for fractional AFK accounting, stable reminder identities, original break progress after settings changes, and active work while overdue.

Local notification setup: documented the ad hoc signed Debug command needed for macOS to register notifications, and Settings now displays the underlying permission-request error for diagnosis. No developer signing identity was added or changed.

## Unreleased — Animated movement guide
Added an optional-to-watch menu bar break guide, offline vector exercise demonstrations, Turkish instructions/safety notes, short/long sequences, previous/next/skip, pause/resume and early finish. Reuses the scheduler heartbeat and sleep/AFK policies. Reduce Motion provides static key poses. Added deterministic integration tests; see TESTING.md for actual results and remaining human acceptance.
- Move exercise guidance into the existing menu bar popover; remove separate window and revert dataset integration.

## Unreleased — Homebrew preview packaging
Add universal ad hoc signed Release ZIP generation, exact-checksum Homebrew cask
and Turkish distribution/installation guidance. No scheduler, application permission,
persistence or project signing identity changes. Not notarized; publication and
real downloaded-install acceptance remain pending.

## Unreleased — Turkish and English
Add Settings → General → Language with Türkçe / English, persisted on this Mac and applied immediately. Translate panel, settings, exercise guidance, accessibility labels and future notifications. Preserve work, break, statistics and notification episode identity.

## Unreleased — Exercise illustrations v2
Replace stick figures with original native Canvas illustrations and movement-specific poses. A monotonic visual clock freezes on pause and does not control break timing.

Exercise illustration refinement: adjust shoulder range, use a side-view in-place step with a stationary supporting shoe, keep the calf-raise support hand anchored and improve dark-appearance clothing contrast. Human movement and live UI acceptance remain pending.

## 2026-10-31 — Quality of life
- Added live localized menu bar minutes and distinct frozen-state indicators.
- Added isolated, authorization-refreshed test notifications and honest submission guidance.
- Added derived Quick Focus/Balanced/Custom timing selection without session resets.
- Added persisted 15/30/60-minute Meeting Mode with early end, replacement and conservative wake/restore expiration.
- Added independent default-off natural break completion sound, using native quiet Tink exactly once per consumed event.
- Preserved legacy settings/checkpoints, existing exercise artwork/playback, AFK rules, short/long cycles and daily totals. Added deterministic lifecycle, migration, formatting, preset and feedback coverage; device acceptance is tracked in TESTING.md.

## 2026-10-31 — Notification banner visibility
- Separate notification authorization/submission from actual desktop-alert eligibility, including provisional quiet permission and Notification Center/sound settings.
- Request banner and list in foreground, sound only when configured in the content and permitted by system settings.
- Add Turkish/English visibility warnings and a best-effort notification settings opener with fallback; refresh when returning to Settings.
- Test results report accepted requests, never confirmed visible banners. Preserve scheduler, daily statistics, reminder UUIDs and cancellation guards.

## 0.1.1 — 2026-10-31
Release build 2 packages the quality-of-life features, updated native exercise artwork and notification visibility guidance above. Universal ad hoc preview; existing user settings/checkpoints remain compatible. Homebrew cask pins the new immutable archive SHA-256. Version/build metadata now comes from Config.xcconfig for both Info.plist fields.
