# Contributing to Kıpır

Thanks for your interest. Kıpır is a small, privacy-first macOS menu bar app, and contributions are welcome. You can write issues and pull requests in Turkish or English.

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

- For behavior changes, add tests and update [CHANGELOG.md](CHANGELOG.md), plus [DECISIONS.md](DECISIONS.md) when you make a design decision.
- Keep pull requests small and focused. For visual changes, include screenshots or a short recording in light and dark mode.

Please do not report security issues in public issues. See [SECURITY.md](SECURITY.md).

By contributing, you agree that your contribution is released under the [MIT License](LICENSE).
