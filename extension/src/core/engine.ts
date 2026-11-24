// Port of Kipir/Core/BreakScheduler.swift for a Manifest V3 service worker.
//
// The native scheduler samples (monotonic time, seconds-since-last-input) once per second. A service worker cannot
// keep a one-second heartbeat, so this engine is sampled on events instead:
//
// - `chrome.idle` with detection interval = AFK threshold reports `active`, `idle` (no input for AFK seconds) and
//   `locked` (native "suspended"). Activity is piecewise constant between those events.
// - Every alarm, idle event, UI action and service-worker wake calls `sample(now)` with a wall-clock timestamp.
//   Credit for (previous sample, now] follows the activity that held during that interval.
// - Samples arrive at least every HEARTBEAT seconds (one-shot alarm). A gap longer than GAP_LIMIT (sleep, a closed
//   browser, a frozen process) or a backward clock is unknown time: it is never credited as work or break
//   progress, exactly like the native "gaps over 10 s fail closed" rule.
// - Native credits input-free time below the AFK threshold only once later input confirms it. Here, the `idle`
//   event says the last input happened AFK seconds ago, so the credit given in that tail is retracted. The visible
//   countdown therefore runs while input is recent and steps back by up to AFK seconds when idle is detected.
//
// All functions are pure with respect to the injected time and id generator.
import { advanceCursor, exerciseSequence, navigateCursor, type ExerciseCursor, type ExerciseDefinition } from './exercises';
import { effectiveNaturalBreak, workingHoursContains, type ExerciseFocus, type Settings, EXERCISE_FOCI, MEETING_DURATIONS } from './settings';

export type Phase = 'working' | 'due' | 'onBreak';
export type Activity = 'active' | 'idle' | 'locked';
export type WorkStatus = 'working' | 'idle' | 'paused' | 'meeting' | 'due' | 'onBreak' | 'suspended' | 'offHours';
export type SchedulerAction = 'startBreak' | 'snooze' | 'skip' | 'togglePause' | 'toggleMeeting' | 'reset';

/** Longest interval between two samples that is still trusted (seconds). */
export const GAP_LIMIT = 150;
/** Longest interval the controller lets pass between samples (seconds). */
export const HEARTBEAT = 60;

export interface DailyStats { day: string; activeSeconds: number; breaks: number }

/** Persisted session state; mirrors the native `Checkpoint`. Times are seconds; `meetingDeadline` is epoch seconds. */
export interface Checkpoint {
  activeWork: number;
  target: number;
  phase: Phase;
  breakRemaining: number;
  breakDuration: number;
  completedShorts: number;
  isLongBreak: boolean;
  paused: boolean;
  meeting: boolean;
  meetingDeadline: number | null;
  snoozed: boolean;
  dueId: string | null;
  today: DailyStats;
  exerciseRotation: number;
  breakFocus: ExerciseFocus | null;
  wasOffHours: boolean;
  /** Browser addition: the playback cursor survives service-worker restarts, so navigation is kept too. */
  exercise: ExerciseCursor | null;
}

/** Sampling bookkeeping. Persisted with the checkpoint because the service worker restarts constantly. */
export interface Runtime {
  /** Epoch seconds of the last sample, null when the next sample must only rebaseline. */
  lastSampleAt: number | null;
  activity: Activity;
  inWindow: boolean;
  /** Work credit given since the last confirmed input; retracted (up to AFK) when idle is detected. */
  runCredit: number;
  /** Natural-break chain (DECISIONS 018): open only after observed input, tainted by unknown gaps. */
  awayOpen: boolean;
  away: number;
  naturalResetPending: boolean;
}

export interface EngineState { checkpoint: Checkpoint; runtime: Runtime }

export type EngineEvent = { type: 'breakCompleted'; sound: boolean; todayBreaks: number } | { type: 'naturalBreak' };

