// Persisted document and the read-only snapshot every UI renders. One storage key holds everything, so each commit
// is a single atomic `chrome.storage.local.set`.
import { restoreState, Scheduler, type EngineState, type Phase, type WorkStatus, type DailyStats } from './engine';
import type { ExerciseCursor, ExerciseDefinition } from './exercises';
import { noticeVisible, notificationState, type LanguagePreference, type Notice, type NotificationEffectiveState, type NotificationPermission, type NotifyBook } from './presentation';
import { validateSettings, type Settings } from './settings';

export const STORAGE_KEY = 'kipir';
export const SCHEMA_VERSION = 1;

export interface Prefs { language: LanguagePreference; onboarded: boolean }

export interface Persisted {
  schema: number;
  settings: Settings;
  engine: EngineState;
  notify: NotifyBook;
  notice: Notice | null;
  prefs: Prefs;
}

const isObj = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);

/** Safe initialization from whatever storage holds: missing, corrupted or older documents never throw. */
export function loadPersisted(raw: unknown, now: number): Persisted {
  const r = isObj(raw) ? raw : {};
  const settings = validateSettings(r.settings);
  const engine = restoreState(r.engine, settings, now);
  const nb = isObj(r.notify) ? r.notify : {};
  const str = (v: unknown) => (typeof v === 'string' ? v : null);
  const n = isObj(r.notice) ? r.notice : null;
  const kind = n && isObj(n.kind) ? n.kind : null;
  let notice: Notice | null = null;
  if (n && kind && typeof n.postedAt === 'number' && Number.isFinite(n.postedAt)) {
    const displayedAt = typeof n.displayedAt === 'number' && Number.isFinite(n.displayedAt) ? n.displayedAt : null;
    if (kind.type === 'naturalBreak') notice = { kind: { type: 'naturalBreak' }, postedAt: n.postedAt, displayedAt };
    else if (kind.type === 'breakCompleted' && Number.isInteger(kind.today)) notice = { kind: { type: 'breakCompleted', today: kind.today as number }, postedAt: n.postedAt, displayedAt };
  }
  const p = isObj(r.prefs) ? r.prefs : {};
  return {
    schema: SCHEMA_VERSION,
    settings,
    engine,
    notify: { lastAttempted: str(nb.lastAttempted), visible: str(nb.visible) },
    notice,
    prefs: {
      language: p.language === 'tr' || p.language === 'en' ? p.language : 'system',
      onboarded: p.onboarded === true,
    },
  };
}

export interface Snapshot {
  /** Background clock (epoch seconds) when this snapshot was computed. */
  at: number;
  status: WorkStatus;
  phase: Phase;
  paused: boolean;
  meeting: boolean;
  meetingRemaining: number | null;
  snoozed: boolean;
  remaining: number;
  countdownTotal: number;
  /** 1 while the countdown (or break) is running now; the UI projects `remaining - rate * elapsed`. */
  countdownRate: 0 | 1;
  workRate: 0 | 1;
  activeWork: number;
  today: DailyStats;
  nextBreakIsLong: boolean;
  isLongBreak: boolean;
  breakDueActionable: boolean;
  locked: boolean;
  exercise: { list: ExerciseDefinition[]; cursor: ExerciseCursor; breakDuration: number } | null;
  notice: Notice | null;
  settings: Settings;
  prefs: Prefs;
  notification: { state: NotificationEffectiveState; permission: NotificationPermission };
}

export function buildSnapshot(p: Persisted, now: number, permission: NotificationPermission): Snapshot {
  const s = new Scheduler(p.engine, p.settings, () => '');
  const c = p.engine.checkpoint;
  const list = s.exercises;
  return {
    at: now,
    status: s.status,
    phase: c.phase,
    paused: c.paused,
    meeting: c.meeting,
    meetingRemaining: s.meetingRemaining(now),
    snoozed: c.snoozed,
    remaining: s.remaining,
    countdownTotal: s.countdownTotal,
    countdownRate: s.countdownRate,
    workRate: s.workRate,
    activeWork: c.activeWork,
    today: { ...c.today },
    nextBreakIsLong: s.nextBreakIsLong,
    isLongBreak: c.isLongBreak,
    breakDueActionable: s.breakDueActionable,
    locked: s.locked,
    exercise: list && c.exercise ? { list, cursor: { ...c.exercise }, breakDuration: c.breakDuration } : null,
    notice: noticeVisible(p.notice, now) ? p.notice : null,
    settings: p.settings,
    prefs: p.prefs,
    notification: { state: notificationState(p.settings.notifications, permission), permission },
  };
}

/** Values a view shows `elapsed` seconds after receiving a snapshot, without asking the background. Rendering only:
 * the background remains the authority and is asked to reconcile when a projected boundary is crossed. */
export function project(snap: Snapshot, elapsed: number) {
  const e = Math.max(0, Number.isFinite(elapsed) ? elapsed : 0);
  const remaining = Math.max(0, snap.remaining - snap.countdownRate * e);
  const work = snap.workRate * e;
  return {
    remaining,
    fraction: snap.countdownTotal > 0 ? Math.min(1, Math.max(0, remaining / snap.countdownTotal)) : 0,
    activeWork: snap.activeWork + work,
    todayActive: snap.today.activeSeconds + work,
    breakElapsed: snap.phase === 'onBreak' ? snap.countdownRate * e : 0,
    boundaryReached: snap.countdownRate === 1 && snap.remaining - e <= 0,
  };
}
