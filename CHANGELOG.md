# Kıpır — Changelog

## 0.1.0 — 2026-10-30

Initial native macOS menu bar implementation: confirmed active-work accounting, conservative AFK exclusion, short/long breaks, active snooze, skip, pause, Meeting Mode and reset. Local validated settings/session/day totals; optional actionable notifications and login registration. Turkish localized native panel/settings and generated icon. Deterministic core tests and Xcode project. See TESTING.md for executed evidence and open device acceptance gates.

Verification: Debug and Release builds succeeded; 25 XCTest cases passed in each of SPM and Xcode on the development Mac. Application launch/process was checked; visual UI, physical lifecycle, notification delivery and distribution acceptance remain pending. Added regression coverage for fractional AFK accounting, stable reminder identities, original break progress after settings changes, and active work while overdue.

Local notification setup: documented the ad hoc signed Debug command needed for macOS to register notifications, and Settings now displays the underlying permission-request error for diagnosis. No developer signing identity was added or changed.
