// Real-browser tests: Playwright's bundled Chromium loads the unpacked e2e build (dist-e2e). The e2e build differs
// from production only by a debug message that sets an absolute clock offset and forces the idle state, because
// headless chrome.idle reflects this machine's real input. Everything else (service worker, alarms, storage,
// notifications, popup UI) is the real extension.
import { test, expect, chromium, type BrowserContext, type Page, type Worker } from '@playwright/test';
import { mkdtempSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const EXT = resolve(here, '../../dist-e2e');
const SHOTS = resolve(here, '../../test-results/screenshots');
mkdirSync(SHOTS, { recursive: true });

let context: BrowserContext;
let extId: string;
let offset = 0;

async function worker(): Promise<Worker> {
  const existing = context.serviceWorkers().find((w) => w.url().includes(extId || 'background.js'));
  return existing ?? context.waitForEvent('serviceworker');
}

async function debug(page: Page, msg: Record<string, unknown>) {
  return page.evaluate((m) => chrome.runtime.sendMessage({ type: 'debug', ...m }), msg);
}
async function advance(page: Page, seconds: number) {
  offset += seconds;
  await debug(page, { offset });
}
async function intent(page: Page, msg: Record<string, unknown>) {
  return page.evaluate((m) => chrome.runtime.sendMessage(m), msg);
}
async function badge(): Promise<{ text: string; title: string }> {
  const w = await worker();
  return w.evaluate(async () => ({ text: await chrome.action.getBadgeText({}), title: await chrome.action.getTitle({}) }));
}
async function openPopup(width = 330): Promise<Page> {
  const page = await context.newPage();
  await page.setViewportSize({ width, height: 600 });
  await page.goto(`chrome-extension://${extId}/popup.html`);
  await page.getByTestId('status').waitFor();
  return page;
}
/** Screenshots wait for 120 ms CSS transitions to settle. */
async function shot(page: Page, name: string, fullPage = false) {
  await page.waitForTimeout(300);
  await page.screenshot({ path: join(SHOTS, name), fullPage });
}
const box = async (page: Page, testId: string) => (await page.getByTestId(testId).boundingBox())!;

test.beforeAll(async () => {
  const userDataDir = mkdtempSync(join(tmpdir(), 'kipir-e2e-'));
  context = await chromium.launchPersistentContext(userDataDir, {
    channel: 'chromium',
    headless: true,
    locale: 'tr-TR',
    args: [`--disable-extensions-except=${EXT}`, `--load-extension=${EXT}`],
  });
  const sw = await worker();
  extId = new URL(sw.url()).host;
});
test.afterAll(async () => { await context?.close(); });

test.describe.serial('Kıpır extension in Chromium', () => {
  test('installs with a valid MV3 manifest, minimal permissions and a badge', async () => {
    const sw = await worker();
    const manifest = await sw.evaluate(() => chrome.runtime.getManifest());
    expect(manifest.manifest_version).toBe(3);
    expect([...(manifest.permissions ?? [])].sort()).toEqual(['alarms', 'idle', 'notifications', 'offscreen', 'storage']);
    expect(manifest.host_permissions ?? []).toEqual([]);
    expect(manifest.content_scripts ?? []).toEqual([]);
    const page = await openPopup();
    await debug(page, { activity: 'active', offset });
    await expect.poll(async () => (await badge()).text).toBe('45');
    expect((await badge()).title).toBe('Kıpır, Çalışıyor, 45 dk');
    const alarms = await sw.evaluate(() => chrome.alarms.getAll());
    expect(alarms.map((a) => a.name).sort()).toEqual(['kipir-wake', 'kipir-watchdog']);
    await page.close();
  });

  test('first run shows the two-step welcome, then the countdown', async () => {
    const page = await openPopup();
    await expect(page.getByTestId('onboarding')).toBeVisible();
    await shot(page, '00-onboarding.png');
    await page.getByRole('button', { name: 'Devam' }).click();
    await expect(page.getByText('Bildirim istersen')).toBeVisible();
    await page.getByRole('button', { name: 'Başlayalım' }).click();
    await expect(page.getByTestId('onboarding')).toHaveCount(0);
    await expect(page.getByTestId('remaining')).toHaveText(/^(45:00|44:5\d)$/); // real seconds keep passing
    await expect(page.getByTestId('status')).toHaveText('Çalışıyor');
    await shot(page, '01-ready.png');
    await page.close();
  });

  test('timer runs in the background with the popup closed, and survives a service-worker restart', async () => {
    let page = await openPopup();
    await advance(page, 50);
    await advance(page, 50); // two heartbeat-sized samples: 100 s of active work
    await page.close();
    await expect.poll(async () => (await badge()).text).toBe('44');
    // Stop the service worker for real (CDP), then reopen the popup: the state comes back from storage.
    const helper = await context.newPage();
    await helper.goto('about:blank');
    const cdp = await context.newCDPSession(helper);
    await cdp.send('ServiceWorker.enable');
    await cdp.send('ServiceWorker.stopAllWorkers');
    await helper.close();
    page = await openPopup();
    await debug(page, { offset, activity: 'active' });
    // 100 s of simulated work plus a few real seconds of test time; nothing lost or double-counted by the restart.
    const [m, sec] = (await page.getByTestId('remaining').textContent())!.split(':').map(Number);
    const remaining = m * 60 + sec;
    expect(remaining).toBeLessThanOrEqual(2700 - 100);
    expect(remaining).toBeGreaterThan(2700 - 100 - 20);
    await page.close();
  });

  test('pause and meeting mode never move the primary controls', async () => {
    const page = await openPopup();
    const ring0 = await box(page, 'countdown');
    const pause0 = await box(page, 'pause');
    const start0 = await box(page, 'start-break');
    await page.getByTestId('pause').click();
    await expect(page.getByTestId('status')).toHaveText('Duraklatıldı');
    await expect(page.getByTestId('pause')).toHaveText(/Sürdür/);
    await shot(page, '03-work-paused.png');
    expect(await box(page, 'pause')).toEqual(pause0);
    expect(await box(page, 'start-break')).toEqual(start0);
    expect(await box(page, 'countdown')).toEqual(ring0);
    await expect.poll(async () => (await badge()).text).toBe('II');
    // Frozen while paused, even across a long gap.
    const frozen = await page.getByTestId('remaining').textContent();
    await advance(page, 600);
    await expect(page.getByTestId('remaining')).toHaveText(frozen!);
    await page.getByTestId('pause').click();
    await expect(page.getByTestId('pause')).toHaveText(/Duraklat/);
    expect(await box(page, 'pause')).toEqual(pause0);
    await page.getByTestId('meeting-toggle').check();
    await expect(page.getByTestId('meeting-extra')).toBeVisible();
    await expect(page.getByTestId('status')).toHaveText('Toplantıda');
    await shot(page, '04-meeting.png');
    expect(await page.evaluate(() => document.documentElement.scrollHeight)).toBeLessThanOrEqual(600);
    expect(await box(page, 'pause')).toEqual(pause0);
    expect(await box(page, 'meeting-row')).toBeTruthy();
    const meetingRow = await box(page, 'meeting-row');
    await page.getByTestId('meeting-toggle').uncheck();
    expect(await box(page, 'meeting-row')).toEqual(meetingRow);
    await page.close();
  });

  test('a short cycle: due notification, meeting suppression, break with exercises, completion', async () => {
    const page = await openPopup();
    await intent(page, { type: 'settings', patch: { work: 60, shortBreak: 60, breakEndSound: true } }); // 60 s break = 2 movements
    await expect(page.getByTestId('status')).toHaveText('Mola zamanı'); // 60 s target already exceeded
    const sw = await worker();
    await expect.poll(() => sw.evaluate(async () => Object.keys(await chrome.notifications.getAll()).length)).toBe(1);
    await expect(page.getByTestId('start-break')).toHaveClass(/prominent/);
    await expect(page.getByTestId('snooze')).toBeVisible();
    await expect.poll(async () => (await badge()).text).toBe('Mola');
    await shot(page, '05-due.png');
    expect(await page.evaluate(() => document.documentElement.scrollHeight)).toBeLessThanOrEqual(600);
    // Meeting withdraws the visible reminder and never replays it.
    await page.getByTestId('meeting-toggle').check();
    await expect.poll(() => sw.evaluate(async () => Object.keys(await chrome.notifications.getAll()).length)).toBe(0);
    // Tallest countdown state (due + meeting details): measured and reported, may scroll but never clips horizontally.
    test.info().annotations.push({ type: 'due+meeting height', description: String(await page.evaluate(() => document.documentElement.scrollHeight)) });
    await shot(page, '05b-due-meeting.png');
    await page.getByTestId('meeting-toggle').uncheck();
    await advance(page, 5);
    expect(await sw.evaluate(async () => Object.keys(await chrome.notifications.getAll()).length)).toBe(0);

    await page.getByTestId('start-break').click();
    await expect(page.getByTestId('exercise')).toBeVisible();
    await expect(page.getByTestId('status')).toHaveText('Molada');
    // Both pose images loaded from the packaged native assets and share one box.
    const imgs = page.locator('.pose-stage img');
    await expect(imgs).toHaveCount(2);
    const loaded = await imgs.evaluateAll((els) => (els as HTMLImageElement[]).map((i) => i.complete && i.naturalWidth > 0));
    expect(loaded).toEqual([true, true]);
    const [a, b] = [await imgs.nth(0).boundingBox(), await imgs.nth(1).boundingBox()];
    expect(a).toEqual(b);
    // The break screen fits Chrome's 600 px popup limit without scrolling.
    const height = await page.evaluate(() => document.documentElement.scrollHeight);
    expect(height).toBeLessThanOrEqual(600);
    await shot(page, '06-break.png');
    const first = await page.getByTestId('exercise-name').textContent();
    await page.keyboard.press('ArrowRight');
    await expect(page.getByTestId('exercise-name')).not.toHaveText(first!);
    await page.keyboard.press('ArrowLeft');
    await expect(page.getByTestId('exercise-name')).toHaveText(first!);
    await page.getByTestId('exercise-pause').click();
    await expect(page.getByTestId('status')).toHaveText('Duraklatıldı');
    await shot(page, '07-break-paused.png');
    await advance(page, 120); // paused: the break does not count down
    await page.getByTestId('exercise-pause').click();
    await expect(page.getByTestId('exercise')).toBeVisible();
    await advance(page, 40);
    await advance(page, 25);
    await expect(page.getByTestId('today-breaks')).toHaveText('1');
    await expect(page.getByTestId('notice')).toContainText('1 mola tamamlandı');
    // Break-end sound enabled: the offscreen AUDIO_PLAYBACK document was created to play it, then closes itself.
    const offscreen = () => sw.evaluate(async () => (await chrome.runtime.getContexts({ contextTypes: ['OFFSCREEN_DOCUMENT' as chrome.runtime.ContextType] })).length);
    expect(await offscreen()).toBe(1);
    await expect.poll(offscreen, { timeout: 8000 }).toBe(0);
    await shot(page, '08-completed.png');
    await page.close();
  });

  test('two open views stay consistent', async () => {
    const a = await openPopup();
    const b = await openPopup();
    await a.getByTestId('pause').click();
    await expect(b.getByTestId('status')).toHaveText('Duraklatıldı');
    await b.getByTestId('pause').click();
    await expect(a.getByTestId('status')).not.toHaveText('Duraklatıldı');
    await a.close(); await b.close();
  });

  test('idle is not counted and the status explains it', async () => {
    const page = await openPopup();
    await intent(page, { type: 'settings', patch: { work: 2700 } });
    await debug(page, { activity: 'idle' });
    await expect(page.getByTestId('status')).toHaveText('Hareketsiz');
    await expect(page.getByTestId('status-note')).toBeVisible();
    const before = await page.getByTestId('remaining').textContent();
    await advance(page, 60);
    await expect(page.getByTestId('remaining')).toHaveText(before!);
    await shot(page, '09-idle.png');
    await debug(page, { activity: 'active' });
    await page.close();
  });

  test('settings page persists changes and presets update the popup', async () => {
    const settings = await context.newPage();
    await settings.goto(`chrome-extension://${extId}/options.html`);
    await settings.getByTestId('preset-quick').click();
    await expect(settings.getByTestId('work')).toHaveText('25 dk');
    await settings.getByTestId('work-inc').click();
    await expect(settings.getByTestId('work')).toHaveText('26 dk');
    await expect(settings.getByTestId('preset-quick')).toHaveAttribute('aria-pressed', 'false');
    await settings.getByTestId('natural').selectOption('300');
    await settings.getByText('Tanılama ve test').click();
    await settings.getByTestId('test-notification').click();
    await expect(settings.getByTestId('test-result')).toBeVisible();
    await shot(settings, '10-settings.png', true);
    await settings.reload();
    await expect(settings.getByTestId('work')).toHaveText('26 dk');
    await expect(settings.getByTestId('natural')).toHaveValue('300');
    await settings.getByTestId('notifications').uncheck();
    await expect(settings.getByTestId('notif-state')).toContainText('kapalı');
    await shot(settings, '11-notifications-off.png', true);
    // English and dark mode.
    await settings.getByTestId('language').selectOption('en');
    await expect(settings.getByRole('heading', { name: 'Kıpır Settings' })).toBeVisible();
    await settings.getByTestId('appearance').selectOption('dark');
    await shot(settings, '12-settings-dark-en.png', true);
    const popup = await openPopup();
    await expect(popup.getByTestId('status')).toHaveText('Working');
    expect(await popup.evaluate(() => document.documentElement.dataset.theme)).toBe('dark');
    await shot(popup, '13-popup-dark-en.png');
    await settings.getByTestId('appearance').selectOption('system');
    await settings.getByTestId('language').selectOption('tr');
    await settings.close(); await popup.close();
  });

  test('locked screen is shown as suspended; reset restores a fresh interval', async () => {
    const page = await openPopup();
    await debug(page, { activity: 'locked' });
    await expect(page.getByTestId('status')).toHaveText('Sistem beklemede');
    await expect(page.getByTestId('start-break')).toBeDisabled();
    await debug(page, { activity: 'active' });
    await page.getByTestId('more').click();
    await page.getByTestId('reset').click();
    await page.getByTestId('confirm-reset').click();
    await expect(page.getByTestId('remaining')).toHaveText(/^(26:00|25:5\d)$/);
    await page.close();
  });

  test('long localized text and dark mode keep the popup within bounds', async () => {
    const page = await openPopup();
    await page.emulateMedia({ colorScheme: 'dark' });
    await intent(page, { type: 'prefs', patch: { language: 'en' } });
    await intent(page, { type: 'meeting', enabled: true, minutes: 30 });
    await debug(page, { activity: 'idle' });
    await expect(page.getByTestId('meeting-extra')).toContainText('30 min remaining');
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth);
    expect(overflow).toBe(false);
    await shot(page, '14-dark-meeting-en.png');
    await intent(page, { type: 'meeting', enabled: false });
    await intent(page, { type: 'prefs', patch: { language: 'tr' } });
    await debug(page, { activity: 'active' });
    await page.close();
  });
});
