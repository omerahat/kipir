// Service-worker entry. Listeners are registered synchronously at top level so Chrome can wake the worker for them.
import { Controller } from './controller';
import { createChromePlatform, registerPort, WAKE_ALARM, WATCHDOG_ALARM, type DebugHooks } from './chromePlatform';
import { parseIntent } from './messages';
import type { Activity } from '../core/engine';

const debug: DebugHooks | undefined = import.meta.env.MODE === 'e2e' ? { clockOffset: 0, activity: null } : undefined;
const platform = createChromePlatform(debug);
const controller = new Controller(platform);

const ensureWatchdog = () => chrome.alarms.create(WATCHDOG_ALARM, { periodInMinutes: 5 });

chrome.runtime.onInstalled.addListener(() => { void ensureWatchdog(); void controller.startup(); });
chrome.runtime.onStartup.addListener(() => { void ensureWatchdog(); void controller.startup(); });

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === WAKE_ALARM || alarm.name === WATCHDOG_ALARM) void controller.sync();
});

chrome.idle.onStateChanged.addListener((state) => {
  if (debug?.activity) return; // e2e: the forced state wins over the real machine's input
  void controller.idleChanged(state as Activity);
});

chrome.notifications.onClicked.addListener((id) => { void controller.notificationClicked(id); });
chrome.notifications.onButtonClicked.addListener((id, index) => {
  void controller.notificationButton(id, index).then(() => chrome.notifications.clear(id));
});

chrome.runtime.onConnect.addListener((port) => {
  if (!registerPort(platform.ports, port)) { port.disconnect(); return; }
  void controller.sync();
});

chrome.runtime.onMessage.addListener((raw, sender, sendResponse) => {
  if (sender.id !== chrome.runtime.id) return false;
  if (typeof raw === 'object' && raw !== null && (raw as { target?: string }).target === 'offscreen') return false;
  if (debug && typeof raw === 'object' && raw !== null && (raw as { type?: string }).type === 'debug') {
    // e2e builds only: an absolute clock offset (the test keeps it, so it survives worker restarts) and a forced
    // idle state, because headless chrome.idle reflects the real machine's input.
    const m = raw as { offset?: number; activity?: Activity | null; restart?: boolean };
    if (typeof m.offset === 'number') debug.clockOffset = m.offset;
    if (m.activity !== undefined) debug.activity = m.activity;
    if (m.restart) controller.forget();
    void chrome.storage.session.set({ 'kipir-debug': { ...debug } });
    const next = m.activity !== undefined && m.activity !== null ? controller.idleChanged(m.activity) : controller.sync();
    void next.then((snapshot) => sendResponse({ snapshot, offset: debug.clockOffset }));
    return true;
  }
  const intent = parseIntent(raw);
  if (!intent) return false;
  controller.handle(intent).then(sendResponse, (error: unknown) => sendResponse({ error: String(error) }));
  return true;
});

// Any wake (alarm, message, event) first accounts for elapsed time; reconciliation is idempotent.
void controller.sync();
void chrome.alarms.get(WATCHDOG_ALARM).then((a) => { if (!a) void ensureWatchdog(); });
