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

## Exercise illustration v2 — 2026-10-30

- `CLANG_MODULE_CACHE_PATH=/tmp/kipir-clang SWIFTPM_MODULECACHE_OVERRIDE=/tmp/kipir-swift swift test --disable-sandbox --scratch-path /tmp/kipir-initial-tests`: **32 XCTest cases passed**, including a monotonic visual-clock pause/resume continuity test. Log: `/tmp/kipir-v2-swift.log`.
- `xcodebuild -project Kipir.xcodeproj -scheme Kipir -configuration Debug -derivedDataPath build build`: **BUILD SUCCEEDED**, log `/tmp/kipir-v2-final-build.log`. The documented ad-hoc signed `xcodebuild ... test` passed **32 XCTest cases** with 0 failures, using unsandboxed execution to reach testmanagerd; log `/tmp/kipir-v2-xcode-test.log`.
- A temporary offscreen SwiftUI Canvas pose sheet was rendered and visually inspected for all five movements in light appearance (`/tmp/kipir-v2-poses.png`). This is static artwork evidence only; the preview uses two sampled phases and does not exercise the app, accessibility environment or animation transitions.
- Native UI automation timed out opening the built application. Live pause/resume, popover reopening, CPU/GPU usage, full motion cycles, dark appearance, Reduce Motion, VoiceOver, real sleep/wake, and human anatomical and exercise review remain unverified. Walking foot contact is approximate and needs visual refinement; the pose sheet does not establish natural gait or medical correctness.

## Exercise v2 visual QA — 2026-10-30

- `Scripts/ExerciseVisualEvidence.swift` compiles with the actual `ExerciseAnimationView.swift` and invokes `ExerciseArtwork.draw` for each sample. Six evenly spaced phases per movement in light and dark are in `/tmp/kipir-visual-qa/{shoulders,chest,wrists,calves,walk}.png`; `/tmp/kipir-visual-qa/overview.png` combines light samples. Each `/tmp/kipir-visual-qa/<movement>.gif` contains 24 deterministic production-renderer samples over a four-second loop (ffmpeg, 6 source fps); these are rendered samples, not recordings of the live app. The sheet renderer duplicates the production Canvas sizing transform, and the files are temporary local artifacts.
- Inspected all five sheets in light and dark. Fixed crossing/sliding front-view walking by using a side-view in-place step with a stationary supporting shoe, improved dark clothing contrast, increased shoulder motion and anchored the supporting hand during calf raises. Wrist close-up remains stylized, and shoulder rotation is subtle. The walk demonstrates stepping in place; natural walking and anatomy require human review. The exact midpoint hand-switch and Reduce Motion view were not visually tested by these sheets.
- SPM: **33 tests, 0 failures** (`/tmp/kipir-qa-swift.log`). Xcode `build test` with documented ad hoc command-line overrides: **BUILD SUCCEEDED / TEST SUCCEEDED**, **33 tests, 0 failures** (`/tmp/kipir-qa-xcode.log`); the final static hand-coordinate fix was followed by a separate build (`/tmp/kipir-qa-final-build.log`). Added deterministic Meeting Mode freeze/resume and selection-reset coverage; earlier tests cover visual clock pause/resume, scheduler suspension, navigation and restore. These do not prove frame-level live behavior.
- Live application inspection was not performed. A repeated UI automation launch was rejected by automatic review because the previous attempt timed out and the user requested no repeated retries. No workaround was attempted. Actual popover layout, pause-frame continuity, reopening, sleep/wake, system Reduce Motion, VoiceOver, CPU/GPU use and anatomical review remain manual acceptance gates. Independent visual clock interpolation may diverge from scheduler-accepted time during long unknown callback gaps until the popover is reopened; this needs live investigation.

## Quality of life — 2026-10-31

Implemented all five features in the requested order, preserving the pre-existing exercise changes and dirty documents/project membership. No settings/session data, signing identity, Homebrew files or remote state was changed by verification.

