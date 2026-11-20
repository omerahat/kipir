# Kıpır 0.2 — Implementation progress

Branch: `feature/0.2-roadmap` (local only, never pushed). Baseline: `0f6caf4` (0.1.1). Untracked pre-existing files preserved and not committed: `.swiftpm/`, `docs/PRODUCT_DISCOVERY.md`.

Baseline evidence (2026-11-19): `swift test` 54/54 pass; `xcodebuild … test` 61/61 pass (7 NotificationManager tests are Xcode-only). After contracts commit: SPM 55/55, Xcode 62/62, `Scripts/test-localization.py` OK.
After the review fixes (2026-11-19): `swift test` 155/155 PASS; Xcode Debug `test` 162/162 TEST SUCCEEDED (see TESTING.md).
After integrating all workstreams (2026-11-19): `swift test` 136/136 PASS; Xcode Debug `test` 143/143 TEST SUCCEEDED; localization OK; `test-release-developer-id.py` 11 PASS; `test-package-release.py` 2 PASS. Full table and gaps: TESTING.md "0.2 integration". Version in `Config.xcconfig` is unchanged (0.1.1); nothing was pushed, published, signed with a Developer ID or notarized.

Status legend: TODO · IN PROGRESS · DONE (automated evidence) · MANUAL REVIEW REQUIRED · BLOCKED

## Roles and process
The orchestrator (Claude Opus 5.5; its effort level is not user-selectable) did recon, the contracts commit, merges and coordination. Agents: A architecture lead (opus/medium, final review), B scheduler (sonnet/high), C exercises (sonnet/high), D UI (sonnet/high), E release/QA (sonnet/high).

Incident: the first worktree launches were based on `main` rather than on this branch, and the agents were relaunched. Only the relaunched work was integrated (see the commits below).

Integrated commits: contracts `f8cd40e`; release `f30e91d` (merge `9f9b214`); UI `59b8fc7` and `ca7d262` (merge `3917bd9`); scheduler `824b630` (merge `93ec19d`); exercises `77fd8de` (merge `b0323b9`). Small artwork fixes may follow.

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
Status words describe automated evidence only; "MANUAL REVIEW REQUIRED" means code and tests are done but a person or device must still accept it.
| Sprint | Task | Agent (model/effort) | Status | Notes |
|---|---|---|---|---|
| 0 | Recon, baseline, contracts commit | Orchestrator (Opus 5.5) | DONE | DECISIONS 017–020 |
| 1 | 3.1 Notification permission consistency | D (sonnet/high) | MANUAL REVIEW REQUIRED | Effective state, single primary action, DECISIONS 022; real prompt/delivery unverified |
| 1 | 3.2 First-launch experience | D (sonnet/high) | MANUAL REVIEW REQUIRED | Two-step popover onboarding; live layout and permission prompt unverified |
| 1 | 3.3 Settings simplification | D (sonnet/high) | MANUAL REVIEW REQUIRED | Five sections, diagnostics disclosure, presets with Custom row; no screenshots (screencapture failed) |
| 1 | 3.4 Timer/system reliability audit | B (sonnet/high) | DONE | Unlock-time baseline, zero-delta ignore, suspended accrual; review fix I2: suspended heartbeat gaps of any finite length count as away time (DECISIONS 025); physical sleep/wake still manual |
| 2 | 4.1–4.4 Animation redesign, timing sync, a11y | C (sonnet/high) | MANUAL REVIEW REQUIRED | Flat key-pose artwork, loop fitting, visual resync, Reduce Motion pairs; offscreen sheets only, no live or human review |
| 3 | 5 Natural break detection | B (sonnet/high) | DONE | DECISIONS 018; threshold max(setting, AFK+60); real-use check manual |
| 4 | 6.1 Catalog expansion | C (sonnet/high) | MANUAL REVIEW REQUIRED | 11 movements; human pose and Turkish copy review pending |
| 4 | 6.2 Rotation | C (sonnet/high) | DONE | DECISIONS 020, 024; deterministic, restored from checkpoint |
| 4 | 6.3 Body-area preference (core + UI) | C + D (sonnet/high) | DONE | `ExerciseFocus` with fallback; picker in Settings → Breaks |
| 5 | 7.1 Compact menu bar | D (sonnet/high) | MANUAL REVIEW REQUIRED | Timer/icon styles, tooltip; actual label rendering unverified |
| 5 | 7.2 Status explanation | D (sonnet/high) | MANUAL REVIEW REQUIRED | Per-state note lines; copy review pending |
| 5 | 7.3 Break duration controls | D (sonnet/high) | MANUAL REVIEW REQUIRED | Presets plus non-destructive Custom row; live layout unverified |
| 5 | 7.4 Completion feedback | D (sonnet/high) | MANUAL REVIEW REQUIRED | Review fix I3: notice pends up to 15 min until the popover displays it, then 6 s heartbeat-driven (DECISIONS 025); sound and appearance unverified |
| 5 | 7.5 Working hours (scheduler + UI) | B + D (sonnet/high) | MANUAL REVIEW REQUIRED | DECISIONS 019; review fix I1: re-entering the window restarts the interval and clears a stale Due (DECISIONS 025); real DST and overnight use unverified |
| 5 | 7.6 Final UI polish | D (sonnet/high) | MANUAL REVIEW REQUIRED | Shared spacing scale; no visual acceptance |
| R | Developer ID / notarization prep | E (sonnet/high) | NOT PLANNED (optional path kept) | Script, WRITE_CASK guard and tests done; 0 Developer ID identities, so no signing, notarization or Gatekeeper evidence |
| R | Documentation reconciliation and 0.2 verification record | E (sonnet/high) | DONE | TASKS, CHANGELOG, TESTING, DESIGN, ARCHITECTURE, README, PRD, DECISIONS 022–024 |
| R | Final review | A (opus/medium) | DONE | 0 Critical; Important I1 (Due survived off hours silently), I2 (suspended tick coalescing broke natural break), I3 (notice expired unseen); Minor M1–M8. 9 throwaway probes in a scratch copy. All actionable items fixed in 8a35b3a. |
| R | Review fixes I1-I3, M1-M6 and cleanup | Integration-fix (sonnet/high) | DONE (automated evidence) | DECISIONS 025; SPM 155/155, Xcode 162/162; no device acceptance claimed |

## Known gaps after review (not fixed, documented)
- I1 residual: if the Mac sleeps or Kıpır is quit inside the window and resumes inside a later window (e.g. Friday 17:30 → Monday 09:30), no off-hours span is observed, so a stale Due episode can survive silently. Closing it needs a persisted last-observed timestamp compared with the last window start.
- I3: whether `.onAppear` of the notice row fires only while the popover is visible depends on MenuBarExtra lifecycle — manual review.
- M7 (refactor duplicated input detection in baseline/trackAway) and M8 (1 Hz Settings re-render, pre-existing) deferred.

## Release
0.2.0 (build 3) packaged ad hoc, published as GitHub release v0.2.0 and served via the Homebrew cask on 2026-11-20 (DECISIONS 027).
