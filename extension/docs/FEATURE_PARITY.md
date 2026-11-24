# Feature parity: macOS app → Chrome extension

The source of truth is the native code (`Kipir/Core`, `Kipir/App`, `Kipir/UI`) at version 0.2.1, not the README.
Status: **Implemented** (same behavior), **Adapted** (same intent with a documented browser difference), **Not possible** (no extension API exists; the closest honest equivalent is described).

## Timing engine

| Feature | macOS behavior | Chrome implementation | Status |
|---|---|---|---|
| Work countdown | Counts *confirmed active* seconds, not wall time. Default 45 min (`work` 60–14400 s). One-second heartbeat samples monotonic time and seconds since last input. | `src/core/engine.ts` ports `BreakScheduler`. Samples on events (alarms ≤ 60 s apart, idle events, UI actions, worker wakes) with wall-clock timestamps; time is credited only while `chrome.idle` reports `active`, inside working hours and not paused. | Adapted |
| AFK threshold | Input-free time under `afk` (default 90 s, 15–600) is provisional and credited only when later input confirms it. | `chrome.idle.setDetectionInterval(afk)`. The `idle` event means the last input was `afk` seconds ago, so the credit given in that tail is retracted. The visible countdown runs while input is recent and steps back by up to `afk` when idle is detected. **Differences:** (1) if the work target is reached inside that unconfirmed tail, the interval becomes Due and the reminder is sent up to `afk` seconds earlier than native would (for example to someone who just walked away). The later retraction lowers active work, but the phase stays Due. (2) The "Confirmed active work" line and today's total can include up to `afk` seconds that are not yet confirmed. | Adapted |
| Unknown gaps | Gaps > 10 s, backward clocks, sleep and app-not-running time are never credited. | Gaps > 150 s (`GAP_LIMIT`; samples are ≤ 60 s apart), backward clocks and browser-closed time are never credited. Wall-clock jumps forward look like a gap and are rejected. **Difference:** a sleep without a screen lock that is shorter than about 150 s minus the time since the last sample cannot be told apart from activity and is credited (native excludes all sleep through monotonic uptime). | Adapted |
| Suspension (lock, sleep, display off, inactive session) | `suspended` status: no work credit, break countdown frozen, away time accrues. | `chrome.idle` `locked` (screen lock or screensaver) maps to `suspended`. Sleep is detected as an unknown gap. A display that sleeps without locking reads as `idle` (not counted, break keeps running). | Adapted |
| Due episode | Reaching the target creates a Due episode with a persisted UUID; active use keeps counting while due (DECISIONS 008). | Same, `crypto.randomUUID()`. | Implemented |
| Short/long cycle | 2 min short (10–1800 s), 5 min long (10–3600 s) after `longEvery` = 3 (1–10) completed shorts; a long break resets the cycle. | Same. | Implemented |
| Start break | Allowed any time except paused/suspended/on break; prominent only when due. | Same. | Implemented |
| Snooze | Target = current active work + `snooze` (default 10 min, 60–3600 s); new episode later; ring refills from snooze length. | Same. | Implemented |
| Skip / finish break | Restarts the interval with no credit and no cycle advance. | Same. | Implemented |
| Pause / resume | Freezes work, break countdown, statistics and reminders; the episode identity is kept. | Same. Resume computes from the stored values, so no time is lost or added. | Implemented |
| Reset session | Confirmation dialog; clears the interval, cycle, pause and meeting; keeps today's totals. | Same (in-panel dialog). | Implemented |
| Break completion | Only a countdown that reaches zero increments `today.breaks`; the completion event is ephemeral and consumed once. | Same. A user action at the completion boundary suppresses the sound and notice, as native does. | Implemented |
| Natural break | Verified away time ≥ max(selection, afk + 60 s) restarts the interval (Off/5/10/15 min, default 10). The notice appears on the first input afterwards. Locked time counts; unknown unlocked gaps taint the chain; a restart starts tainted. | Same rule and threshold. Away time starts at the inferred last input (idle event − afk). Locked wall time counts in full, while native excludes sleep uptime: a locked laptop that sleeps overnight counts as away. | Adapted |
| Working hours | Optional weekdays and start/end, overnight windows belong to the start day; no credit, Due or reminder off hours; window entry restarts a stale interval; a running break is never interrupted; settings edits never restart. | Same logic (`workingHoursContains`, local time). Boundaries are noticed at the next sample (≤ 60 s). | Implemented |
| Day rollover | Today's totals reset at local midnight; session work is kept; the crossing sample is not credited. | Same. | Implemented |
| Settings change semantics | New work target applies to a non-snoozed interval (can become due); the current break and snooze target are never changed. | Same. | Implemented |
| Persistence and recovery | Validated checkpoint in UserDefaults, saved after meaningful changes and every 15 s; invalid data recovers safely; offline time never credited on restart. | One atomic `chrome.storage.local` document (`kipir`), committed after every operation; schema version; field-wise validation; a corrupted document falls back to defaults. A new browser session (Chrome reopened, or the extension installed, updated or reloaded), detected through a `chrome.storage.session` marker that Chrome clears, restarts with a tainted away chain and credits nothing, however short the gap and whichever event woke the worker first. The exercise cursor is persisted too, so navigation survives worker restarts. | Implemented |