- Test-first feature checks: missing formatter/policy/preset/meeting/sound APIs first failed, then passed at 34 / 35 / 37 / 46 / 51 core tests respectively. Added a full Balanced → countdown → due → guide → natural completion → next interval integration check. Final SPM: **52 XCTest cases, 0 failures**, exit 0. Exact command: `CLANG_MODULE_CACHE_PATH=/tmp/kipir-clang SWIFTPM_MODULECACHE_OVERRIDE=/tmp/kipir-swift swift test --disable-sandbox --scratch-path /tmp/kipir-initial-tests`. Log: `/tmp/kipir-qol-swift-final.log`. SwiftPM emits restricted user cache warnings; no Swift source warnings. Its separate Swift Testing runner's 0 is not the XCTest count.
- Deterministic coverage includes ceiling-minute boundaries and all states; preset derivation and preservation of break budget/snooze/cycle/totals; timed meeting start/before/exact deadline/early end/indefinite/replacement/sleep/restart/pause/reset/AFK/due suppression and resumption; corrupt/missing timestamp recovery; absolute forward/backward clock changes; legacy settings/checkpoints; short/long natural sound events, disabled consumption, overrides, manual finish, repeated consumption and restoration. Sound is observed via the injected playback closure, not audible OS output.
- Native NotificationManager tests compile the real manager and localization helper into the hostless Xcode target, injecting only OS notification delivery. They cover refreshed denied/unknown/disabled/authorized authorization, request identity/category/trigger/sound, errors and submission feedback, unchanged real attempt marker, no real-reminder removal/permission request, future real reminder delivery, and queued/in-flight cancellation. SPM intentionally runs Foundation-only tests; these three native manager cases run through Xcode.
- Independent source review found an asynchronous stale-reminder race. Reproduced with failing queued-pause and in-flight-meeting tests, then guarded both before submission and after asynchronous OS acceptance. Both regression tests pass in the final suite. A formatter regression also confirmed that long persisted targets must not be arbitrarily capped at 240 minutes; corrected without integer overflow on malformed extremes.
- Source/resource checks: `python3 Scripts/test-localization.py` **2 checks passed**; `plutil -lint` for both string tables and the Xcode project **passed**; `git diff --check` **passed**. Core imports remain Foundation-only; AppController still owns the only Timer. Both app and Xcode test targets include the new shared source; the native sound needs no bundled resource.

### Execution constraints and manual acceptance
The initial sandboxed Debug build succeeded, but test startup could not reach `com.apple.testmanagerd.control`; the same suite ran successfully with approved native service access. Initial Xcode validation passed 52 tests, and the race-fix run passed 54, before the final integration case was added. One overlapping test invocation was rejected by Xcode's build-database lock; subsequent Xcode runs were serial. Intentional red-test failure diagnostics encountered low disk space; a later test bundle signing failure was resolved by moving only that generated test bundle to `/tmp/kipir-qol-tests-signing-backup-20261031` and regenerating it. A subsequent universal-binary write also hit low disk space. Removed only generated `build/Index.noindex` and the SPM scratch `debug/ModuleCache` and `debug/index`; sources, personal data, settings and test logs were preserved. Final Xcode commands disable compiler indexing and failure diagnostic archives to avoid recreating those large artifacts. No general disk cleanup ran.

A single native UI access attempt (`cua.getApp("Kipir")`) timed out in the computer-control service. No successful screenshot or live interaction is claimed and no repeated UI retries were made. Still pending: actual menu icon+text/width/tint in Turkish/English; all preset and meeting controls; notification appearance under Focus and click behavior; audible Tink quality/output mute; physical sleep/wake/lock; keyboard/VoiceOver/contrast; sustained CPU/energy; actual macOS 14 and Intel runtime. All existing exercise human/device gates remain open. This is not signing/notarization or distribution acceptance.

Manual smoke sequence: choose Balanced, observe menu minutes and due state; send Test Notification while working and verify progress is preserved; start a break with completion sound enabled, step away and verify one quiet sound; repeat with early finish and sound disabled (silence). Choose Quick Focus, edit work to 30 minutes (Custom), choose Balanced during a break (current remaining unchanged). Start a 30-minute meeting, manually pause, sleep beyond its deadline, wake (meeting off, manual pause retained), then unpause (preserved work resumes). Test indefinite mode, early end and replacement deadlines separately.

