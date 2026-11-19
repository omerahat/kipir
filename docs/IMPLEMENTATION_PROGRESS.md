# Kıpır 0.2 — Implementation progress

Branch: `feature/0.2-roadmap` (local only, never pushed). Baseline: `0f6caf4` (0.1.1). Untracked pre-existing files preserved and not committed: `.swiftpm/`, `docs/PRODUCT_DISCOVERY.md`.

Baseline evidence (2026-11-19): `swift test` 54/54 pass; `xcodebuild … test` 61/61 pass (7 NotificationManager tests are Xcode-only). After contracts commit: SPM 55/55, Xcode 62/62, `Scripts/test-localization.py` OK.

Status legend: TODO · IN PROGRESS · DONE (automated evidence) · MANUAL REVIEW REQUIRED · BLOCKED

## File ownership (Wave B/D)
| Workstream | Agent (model/effort) | Files |
|---|---|---|
| Scheduler & reliability | B — sonnet/high | Core/BreakScheduler, Core/Settings, Core/WorkingHours, Core/LocalStore, App/ActivityMonitor, KipirTests/BreakSchedulerTests, KipirTests/NaturalBreakTests |
| Exercise & animation | C — sonnet/high | Core/Exercises, UI/Exercises/*, KipirTests/ExerciseTests, Scripts/ExerciseVisualEvidence |
| UI/UX | D — sonnet/high | UI/MenuBarView, UI/SettingsView, UI/OnboardingView, UI/Localization, App/AppController, App/KipirApp, App/NotificationManager, Core/QualityOfLife, KipirTests/PresentationTests |
| Release & QA | E — sonnet/high | Scripts/package-release.sh, new release scripts, DISTRIBUTION.md, TESTING.md |
| Architecture / review | A — opus/medium | read-only review |
Localizable.strings: each workstream edits only its marked section. `project.pbxproj`: orchestrator only.

## Tasks
| Sprint | Task | Agent | Status | Notes |
|---|---|---|---|---|
| 0 | Recon, baseline, contracts commit | Orchestrator | DONE | DECISIONS 017–020 |
| 1 | 3.1 Notification permission consistency | D | TODO | |
| 1 | 3.2 First-launch experience | D | TODO | |
| 1 | 3.3 Settings simplification | D | TODO | |
| 1 | 3.4 Timer/system reliability audit | B | TODO | |
| 2 | 4.1–4.4 Animation redesign, timing sync, a11y | C | TODO | |
| 3 | 5 Natural break detection | B | TODO | DECISIONS 018 |
| 4 | 6.1 Catalog expansion | C | TODO | |
| 4 | 6.2 Rotation | C | TODO | DECISIONS 020 |
| 4 | 6.3 Body-area preference (core + UI) | C + D | TODO | |
| 5 | 7.1 Compact menu bar | D | TODO | |
| 5 | 7.2 Status explanation | D | TODO | |
| 5 | 7.3 Break duration controls | D | TODO | |
| 5 | 7.4 Completion feedback | D | TODO | |
| 5 | 7.5 Working hours (scheduler + UI) | B + D | TODO | DECISIONS 019 |
| 5 | 7.6 Final UI polish | D | TODO | |
| R | Developer ID / notarization prep | E | TODO | |
| R | Final review | A | TODO | |