## Meeting mode

| Feature | macOS behavior | Chrome implementation | Status |
|---|---|---|---|
| Meeting toggle | Indefinite by default; silences reminder notification and break sound only; timer, statistics, transitions and natural-break rules unchanged (DECISIONS 028). | Same. | Implemented |
| Timed meeting | Clock menu: 15/30/60 min or indefinite; expires at an absolute deadline; a backward jump beyond 1 h cancels; expiry keeps pause and progress. | Same, with a dedicated wake at the deadline. | Implemented |
| No replay | The current episode is marked as attempted; a visible reminder is withdrawn when the meeting starts; later episodes notify normally. | Same (`planNotifications`). Verified in a real browser. | Implemented |
| Layout | Meeting details render below the stable toggle row. | Same; verified by bounding-box comparison. | Implemented |

## Notifications and sound

| Feature | macOS behavior | Chrome implementation | Status |
|---|---|---|---|
| Due reminder | One `UNNotification` per episode: "Kıpır zamanı!" and a short or long body. At most one attempt per episode, persisted across restarts. | `chrome.notifications` basic notification with the same copy, created only after the attempt marker is committed. | Implemented |
| Reminder actions | Start break, Snooze, Skip, Pause; stale actions are ignored. | Chrome allows at most **2 buttons**: Start break and Snooze. Skip and Pause stay in the panel. A stale button is ignored. | Adapted |
| Click opens panel | A notification click shows the popover. | `chrome.action.openPopup()` (Chrome 127+). If Chrome cannot open it (no focused window), the same panel opens in a small extension window. | Adapted |
| Withdrawal | Leaving the deliverable state removes the delivered reminder. | `chrome.notifications.clear`. | Implemented |
| Enable/disable | `notifications` (default on). | Same. | Implemented |
| Permission states | Five states from macOS authorization, banner style, Notification Center and sound settings; request permission and open System Settings buttons. | Chrome exposes only `getPermissionLevel()` (granted/denied; granted at install). States: off, active, denied. OS-level presentation (macOS Notifications → Google Chrome, Focus) cannot be read, so the UI never claims a banner was shown and gives manual guidance instead. No permission request button: none exists in Chrome. | Adapted |
| Test notification | Diagnostics → Test Notification; not silenced by meeting mode; never touches the real episode. | Same (`kipir.test.<uuid>`). | Implemented |
| Notification sound | `sound` (default off) adds the system notification sound. | Notifications are created `silent`; when `sound` is on, a soft two-tone chime plays from the offscreen document, so exactly one controlled sound plays. | Adapted |
| Break completion sound | `breakEndSound` (default off), quiet `Tink` at 25% gain; silenced by meeting mode; never replayed. | A synthesized soft tone through an offscreen document (`AUDIO_PLAYBACK`). The document closes itself after 2 s and is never kept open. If playback fails, nothing else is affected. | Adapted |

## Panel (popover → popup)

| Feature | macOS behavior | Chrome implementation | Status |
|---|---|---|---|
| Header | Walking figure, Kıpır, status capsule (8 states). | Same. | Implemented |
| Countdown ring | Remaining share, anchored at 12 o'clock, starts full and recedes counterclockwise; snooze refills; frozen while paused; smooth between heartbeats. | SVG arc (`stroke-dashoffset`), the same geometry, a 174 px ring and 38 px rounded tabular digits. Projected from the snapshot; Reduce Motion jumps. | Implemented |
| Summary lines | Next break hint (short/long), confirmed active work. | Same strings. | Implemented |
| Primary row | Pause/Resume and Start break share the row equally; Start break is prominent only when due. | Same; verified by pixel-exact bounding boxes across pause, resume and meeting toggles. | Implemented |
| Due actions | Snooze and Skip below the primary row. | Same. | Implemented |
| Status notes | Below the controls; none for pause, meeting or break on the countdown screen (DECISIONS 031). | Same (`statusNoteKey`). | Implemented |
| Transient notice | Completed break or natural break; pending 15 min until shown, then 6 s. | Same, persisted, so it survives a closed popup. | Implemented |
| Today card | Active time today and completed break timers. | Same. | Implemented |
| Footer | Settings and a More menu (Reset session, Quit). | Settings and More → Reset session. **Quit**: not possible (an extension cannot quit itself; disable it in `chrome://extensions`). | Adapted |
| Onboarding | Two-step welcome in the panel; step 2 offers the permission request. | Two steps; step 2 shows Chrome's permission level and OS guidance (no request exists). | Adapted |
| Panel width and stability | 330 pt, top-anchored. | 330 px; every state measured ≤ 600 px, Chrome's popup height limit. | Implemented |