export function localDayKey(epochSeconds: number): string {
  const d = new Date(epochSeconds * 1000);
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

export function initialState(settings: Settings, now: number): EngineState {
  const inWindow = workingHoursContains(settings.workingHours, new Date(now * 1000));
  return {
    checkpoint: {
      activeWork: 0, target: settings.work, phase: 'working', breakRemaining: 0, breakDuration: settings.shortBreak,
      completedShorts: 0, isLongBreak: false, paused: false, meeting: false, meetingDeadline: null, snoozed: false,
      dueId: null, today: { day: localDayKey(now), activeSeconds: 0, breaks: 0 }, exerciseRotation: 0, breakFocus: null,
      wasOffHours: !inWindow, exercise: null,
    },
    runtime: { lastSampleAt: null, activity: 'active', inWindow, runCredit: 0, awayOpen: false, away: 0, naturalResetPending: false },
  };
}

const fin = (v: unknown): v is number => typeof v === 'number' && Number.isFinite(v);
const isObj = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);

/** Native `Checkpoint.isValid` plus structural checks. */
export function checkpointIsValid(c: unknown): c is Checkpoint {
  if (!isObj(c)) return false;
  const t = c.today;
  return fin(c.activeWork) && c.activeWork >= 0 && c.activeWork <= 1e9
    && fin(c.target) && c.target >= 0 && c.target <= 1_000_003_600
    && fin(c.breakRemaining) && c.breakRemaining >= 0 && c.breakRemaining <= 3600
    && fin(c.breakDuration) && c.breakDuration >= 10 && c.breakDuration <= 3600 && c.breakRemaining <= c.breakDuration
    && Number.isInteger(c.completedShorts) && (c.completedShorts as number) >= 0 && (c.completedShorts as number) <= 10
    && (c.phase === 'working' || c.phase === 'due' || c.phase === 'onBreak')
    && typeof c.isLongBreak === 'boolean' && typeof c.paused === 'boolean' && typeof c.meeting === 'boolean'
    && typeof c.snoozed === 'boolean'
    && isObj(t) && typeof t.day === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(t.day)
    && fin(t.activeSeconds) && t.activeSeconds >= 0 && t.activeSeconds <= 172800
    && Number.isInteger(t.breaks) && (t.breaks as number) >= 0 && (t.breaks as number) <= 10000
    && (c.phase !== 'onBreak' || c.breakRemaining > 0);
}

/** Restores persisted state. An invalid checkpoint falls back to a fresh session; malformed optional fields are
 * repaired without discarding the session (native lenient decoding). Restored runtime always starts tainted
 * when `fresh` is true (browser start), so offline time is never credited. */
export function restoreState(raw: unknown, settings: Settings, now: number): EngineState {
  const base = initialState(settings, now);
  if (!isObj(raw) || !checkpointIsValid(raw.checkpoint)) return base;
  const c = { ...(raw.checkpoint as Checkpoint) };
  const deadline: unknown = c.meetingDeadline;
  // Missing deadline means indefinite mode; a malformed one clears meeting only, never the session.
  c.meetingDeadline = fin(deadline) ? deadline : null;
  if (deadline !== undefined && deadline !== null && !fin(deadline)) c.meeting = false;
  c.dueId = typeof c.dueId === 'string' ? c.dueId : null;
  c.exerciseRotation = fin(c.exerciseRotation) ? Math.min(1_000_000, Math.max(0, Math.trunc(c.exerciseRotation))) : 0;
  c.breakFocus = EXERCISE_FOCI.includes(c.breakFocus as ExerciseFocus) ? c.breakFocus : null;
  c.wasOffHours = typeof c.wasOffHours === 'boolean' ? c.wasOffHours : false;
  c.today = { ...c.today };
  const cur = c.exercise as unknown;
  c.exercise = isObj(cur) && Number.isInteger(cur.index) && fin(cur.elapsed) && (cur.index as number) >= 0 && cur.elapsed >= 0
    ? { index: cur.index as number, elapsed: cur.elapsed } : null;
  const r = isObj(raw.runtime) ? raw.runtime : {};
  const activity: Activity = r.activity === 'idle' || r.activity === 'locked' ? r.activity : 'active';
  const runtime: Runtime = {
    lastSampleAt: fin(r.lastSampleAt) ? r.lastSampleAt : null,
    activity,
    inWindow: typeof r.inWindow === 'boolean' ? r.inWindow : base.runtime.inWindow,
    runCredit: fin(r.runCredit) && r.runCredit >= 0 ? r.runCredit : 0,
    awayOpen: r.awayOpen === true,
    away: fin(r.away) && r.away >= 0 ? r.away : 0,
    naturalResetPending: r.naturalResetPending === true,
  };
  return { checkpoint: c, runtime };
}

