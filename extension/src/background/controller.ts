// The single authority. Every input (alarm, idle event, UI action, notification click, service-worker wake) runs as
// one serialized operation: load -> engine step -> side-effect plan -> one atomic commit -> effects -> broadcast.
// Views never own timers; they render snapshots and send intents.
import { HEARTBEAT, Scheduler, type Activity, type SchedulerAction } from '../core/engine';
import { buildSnapshot, loadPersisted, type Persisted, type Prefs, type Snapshot } from '../core/model';
import { badgeView, ceilMinutes, markNoticeDisplayed, nextNotice, planNotifications, type NotificationPermission } from '../core/presentation';
import { validateSettings, type Settings } from '../core/settings';
import { languageFor, translator } from '../i18n';
import type { Intent, IntentResult } from './messages';

export interface Platform {
  /** Wall clock, epoch seconds. */
  now(): number;
  newId(): string;
  load(): Promise<unknown>;
  /** True exactly once per browser session (browser start, extension install, update or reload); a restarted
   * service worker inside the same session gets false. Backed by chrome.storage.session. */
  isNewSession(): Promise<boolean>;
  save(doc: Persisted): Promise<void>;
  scheduleWake(epochSeconds: number): Promise<void>;
  queryIdle(afk: number): Promise<Activity>;
  setIdleInterval(afk: number): void;
  notificationPermission(): Promise<NotificationPermission>;
  createNotification(id: string, opts: { title: string; message: string; buttons: string[]; silent: boolean }): Promise<void>;
  clearNotification(id: string): Promise<void>;
  setBadge(view: { text: string; color: string; title: string }): Promise<void>;
  playSound(kind: 'reminder' | 'breakEnd'): Promise<void>;
  openPanel(): Promise<void>;
  openSettings(): Promise<void>;
  broadcast(snapshot: Snapshot): void;
  /** Browser UI languages, for "System Default". */
  languages(): readonly string[];
}

type Op = (s: Scheduler, doc: Persisted, now: number) => void | { result?: unknown };

export class Controller {
  private doc: Persisted | null = null;
  private queue: Promise<unknown> = Promise.resolve();
  private permission: NotificationPermission = 'unknown';
  private lastBadge = '';
  private appliedAfk = 0;
  private testing = false;
  /** Whether this worker already asked if the browser session is new. */
  private sessionChecked = false;
  constructor(private readonly p: Platform) {}

  /** Serializes operations so popup actions, alarms and idle events can never interleave. */
  private enqueue<T>(fn: () => Promise<T>): Promise<T> {
    const run = this.queue.then(fn, fn);
    this.queue = run.catch(() => undefined);
    return run;
  }

  private async step(op: Op, opts: { activity?: Activity; query?: boolean } = {}): Promise<Snapshot> {
    const raw = this.doc ? null : await this.p.load();
    // A new browser session (Chrome reopened, extension updated or reloaded) restores without crediting the time in
    // between, however short, and whichever event woke the worker first (native restart rules).
    let fresh = false;
    if (!this.sessionChecked) { this.sessionChecked = true; fresh = await this.p.isNewSession().catch(() => false); }
    const now = this.p.now();
    if (!this.doc) this.doc = loadPersisted(raw, now);
    const doc = this.doc;
    const sched = new Scheduler(doc.engine, doc.settings, () => this.p.newId());
    this.permission = await this.p.notificationPermission().catch(() => 'unknown' as const);
    // Every operation re-reads the idle state, so a missed `onStateChanged` can never leave activity stale.
    let activity = opts.activity;
    if (!activity && opts.query !== false) activity = await this.p.queryIdle(doc.settings.afk).catch(() => undefined);
    if (fresh) { sched.restart(now, activity ?? 'active'); this.lastBadge = ''; }
    else if (activity) sched.observeActivity(now, activity); else sched.sample(now);
    op(sched, doc, now);
    doc.engine = sched.state;
    doc.settings = sched.settings;

    // Ephemeral engine events: one consumption feeds the sound and the notice; never persisted, never replayed.
    let completed: number | null = null, natural = false, playBreakEnd = false;
    for (const e of sched.events) {
      if (e.type === 'breakCompleted') { completed = e.todayBreaks; playBreakEnd = e.sound && doc.settings.breakEndSound && !doc.engine.checkpoint.meeting; }
      else natural = true;
    }
    doc.notice = nextNotice(doc.notice, { completed, naturalBreak: natural }, now);

    const plan = planNotifications({
      book: doc.notify, enabled: doc.settings.notifications, permitted: this.permission === 'granted',
      meeting: doc.engine.checkpoint.meeting, dueId: doc.engine.checkpoint.dueId, reminderId: sched.reminderId,
    });
    doc.notify = plan.book;
    // Commit before any side effect: a reminder is attempted at most once per episode, even if the worker dies here.
    await this.p.save(doc);

    const t = translator(languageFor(doc.prefs.language, this.p.languages()));
    if (plan.clear) await this.p.clearNotification(plan.clear).catch(() => undefined);
    if (plan.create) {
      await this.p.createNotification(plan.create, {
        title: t('notification.title'),
        message: t(sched.nextBreakIsLong ? 'notification.long' : 'notification.short'),
        buttons: [t('break.start'), t('snooze')],
        silent: true,
      }).catch(() => undefined);
      if (doc.settings.sound) await this.p.playSound('reminder').catch(() => undefined);
    }
    if (playBreakEnd) await this.p.playSound('breakEnd').catch(() => undefined);
    if (this.appliedAfk !== doc.settings.afk) { this.p.setIdleInterval(doc.settings.afk); this.appliedAfk = doc.settings.afk; }

    const snap = buildSnapshot(doc, now, this.permission);
    await this.updateBadge(sched, doc, t);
    await this.p.scheduleWake(sched.nextWake(now)).catch(() => undefined);
    this.p.broadcast(snap);
    return snap;
  }

