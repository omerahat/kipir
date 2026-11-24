// Loads the real release artifact (release/kipir-chrome-<version>.zip, unzipped) in Chromium with live chrome.idle:
// no debug hooks exist in this build, so values are not asserted exactly. Also renders 1280x800 store screenshots.
import { test, expect, chromium, type BrowserContext, type Page } from '@playwright/test';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../..');
const version = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8')).version as string;
const ZIP = join(root, `release/kipir-chrome-${version}.zip`);
const STORE = join(root, 'test-results/store');
mkdirSync(STORE, { recursive: true });

let context: BrowserContext;
let extId: string;
const errors: string[] = [];

function watch(page: Page) {
  page.on('pageerror', (e) => errors.push(`pageerror ${page.url()}: ${e.message}`));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(`console ${page.url()}: ${m.text()}`); });
  return page;
}

test.beforeAll(async () => {
  const dir = mkdtempSync(join(tmpdir(), 'kipir-release-'));
  execFileSync('unzip', ['-q', ZIP, '-d', dir]);
  context = await chromium.launchPersistentContext(mkdtempSync(join(tmpdir(), 'kipir-prod-')), {
    channel: 'chromium', headless: true, locale: 'en-US',
    args: [`--disable-extensions-except=${dir}`, `--load-extension=${dir}`],
  });
  const sw = context.serviceWorkers()[0] ?? await context.waitForEvent('serviceworker');
  extId = new URL(sw.url()).host;
});
test.afterAll(async () => { await context?.close(); });

test('the release ZIP loads, renders and runs without errors', async () => {
  const sw = context.serviceWorkers()[0];
  expect(sw.url()).toContain('/background.js');
  const popup = watch(await context.newPage());
  await popup.setViewportSize({ width: 330, height: 600 });
  await popup.goto(`chrome-extension://${extId}/popup.html`);
  await expect(popup.getByTestId('status')).toBeVisible();
  await popup.evaluate(() => chrome.runtime.sendMessage({ type: 'prefs', patch: { onboarded: true } }));
  await expect(popup.getByTestId('remaining')).toHaveText(/^\d\d:\d\d$/);
  await expect.poll(() => sw.evaluate(() => chrome.action.getTitle({}))).toMatch(/^Kıpır, .+, \d+ min$/);
  // The production build answers no debug message.
  const debugReply = await popup.evaluate(() => chrome.runtime.sendMessage({ type: 'debug', offset: 999 }).catch(() => 'none'));
  expect(debugReply ?? 'none').toBe('none');
  const options = watch(await context.newPage());
  await options.goto(`chrome-extension://${extId}/options.html`);
  await expect(options.getByRole('heading', { name: 'Kıpır Settings' })).toBeVisible();
  await expect(popup.locator('img').first()).toHaveCount(0); // countdown screen: no pose images requested
  expect(errors).toEqual([]);
  await popup.close(); await options.close();
});

/** Centers a real extension page in a 1280x800 canvas for the store listing. */
async function storeShot(path: string, name: string, setup?: (p: Page) => Promise<void>) {
  const page = watch(await context.newPage());
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto(`chrome-extension://${extId}/${path}`);
  await page.getByTestId('status').or(page.getByRole('heading', { level: 1 })).first().waitFor();
  if (setup) await setup(page);
  if (path.startsWith('popup')) {
    await page.addStyleTag({ content: `
      html, body { height: 100%; }
      body { display: flex; align-items: center; justify-content: center; background: linear-gradient(135deg, #dff3f6, #f6efe6); }
      .panel { background: var(--bg); border-radius: 14px; box-shadow: 0 24px 60px rgba(0,0,0,.18), 0 0 0 1px rgba(0,0,0,.06); }` });
  }
  await page.waitForTimeout(400);
  await page.screenshot({ path: join(STORE, name) });
  await page.close();
}

test('store screenshots (1280x800)', async () => {
  await storeShot('popup.html', '1-timer.png');
  await storeShot('popup.html', '2-break.png', async (p) => {
    await p.evaluate(() => chrome.runtime.sendMessage({ type: 'action', action: 'startBreak' }));
    await p.getByTestId('exercise').waitFor();
  });
  await storeShot('options.html', '3-settings.png');
  expect(errors).toEqual([]);
});