/** One engine operation over a state value. Construct, call methods, then read `state` and `events`. */
export class Scheduler {
  readonly state: EngineState;
  readonly events: EngineEvent[] = [];
  settings: Settings;
  private readonly newId: () => string;

  constructor(state: EngineState, settings: Settings, newId: () => string) {
    this.state = structuredClone(state);
    this.settings = settings;
    this.newId = newId;
    this.repairCursor();
  }

  private get c() { return this.state.checkpoint; }
  private get r() { return this.state.runtime; }

  // MARK: Derived values

  get locked() { return this.r.activity === 'locked'; }
  get nextBreakIsLong() { return this.c.completedShorts >= this.settings.longEvery; }
  get remaining() { return this.c.phase === 'onBreak' ? this.c.breakRemaining : Math.max(0, this.c.target - this.c.activeWork); }
  /** Share of the current countdown still left: 1 at its start, 0 at zero (the popup ring draws exactly this). */
  get countdownTotal() {
    if (this.c.phase === 'onBreak') return this.c.breakDuration;
    return this.c.snoozed ? this.settings.snooze : this.c.target;
  }
  get remainingFraction() {
    const total = this.countdownTotal;
    if (!(total > 0) || !Number.isFinite(this.remaining)) return 0;
    return Math.min(1, Math.max(0, this.remaining / total));
  }
  get breakProgress() {
    return this.c.phase === 'onBreak' ? Math.min(1, Math.max(0, 1 - this.c.breakRemaining / this.c.breakDuration)) : 0;
  }
  get status(): WorkStatus {
    if (this.locked) return 'suspended';
    if (this.c.paused) return 'paused';
    if (this.c.phase === 'onBreak') return 'onBreak';
    if (this.c.meeting) return 'meeting';
    if (!this.r.inWindow) return 'offHours';
    if (this.c.phase === 'due') return 'due';
    return this.r.activity === 'idle' ? 'idle' : 'working';
  }
  /** The deliverable reminder; meeting mode only withholds delivery (DECISIONS 028). */
  get reminderId(): string | null {
    const c = this.c;
    return c.phase === 'due' && !c.paused && !c.meeting && !this.locked && this.r.inWindow ? c.dueId : null;
  }
  /** A Due episode the user can act on from the panel, also while meeting mode silences the reminder. */
  get breakDueActionable() { return this.c.phase === 'due' && (this.status === 'due' || this.status === 'meeting'); }
  /** 1 while confirmed work is accruing right now (drives the projected countdown in the UI). */
  get workRate(): 0 | 1 {
    const c = this.c;
    return (c.phase === 'working' || c.phase === 'due') && !c.paused && this.r.activity === 'active' && this.r.inWindow ? 1 : 0;
  }
  get breakRate(): 0 | 1 { return this.c.phase === 'onBreak' && !this.c.paused && !this.locked ? 1 : 0; }
  get countdownRate(): 0 | 1 {
    if (this.c.phase === 'onBreak') return this.breakRate;
    return this.c.phase === 'working' ? this.workRate : 0;
  }
  get exercises(): ExerciseDefinition[] | null {
    const c = this.c;
    if (c.phase !== 'onBreak') return null;
    return exerciseSequence(c.isLongBreak, c.breakDuration, c.breakFocus ?? 'all', c.exerciseRotation);
  }
  meetingRemaining(now: number): number | null {
    return this.c.meetingDeadline === null ? null : Math.max(0, this.c.meetingDeadline - now);
  }

