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

## Animated exercise guide — 2026-10-30
- SPM: **31 XCTest cases passed, 0 failures**, including six exercise tests (order/default durations, advance/navigation, pause/sleep integration, uncredited manual finish, restart position, and 300-second long guide completion entirely without input).
- Xcode: **TEST SUCCEEDED**, 31 cases, 0 failures. Result: `build/Logs/Test/Test-Kipir-2026.10.30_18-32-31-+0300.xcresult`. App sources and existing target membership compiled with native Canvas/TimelineView/NSWindow.
- Static key-pose sheet for all five movements was rendered offscreen and visually inspected in light appearance. This is illustration/layout evidence, not a video or a human assessment of movement accuracy. Native desktop automation timed out when opening the updated app. Continuous cycles, full-window light/dark appearance, VoiceOver, focus order, close/reopen interaction and physical sleep/wake remain human acceptance gates.
- First build/test attempts failed with **No space left on device**. Only temporary build directories created in this session were removed; cached reruns passed. About 441 MiB free remained at that check; additional builds may require user-managed disk space.
- Manual procedure: start a short break; confirm the guide embedded in the menu bar popover, previous/next (arrow keys), Space pause, skip and early finish. Dismiss and reopen using the menu bar icon. Leave the computer past AFK and confirm the guide continues. Set long-break frequency to 1, complete a short timer, then verify the three-minute final walk. Repeat in light/dark and Reduce Motion (two static poses), and with VoiceOver. Early finish and skipping the final exercise must not increment completed timers. Manual navigation must not extend the total break budget.
- Independent read-only review found no critical/important correctness issue in exercise playback, scheduler integration or window lifecycle. No medical or exercise-performance validation is claimed.


## Embedded popover guide — 2026-10-30
Reverted dataset instruction/provenance changes and removed the separate window controller. App build and Xcode tests passed (31 tests, 0 failures); SPM passed 31 tests, 0 failures. Logs: `/tmp/kipir-popover-xcode.log` and `/tmp/kipir-popover-swift.log`. No scheduler timing changes were needed. `git diff --check` passed. Manual acceptance remains pending: start a break in the menu popover, use all controls, dismiss/reopen and confirm continued countdown; check small-screen layout, light/dark, Reduce Motion and VoiceOver. Prior dedicated-window verification above is historical, superseded by this presentation.

## Homebrew preview packaging — 2026-10-30

- `bash Scripts/package-release.sh`: **passed**, universal arm64/x86_64 Release
  build, ad hoc signed with command-line overrides only. Log:
  `build/package-release.log`. Produced `dist/Kipir-0.1.0.zip` (443 KiB), its
  `.zip.sha256` sidecar and `Casks/kipir.rb`. SHA-256:
  `fb3959f8453b80d2bb5cd9342914e3baaa887f802498d38d3e22eea621fb7cb9`.
- ZIP integrity and exact cask/sidecar SHA-256 comparison passed. Extracted the
  ZIP into a temporary directory with `ditto -x -k`, then ran
  `codesign --verify --deep --strict` and `lipo -verify_arch arm64 x86_64` on
  that extracted app: **passed**. This is ad hoc signature integrity, not
  Developer ID, notarization or Gatekeeper acceptance.
- `bash -n Scripts/package-release.sh`, `ruby -c Casks/kipir.rb`, and
  `python3 Scripts/test-package-release.py`: **passed**, 2 guard tests covering
  unexpected arguments, invalid version and refusal to overwrite an existing
  archive without changing its bytes or starting a build.
- Homebrew's own `Cask::CaskLoader.load(File.read("Casks/kipir.rb"))` accepted
  the final cask; explicit version and expanded download URL checks passed.
  First path-based attempt was rejected because the checkout is not installed
  as a tap; content-based validation requires no tap/install. Updated deprecated
  macOS string comparison to the current `depends_on macos: :sonoma` syntax;
  final validation passed without that warning. Homebrew required normal cache
  access outside the sandbox and downloaded its API metadata. No app install ran.
- SPM: **31 XCTest cases, 0 failures** using
  `CLANG_MODULE_CACHE_PATH=/tmp/kipir-clang SWIFTPM_MODULECACHE_OVERRIDE=/tmp/kipir-swift swift test --disable-sandbox --scratch-path /tmp/kipir-initial-tests`.
  Log: `/tmp/kipir-brew-swift.log`.
- Xcode Debug build and tests: **BUILD SUCCEEDED / TEST SUCCEEDED**, 31 XCTest
  cases, 0 failures using the documented ad hoc command with `build test`.
  First sandboxed test attempt could not connect to testmanagerd; approved
  rerun passed. Log: `/tmp/kipir-brew-xcode-approved.log`; result:
  `build/Logs/Test/Run-Kipir-2026.10.30_20-10-08-+0300.xcresult`.
- No push, tag, GitHub Release, downloaded Homebrew install/upgrade/uninstall,
  Gatekeeper interaction, notarization, Intel runtime or actual macOS 14 runtime
  test was performed. Notification/login, physical lifecycle and human UI
  acceptance gates remain open. The cask download URL will work only after the
  matching release asset and cask are published. Existing dirty work was preserved.

## Turkish / English language choice — 2026-10-30

- SPM: **31 XCTest cases, 0 failures**, using the cache/scratch-path command above. Log: `/tmp/kipir-language-swift.log`.
- Xcode Debug `build test`: **BUILD SUCCEEDED / TEST SUCCEEDED**, **31 XCTest cases, 0 failures**, using existing project signing settings. The sandboxed runs built successfully but could not connect to testmanagerd; the approved unsandboxed rerun passed. Log: `/tmp/kipir-language-xcode-approved.log`; result: `build/Logs/Test/Run-Kipir-2026.10.30_22-35-49-+0300.xcresult`. No project signing identity changed.
- `python3 Scripts/test-localization.py`: **2 checks passed** for equal Turkish/English keys, duplicate/empty entries, literal L calls, language labels and both built resource paths. `plutil -lint` passed for both string tables and the project; `git diff --check` passed.
- The log directly reports test totals. An optional `xcresulttool get test-results summary` read failed when the tool attempted to write its TestReport cache outside permitted paths; no extra permission was needed to establish the test result from the log.
- Manual acceptance remains pending: choose English in Settings → General → Dil; verify immediate panel/settings/guide updates, switch back, quit/relaunch and confirm selection persists. Check English layout, keyboard/VoiceOver, and newly delivered notification text/actions. Already delivered bodies retain their language; underlying OS error details follow macOS. No notification delivery, physical lifecycle or human accessibility acceptance is claimed.
