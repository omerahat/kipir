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