### Final command outcomes
- **Debug build and Xcode tests: exit 0, BUILD SUCCEEDED / TEST SUCCEEDED, 55 XCTest cases, 0 failures.** Command: `xcodebuild -project Kipir.xcodeproj -scheme Kipir -configuration Debug -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual CODE_SIGNING_ALLOWED=YES COMPILER_INDEX_STORE_ENABLE=NO -collect-test-diagnostics never build test` (approved native test-service access). Log: `/tmp/kipir-qol-xcode-final.log`; result: `build/Logs/Test/Run-Kipir-2026.10.31_02-49-13-+0300.xcresult`. Compilation covers both arm64/x86_64 app slices; tests ran on this arm64 host.
- **Release build: exit 0, BUILD SUCCEEDED.** Command: `xcodebuild -project Kipir.xcodeproj -scheme Kipir -configuration Release -derivedDataPath build COMPILER_INDEX_STORE_ENABLE=NO build`. Log: `/tmp/kipir-qol-release-final.log`. App product: `build/Build/Products/Release/Kipir.app`. Debug product: `build/Build/Products/Debug/Kipir.app`. No project signing identity changed. Sandbox CoreSimulator service diagnostics are unrelated to this macOS target; Apple's informational AppIntents metadata warning remains; no Swift source warnings were reported.
- Final localization checks, property-list parsing and whitespace validation passed after the last source change. A source check confirmed one AppController Timer and no AppKit/SwiftUI imports in Core. No remote fetch/push, release, permission grant, audio playback or OS notification submission was performed by the tests.

## Notification banners — 2026-10-31

### Findings and implementation
The delegate was already registered synchronously at NotificationManager initialization and retained by AppController for the app lifetime; no lifetime rewrite was necessary. The actual code gaps were authorization collapsed with provisional/quiet permission, no inspection of alert setting/style or Notification Center/sound availability, and foreground presentation requesting banner+sound unconditionally without list. These findings do not establish the exact configuration of the user's Mac, which was not observed.

SystemNotificationDelivery now maps `authorizationStatus`, `alertSetting`, `alertStyle`, `notificationCenterSetting` and `soundSetting` into a Foundation-only capability snapshot. Only fully authorized + enabled alerts + banner/alert style qualifies as desktop-alert eligible. Quiet/provisional still permits submission, preserving background reminder behavior, but receives explicit quiet guidance. Authorized with no desktop alerts receives the requested localized Notification Center warning (or a separate explanation when Notification Center is also disabled). Center and sound status are separately visible.

Foreground options request banner+list and add sound only for sound-bearing content; request content requires both the app and system sound setting. Apple's [presentation options](https://developer.apple.com/documentation/usernotifications/unnotificationpresentationoptions) specify requested interactions, not proof that a banner was shown. Background display remains controlled by macOS and Focus. Test content and results no longer claim notifications are working. Test requests remain category-free with separate identifiers and unchanged real reminder markers.

The settings opener uses public NSWorkspace APIs with a best-effort `x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=<bundle>` URL; fallback opens the System Settings application if that URL is rejected. URL acceptance does not confirm selected-page navigation, so manual directions remain visible. Returning to Kıpır refreshes capability status. No system preferences, critical-alert permissions, Focus bypass, overlays, scheduling or persistence schema changes were introduced.

### Actual verification
- Red core regression: the two new tests first failed because capability interpretation was absent. Native red compile confirmed missing native settings mapping and presentation helper. Logs: `/tmp/kipir-banners-red.log`, `/tmp/kipir-banners-native-red.log`. The initial sandboxed native test attempt also encountered the known test-service restriction; final test service access was approved.
- `CLANG_MODULE_CACHE_PATH=/tmp/kipir-clang SWIFTPM_MODULECACHE_OVERRIDE=/tmp/kipir-swift swift test --disable-sandbox --scratch-path /tmp/kipir-initial-tests`: **exit 0; 54 XCTest cases, 0 failures**. Log: `/tmp/kipir-banners-swift.log`. Restricted SwiftPM user-cache warnings remain; no Swift source warnings.
- `xcodebuild -project Kipir.xcodeproj -scheme Kipir -configuration Debug -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual CODE_SIGNING_ALLOWED=YES COMPILER_INDEX_STORE_ENABLE=NO -collect-test-diagnostics never build test`: **exit 0; BUILD SUCCEEDED / TEST SUCCEEDED; 61 XCTest cases, 0 failures**, including 7 native manager cases. Log: `/tmp/kipir-banners-xcode.log`; result: `build/Logs/Test/Run-Kipir-2026.10.31_03-25-34-+0300.xcresult`.
- `xcodebuild -project Kipir.xcodeproj -scheme Kipir -configuration Release -derivedDataPath build COMPILER_INDEX_STORE_ENABLE=NO build`: **exit 0; BUILD SUCCEEDED**. Log: `/tmp/kipir-banners-release.log`. Sandbox CoreSimulator messages do not prevent this macOS build; Apple's informational AppIntents metadata warning remains. Signing identity/project settings unchanged.
- New tests cover visible banner/alert styles, alert style None, disabled/unsupported alert settings, quiet/denied/undetermined authorization, native settings mapping, foreground sound/no-sound options, early delegate/category registration and retention, quiet-test accepted status, system-disabled sound, unchanged real-attempt markers, settings opener accepted/fallback/failure paths. Existing scheduler, lifecycle, migration and notification-cancellation tests remain green. Native delivery and URL opening are injected; these tests do not submit an OS notification or open System Settings.
- `python3 Scripts/test-localization.py`: **2 checks passed**. Both string tables pass `plutil -lint`; `git diff --check` passed. Independent source review found no important correctness gap.

