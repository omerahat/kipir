# Chrome Web Store preparation

Status: **prepared, not published.** The upload package is `release/kipir-chrome-<version>.zip` (`npm run package`).

## Listing

**Name:** Kıpır — movement breaks (Turkish locale: "Kıpır — hareket molası")

**Short description (≤ 132 characters)**
- en: A private movement reminder that counts your active computer time and guides short illustrated stretches.
- tr: Etkin bilgisayar kullanımını sayan ve kısa, resimli esneme hareketleriyle mola veren gizlilik dostu hatırlatıcı.

**Category:** Productivity (alternatively Health & Fitness, if offered).

**Single purpose:** Remind the user to take short movement breaks during long computer sessions and guide the break.

**Full description (en)**

> Kıpır ("a little movement" in Turkish) reminds you to move during long computer sessions, gently and privately.
>
> - **Counts confirmed active time, not just the clock.** Idle time past your threshold, a locked screen, sleep and time while Chrome is closed are never counted.
> - **Notices when you already took a break.** After a stretch with no input (10 minutes by default), the work interval restarts.
> - **Guided movements.** A break opens an illustrated, two-pose guide in the toolbar panel: 11 movements for the neck and shoulders, back, hands and legs, with long breaks ending in a short walk. Keyboard controls and a Reduce Motion version are included.
> - **Meeting mode.** Silences reminders and sounds for 15, 30 or 60 minutes or until you end it; the timer keeps running and nothing is replayed afterwards.
> - **Pause, snooze, skip.** Plus working hours, presets (Quick Focus 25/1/5, Balanced 45/2/5) and fully adjustable timing.
> - **A toolbar badge** shows the minutes left; the tooltip gives the full state.
> - **Turkish and English**, light and dark appearance.
>
> Kıpır makes no network connections, needs no account, and does not read web pages, what you type or what is on your screen. Settings and today's totals stay in your browser.
>
> Kıpır is also available as a free macOS menu bar app: https://kipir.omerahat.com/

**Website / support:** https://kipir.omerahat.com/ (source code and issues: https://github.com/omerahat/kipir)

## Permission justifications

| Permission | Why it is needed |
|---|---|
| `storage` | Saves settings, the current session (timer state and today's totals) and the reminder bookkeeping locally, so the timer survives the popup closing, service-worker restarts and browser restarts. |
| `alarms` | Wakes the extension at the exact moment a break is due or ends, at badge-minute changes and at most once a minute otherwise, without a running background page. |
| `idle` | Kıpır counts active computer time only. It reads Chrome's system idle state (active, idle or locked) to stop counting when you step away and to detect a natural break. It never sees what you do, only whether there was any input. |
| `notifications` | Shows the optional "time to move" reminder with Start break and Snooze buttons, and a user-requested test notification. |
| `offscreen` | Plays the optional, off-by-default reminder and break-completion sounds. MV3 service workers cannot play audio; the offscreen document exists only while a sound plays. |

No host permissions, no content scripts and no remote code are used.

## Privacy practices (dashboard answers)

- **Data collected:** none. Nothing is transmitted; there is no server.
- **Data stored locally** (`chrome.storage.local`, on this device only):
  - preferences
  - timer session state
  - the current local day's active-time total and completed-break count
  - the id of the last reminder episode
  - the language preference and onboarding flag

  The appearance choice is mirrored in the extension's `localStorage` to avoid a theme flash.
- **Not stored or read:** browsing history, page content, keystrokes, screenshots, accounts or identifiers.
- **Remote code:** none (CSP `script-src 'self'`; all assets packaged).
- **Certifications to tick:** no selling or transfer of user data; no use for unrelated purposes; no creditworthiness or lending use.
- A privacy policy URL is required by the dashboard only when user data is collected. Kıpır collects none, but if the form asks for one, publish the paragraph above on https://kipir.omerahat.com/ before submitting. No such page exists yet, so create it; do not link a page that doesn't exist.

## Assets

| Asset | Requirement | Source |
|---|---|---|
| Extension icon | 128×128 PNG (in the ZIP) | `public/icons/icon-128.png`, the native app icon |
| Toolbar/manifest icons | 16, 32, 48, 128 | `public/icons/` (48 resized from the native 256 icon) |
| Screenshots | 1–5, 1280×800 or 640×400 PNG/JPEG | `npm run test:e2e` renders three 1280×800 candidates from the production build into `test-results/store/` (timer, break, settings). Review them, or replace them with captures from a real Chrome window, before uploading. |
| Small promo tile | 440×280 (optional) | To do |

## Release steps

1. Bump `version` in **both** `package.json` and `manifest.json` (the build refuses mismatches).
2. `npm ci && npm run check`: typecheck, lint, unit and integration tests, production build and packaging checks, real-Chromium e2e.
3. Run the manual checklist below in Google Chrome with the unpacked `dist/`.
4. Upload `release/kipir-chrome-<version>.zip` in the Developer Dashboard, fill in the listing, permissions and privacy sections from this document, and submit for review.

## Manual verification checklist (Google Chrome, macOS)

- [ ] Load `dist/` unpacked; no errors on `chrome://extensions`; pin the icon.
- [ ] The badge shows `45`; hovering shows "Kıpır, Çalışıyor, 45 dk" (or English).
- [ ] Set work to 1 min and short break to 1 min. Work actively and the reminder appears with **Molaya başla / Ertele**; the badge turns orange `Mola`.
- [ ] Click the notification body: the popup (or the Kıpır window) opens.
- [ ] Click **Ertele** on a new reminder: snoozed; no duplicate notification afterwards.
- [ ] Start a break; the exercise animates; close and reopen the popup and the break continues.
- [ ] With **Mola bitiş sesi** on, a soft tone plays when the break ends; with meeting mode on, no tone.
- [ ] Leave the computer for longer than the AFK threshold: the status becomes Hareketsiz and the time stops.
- [ ] Lock the screen: Sistem beklemede. After more than 10 minutes, unlocking shows the natural-break notice.
- [ ] Put the Mac to sleep for a few minutes: no time is credited for the sleep.
- [ ] Quit and reopen Chrome: the session is restored and no time was credited while it was closed.
- [ ] Meeting mode for 15 min expires on its own; no reminder is replayed.
- [ ] Dark mode (System and forced), English, Türkçe; VoiceOver reads the timer and controls.
- [ ] If notifications do not appear: System Settings → Notifications → Google Chrome must allow them.

## Known limitations

- Works only while Chrome is running; it cannot remind you while Chrome is quit.
- Activity is Chrome's system-wide idle state, so reading without input does not count, as in the native app. Detection uses Chrome's polling, and a missed state change is corrected at the next heartbeat (≤ 60 s).
- Chrome notifications show at most two buttons; Skip and Pause stay in the panel. Whether a banner is actually shown depends on OS settings Chrome cannot report.
- Packed-build alarm timing is not verified. Chrome documents alarms as firing at most once per second and possibly later; the popup corrects a late boundary while it is open.
