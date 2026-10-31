# Quality-of-life implementation — 2026-10-31

Execute the supplied five-feature specification in place, preserving the dirty tree.
1. Foundation menu-label formatter, localized native label, boundary/state tests.
2. Existing notification manager with injected native delivery boundary; independent test identifier/category, refreshed authorization and honest result UI; authorization/isolation tests.
3. Derive presets from six timing fields; apply through one existing validated update; integration tests for active break/snooze/statistics.
4. Optional checkpoint Date deadline, explicit meeting setters, expiration before accounting on tick/restore/wake; deterministic lifecycle, corruption and migration tests.
5. Default-off backward-compatible setting; consumable natural-completion event and injected playback closure; native soft sound; exactly-once/override tests.
Finish with localization checks, SPM, Xcode Debug/Release/test, documentation and review of the complete diff. No publishing, push, identity or distribution changes.

Review focus: expiration tick must discard its entire frozen interval; legacy missing fields must preserve old values; test notifications must not call real-reminder sync; action-driven completion must not sound; sound events must never survive restore.

Execution complete: each feature's first core test failed against the missing API and passed after implementation. Final checks: 52 SPM / 55 Xcode cases, Debug/Release and localization passed. The one important independent-review finding (deferred real reminder cancellation) was reproduced with two red regressions and fixed with pre-/post-submission eligibility checks; no other important finding was reported. Review and actual environment constraints are recorded in TESTING.md. Native UI service timed out; manual acceptance remains pending. No commits/push/release/signing-identity/distribution changes.