## Exercises

| Feature | macOS behavior | Chrome implementation | Status |
|---|---|---|---|
| Catalog | 11 movements in 4 areas plus a walk; localized names and instructions. | Ported (`src/core/exercises.ts`); copy read from the native tables at build time. | Implemented |
| Sequence and rotation | ~30 s per movement; long breaks 40% movements, then a 60% walk; deterministic rotation; focus area first. | Same algorithm, tested against the native break-1 sequence. | Implemented |
| Illustrations | Two flat key poses per movement (22 PNGs, shared crop), on a white rounded card even in dark mode. | The **same PNG files**, copied from the asset catalog at build time and drawn in one fixed box with `object-fit: contain`, so there is no horizontal shift, rescale or baseline jump. Verified equal boxes in a real browser. | Implemented |
| Animation | Hold each pose, short eased crossfade (`exercisePoseBlend`), loop fitted to the movement, wrist mirror at halfway, ≤ 30 fps, frozen while paused. | Same functions; 30 fps render loop only while the break runs. | Implemented |
| Reduce Motion | Two labeled still poses side by side. | `prefers-reduced-motion`: same. | Implemented |
| Controls | Previous/Pause/Next with ←/Space/→, Skip movement, Finish break, movement countdown, overall progress, safety note. | Same, including the keyboard shortcuts (verified in a browser). | Implemented |
| Surface | In the popover; closing it never finishes the break. | In the popup; closing it never finishes the break. A side panel was considered and rejected: the popup fits and matches the native single-surface design. | Implemented |

## Settings

| Feature | macOS behavior | Chrome implementation | Status |
|---|---|---|---|
| Timing | Preset segmented control (Quick Focus 25/1/5, Balanced 45/2/5, derived disabled Custom); work stepper 1–240 min; short break pick (30 s, 1, 2, 3, 5 min); long break pick (3, 5, 10, 15 min); a stored non-preset value shows as disabled "Custom (…)"; frequency 1–10; AFK 15–600 s step 15; snooze 1–60 min; break-end sound; accounting note. | Same controls, ranges and copy on the options page. | Implemented |
| Breaks | Natural break (Off/5/10/15 min) with an effective-threshold hint; exercise focus. | Same. | Implemented |
| Working hours | Enable, weekday toggles in locale order (never fewer than one), start/end, overnight hint. | Same (`<input type="time">`). | Implemented |
| Notifications | Toggle, sound toggle (disabled when off), effective state, diagnostics with test. | Same, with Chrome-specific state wording. | Adapted |
| Language | System Default / Türkçe / English, applied immediately. | Same. A runtime dictionary is used because `chrome.i18n` cannot override the browser language. | Implemented |
| Appearance | System / Light / Dark. | Same; `prefers-color-scheme` plus `data-theme`; a tiny boot script avoids a theme flash. | Implemented |
| Menu bar style | Icon + minutes, or icon only. | **Toolbar** style: badge with minutes, or no badge text. | Adapted |
| Launch at login | `SMAppService` login item. | **Not possible.** The extension runs whenever Chrome runs; use Chrome's own startup settings. Explained on the settings page. | Not possible |
| ⌘, opens Settings | App menu command. | No equivalent inside a page. Chrome lets users assign a shortcut to open the popup in `chrome://extensions/shortcuts`. | Not possible |

## Menu bar item → toolbar

| Feature | macOS behavior | Chrome implementation | Status |
|---|---|---|---|
| Countdown label | Remaining minutes (rounded up), "Mola"/"Break" when due. | Badge text: minutes, `Mola`/`Move` when due (5-letter "Break" does not fit a badge), `II` while paused. Updated at the next minute boundary by a precise wake, never more than once per needed change. | Adapted |
| State icon | SF Symbol per state (walk, moon, pause, people, sleep, ...). | Badge color per state (teal working, slate idle/paused/suspended/off hours, indigo meeting, orange due, green break). The icon itself stays the Kıpır icon. | Adapted |
| Tooltip / VoiceOver | "Kıpır, <status>, N min". | `chrome.action.setTitle` with the same summary. | Implemented |

## Privacy and platform

| Feature | macOS behavior | Chrome implementation | Status |
|---|---|---|---|
| No network, telemetry, accounts | Sandbox, no network code. | No host permissions, no content scripts, no remote code, CSP `script-src 'self'`; verified by the packaging script. | Implemented |
| Local data only | UserDefaults. | `chrome.storage.local` (not sync: a live countdown must not sync across computers). | Implemented |
| Runs in the background | Always while the app runs. | Only while Chrome runs (macOS keeps Chrome running with no windows open). With Chrome closed, nothing counts and no reminders fire. Recovery on reopen never credits the closed time. | Adapted |
