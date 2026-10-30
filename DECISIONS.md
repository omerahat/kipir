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
