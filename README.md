# Kıpır

A little movement goes a long way.

Kıpır is a private, native macOS 14+ menu bar assistant for gentle movement reminders. Turkish is the initial interface language. No account, network, telemetry, input contents or dependencies.

## Features and usage
Open the menu bar movement symbol to see confirmed active work, time until a break, today's aggregate totals and controls. Defaults: 45 minutes work, 2 minutes short break, 5 minutes long break after 3 completed short breaks, 90 seconds AFK, 10 minutes active-work snooze. Settings validates every value.

Pause and Meeting Mode freeze scheduling and statistics. Sleep, lock and unknown callback gaps receive no credit. Completing a countdown records a completed break timer, not exercise. Skip resets the interval without advancing the cycle. Snooze adds active work before another reminder. Notifications are optional; the panel always displays a due break.

## Build and install
Requires macOS 14+, Xcode with macOS SDK and Swift 5.9+. Open `Kipir.xcodeproj`, select **Kipir**, choose **My Mac**, and Run. Kıpır has no regular window: click the walking icon in the menu bar to open it. Xcode signs local Debug builds as **Sign to Run Locally**; keep code signing enabled when running Kıpır because a `CODE_SIGNING_ALLOWED=NO` build cannot register the app for notifications. No package installation is needed. The bundle ID is configurable in `Config.xcconfig`. Copy a personally built app from DerivedData to Applications if desired; distributed builds require appropriate signing/notarization. Respect corporate IT approval.

## Homebrew distribution (free preview)

Packaging is ready; the commands below will not work until the first GitHub Release and cask are published.
After publication, on macOS 14+:

```sh
brew tap omerahat/kipir https://github.com/omerahat/kipir.git
brew install --cask omerahat/kipir/kipir
open /Applications/Kipir.app
```

Open Kıpır from the walking-person icon in the menu bar. This free preview is locally
(ad hoc) signed and has not been notarized by Apple. If macOS blocks the first launch,
use System Settings → Privacy & Security → Open Anyway only if you trust the source
you downloaded it from. Managed Mac policies may block the app. Homebrew does not
remove security checks.

Quit Kıpır before updating, then run `brew update` and
`brew upgrade --cask omerahat/kipir/kipir`. To uninstall, run
`brew uninstall --cask omerahat/kipir/kipir`; local settings are not removed.
See [DISTRIBUTION.md](DISTRIBUTION.md) for packaging and release steps.

## Configuration and permissions
Open **Settings** from the panel. Configure durations, notifications, sound, appearance and launch at login. Notification authorization is requested only by the explicit permission button. Idle detection reads aggregate seconds since input; no Accessibility or Input Monitoring request is made. Login registration uses Apple's ServiceManagement and can fail under policy; errors appear in Settings.

## Screenshots
Run the app, open its menu panel, and use macOS Screenshot (Shift-Command-5). Capture working, due and break states in both system appearances. Do not include personal desktop content. No screenshot is claimed until captured.

## Limitations and roadmap
Idle is a proxy: reading without input is not confirmed work. Up to the AFK threshold of recent input-free time is provisional and credited only when another event confirms a short gap. Meeting Mode explicitly excludes meetings. Offline time never advances work or break completion. One current local-day aggregate is retained. See [TESTING.md](TESTING.md) for actual results and outstanding device checks. Future scope: English localization and distribution hardening, not cloud or productivity scores.

## Repository
Repository identity: `kipir-macos` (this local checkout may use a shorter folder name).

`Kipir/Core` is Foundation-only scheduling, validation and persistence. `Kipir/App` adapts native lifecycle/notifications. `Kipir/UI` contains native views. `KipirTests` runs the same core through Xcode and Swift Package Manager. Product requirements, architecture, design, decisions, security and delivery checklist live in the root Markdown files.

## Animated movement guide
Starting a break displays guidance directly in the menu bar popover with Turkish-language instructions, a joint-based animated figure, per-movement countdown, overall progress and keyboard controls (left/right, Space). Short breaks use four 30-second movements; long breaks add a three-minute walk. Custom break durations scale the sequence proportionally. Dismiss the popover to continue away from the screen; click the menu bar icon to return. Move gently and stop if uncomfortable.
