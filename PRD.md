# Kıpır — Product requirements

## Vision and users
Help developers and knowledge workers move during long computer sessions without pressure, accounts or surveillance. The problem is forgotten movement, not insufficient productivity.

## Stories and functional requirements
- As a user, I receive one gentle reminder after 45 minutes of confirmed active use, excluding AFK, sleep, lock, suspension and offline time.
- I can start a short break, snooze for 10 active minutes, skip, pause, resume, reset or enter Meeting Mode. All actions update one engine.
- Three completed short breaks make the next break long. Skips do not advance this cycle; snooze preserves it.
- I see the countdown, current state, confirmed interval, today's active total and completed countdowns.
- I can choose Turkish or English, and configure all six timing values, optional notifications/sound, appearance and login launch. Invalid persisted data recovers safely.
- Denied notifications leave an actionable due state in the panel; no repeated permission prompts.

## MVP and nonfunctional acceptance
Native SwiftUI/AppKit menu bar window, hidden Dock icon, macOS 14 minimum. Exactly one modest heartbeat; deterministic Foundation scheduling; monotonic elapsed time; local aggregate persistence and no content collection. Keyboard operability, VoiceOver labels, system contrast, dark/light themes and reduced-motion-safe UI. Reproducible Xcode app and tests plus headless core harness.

Acceptance: automated tests cover all scheduler transitions and persistence edges; app builds; actual runtime/device evidence is separately recorded. Notification delivery, physical sleep, login service and accessibility acceptance require real OS checks. No human gate is complete merely because compilation succeeds.

## Out of scope
Other platforms, AI, accounts, sync, application tracking, productivity scores, social features, subscriptions, exercise verification and web dashboards. Turkish and English use the existing localization resources.

## Exercise guidance acceptance
Breaks present shoulder rolls, chest opening, gentle wrist stretching and supported calf raises; long breaks end with walking away. The guide supports previous/next, skip, pause/resume and early finish. The guide is embedded in the existing menu bar popover; dismissing it preserves the break. AFK never pauses the break, but sleep, meeting and manual pause do. Automated acceptance covers order, scaled durations, transitions, integration and single completion. Recognizability, VoiceOver and appearance need human acceptance; illustration is not medical or exercise-performance validation.