  /** Earliest time at which the state can change or the badge minute changes; always within HEARTBEAT. */
  nextWake(now: number): number {
    const c = this.c;
    const candidates = [now + HEARTBEAT];
    const rate = this.countdownRate;
    if (rate) {
      const rem = this.remaining;
      candidates.push(now + rem);
      const minuteStep = rem - 60 * (Math.ceil(rem / 60) - 1);
      if (minuteStep > 0.5) candidates.push(now + minuteStep);
    }
    if (c.meetingDeadline !== null) candidates.push(c.meetingDeadline);
    const threshold = effectiveNaturalBreak(this.settings);
    if (threshold > 0 && this.r.awayOpen && this.r.activity !== 'active' && this.canAccrueAway
      && (c.activeWork > 0 || c.phase === 'due' || c.snoozed)) {
      candidates.push(now + Math.max(0, threshold - this.r.away));
    }
    return Math.max(now + 1, Math.min(...candidates.filter(Number.isFinite)));
  }

  // MARK: Sampling

  /** Accounts for the interval since the previous sample. Idempotent for a repeated `now`. */
  sample(now: number): void {
    const c = this.c, r = this.r;
    if (!Number.isFinite(now)) { r.lastSampleAt = null; r.runCredit = 0; this.dropAway(); return; }
    const changedDay = this.rollover(now);
    this.reconcileMeeting(now);
    // Entering or leaving the working window rebaselines; the crossing sample is discarded, except that a running
    // break keeps counting down (DECISIONS 019). Entering the window starts a new working period (DECISIONS 025).
    if (this.refreshWindow(now)) {
      if (r.inWindow) this.restartIntervalOnWindowEntry();
      if (c.phase !== 'onBreak') {
        this.dropAway(); r.lastSampleAt = now; r.runCredit = 0; this.refreshReminder(); return;
      }
    }
    const prev = r.lastSampleAt;
    if (prev === now) return;
    r.lastSampleAt = now;
    if (prev === null || !(now > prev)) {
      // First sample after a restart, or a backward clock: rebaseline without credit.
      r.runCredit = 0; this.dropAway(); this.refreshReminder(); return;
    }
    const delta = now - prev;
    const valid = delta <= GAP_LIMIT;
    if (this.trackAway(delta, valid)) { this.refreshReminder(); return; }
    if (changedDay || !valid) { r.runCredit = 0; this.refreshReminder(); return; }
    if (this.locked || c.paused) { this.refreshReminder(); return; }
    if (c.phase === 'onBreak') {
      if (c.exercise) {
        const list = this.exercises!;
        c.exercise = advanceCursor(list, c.exercise, Math.min(delta, c.breakRemaining));
      }
      c.breakRemaining = Math.max(0, c.breakRemaining - delta);
      if (c.breakRemaining === 0) {
        c.today.breaks += 1;
        c.completedShorts = c.isLongBreak ? 0 : Math.min(10, c.completedShorts + 1);
        this.resetInterval();
        this.events.push({ type: 'breakCompleted', sound: this.settings.breakEndSound, todayBreaks: c.today.breaks });
      }
    } else if (r.inWindow && r.activity === 'active') {
      c.activeWork += delta;
      c.today.activeSeconds = Math.min(172800, c.today.activeSeconds + delta);
      r.runCredit += delta;
      if (c.activeWork >= c.target) c.phase = 'due';
    }
    this.refreshReminder();
  }

  /** A `chrome.idle` state report. The interval before it is credited with the previous activity. */
  observeActivity(now: number, next: Activity): void {
    this.sample(now);
    const r = this.r, c = this.c;
    const old = r.activity;
    if (old === next) return;
    r.activity = next;
    if (next === 'active') {
      // Input observed: the away span ends and a pending natural-break notice is delivered.
      this.input();
    } else if (old === 'active' && next === 'idle') {
      // The last input was AFK seconds ago: that tail was never confirmed by input.
      const retract = Math.min(this.settings.afk, r.runCredit);
      if (retract > 0 && (c.phase === 'working' || c.phase === 'due')) {
        c.activeWork = Math.max(0, c.activeWork - retract);
        c.today.activeSeconds = Math.max(0, c.today.activeSeconds - retract);
      }
      r.runCredit = 0;
      if (this.canAccrueAway && r.awayOpen) { r.away = this.settings.afk; this.applyNaturalBreak(); }
      else this.dropAway();
    } else if (old === 'active' && next === 'locked') {
      // Locking is itself input; away time starts now.
      r.runCredit = 0;
      if (this.canAccrueAway && r.lastSampleAt !== null) { r.awayOpen = true; r.away = 0; } else this.dropAway();
    }
    this.refreshReminder();
  }

