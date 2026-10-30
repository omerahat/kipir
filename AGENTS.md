# Working on Kıpır

## Principles and scope
Lightweight private movement reminders for macOS 14+. Visible identity Kıpır; ASCII module/target Kipir. Native SwiftUI/AppKit, no network, telemetry, content collection, accounts or third-party dependencies. Do not add speculative features.

## Repository and architecture
Read README.md, PRD.md, ARCHITECTURE.md, DESIGN.md and TESTING.md before editing relevant code. `Kipir/Core` owns Foundation scheduling, validation and persistence; `Kipir/App` owns lifecycle, activity, notifications and the controller; `Kipir/UI` owns SwiftUI presentation. `KipirTests` tests the same core through Xcode and SPM. `Kipir.xcodeproj` is canonical; `Package.swift` is the headless test harness. `Config.xcconfig` holds the provisional bundle identity.

## Swift conventions
Use small concrete types, clear names and explicit transitions. Main-actor isolate UI/adapters. Scheduler must not import AppKit/SwiftUI, own timers or request permissions. Only controller owns heartbeat. Inject monotonic time, wall date and idle. Never credit unknown/sleep/offline time. Preserve validation and recovery. Localize every new visible string through Turkish resources.

## Workflow and testing
Inspect dirty tree first; preserve existing work. Use deterministic clocks for nontrivial timing changes and cover invalid input/lifecycle edges. Run swift test and xcodebuild build/test from TESTING.md. Complete target membership and callers. No dependency additions without a concrete need and user approval; prefer native APIs.

## Documentation and Done
Update TASKS.md plus DECISIONS.md/CHANGELOG.md for behavior changes. Record actual command results and gaps in TESTING.md. Done requires complete callers/config/project membership, relevant tests/build passing, no extra permissions/content collection, matching docs. Never claim notification delivery, physical sleep/wake, accessibility or signing from unit tests alone. Keep human/device acceptance pending until evidence exists. Do not deploy, push or change signing identities without authorization.

## Exercise conventions
Exercise catalog/playback remain Foundation-only. Feed playback solely from scheduler-accepted countdown deltas; never add a second countdown timer. TimelineView is rendering-only. Render guidance in the menu bar popover; dismissing it must not finish a break. Preserve existing completion statistics semantics; manual finishes/skips are uncredited. New movement definitions need localized names/instructions and human pose review.
