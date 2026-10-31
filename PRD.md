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

## Quality of life — 2026-10-31
- Menu bar presents ceiling-rounded work/break minutes and distinct due/idle/paused/meeting/suspended states, through the existing heartbeat with an accessible localized description.
- Notification testing is explicit, permission-refreshed, separately identified and action-free. Disabled/denied/unknown permission gives guidance; submitted is not evidence of presentation. It must not change reminder attempts, sessions or statistics.
- Quick Focus and Balanced atomically update six timing values; Custom is derived. Preserve active break duration, snooze target, cycle and totals.
- Meeting Mode retains indefinite operation and adds 15/30/60-minute absolute deadlines, early end and replacement. Expiration on tick/wake/restore preserves manual pause and excludes the crossing sample from accounting.
- Default-off break completion sound is independent of notification sound. Only a consumed natural-completion event can request playback, once, never on restore or manual finish.
- Existing serialized settings/checkpoints without new fields remain readable. New malformed fields recover locally without resetting otherwise valid user state. Device delivery/audio/accessibility acceptance stays separate.

Notification visibility acceptance: distinguish full desktop alert eligibility, center-only delivery, provisional/quiet, denied and unknown settings; show localized actionable guidance and a notification-settings opener. Foreground requests banner/list with optional configured sound. Test notification acceptance is not evidence of an on-screen banner. Focus and user preferences must remain respected.
