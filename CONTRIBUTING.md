# Contributing to Kıpır

Thanks for your interest. Kıpır is a small, privacy-first macOS menu bar app with a Chrome extension version in [`extension/`](extension/), and contributions are welcome. You can write issues and pull requests in Turkish or English.

## Help wanted: exercise animations

**The exercise animations are the area that needs the most help.** If you draw, animate or care about how movement looks on screen, this is the best place to start. Discussion happens in [issue #1](https://github.com/omerahat/kipir/issues/1).

### How it works today

- Each of the 11 movements has exactly **two still poses**, a start pose and an end pose. The app holds each pose and briefly crossfades between them (`exercisePoseBlend` in `Kipir/Core/Exercises.swift`). Because there are only two frames, the result looks like a slideshow rather than real motion.
- The poses are AI-generated raster illustrations. They are in `generated_images/`, with one two-panel image per movement. `swift Scripts/PrepareExerciseImages.swift generated_images` splits, aligns and scales them into `Kipir/Resources/Assets.xcassets` as `exercise-<movement>-start|end` (360 px tall, @2x).
- Playback is drawn by `Kipir/UI/Exercises/ExerciseAnimationView.swift`: a `TimelineView` capped at 30 fps that is frozen while paused. The loop length comes from `basePeriod` and `loopPeriod` in `Kipir/Core/Exercises.swift`.
- With Reduce Motion enabled, both poses are shown side by side with Start/Movement labels instead of the animation.

### Known problems

- With only two frames there is no in-between motion, so the speed and direction of the movement are hard to read.
- Pose accuracy has not had a human review yet. Some poses may not match the instruction text, and the chest-opening hands touch the crop edge.
- Small details such as wrists and fingers are hard to read at the card's ~180 pt size.
- Dark mode currently shows the illustrations on a white card. A design that works natively in both appearances would be welcome.

### Ideas we would welcome

- More key frames per movement, or a smoother in-between method that keeps the current character style.
- Hand-drawn or vector artwork. Native SwiftUI `Path`/`Canvas` drawing works too, if it looks good.
- Corrected poses that match the instructions in `Kipir/Resources/*.lproj/Localizable.strings`.
- Better pacing: hold times, easing, and per-movement loop lengths.

### Constraints

These are part of what the app is, so please keep them:

- **Offline and dependency-free.** No network access, no third-party frameworks or animation runtimes. Use only Apple frameworks.
- **The scheduler stays in charge of time.** The animation is for rendering only: it is driven by the break countdown, never starts a timer of its own, and freezes when paused.
- **Accessibility.** Reduce Motion must keep a static alternative. Every movement needs a VoiceOver label and must work in light and dark mode.
- **Small bundle.** All exercise artwork together is currently under 2 MB. Keep additions reasonable.
- **Artwork rights.** Only submit artwork you made yourself or have the right to release under this repository's MIT license, and say where it came from.

If you plan a bigger change, such as a new art style, a new frame format or a different rendering approach, please **open an issue first** with a sketch or a short screen recording, so we can agree on the direction before you spend time on it.

## Help wanted: a Windows app

Kıpır is a native macOS app. Today, Windows users can only use the [Chrome extension](extension/), which runs only while Chrome is running. **A native Windows version is wanted.** Please open an issue before you start, so we can agree on the approach and avoid duplicate work.

### What it should do

The same product, not a new one: everything in the macOS app, in a Windows notification-area (system tray) app.

- Count **confirmed active time** with the same rules: the AFK threshold, never crediting sleep, a locked session or unknown gaps, natural breaks, working hours, the short/long cycle, snooze, skip, pause and meeting mode (which only silences notifications).
- The same defaults (45 min work, 2 min short break, 5 min long break after 3 short ones) and the same settings and validation ranges.
- A tray icon with the remaining minutes in its tooltip, a compact panel matching [DESIGN.md](DESIGN.md), and the illustrated exercise guide.
- Windows toast notifications with Start break and Snooze, at most one per break episode.
- Turkish and English, light and dark appearance, optional launch at sign-in.

### Where to start

- **Behavior spec:** `Kipir/Core` (Swift) and its tests in `KipirTests`. [`extension/src/core/`](extension/src/core/) is a second, platform-neutral TypeScript port with deterministic tests, and [extension/docs/FEATURE_PARITY.md](extension/docs/FEATURE_PARITY.md) lists every feature with its exact behavior. Port those tests first.
- **Reuse, don't copy:** read the strings from `Kipir/Resources/{tr,en}.lproj/Localizable.strings` and the 22 pose PNGs from `Kipir/Resources/Assets.xcassets` at build time, the way the extension does (`extension/scripts/native.ts`).
- **Platform mapping:**
  - idle seconds: `GetLastInputInfo`
  - lock and unlock: `WTSRegisterSessionNotification`
  - sleep and wake: power broadcast messages
  - notifications: toast notifications
  - launch at sign-in: a startup task

  Inject time and idle into the scheduler, as the macOS core does.
- Put the app in its own top-level folder (for example `windows/`) and leave `Kipir/` and `extension/` unchanged.

### Constraints

- **Same privacy promise:** no network access, telemetry, accounts or content collection; idle detection reads only time since the last input.
- **Native and lightweight:** use the platform's own UI framework. Avoid large runtimes, and get agreement in the issue before adding any third-party dependency.
- **One timing authority:** a single heartbeat drives the scheduler; the UI and animation never own a timer.
- **Tests:** deterministic clock tests for the scheduler, and build and test commands documented in a README in the app's folder.
- Every visible string in Turkish and English.

## Other contributions

Bug reports, Turkish/English copy fixes, and tests are also welcome. Before you change code:

- Read [AGENTS.md](AGENTS.md) for the conventions, [ARCHITECTURE.md](ARCHITECTURE.md) and [DESIGN.md](DESIGN.md) for the structure, and [PRD.md](PRD.md) for the product scope.
- Add every visible string to both `tr.lproj` and `en.lproj`. Turkish is the default language.
- Run the checks from the README:

  ```sh
  swift test
  xcodebuild -project Kipir.xcodeproj -scheme Kipir -configuration Debug -derivedDataPath build \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual CODE_SIGNING_ALLOWED=YES test
  python3 Scripts/test-localization.py
  ```

- For changes in `extension/`, run `npm run check` there (typecheck, lint, unit, integration and real-Chromium tests). The extension reads `Kipir/Resources`, so string and artwork changes need this too.
- For behavior changes, add tests and update [CHANGELOG.md](CHANGELOG.md), plus [DECISIONS.md](DECISIONS.md) when you make a design decision.
- Keep pull requests small and focused. For visual changes, include screenshots or a short recording in light and dark mode.

Please do not report security issues in public issues. See [SECURITY.md](SECURITY.md).

By contributing, you agree that your contribution is released under the [MIT License](LICENSE).
