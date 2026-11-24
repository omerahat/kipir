# Kıpır for Chrome

The Kıpır movement reminder as a Manifest V3 Chrome extension. It is the same product as the macOS menu bar app in this repository, with the same timing rules, defaults, copy and illustrations, running in the browser instead of the menu bar.

> A little movement goes a long way.

## What it does

- **Counts confirmed active computer time.** Defaults: 45 min of work, a 2 min short break, and a 5 min long break after 3 short ones. Idle time past the AFK threshold (90 s), a locked screen, sleep and time while Chrome is closed are never counted.
- **Natural break detection.** After 10 min (Off/5/10/15) with no input, the interval restarts. That is never counted as a completed break.
- **Guided exercises** in the popup: 11 movements with the native two-pose illustrations, crossfade animation, keyboard controls (← → Space), body-area focus and a Reduce Motion version.
- **Pause, snooze, skip, reset**, plus **meeting mode** (indefinite or 15/30/60 min). Meeting mode silences reminders and sounds while the timer keeps running.
- **Working hours**, timing presets (Quick Focus 25/1/5, Balanced 45/2/5) and every native timing setting.
- **Toolbar badge** with the remaining minutes (`II` paused, `Mola`/`Move` when due) and a tooltip with the full state.
- **Chrome notifications** with Start break and Snooze buttons, at most one per break episode. Optional soft sounds.
- **Turkish and English** (System Default follows the browser), light, dark or system appearance.
- **Private.** No network, no account, no host permissions, no content scripts. Everything stays in `chrome.storage.local`.

See [docs/FEATURE_PARITY.md](docs/FEATURE_PARITY.md) for the feature-by-feature comparison with the macOS app.

## Relationship with the macOS app

The extension lives entirely in `extension/` and does not modify the native app. It **reuses** the native resources at build time instead of copying them:

- `Kipir/Resources/{tr,en}.lproj/Localizable.strings` is parsed into the runtime dictionary; browser-specific wording lives in `src/i18n/browser.ts`.
- `Kipir/Resources/Assets.xcassets/exercise-*` provides the 22 pose PNGs, copied into `dist/exercises/`.
- The app icon provides the extension icons in `public/icons/`.

The timing engine (`src/core/engine.ts`) is a TypeScript port of `Kipir/Core/BreakScheduler.swift`. Settings validation, the exercise catalog, rotation and the presentation rules are ports too, each annotated with the Swift type it mirrors.

## Architecture

The service worker is the single authority; the popup and the settings page only render snapshots and send intents. Time is never kept with `setInterval`. Every event (an alarm at most 60 s away, an idle-state change, a UI action) samples the engine with a timestamp, and the result is committed to `chrome.storage.local` as one atomic document. Details: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

```
src/core/          pure logic: engine, settings, exercises, presentation, model (fully unit-tested)
src/background/    service worker: controller (serialized ops), Chrome adapters, messages
src/offscreen/     audio-only offscreen document
src/ui/            React popup, options page, components
src/i18n/          runtime dictionary (native strings + browser overrides)
scripts/           Vite plugin for native resources; release packager
tests/             unit, integration (fake Chrome), e2e (real Chromium)
```

**Stack:** TypeScript, React 19, Vite 8, Vitest, Playwright, ESLint. No runtime dependencies besides React.

## Requirements

- Node.js 20+ and npm
- Google Chrome 127+ (or another Chromium browser) to use the extension
- The repository checkout: the build reads `../Kipir/Resources`

## Commands

```sh
cd extension
npm ci                 # install
npm run dev            # rebuild dist/ on change (reload the extension in chrome://extensions)
npm run build          # typecheck + production build into dist/
npm run typecheck
npm run lint
npm test               # unit + integration tests (Vitest)
npm run test:e2e       # builds dist-e2e/ and runs the real-Chromium suite (Playwright)
npm run package        # production build + checks + release/kipir-chrome-<version>.zip
npm run check          # everything above, in order
```

The first `npm run test:e2e` may need `npx playwright install chromium`.

## Load the unpacked extension

1. `npm run build`
2. Open `chrome://extensions` and turn on **Developer mode**.
3. Click **Load unpacked** and select `extension/dist`.
4. Pin Kıpır from the puzzle-piece menu so the badge is always visible.

## Release ZIP

`npm run package` writes `release/kipir-chrome-<version>.zip`. Before zipping it verifies:

- MV3 and a version that matches `package.json`
- exactly the five expected permissions
- no host access or content scripts
- all icons present
- no e2e hook, `eval` or inline script
- no remote URLs

Store listing, permission justifications and the release checklist are in [docs/CHROME_WEB_STORE.md](docs/CHROME_WEB_STORE.md).

## Permissions

| Permission | Used for |
|---|---|
| `storage` | Settings, session state and today's totals, locally |
| `alarms` | Waking at break boundaries, badge-minute changes and a ≤ 60 s heartbeat |
| `idle` | Counting only active time (active / idle / locked); no input content is ever read |
| `notifications` | Break reminders and the user-initiated test |
| `offscreen` | Optional sounds (service workers cannot play audio) |

## Timer lifecycle

| Situation | What happens |
|---|---|
| Popup closed, other tab or window, browser minimized | The timer keeps running in the service worker. |
| Service worker suspended or restarted | State is reloaded from storage; nothing is lost. |
| Computer sleeps | Missed alarms fire on wake; the sleep is detected as a gap and not credited. Only a very short unlocked sleep (under about 2 minutes) can go unnoticed. |
| Chrome quit and reopened, extension updated | The session is restored as it was and the closed period is not credited, however short (session marker in `chrome.storage.session`). A pending break reminder keeps its identity and is not re-sent. |
| Clock changed | A backward change rebaselines without credit; a forward jump counts as a gap. |
| Meeting mode ends | The timer is simply where it would be; suppressed reminders are not replayed. |

## Browser limitations

- **Chrome must be running.** While Chrome is quit nothing is counted and no reminder can be shown. On macOS, Chrome keeps running with all windows closed.
- **No "launch at login" or "quit".** The extension runs whenever Chrome does; disable it in `chrome://extensions`.
- **At most two notification buttons** (Start break, Snooze). Skip and Pause are in the popup.
- **Notification visibility** depends on OS settings Chrome cannot report (macOS: System Settings → Notifications → Google Chrome, Focus).
- **Idle detection** is Chrome's: the `idle` state arrives AFK seconds after the last input, so the countdown can step back by up to the threshold when you stop typing. If the target is reached inside that window, the reminder can come up to the AFK threshold early. A display that sleeps without locking counts as idle.
- The badge cannot show a state icon next to the minutes, so the state is shown by the badge color and `II` while paused.

## Troubleshooting

| Problem | Fix |
|---|---|
| No notifications | Settings → Notifications shows Chrome's permission. Allow Google Chrome in the OS notification settings and check Focus. Use **Bildirimi dene / Test Notification**. |
| Timer does not move | The status shows why: Idle (no input for the AFK threshold), Paused, Off hours or System suspended (locked screen). |
| Badge missing | Pin the extension; the "Icon only" toolbar style hides the minutes. |
| No sound | Sounds are off by default (Settings → Timing → break completion sound; Notifications → notification sound) and are silenced by meeting mode. |
| E2E: extension does not load | Use Playwright's bundled Chromium (`channel: 'chromium'`); branded Chrome 137+ ignores `--load-extension`. |

## Testing

See [docs/TESTING.md](docs/TESTING.md) for what each suite covers, the latest results, and the manual checks that require a real Chrome on a real machine.