  /** Browser start or extension install/update: restored state never credits offline time and the away chain
   * starts tainted (native restart rules). */
  restart(now: number, activity: Activity): void {
    const c = this.c, r = this.r;
    r.inWindow = workingHoursContains(this.settings.workingHours, new Date(now * 1000));
    if (c.wasOffHours && r.inWindow) this.restartIntervalOnWindowEntry();
    c.wasOffHours = !r.inWindow;
    this.rollover(now);
    this.reconcileMeeting(now);
    r.activity = activity;
    r.lastSampleAt = now; r.runCredit = 0; r.naturalResetPending = false;
    this.dropAway();
    this.refreshReminder();
  }

  // MARK: Actions

  perform(now: number, action: SchedulerAction): void {
    this.sample(now);
    const c = this.c;
    const dropCompletion = () => this.dropCompletionEvents();
    switch (action) {
      case 'startBreak':
        if (c.paused || this.locked || c.phase === 'onBreak') break;
        c.isLongBreak = this.nextBreakIsLong;
        c.breakDuration = c.isLongBreak ? this.settings.longBreak : this.settings.shortBreak;
        c.breakRemaining = c.breakDuration;
        c.phase = 'onBreak';
        c.exerciseRotation = c.exerciseRotation >= 1_000_000 ? 0 : c.exerciseRotation + 1;
        c.breakFocus = this.settings.exerciseFocus;
        c.exercise = { index: 0, elapsed: 0 };
        this.r.naturalResetPending = false;
        break;
      case 'snooze':
        if (c.phase !== 'due' || c.paused || this.locked) break;
        c.target = c.activeWork + this.settings.snooze;
        c.snoozed = true; c.phase = 'working';
        break;
      case 'skip':
        dropCompletion(); this.r.naturalResetPending = false;
        if (c.phase === 'due' || c.phase === 'onBreak') this.resetInterval();
        break;
      case 'togglePause': dropCompletion(); c.paused = !c.paused; break;
      case 'toggleMeeting': dropCompletion(); c.meeting = !c.meeting; c.meetingDeadline = null; break;
      case 'reset':
        dropCompletion(); this.r.naturalResetPending = false;
        this.resetInterval(); c.completedShorts = 0; c.paused = false; c.meeting = false; c.meetingDeadline = null;
        break;
    }
    // A click in the panel is user input (native perform -> baseline).
    this.input();
    this.refreshReminder();
  }

  /** Timed (15/30/60 min) or indefinite meeting mode. Never rebaselines (DECISIONS 028). */
  setMeeting(now: number, enabled: boolean, minutes?: number): void {
    if (minutes !== undefined && !(MEETING_DURATIONS as readonly number[]).includes(minutes)) return;
    this.sample(now);
    if (enabled) this.dropCompletionEvents();
    this.c.meeting = enabled;
    this.c.meetingDeadline = enabled && minutes !== undefined ? now + minutes * 60 : null;
    this.reconcileMeeting(now);
    this.refreshReminder();
  }

  updateSettings(now: number, value: Settings): void {
    this.sample(now);
    const c = this.c, r = this.r;
    this.settings = value;
    // Editing the window in Settings never restarts the interval; only a clock transition does.
    r.inWindow = workingHoursContains(value.workingHours, new Date(now * 1000));
    c.wasOffHours = !r.inWindow;
    if (!c.snoozed && c.phase !== 'onBreak') {
      c.target = value.work;
      c.phase = c.activeWork >= c.target && (r.inWindow || c.phase === 'due') ? 'due' : 'working';
    }
    this.input();
    this.refreshReminder();
  }

  navigateExercise(now: number, offset: number): void {
    this.sample(now);
    const list = this.exercises;
    if (!list || !this.c.exercise) return;
    this.c.exercise = navigateCursor(list, this.c.exercise, offset);
  }

  // MARK: Internals

