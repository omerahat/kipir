// Controller + fake platform: storage, alarms, idle, notifications, sound, badge and multiple views, with a fake
// clock. A "service-worker restart" is modelled by building a new Controller over the same storage.
import { describe, expect, it } from 'vitest';
import { Controller, type Platform } from '../../src/background/controller';
import { parseIntent } from '../../src/background/messages';
import type { Activity } from '../../src/core/engine';
import { STORAGE_KEY, type Persisted, type Snapshot } from '../../src/core/model';
import type { NotificationPermission } from '../../src/core/presentation';

const T0 = new Date(2026, 10, 23, 10, 0, 0).getTime() / 1000;

class FakeChrome {
  t = T0;
  storage: Record<string, unknown> = {};
  wake: number | null = null;
  activity: Activity = 'active';
  idleInterval = 60;
  permission: NotificationPermission = 'granted';
  notifications = new Map<string, { title: string; message: string; buttons: string[] }>();
  created: string[] = [];
  sounds: string[] = [];
  badge = { text: '', color: '', title: '' };
  views: Snapshot[][] = [[], []];
  panelOpens = 0;
  ids = 0;
  saves = 0;
  /** chrome.storage.session marker; cleared to simulate a browser restart or extension update. */
  session = false;

  platform(): Platform {
    return {
      now: () => this.t,
      newId: () => `ep-${++this.ids}`,
      load: async () => structuredClone(this.storage[STORAGE_KEY]),
      isNewSession: async () => { const fresh = !this.session; this.session = true; return fresh; },
      save: async (doc: Persisted) => { this.saves++; this.storage[STORAGE_KEY] = structuredClone(doc); },
      scheduleWake: async (w) => { this.wake = w; },
      queryIdle: async () => this.activity,
      setIdleInterval: (s) => { this.idleInterval = s; },
      notificationPermission: async () => this.permission,
      createNotification: async (id, o) => { this.created.push(id); this.notifications.set(id, o); },
      clearNotification: async (id) => { this.notifications.delete(id); },
      setBadge: async (b) => { this.badge = b; },
      playSound: async (k) => { this.sounds.push(k); },
      openPanel: async () => { this.panelOpens++; },
      openSettings: async () => undefined,
      broadcast: (s) => { for (const v of this.views) v.push(s); },
      languages: () => ['tr-TR'],
    };
  }
}

async function setup(settings: Record<string, unknown> = {}) {
  const fake = new FakeChrome();
  let c = new Controller(fake.platform());
  await c.startup();
  if (Object.keys(settings).length) await c.handle({ type: 'settings', patch: settings });
  /** Fires the scheduled wake alarm (and any due ones) until `seconds` elapsed. */
  const advance = async (seconds: number) => {
    const end = fake.t + seconds;
    while (fake.wake !== null && fake.wake <= end) { fake.t = fake.wake; await c.sync(); }
    fake.t = end;
    await c.sync();
  };
  const restartWorker = () => { c = new Controller(fake.platform()); return c; };
  /** Chrome quit and reopened (or the extension updated): the session marker is gone and the worker is new. */
  const restartBrowser = () => { fake.session = false; return restartWorker(); };
  return { fake, get c() { return c; }, advance, restartWorker, restartBrowser };
}

