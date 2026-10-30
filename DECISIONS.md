# Kıpır — Decisions

## 001: Native menu utility
SwiftUI MenuBarExtra window, AppKit lifecycle, Foundation engine; macOS 14+. No dependencies, server or event taps. One controller heartbeat avoids competing timers. Tradeoff: macOS-only delivery.

## 002: Confirm active spans conservatively
Buffer input-free time until another event confirms a gap shorter than AFK. Discard on AFK, invalid data, suspension or unknown gaps. This undercounts passive reading and can delay the visible timer by the AFK threshold, but avoids granting a full threshold on every departure. Meeting Mode freezes both schedule and statistics.

## 003: Cycle and overrides
Three completed short timers precede a long timer; completing long resets cycle. Skip resets work without advancing cycle. Snooze adds configurable active work while preserving the pending break kind. Pause/meeting preserve phase and break time. Breaks do not complete offline or while suspended.

## 004: Minimal local recovery
Persist validated confirmed session state and one local-day aggregate, never raw events. Offline elapsed time is not trusted. Crash loss is bounded by periodic checkpointing. Invalid persistence returns to safe defaults. Day rollover excludes the crossing sample.

## 005: Permission and stale actions
Notification authorization is an explicit user action. Denied/failed delivery retains a visible due state. Persisted per-episode identifiers and the last attempted delivery prevent duplicate reminders across restart and stale notification actions. Pause/meeting do not create new episodes; a failed delivery is not retried during that episode. No permission prompts at launch. Login service is optional with visible error reporting.

## 006: Identity and distribution
Kıpır is the visible brand; Kipir is the module, executable and project. Bundle identifier is configurable in Config.xcconfig. No signing team is selected; distribution, IT approval and human acceptance remain separate gates.

## 007: Break progress follows its original duration
Store the original duration alongside remaining break time. Editing future break settings does not change the current countdown or progress ring, including after restart. Fractional idle accounting subtracts the entire unconfirmed tail, not a rounded tick. Regression tests cover both.

## 008: Count active use while a break is due
A due reminder stays due with the same identity, but confirmed active work and daily totals continue. Accepting the break is not required to keep statistics accurate. Snooze adds its duration from the current active total.

## 009: Vector exercise guide with one timing authority
Native Canvas and TimelineView provide offline scalable movement without assets/dependencies. Visual animation has no scheduling authority. The scheduler feeds only accepted break-time deltas to the sequence, so AFK continues and sleep/unknown callback gaps freeze both. Navigation does not extend breaks; the final selected movement fills the remaining overall budget. Manual finish/last skip receives no completion credit. Closing hides the guide and leaves the countdown running. Restart reconstructs the default chronological position rather than persisting navigation history.

## 010 — Guide inside the menu bar popover
User preference supersedes the dedicated-window design. Render BreakExerciseView in MenuBarView while the scheduler phase is onBreak; retain the shared header, meeting toggle and footer. Dismissing the popover does not change timing; reopening displays the current movement. Remove BreakWindowController and its automatic window lifecycle. Revert the dataset instruction integration and use original Kıpır instructions/artwork.

## 011 — Free Homebrew preview
Use the existing omerahat/kipir repository as a tap via its explicit Git URL, with a
root Casks/kipir.rb and universal Release ZIP on GitHub Releases. No second tap
repository, DMG tooling, third-party dependency or automatic updater is needed.
Scripts/package-release.sh uses ad hoc signing only through command-line overrides;
project signing identities, sandbox and bundle ID stay unchanged. This is not
Developer ID signing/notarization and cannot promise Gatekeeper acceptance or OS
notification/login behavior. Never remove quarantine automatically. Pin the exact
archive SHA-256; never overwrite an existing versioned release. Publishing is a
separate authorized action. Uninstall preserves local data and has no zap hook.

## 012 — Local interface language
Use a separate validated `language` UserDefaults preference (`tr` / `en`, default/fallback `tr`) and the existing L helper with an explicit language bundle. Do not change the scheduler Settings payload or migrate session/statistics. Controller revision and SwiftUI locale refresh existing views immediately. Re-register notification categories without resending an existing due episode. Delivered notification bodies and OS error details are not retroactively translated. No new permission, dependency or network access.
