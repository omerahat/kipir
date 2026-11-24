// Chrome implementation of the controller's Platform. Kept thin so the controller is testable with fakes.
import type { Activity } from '../core/engine';
import { STORAGE_KEY, type Persisted, type Snapshot } from '../core/model';
import type { NotificationPermission } from '../core/presentation';
import type { Platform } from './controller';
import { PORT_NAME, type PortMessage } from './messages';

export const WAKE_ALARM = 'kipir-wake';
export const WATCHDOG_ALARM = 'kipir-watchdog';
const OFFSCREEN_URL = 'offscreen.html';
/** Cleared by Chrome on browser restart and on extension install, update or reload. */
const SESSION_KEY = 'kipir-session';

export interface DebugHooks { clockOffset: number; activity: Activity | null }

export function createChromePlatform(debug?: DebugHooks): Platform & { ports: Set<chrome.runtime.Port> } {
  const ports = new Set<chrome.runtime.Port>();
  let creatingOffscreen: Promise<void> | null = null;

  async function ensureOffscreen() {
    const contexts = await chrome.runtime.getContexts({
      contextTypes: [chrome.runtime.ContextType.OFFSCREEN_DOCUMENT],
      documentUrls: [chrome.runtime.getURL(OFFSCREEN_URL)],
    });
    if (contexts.length > 0) return;
    if (!creatingOffscreen) {
      creatingOffscreen = chrome.offscreen.createDocument({
        url: OFFSCREEN_URL,
        reasons: [chrome.offscreen.Reason.AUDIO_PLAYBACK],
        justification: 'Plays the optional Kıpır reminder and break-completion sounds.',
      }).finally(() => { creatingOffscreen = null; });
    }
    await creatingOffscreen;
  }

  async function findPanelWindow(): Promise<number | null> {
    const contexts = await chrome.runtime.getContexts({ contextTypes: [chrome.runtime.ContextType.TAB] });
    const panel = contexts.find((c) => c.documentUrl?.includes('popup.html') && c.windowId >= 0);
    return panel ? panel.windowId : null;
  }

  return {
    ports,
    now: () => Date.now() / 1000 + (debug?.clockOffset ?? 0),
    newId: () => crypto.randomUUID(),
    load: async () => {
      if (import.meta.env.MODE === 'e2e' && debug) {
        // e2e only (removed from production builds at compile time): the test's clock offset survives service-worker restarts.
        const v = (await chrome.storage.session.get('kipir-debug'))['kipir-debug'] as DebugHooks | undefined;
        if (v) { debug.clockOffset = v.clockOffset; debug.activity = v.activity; }
      }
      return (await chrome.storage.local.get(STORAGE_KEY))[STORAGE_KEY];
    },
    isNewSession: async () => {
      const marker = (await chrome.storage.session.get(SESSION_KEY))[SESSION_KEY];
      if (marker) return false;
      await chrome.storage.session.set({ [SESSION_KEY]: true });
      return true;
    },
    save: (doc: Persisted) => chrome.storage.local.set({ [STORAGE_KEY]: doc }),
    scheduleWake: async (when: number) => {
      // Converted back to the real clock: the debug offset only exists in e2e builds.
      const real = (when - (debug?.clockOffset ?? 0)) * 1000;
      await chrome.alarms.create(WAKE_ALARM, { when: Math.max(Date.now() + 1000, real) });
    },
    queryIdle: async (afk: number) => {
      if (debug?.activity) return debug.activity;
      return (await chrome.idle.queryState(Math.max(15, Math.round(afk)))) as Activity;
    },
    setIdleInterval: (afk: number) => chrome.idle.setDetectionInterval(Math.max(15, Math.round(afk))),
    notificationPermission: async () => (await chrome.notifications.getPermissionLevel()) as NotificationPermission,
    createNotification: async (id, o) => {
      await chrome.notifications.create(id, {
        type: 'basic',
        iconUrl: chrome.runtime.getURL('icons/icon-128.png'),
        title: o.title,
        message: o.message,
        buttons: o.buttons.map((title) => ({ title })),
        silent: o.silent,
        priority: 2,
      });
    },
    clearNotification: async (id) => { await chrome.notifications.clear(id); },
    setBadge: async ({ text, color, title }) => {
      await Promise.all([
        chrome.action.setBadgeText({ text }),
        chrome.action.setBadgeBackgroundColor({ color }),
        chrome.action.setBadgeTextColor({ color: '#FFFFFF' }),
        chrome.action.setTitle({ title }),
      ]);
    },
    playSound: async (kind) => {
      await ensureOffscreen();
      await chrome.runtime.sendMessage({ target: 'offscreen', sound: kind });
    },
    openPanel: async () => {
      try {
        await chrome.action.openPopup();
        return;
      } catch {
        // No focused browser window (or an older Chrome): show the same panel in a small extension window.
      }
      const existing = await findPanelWindow().catch(() => null);
      if (existing !== null) { await chrome.windows.update(existing, { focused: true }); return; }
      await chrome.windows.create({ url: chrome.runtime.getURL('popup.html?surface=window'), type: 'popup', width: 380, height: 680, focused: true });
    },
    openSettings: () => chrome.runtime.openOptionsPage(),
    broadcast: (snapshot: Snapshot) => {
      const message: PortMessage = { type: 'snapshot', snapshot };
      for (const port of ports) { try { port.postMessage(message); } catch { ports.delete(port); } }
    },
    languages: () => (navigator.languages?.length ? navigator.languages : [navigator.language]),
  };
}

export function registerPort(ports: Set<chrome.runtime.Port>, port: chrome.runtime.Port): boolean {
  if (port.name !== PORT_NAME || port.sender?.id !== chrome.runtime.id) return false;
  ports.add(port);
  port.onDisconnect.addListener(() => ports.delete(port));
  return true;
}
