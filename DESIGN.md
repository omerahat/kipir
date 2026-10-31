# Kıpır — Design

## Identity
Kıpır means a little movement. “A little movement goes a long way.” Warm Turkish copy, concise actions, no guilt or productivity claims. Technical module/executable: Kipir.

## Native visual system
SF system typography, rounded numeric countdown with monospaced digits, semantic primary/secondary text. Adaptive teal accent, system grouped backgrounds, 12–18 point corner radii. Spacing scale: 4, 8, 12, 16, 24. Compact 330-point menu panel; no dashboard or fullscreen interruption. Light/dark preference uses native color schemes.

## Layout and components
Header: movement symbol, Kıpır, status capsule. Center: progress ring, large remaining time, next break explanation. Then primary break/pause controls, context-specific due actions, Meeting Mode. A small Today card shows active minutes and completed countdowns. Footer: Settings and Quit Kıpır. State text distinguishes Working, Idle, Paused, Meeting, Due and Break. Countdown completion never implies exercise was performed.

## Interaction and accessibility
Native buttons, toggles and form fields; text labels accompany symbols. Progress has spoken value; color is never the only status signal. System fonts scale with platform conventions. No custom animated transitions, so Reduce Motion receives a stable experience. Keyboard and VoiceOver acceptance remains a manual gate.

## Notifications and onboarding
First launch shows a compact local-only explanation and optional permission button; dismissing it does not authorize notifications. Due copy: “Kıpır zamanı!” and a friendly invitation to stand, move shoulders or walk. Actions: Molaya başla, Ertele, Atla, Duraklat. Denied permission shows Settings guidance and retains panel actions.

## Icon
A teal rounded square with two soft stepping/motion strokes and an offset warm dot: a small moving figure without a stopwatch. Generated locally using AppKit vector paths at standard app-icon resolutions. Menu bar uses the template SF Symbol `figure.walk`. No downloaded art. Icon output is static; generator is reproducible in `Scripts/GenerateIcon.swift`.

## Localization
User-facing strings live in matching `tr.lproj` and `en.lproj/Localizable.strings` resources and pass through the shared localization helper (dynamic state labels too). Settings → General offers Türkçe / English. Turkish remains the default; the local language preference applies immediately to the panel, settings, guidance and future notifications. Previously delivered notification bodies and system-provided error details retain their original language.

## Exercise popover and motion
The existing 330-point menu bar popover replaces its work summary with the exercise guide during breaks. It uses a teal figure card, large monospaced countdown, Turkish instruction and safety text, overall progress, and native keyboard-accessible controls. The shared header, meeting toggle and footer remain visible. There is no separate break window. Canvas draws explicit head, torso, shoulders, elbows, wrists, hips, knees and feet. A four-second cosine cycle opens arms and raises heels; small shoulder circles and hand-angle changes illustrate gentle movement. Walking alternates limbs. Reduce Motion replaces TimelineView with two labeled static key poses; paused/suspended playback is static. Wrist stretching is intentionally gentle, with an instruction to change hands halfway. Human movement accuracy and light/dark/VoiceOver acceptance remain required.

## Exercise illustrations v2
Original filled vector artwork replaces the previous stick figure: a teal clothed character, jointed limbs and shoes; close-up wrists and a side-view supported heel raise use dedicated compositions. Shoulder accents show the circular motion, chest opening moves the arms outward, walking alternates limbs. Reduce Motion renders two labeled still poses. Colors use fixed teal/skin/clothing tones and a semantic background for light and dark. Artwork is authored in Swift Canvas/Path; add a movement by extending the catalog and the illustration switch, adding localized instructions and reviewing poses with a human. No third-party art or licenses apply.

## Quality-of-life controls
MenuBarExtra uses native Label/SF Symbols, ceiling-rounded localized minutes, monospaced digits and a minimum text width. Working/idle retain work remaining; idle uses a moon, pause is icon-only, meeting and suspension are explicit, and break shows its own remaining minutes. VoiceOver receives the full state and preserved remaining time. No visual interpolation advances frozen work.

Timing begins with a compact native segmented preset selector (Quick Focus / Balanced / derived disabled Custom); all six advanced controls remain below it. The independent default-off completion-sound toggle is in Timing. Notifications adds a test button with in-flight disabling and a short localized result/guidance. Existing explicit permission request stays visible.

The shared meeting toggle remains indefinite by default. An adjacent clock menu offers 15/30/60 minutes and indefinite mode. While active, a caption row shows ceiling-rounded wall-clock minutes or indefinite status plus End meeting. No new window or exercise rendering changes. Live layout, tinting, keyboard and VoiceOver acceptance remain manual checks.

## Notification visibility guidance
Notifications shows an orange actionable explanation for authorized-but-silent and provisional configurations, with separate compact Notification Center/system-sound availability. The localized Open Notification Settings button is always available. Manual System Settings → Notifications → Kıpır guidance covers unsupported or misdirected pane links. Returning to Kıpır refreshes system settings. Test submission copy never states that a banner appeared, and the test notification body no longer claims notifications are working.
