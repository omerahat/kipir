# Kıpır — Testing

## Reproducible commands
```sh
swift test
xcodebuild -project Kipir.xcodeproj -scheme Kipir -configuration Debug -derivedDataPath build build
xcodebuild -project Kipir.xcodeproj -scheme Kipir -configuration Debug -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual CODE_SIGNING_ALLOWED=YES test
open build/Build/Products/Debug/Kipir.app
```
Requires Xcode and a macOS 14+ host. Xcode normally signs a local Debug build as **Sign to Run Locally**, without an Apple certificate or team. Do not set `CODE_SIGNING_ALLOWED=NO` for an app you intend to use; unsigned builds cannot request notifications. Local signing does not establish distributability.

## Automated coverage
Deterministic monotonic/date/idle injection: active accumulation, AFK threshold, return, prolonged inactivity, duplicate due prevention, short/long cycle, snooze, skip, pause, Meeting Mode, sleep/wake and unknown gaps, invalid input, configuration, midnight, restart and permission-denied fallback. Local persistence is tested in isolated UserDefaults suites.

## Manual acceptance procedure
1. Run from Xcode, confirm menu item and no Dock icon; open panel by mouse and keyboard. Capture light/dark screenshots.
2. Use short configured intervals; work with input, then leave past AFK. Confirm the threshold is not counted and return resumes prior progress.
3. Test short/long completion, snooze, skip, pause, Meeting Mode and reset. Confirm no notification while paused/in a meeting.
4. Deny permission, become due and use panel actions; enable permission in System Settings, request a new due episode and test every notification action, including an old delivered notification.
5. Lock/unlock, sleep/wake and fast-user-switch. Confirm no credited suspension or offline time and no surprise completed break.
6. Quit/relaunch during work, due, break, pause and meeting. Check persistence; cross local midnight/timezone/DST without duplicate time.
7. Test launch-at-login from an installed signed build, rejection under managed policy, VoiceOver reading order, keyboard focus, increased contrast and Reduce Motion.
8. Inspect resource usage over an extended session and verify no unexpected permission prompt/network access. Source inspection alone is not a network capture.

## Actual results
Verified on 2026-10-30, macOS 26.3.1 (25D771280a), Xcode 26.3 (17C529), Swift 6.2.4, macOS 26.2 SDK, Swift 5 language mode. Deployment minimum remains macOS 14; an actual macOS 14 runtime has not been tested.

- **SPM: passed, 25 XCTest cases, 0 failures.** In this restricted tool environment the exact command was `CLANG_MODULE_CACHE_PATH=/tmp/kipir-clang SWIFTPM_MODULECACHE_OVERRIDE=/tmp/kipir-swift swift test --disable-sandbox --scratch-path /tmp/kipir-initial-tests`. These options only relocate compiler caches and allow the local package manifest to compile; they do not change app permissions or macOS protections. The trailing Swift Testing runner reports 0 tests because this suite uses XCTest; the 25 XCTest cases are the actual result.
- **Xcode Debug build: BUILD SUCCEEDED** both unsigned during core verification and ad hoc signed for local notification registration. The latter used `CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual CODE_SIGNING_ALLOWED=YES`; `codesign --verify --deep --strict` reported a valid bundle. No Apple Developer identity/team was used or changed.
- **Xcode tests: TEST SUCCEEDED, 25 XCTest cases, 0 failures, with Xcode local ad hoc signing enabled via command-line override.** Result bundle: `build/Logs/Test/Test-Kipir-2026.10.30_17-57-18-+0300.xcresult`. The hostless test target compiles the same Foundation source files directly; it does not launch or verify the app adapters.
- **Xcode Release build: BUILD SUCCEEDED**, `CODE_SIGNING_ALLOWED=NO`. The runtime Debug product was subsequently rebuilt ad hoc signed for local notifications. Debug and Release app products are in `build/Build/Products/{Debug,Release}/Kipir.app`. The Debug executable is universal arm64/x86_64; only arm64 tests ran on this host.
- **App launch: partial runtime evidence.** `open build/Build/Products/Debug/Kipir.app` succeeded when allowed outside the tool sandbox. The exact executable process remained running, and no Kıpır startup crash report was found at that check. The final Debug build was relaunched with `open -n` and its process confirmed running after the final source changes. A regular relaunch immediately after terminating the earlier development process briefly returned Launch Services -600; the fresh-process launch succeeded. The built Info.plist contains display name Kıpır, bundle identifier com.omerahat.kipir and LSUIElement=true. Visual menu presence and absence of the Dock icon are not established by these facts.
- **Resources and source checks: passed.** Property lists/project parse; all static localization keys and seven state labels are present; ten expected icon PNGs exist; the large icon was visually inspected. No legacy identity or network/event-tap/content-monitoring APIs found in the application source inspection. No network capture or extended resource-use measurement was performed.

Full final command logs are preserved locally in `build/Verification/` (ignored build artifacts). Initial red tests established missing accumulation, fractional idle overcount, changing due identity, break-progress changes and missing overdue totals; all were corrected before final green runs. Initial Xcode project syntax/name collisions were fixed. Restricted first test/launch attempts could not access macOS testmanagerd/Launch Services; reruns with approved local tool access passed. Final logs contain only Apple's informational AppIntents metadata warning (no AppIntents dependency), not Swift source warnings.

### Remaining acceptance gates
The initial unsigned bundle was absent from macOS System Settings → Notifications; the permission request failed (`UNErrorDomain`, request reported an error in usernoted logs) because Xcode was invoked with code signing explicitly disabled. A valid locally signed Debug bundle now exists; the user still needs to click **Bildirim izni iste** and decide on the macOS prompt. The native UI automation service timed out, so no screenshot, native panel interaction, light/dark visual acceptance, keyboard/VoiceOver or Reduce Motion acceptance is claimed. Physical sleep/wake/lock, real notification authorization/delivery/actions/Focus behavior, login registration, signing/notarization, sandbox behavior of a signed build, corporate approval and sustained energy/resource checks remain unverified. Notification denial coverage verifies the core delivery gate and retained Due state, not a live OS permission dialog. No critical defect is currently known, but automated core tests cannot establish these OS/device outcomes.

### Independent source review
A separate reviewer inspected the engine, native adapters, UI and tests. Its important finding—discarded provisional input-free time while Due—was reproduced with a red regression (61 versus 91 seconds), fixed by preserving the provisional span, and included in the final 25 green tests. The reviewer confirmed that correction and reported no further critical/important finding. This review does not replace the open OS/device gates.

The one-line `open` command is silent because Kıpır is menu-bar-only. Click the walking-person icon in the menu bar to open the panel. In Settings, click **Bildirim izni iste** and choose Allow in the macOS prompt. Then open Apple menu → System Settings → Notifications → Kıpır to adjust alerts and sound.
