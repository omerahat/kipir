# Kıpır — Design

## Identity
Kıpır means a little movement. “A little movement goes a long way.” Warm Turkish copy, concise actions, no guilt or productivity claims. Technical module/executable: Kipir.

## Native visual system
SF system typography, rounded numeric countdown with monospaced digits, semantic primary/secondary text. Adaptive teal accent, system grouped backgrounds, 12–18 point corner radii. Spacing scale: 4, 8, 12, 16, 24. Compact 330-point menu panel; no dashboard or fullscreen interruption. Light/dark preference uses native color schemes.

## Layout and components
Header: movement symbol, Kıpır, status capsule. Center: progress ring, large remaining time, next break explanation. Then primary break/pause controls, context-specific due actions, Meeting Mode. A small Today card shows active minutes and completed countdowns. Footer: Settings and Quit Kıpır. State text distinguishes Working, Idle, Paused, Meeting, Due and Break. Countdown completion never implies exercise was performed. Below the header a one-line status note explains every non-working state (idle, paused, meeting, suspended, off hours, due, on break). Break start is the single prominent control, and only while a break is due. A transient notice under the timer (waits up to 15 minutes until the popover shows it, then lasts 6 s; expiry driven by the existing heartbeat, no transition or animation) reports a completed break or a natural-break reset. Spacing uses the shared `Space` scale (4/8/12/16/24); the popover padding is 16.

## Interaction and accessibility
Native buttons, toggles and form fields; text labels accompany symbols. Progress has spoken value; color is never the only status signal. System fonts scale with platform conventions. No custom animated transitions, so Reduce Motion receives a stable experience. Keyboard and VoiceOver acceptance remains a manual gate.

## Notifications and onboarding
First launch shows a two-step welcome inside the popover (no window). Step 1: the menu bar icon, that only active computer time counts, and that everything stays local. Step 2: an optional notification explanation with at most one explicit button chosen from the effective state (request permission, or open System Settings when denied or limited); finishing never requests permission by itself. Due copy: “Kıpır zamanı!” and a friendly invitation to stand, move shoulders or walk. Actions: Molaya başla, Ertele, Atla, Duraklat. Denied permission shows Settings guidance and retains panel actions. Effective states (off, needs permission, denied, limited, active) are derived from the stored preference plus OS capabilities and never rewrite the preference (DECISIONS 022).

## Icon
A teal rounded square with two soft stepping/motion strokes and an offset warm dot: a small moving figure without a stopwatch. Generated locally using AppKit vector paths at standard app-icon resolutions. Menu bar uses the template SF Symbol `figure.walk`. No downloaded art. Icon output is static; generator is reproducible in `Scripts/GenerateIcon.swift`.

## Localization
User-facing strings live in matching `tr.lproj` and `en.lproj/Localizable.strings` resources and pass through the shared localization helper (dynamic state labels too). Settings → General offers Türkçe / English. Turkish remains the default; the local language preference applies immediately to the panel, settings, guidance and future notifications. Previously delivered notification bodies and system-provided error details retain their original language.

## Exercise popover and motion
The existing 330-point menu bar popover replaces its work summary with the exercise guide during breaks. It uses a teal figure card, large monospaced countdown, localized instruction and safety text, overall progress, and native keyboard-accessible controls. The shared header, meeting toggle and footer remain visible. There is no separate break window. Reduce Motion replaces TimelineView with two labeled static key poses for every movement; paused/suspended playback is static. Human movement accuracy and light/dark/VoiceOver acceptance remain required.

## Exercise illustrations (0.2 flat vector redesign)
`ExerciseArtwork` (Swift Canvas/Path, no assets, no third-party art) draws one shared flat figure from a single 16-joint skeleton. Each of the 11 movements is 2 to 4 explicit key poses (joint data) blended on a loop with a short hold and cosine easing, in a front or side view with simple props (chair, desk, support, ground line). Close-up compositions exist for wrists and fingers; the wrist hand switch happens at the halfway point, which `loopPeriod` places on a loop boundary by fitting an even number of equal cycles to each movement's real duration. Colors are fixed teal shirt, slate trousers, warm shoes and skin tones over a semantic background for light and dark. Redraws run at most 30 fps and only while running. To add a movement: extend `Movement` and `BodyArea` mapping, add key poses and a scene, add localized name and instruction in both languages, and obtain a human pose review. Offscreen sheets from `Scripts/ExerciseVisualEvidence.swift` are illustration evidence only, not live playback or movement validation.

## Quality-of-life controls
MenuBarExtra uses native Label/SF Symbols, ceiling-rounded localized minutes, monospaced digits and a minimum text width. Working/idle retain work remaining; idle uses a moon, pause is icon-only, meeting and suspension are explicit, and break shows its own remaining minutes. VoiceOver receives the full state and preserved remaining time. No visual interpolation advances frozen work.

Timing begins with a compact native segmented preset selector (Quick Focus / Balanced / derived disabled Custom); all six advanced controls remain below it. The independent default-off completion-sound toggle is in Timing. Notifications adds a test button with in-flight disabling and a short localized result/guidance. Existing explicit permission request stays visible.

The shared meeting toggle remains indefinite by default. An adjacent clock menu offers 15/30/60 minutes and indefinite mode. While active, a caption row shows ceiling-rounded wall-clock minutes or indefinite status plus End meeting. No new window or exercise rendering changes. Live layout, tinting, keyboard and VoiceOver acceptance remain manual checks.

## Notification visibility guidance
Settings → Notifications shows one status line for the effective state (orange for denied and limited) and one primary button: request permission when undecided, Open Notification Settings when denied or limited. Authorization, banner/center/sound detail, the always-available Open Notification Settings button, manual navigation guidance and Test Notification live in a collapsed Diagnostics disclosure. Manual System Settings → Notifications → Kıpır guidance covers unsupported or misdirected pane links. Returning to Kıpır refreshes system settings. Test submission copy never states that a banner appeared, and the test notification body no longer claims notifications are working.

## 0.2 presentation
Menu bar style (Settings → General) is `timer` (symbol plus ceiling-rounded minutes, only the minute countdown reserves width) or `icon` (symbol only). Both styles carry the same tooltip and VoiceOver summary of app, status and remaining minutes; off hours uses `moon.zzz`. Settings → Timing offers Quick Focus/Balanced presets and break-length pickers over fixed presets (short 30 s, 1, 2, 3, 5 min; long 3, 5, 10, 15 min). A stored value outside the presets appears as a disabled "Custom (…)" row so the picker is never blank and nothing is rewritten until the user chooses. Settings → Breaks holds the natural-break picker (Off/5/10/15 min with a one-line explanation) and the exercise-focus picker (all, neck and shoulders, back, hands). Settings → Working hours has an enable toggle, weekday toggle buttons in the locale's first-weekday order (never fewer than one), start and end time pickers, an overnight hint and an explanatory note. Live layout, tooltip, light/dark, keyboard and VoiceOver acceptance are manual checks.