### Manual device acceptance — still pending
A single native UI attempt using the built Debug app path timed out (`Computer Use server error -10005: timeoutReached`). No repeated retries or alternative automation workaround ran. No actual on-screen banner, System Settings navigation, Focus behavior, permission dialog or foreground/background delivery is claimed.

On the newly built/relaunched app, manually check:
1. Allow notifications, enable Banners (then Alerts): settings says desktop alerts configured; send a test while Settings is active and observe actual appearance separately from the accepted message.
2. Change alert style to None with Notification Center enabled: return to Kıpır, confirm center-only warning, test request accepted with quiet warning and no promise of desktop display.
3. Enable Focus: test request may be accepted while no banner appears; Kıpır must neither bypass Focus nor claim visibility. Restore the user's original Focus preferences afterward.
4. With Settings foreground, verify sound-off test requests are silent and sound-enabled requests respect both system availability and system volume/mute.
5. With Kıpır in the background, observe a real reminder (or a test request that completes after switching away) under Banners and None. Foreground delegate options do not control the background case. Verify reminders, exercise progress and statistics stay unchanged by test requests.
6. Use Open Notification Settings, verify the actual destination; if macOS opens a different page, use the displayed manual route. Verify status refresh on returning to Kıpır. Do not infer navigation success from the open call's return value.

## 0.1.1 Homebrew release preparation — 2026-10-31
User explicitly authorized pushing and updating Homebrew. Verified the public repository's main branch matched local HEAD and the existing immutable v0.1.0 release/cask. Prepared 0.1.1/build 2 without overwriting the 0.1.0 archive or release. Info.plist now expands MARKETING_VERSION/CURRENT_PROJECT_VERSION from Config.xcconfig. Packaging disables compiler indexing only; project signing identities and sandbox settings remain unchanged.

`bash Scripts/package-release.sh`: exit 0, universal Release build and ad hoc signature checks passed; log `build/package-release.log`, wrapper log `/tmp/kipir-011-package.log`. New `dist/Kipir-0.1.1.zip` SHA-256: `35fe95418a6bb27428a71e70298f41278212918410caffc8b79bb24b1d27d6e3`. Cask and sidecar match. Extracted ZIP verifies with codesign --verify --deep --strict and lipo -verify_arch arm64 x86_64; extracted bundle reports version 0.1.1/build 2. ZIP integrity, packaging guard tests (2), Ruby cask syntax, localization checks (2), property-list parsing and git diff --check passed. No Gatekeeper bypass, local app upgrade/uninstall, system setting change or human/device acceptance is implied.

0.1.1 final Debug `build test` with documented ad hoc overrides, compiler indexing disabled and failure diagnostics disabled: **exit 0; BUILD SUCCEEDED / TEST SUCCEEDED; 61 tests, 0 failures**. Log `/tmp/kipir-011-xcode.log`; result `build/Logs/Test/Run-Kipir-2026.10.31_03-32-10-+0300.xcresult`. Homebrew's own CaskLoader parsed the generated cask and resolved the exact v0.1.1 asset URL. Publication/download verification is reported separately from these local checks.