describe('controller lifecycle', () => {
  it('runs a full cycle with alarms only: work -> due notification -> break -> completion', async () => {
    const h = await setup({ work: 120, shortBreak: 30, breakEndSound: true });
    await h.advance(119);
    expect(h.fake.created).toHaveLength(0);
    expect(h.fake.badge.text).toBe('1');
    await h.advance(1);
    expect(h.fake.created).toEqual(['ep-1']);
    expect(h.fake.notifications.get('ep-1')).toMatchObject({ title: 'Kıpır zamanı!', buttons: ['Molaya başla', 'Ertele'] });
    expect(h.fake.badge.text).toBe('Mola');
    await h.c.notificationButton('ep-1', 0);
    expect(h.fake.notifications.size).toBe(0); // leaving due withdraws the reminder
    await h.advance(30);
    const doc = h.fake.storage[STORAGE_KEY] as Persisted;
    expect(doc.engine.checkpoint.today.breaks).toBe(1);
    expect(h.fake.sounds).toEqual(['breakEnd']);
    expect(doc.notice?.kind).toEqual({ type: 'breakCompleted', today: 1 });
  });

  it('never sends a duplicate reminder for repeated, delayed or duplicated alarms', async () => {
    const h = await setup({ work: 60 });
    await h.advance(60);
    for (let i = 0; i < 5; i++) await h.c.sync();
    await h.advance(600);
    expect(h.fake.created).toEqual(['ep-1']);
  });

  it('a service-worker restart in the middle loses no time and sends no duplicate', async () => {
    const h = await setup({ work: 120 });
    await h.advance(60);
    h.restartWorker();
    await h.advance(60);
    expect(h.fake.created).toEqual(['ep-1']);
    h.restartWorker();
    await h.c.sync();
    expect(h.fake.created).toEqual(['ep-1']);
    expect((h.fake.storage[STORAGE_KEY] as Persisted).engine.checkpoint.activeWork).toBeCloseTo(120);
  });

  it('a browser restart (startup) never credits the time Chrome was closed', async () => {
    const h = await setup();
    await h.advance(300);
    h.fake.t += 3 * 3600;
    h.restartBrowser();
    await h.c.startup();
    await h.advance(60);
    expect((h.fake.storage[STORAGE_KEY] as Persisted).engine.checkpoint.activeWork).toBeCloseTo(360);
  });

  it('a quick browser restart credits nothing, even if another event wakes the worker before onStartup', async () => {
    const h = await setup({ work: 330 });
    await h.advance(300);
    h.fake.t += 60; // closed for a minute: shorter than the gap limit
    h.restartBrowser();
    await h.c.sync(); // e.g. the top-level wake or an alarm, before onStartup
    await h.c.startup();
    const doc = h.fake.storage[STORAGE_KEY] as Persisted;
    expect(doc.engine.checkpoint.activeWork).toBeCloseTo(300);
    expect(doc.engine.checkpoint.phase).toBe('working');
    expect(h.fake.created).toHaveLength(0);
  });

  it('an extension update or reload mid-session also restarts without credit', async () => {
    const h = await setup();
    await h.advance(120);
    h.fake.t += 30;
    h.restartBrowser();
    await h.c.handle({ type: 'sync' });
    expect((h.fake.storage[STORAGE_KEY] as Persisted).engine.checkpoint.activeWork).toBeCloseTo(120);
  });

  it('sleep: a missed alarm firing late on wake does not credit the sleep', async () => {
    const h = await setup();
    await h.advance(120);
    h.fake.t += 2 * 3600; // asleep; the alarm fires on wake
    await h.c.sync();
    expect((h.fake.storage[STORAGE_KEY] as Persisted).engine.checkpoint.activeWork).toBeCloseTo(120);
  });

  it('meeting mode suppresses notification and sound but not transitions, and never replays', async () => {
    const h = await setup({ work: 60, shortBreak: 30, breakEndSound: true, sound: true });
    await h.c.handle({ type: 'meeting', enabled: true, minutes: 15 });
    await h.advance(60);
    const doc = () => h.fake.storage[STORAGE_KEY] as Persisted;
    expect(doc().engine.checkpoint.phase).toBe('due');
    expect(h.fake.created).toHaveLength(0);
    await h.c.handle({ type: 'action', action: 'startBreak' });
    await h.advance(30);
    expect(doc().engine.checkpoint.today.breaks).toBe(1);
    expect(h.fake.sounds).toHaveLength(0);
    await h.c.handle({ type: 'meeting', enabled: false });
    await h.advance(60);
    expect(h.fake.created).toEqual(['ep-2']); // a later episode notifies normally, with the reminder sound
    expect(h.fake.sounds).toEqual(['reminder']);
  });

  it('starting a meeting withdraws a visible reminder and ending it does not replay', async () => {
    const h = await setup({ work: 60 });
    await h.advance(60);
    expect(h.fake.notifications.has('ep-1')).toBe(true);
    await h.c.handle({ type: 'meeting', enabled: true });
    expect(h.fake.notifications.size).toBe(0);
    await h.c.handle({ type: 'meeting', enabled: false });
    expect(h.fake.created).toEqual(['ep-1']);
  });

  it('respects the notifications preference and the Chrome permission', async () => {
    const h = await setup({ work: 60, notifications: false });
    await h.advance(60);
    expect(h.fake.created).toHaveLength(0);
    const g = await setup({ work: 60 });
    g.fake.permission = 'denied';
    await g.advance(60);
    expect(g.fake.created).toHaveLength(0);
    const r = await g.c.handle({ type: 'testNotification' });
    expect(r.testResult).toBe('permission.denied');
    expect(r.snapshot.notification.state).toBe('denied');
  });

  it('stale notification buttons cannot act on a newer episode', async () => {
    const h = await setup({ work: 60 });
    await h.advance(60);
    await h.c.handle({ type: 'action', action: 'skip' });
    await h.advance(60);
    await h.c.notificationButton('ep-1', 0);
    expect((h.fake.storage[STORAGE_KEY] as Persisted).engine.checkpoint.phase).toBe('due');
    await h.c.notificationButton('ep-2', 1);
    expect((h.fake.storage[STORAGE_KEY] as Persisted).engine.checkpoint.snoozed).toBe(true);
  });

  it('idle events retract the AFK tail and update the idle detection interval with settings', async () => {
    const h = await setup({ afk: 120 });
    expect(h.fake.idleInterval).toBe(120);
    await h.advance(600);
    h.fake.activity = 'idle';
    await h.c.idleChanged('idle');
    expect((h.fake.storage[STORAGE_KEY] as Persisted).engine.checkpoint.activeWork).toBeCloseTo(480);
    expect(h.fake.badge.title).toContain('Hareketsiz');
  });

  it('a missed idle event is caught by the next query', async () => {
    const h = await setup({ naturalBreak: 0 });
    await h.advance(300);
    h.fake.activity = 'idle'; // no event delivered
    await h.advance(600);
    // The next heartbeat (60 s later) observes idle: that heartbeat interval was credited, then the AFK tail (90 s)
    // is retracted. Detection lags by at most one heartbeat; nothing after it is credited.
    expect((h.fake.storage[STORAGE_KEY] as Persisted).engine.checkpoint.activeWork).toBeCloseTo(300 + 60 - 90);
  });

  it('rapid concurrent intents are serialized and every view sees the same final state', async () => {
    const h = await setup();
    await Promise.all(Array.from({ length: 21 }, () => h.c.handle({ type: 'action', action: 'togglePause' })));
    const doc = h.fake.storage[STORAGE_KEY] as Persisted;
    expect(doc.engine.checkpoint.paused).toBe(true);
    expect(h.fake.views[0].at(-1)).toEqual(h.fake.views[1].at(-1));
    expect(h.fake.views[0].at(-1)!.paused).toBe(true);
    expect(h.fake.badge.text).toBe('II');
  });

  it('recovers from corrupted storage', async () => {
    const fake = new FakeChrome();
    fake.storage[STORAGE_KEY] = { schema: 'x', settings: 7, engine: { checkpoint: 'broken' } };
    const c = new Controller(fake.platform());
    const snap = await c.startup();
    expect(snap.phase).toBe('working');
    expect(snap.settings.work).toBe(2700);
  });

  it('always schedules a wake within the heartbeat', async () => {
    const h = await setup();
    await h.c.handle({ type: 'action', action: 'togglePause' });
    expect(h.fake.wake! - h.fake.t).toBeLessThanOrEqual(60);
  });

  it('prefs, notice display and icon-only badge', async () => {
    const h = await setup({ work: 60, shortBreak: 30 });
    const r = await h.c.handle({ type: 'prefs', patch: { language: 'en', onboarded: true } });
    expect(r.snapshot.prefs).toEqual({ language: 'en', onboarded: true });
    await h.advance(60);
    expect(h.fake.badge.text).toBe('Move');
    await h.c.handle({ type: 'action', action: 'startBreak' });
    await h.advance(30);
    await h.c.handle({ type: 'noticeDisplayed' });
    h.fake.t += 7;
    expect((await h.c.sync()).notice).toBeNull();
    await h.c.handle({ type: 'settings', patch: { menuBarStyle: 'icon' } });
    expect(h.fake.badge.text).toBe('');
  });
});

describe('message validation', () => {
  it('rejects malformed intents', () => {
    expect(parseIntent({ type: 'action', action: 'explode' })).toBeNull();
    expect(parseIntent({ type: 'navigate', offset: 5 })).toBeNull();
    expect(parseIntent({ type: 'meeting', enabled: 'yes' })).toBeNull();
    expect(parseIntent(null)).toBeNull();
    expect(parseIntent({ type: 'action', action: 'snooze' })).toEqual({ type: 'action', action: 'snooze' });
  });
});
