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
All user-facing strings live in Turkish `Localizable.strings` and pass through a shared localization helper (dynamic state labels too). English can be added as `en.lproj/Localizable.strings`, preserving keys and formats.
