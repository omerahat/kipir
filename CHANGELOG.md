# Kıpır — Changelog

## 0.2.1 — Pre-release stabilization
- The countdown ring now starts full and empties counterclockwise from 12 o'clock, reaching empty exactly at zero; a snooze refills it.
- The menu bar item has a fixed width in every state and language: it always shows the remaining minutes (or "Break"), with the state in the icon. The panel no longer jumps sideways on pause, resume or meeting toggles (DECISIONS 030).
- Meeting mode only silences notifications and the break-completion sound; the timer, statistics and breaks keep running. Reminders silenced during a meeting are not replayed afterwards (DECISIONS 028).
- Light/Dark/System appearance applies to the main panel and Settings together, immediately.
- Clicking a Kıpır notification opens the main panel.
- Language: new "System Default" option (follows macOS; unsupported languages use English), English declared as a bundle localization, corrected meeting copy (DECISIONS 029).
- The work-countdown popover no longer shifts vertically on pause, resume or meeting toggles: the state note moved from above the ring to below the controls (none for pause), and Pause/Resume/break buttons share the row equally so their frame and hit area never change with the label (DECISIONS 031).
- The countdown ring now moves smoothly between heartbeats instead of stepping once per second: a forward tick is interpolated linearly over one second (rendering only; no new timer). Reduce Motion, snooze refills and resets jump (DECISIONS 032).
- Localization checks now cover format arguments, runtime-built keys, unused keys and bundle localizations.

## Unreleased — 0.2 review fixes
- Entering the working window starts a fresh interval; a Due episode from the previous workday no longer returns silently (DECISIONS 025).
- A long screen lock or display sleep counts as being away even when the heartbeat is coalesced; work time is still never credited while locked or asleep.
- Completion and natural-break notices wait up to 15 minutes for the popover, then show for 6 s.
- The checkpoint is saved when a natural or window-entry reset happens; a malformed exercise rotation no longer discards the session.
- Settings states the effective natural-break threshold when the idle threshold raises it; clearer notice and lock copy; onboarding publishes and resumes at the notification step.
- Developer ID script: Gatekeeper assessment and codesign output are captured before grepping (no pipefail/SIGPIPE failures). Removed unused strings.

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

## 0.2.0 — 2026-11-20

- Exercise animations now use illustrated start/end poses (generated with ChatGPT image generation, consistent character) crossfaded on the existing loop, replacing the programmatic Canvas figure. Reduce Motion shows both poses still.
Release build 3: universal ad hoc signed preview distributed through the Homebrew cask (SHA-256 `5ed71eeacebbde47f5d3e82e9dfe1ec667be5680f80326065140bd98efe00478`). Existing settings and checkpoints migrate leniently. Automated evidence is in TESTING.md; device and human acceptance are pending.

Added
- Natural break: a verified no-input span (Off/5/10/15 min, default 10) restarts the work interval and withdraws a due reminder. It never counts as a completed break and never touches the short/long cycle. The effective threshold is max(setting, AFK + 60 s). A short notice appears on the first input afterwards.
- Working hours (weekdays, start, end, overnight allowed): outside the window nothing is credited and no reminder is sent; new `offHours` status.
- Notification state (off, needs permission, denied, limited, active) with a single primary action; diagnostics and test notification moved into a collapsed section.
- Two-step first-run welcome inside the popover.
- Menu bar style (timer or icon), tooltip, per-state status notes, 6-second completion/natural-break notice, break-length presets with a non-destructive Custom row, shared spacing scale.
- Exercise catalog grew from 5 to 11 movements in body areas, with deterministic rotation, optional exercise focus and a redesigned flat vector key-pose illustration set (cosine blending, loop fitting, Reduce Motion pairs).
- `Scripts/release-developer-id.sh` (BLOCKED here: no Developer ID identity) and a `WRITE_CASK=1` guard so packaging no longer rewrites `Casks/kipir.rb` by default.

Changed
- New Settings/Checkpoint keys decode leniently, so 0.1.x data keeps working. Two scheduler tests now set `naturalBreak = 0` because their long no-input spans would legitimately trigger the reset.
- Status wording and layout use consistent spacing; Turkish and English resources cover all new strings.

Not claimed: live UI, VoiceOver, notification delivery, physical sleep/wake, real DST, movement correctness, signing or notarization.