  private get canAccrueAway() {
    const c = this.c;
    return (c.phase === 'working' || c.phase === 'due') && !c.paused && this.r.inWindow;
  }
  private dropAway() { this.r.awayOpen = false; this.r.away = 0; }
  private dropCompletionEvents() {
    for (let i = this.events.length - 1; i >= 0; i--) if (this.events[i].type === 'breakCompleted') this.events.splice(i, 1);
  }
  private armNaturalNotice() {
    if (this.r.naturalResetPending) { this.r.naturalResetPending = false; this.events.push({ type: 'naturalBreak' }); }
  }
  /** Observed input: opens a fresh away chain and releases a pending natural-break notice. */
  private input() {
    const r = this.r;
    r.runCredit = 0;
    this.armNaturalNotice();
    if (this.canAccrueAway && r.lastSampleAt !== null) { r.awayOpen = true; r.away = 0; } else this.dropAway();
  }
  /** Returns true when this sample reset the work interval. */
  private trackAway(delta: number, valid: boolean): boolean {
    const r = this.r;
    if (!this.canAccrueAway) { this.dropAway(); return false; }
    if (r.activity === 'active') {
      // Activity reported active across a trusted interval means input happened within it.
      if (valid) { r.awayOpen = true; r.away = 0; this.armNaturalNotice(); } else this.dropAway();
      return false;
    }
    if (r.activity === 'locked') {
      // Input is impossible while locked, so any locked time is verified away time (DECISIONS 025).
      if (r.awayOpen) { r.away += delta; return this.applyNaturalBreak(); }
      return false;
    }
    if (valid && r.awayOpen) { r.away += delta; return this.applyNaturalBreak(); }
    this.dropAway();
    return false;
  }
  private applyNaturalBreak(): boolean {
    const threshold = effectiveNaturalBreak(this.settings);
    const c = this.c;
    if (!(threshold > 0) || this.r.away < threshold) return false;
    if (!(c.activeWork > 0 || c.phase === 'due' || c.snoozed)) return false;
    this.resetInterval();
    this.r.runCredit = 0;
    this.r.naturalResetPending = true;
    return true;
  }
  private refreshWindow(now: number): boolean {
    const value = workingHoursContains(this.settings.workingHours, new Date(now * 1000));
    if (value === this.r.inWindow) return false;
    this.r.inWindow = value; this.c.wasOffHours = !value;
    return true;
  }
  private restartIntervalOnWindowEntry() {
    const c = this.c;
    if (c.phase === 'onBreak' || !(c.activeWork > 0 || c.phase === 'due' || c.snoozed)) return;
    this.resetInterval(); this.r.runCredit = 0;
  }
  private rollover(now: number): boolean {
    const day = localDayKey(now);
    if (day === this.c.today.day) return false;
    this.c.today = { day, activeSeconds: 0, breaks: 0 };
    return true;
  }
  private reconcileMeeting(now: number) {
    const c = this.c;
    if (!c.meeting) { c.meetingDeadline = null; return; }
    if (c.meetingDeadline === null) return;
    const remaining = c.meetingDeadline - now;
    // Expired, or a backward clock jump beyond the supported one-hour horizon: end timed mode.
    if (!(Number.isFinite(remaining) && remaining > 0 && remaining <= 3600)) { c.meeting = false; c.meetingDeadline = null; }
  }
  private resetInterval() {
    const c = this.c;
    c.exercise = null; c.activeWork = 0; c.target = this.settings.work; c.phase = 'working';
    c.breakRemaining = 0; c.isLongBreak = false; c.snoozed = false;
  }
  private refreshReminder() {
    const c = this.c;
    if (c.phase === 'due') { if (c.dueId === null) c.dueId = this.newId(); } else c.dueId = null;
  }
  private repairCursor() {
    const c = this.c;
    if (c.phase !== 'onBreak') { c.exercise = null; return; }
    const list = this.exercises!;
    if (!c.exercise || c.exercise.index >= list.length) {
      // Rebuild the chronological position from the confirmed break elapsed time (native restore).
      c.exercise = advanceCursor(list, { index: 0, elapsed: 0 }, c.breakDuration - c.breakRemaining);
    }
  }
}