  private async updateBadge(s: Scheduler, doc: Persisted, t: ReturnType<typeof translator>) {
    const view = badgeView({
      status: s.status, remaining: s.remaining, breakDue: doc.engine.checkpoint.phase === 'due',
      iconOnly: doc.settings.menuBarStyle === 'icon', dueText: t('ext.badge.due'),
    });
    const title = `${t('app.name')}, ${t(view.statusKey)}, ${t('menubar.minutes', ceilMinutes(s.remaining))}`;
    const key = `${view.text}|${view.color}|${title}`;
    if (key === this.lastBadge) return;
    this.lastBadge = key;
    await this.p.setBadge({ text: view.text, color: view.color, title }).catch(() => { this.lastBadge = ''; });
  }

  // MARK: Entry points

  /** Service-worker wake, alarm, popup open: account for elapsed time. */
  sync(): Promise<Snapshot> { return this.enqueue(() => this.step(() => undefined)); }

  /** Browser start or install/update. The restart itself is driven by the session marker in `step`, so it applies
   * even when another event reached the worker first; this only refreshes the idle interval and the badge. */
  startup(): Promise<Snapshot> {
    this.appliedAfk = 0; this.lastBadge = '';
    return this.sync();
  }

  idleChanged(activity: Activity): Promise<Snapshot> {
    return this.enqueue(() => this.step(() => undefined, { activity }));
  }

  /** Notification action buttons only act on the episode they were created for. */
  notificationButton(id: string, index: number): Promise<Snapshot> {
    return this.enqueue(() => this.step((s, _d, now) => {
      if (s.reminderId !== id) return;
      s.perform(now, index === 0 ? 'startBreak' : 'snooze');
    }));
  }

  /** A notification body click opens the panel (opened first, while Chrome still treats it as a user action). */
  async notificationClicked(id: string): Promise<void> {
    const opening = this.p.openPanel().catch(() => undefined);
    await this.p.clearNotification(id).catch(() => undefined);
    await opening;
  }

  handle(intent: Intent): Promise<IntentResult> {
    switch (intent.type) {
      case 'sync': return this.sync().then((snapshot) => ({ snapshot }));
      case 'action': return this.run((s, _d, now) => s.perform(now, intent.action as SchedulerAction));
      case 'meeting': return this.run((s, _d, now) => s.setMeeting(now, intent.enabled, intent.minutes));
      case 'navigate': return this.run((s, _d, now) => s.navigateExercise(now, intent.offset));
      case 'settings': return this.run((s, d, now) => {
        const next = validateSettings({ ...d.settings, ...(intent.patch as Partial<Settings>) });
        s.updateSettings(now, next);
      });
      case 'prefs': return this.run((_s, d) => { d.prefs = { ...d.prefs, ...sanitizePrefs(intent.patch) }; this.lastBadge = ''; });
      case 'noticeDisplayed': return this.run((_s, d, now) => { d.notice = markNoticeDisplayed(d.notice, now); });
      case 'openSettings': return this.p.openSettings().then(() => this.sync()).then((snapshot) => ({ snapshot }));
      case 'testNotification': return this.testNotification();
    }
  }

  private run(op: Op): Promise<IntentResult> { return this.enqueue(() => this.step(op)).then((snapshot) => ({ snapshot })); }

  /** User-initiated test; never touches a real reminder episode and is deliberately not silenced by meeting mode. */
  private async testNotification(): Promise<IntentResult> {
    const snapshot = await this.sync();
    if (this.testing) return { snapshot, testResult: null };
    this.testing = true;
    try {
      const doc = this.doc!;
      const t = translator(languageFor(doc.prefs.language, this.p.languages()));
      if (!doc.settings.notifications) return { snapshot, testResult: 'notification.test.disabled' };
      if (this.permission === 'denied') return { snapshot, testResult: 'permission.denied' };
      try {
        await this.p.createNotification('kipir.test.' + this.p.newId(), {
          title: t('notification.test.title'), message: t('notification.test.body'), buttons: [], silent: true,
        });
        if (doc.settings.sound) await this.p.playSound('reminder').catch(() => undefined);
        return { snapshot, testResult: 'notification.test.submitted' };
      } catch { return { snapshot, testResult: 'notification.test.failed' }; }
    } finally { this.testing = false; }
  }

  /** For tests: the in-memory document. */
  peek(): Persisted | null { return this.doc; }
  /** Drops the in-memory cache, as a service-worker restart does. */
  forget(): void { this.doc = null; this.lastBadge = ''; this.appliedAfk = 0; this.sessionChecked = false; }
}

function sanitizePrefs(patch: unknown): Partial<Prefs> {
  const out: Partial<Prefs> = {};
  if (typeof patch !== 'object' || patch === null) return out;
  const p = patch as Record<string, unknown>;
  if (p.language === 'system' || p.language === 'tr' || p.language === 'en') out.language = p.language;
  if (typeof p.onboarded === 'boolean') out.onboarded = p.onboarded;
  return out;
}

export { HEARTBEAT };
