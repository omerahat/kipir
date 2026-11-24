// Port of Kipir/Core/Settings.swift, WorkingHours.swift and the settings helpers in QualityOfLife.swift.
// Every duration is stored in seconds, exactly like the native app, and validated with the same ranges and
// fallbacks.

export type Appearance = 'system' | 'light' | 'dark';
export type ToolbarStyle = 'timer' | 'icon';
export type ExerciseFocus = 'all' | 'neckShoulders' | 'back' | 'hands';
export const EXERCISE_FOCI: readonly ExerciseFocus[] = ['all', 'neckShoulders', 'back', 'hands'];

/** Optional working-hour window. Minutes are local wall-clock minutes from midnight; weekdays use the native
 * Calendar numbering (1 = Sunday ... 7 = Saturday). `end < start` is a window crossing midnight, attributed to the
 * weekday on which it starts. */
export interface WorkingHours {
  enabled: boolean;
  weekdays: number[];
  start: number;
  end: number;
}

export interface Settings {
  work: number;
  shortBreak: number;
  longBreak: number;
  longEvery: number;
  afk: number;
  snooze: number;
  notifications: boolean;
  sound: boolean;
  breakEndSound: boolean;
  appearance: Appearance;
  /** Verified no-input span that counts as a natural break; 0 disables. Allowed: 0, 300, 600, 900. */
  naturalBreak: number;
  workingHours: WorkingHours;
  exerciseFocus: ExerciseFocus;
  /** Native "menuBarStyle": "timer" (icon + remaining minutes) or "icon" (icon only). Drives the toolbar badge. */
  menuBarStyle: ToolbarStyle;
}

export const defaultWorkingHours = (): WorkingHours => ({ enabled: false, weekdays: [2, 3, 4, 5, 6], start: 540, end: 1080 });

export const defaultSettings = (): Settings => ({
  work: 45 * 60,
  shortBreak: 2 * 60,
  longBreak: 5 * 60,
  longEvery: 3,
  afk: 90,
  snooze: 10 * 60,
  notifications: true,
  sound: false,
  breakEndSound: false,
  appearance: 'system',
  naturalBreak: 600,
  workingHours: defaultWorkingHours(),
  exerciseFocus: 'all',
  menuBarStyle: 'timer',
});

export const NATURAL_BREAK_OPTIONS = [0, 300, 600, 900] as const;
export const SHORT_BREAK_OPTIONS = [30, 60, 120, 180, 300] as const;
export const LONG_BREAK_OPTIONS = [180, 300, 600, 900] as const;
export const MEETING_DURATIONS = [15, 30, 60] as const;

const isNum = (v: unknown): v is number => typeof v === 'number' && Number.isFinite(v);
const isObj = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);

function inRange(value: unknown, min: number, max: number, fallback: number): number {
  return isNum(value) && value >= min && value <= max ? value : fallback;
}

export function validateWorkingHours(raw: unknown): WorkingHours {
  const d = defaultWorkingHours();
  if (!isObj(raw)) return d;
  const enabled = typeof raw.enabled === 'boolean' ? raw.enabled : d.enabled;
  const days = Array.isArray(raw.weekdays)
    ? [...new Set(raw.weekdays.filter((x): x is number => Number.isInteger(x) && x >= 1 && x <= 7))].sort((a, b) => a - b)
    : [];
  let start = Number.isInteger(raw.start) ? (raw.start as number) : d.start;
  let end = Number.isInteger(raw.end) ? (raw.end as number) : d.end;
  if (start < 0 || start >= 1440 || end < 0 || end >= 1440 || start === end) { start = d.start; end = d.end; }
  return { enabled, weekdays: days.length ? days : d.weekdays, start, end };
}

/** Field-wise lenient validation: a missing or malformed field falls back to its default without discarding the
 * others (native lenient decoding plus `Settings.validated()`). */
export function validateSettings(raw: unknown): Settings {
  const d = defaultSettings();
  const r = isObj(raw) ? raw : {};
  const bool = (key: keyof Settings, fallback: boolean) => (typeof r[key] === 'boolean' ? (r[key] as boolean) : fallback);
  const pick = <T extends string>(value: unknown, allowed: readonly T[], fallback: T): T =>
    allowed.includes(value as T) ? (value as T) : fallback;
  return {
    work: inRange(r.work, 60, 14400, 2700),
    shortBreak: inRange(r.shortBreak, 10, 1800, 120),
    longBreak: inRange(r.longBreak, 10, 3600, 300),
    longEvery: Number.isInteger(r.longEvery) && (r.longEvery as number) >= 1 && (r.longEvery as number) <= 10 ? (r.longEvery as number) : 3,
    afk: inRange(r.afk, 15, 600, 90),
    snooze: inRange(r.snooze, 60, 3600, 600),
    notifications: bool('notifications', d.notifications),
    sound: bool('sound', d.sound),
    breakEndSound: bool('breakEndSound', d.breakEndSound),
    appearance: pick(r.appearance, ['system', 'light', 'dark'] as const, 'system'),
    naturalBreak: (NATURAL_BREAK_OPTIONS as readonly number[]).includes(r.naturalBreak as number) ? (r.naturalBreak as number) : 600,
    workingHours: validateWorkingHours(r.workingHours),
    exerciseFocus: pick(r.exerciseFocus, EXERCISE_FOCI, 'all'),
    menuBarStyle: pick(r.menuBarStyle, ['timer', 'icon'] as const, 'timer'),
  };
}

/** Verified away span that actually restarts the work interval: the selection, but always at least one minute
 * beyond the AFK threshold (DECISIONS 018). Zero when natural break is off. */
export function effectiveNaturalBreak(s: Settings): number {
  return s.naturalBreak > 0 ? Math.max(s.naturalBreak, s.afk + 60) : 0;
}
export const naturalBreakIsRaised = (s: Settings) => s.naturalBreak > 0 && effectiveNaturalBreak(s) > s.naturalBreak;
export const effectiveNaturalBreakMinutes = (s: Settings) => Math.ceil(effectiveNaturalBreak(s) / 60);

// MARK: Working hours

/** Whether `date` lies inside the window, read in local time. Disabled windows contain every date. The start minute
 * is inside, the end minute is outside. An overnight window belongs to the weekday it starts on. */
export function workingHoursContains(hours: WorkingHours, date: Date): boolean {
  if (!hours.enabled) return true;
  const w = validateWorkingHours(hours);
  const weekday = date.getDay() + 1; // native numbering: 1 = Sunday
  const now = date.getHours() * 60 + date.getMinutes();
  if (!Number.isFinite(now)) return true;
  if (w.start < w.end) return w.weekdays.includes(weekday) && now >= w.start && now < w.end;
  const previous = weekday === 1 ? 7 : weekday - 1;
  return (w.weekdays.includes(weekday) && now >= w.start) || (w.weekdays.includes(previous) && now < w.end);
}

/** Toggles a day but never removes the last one. */
export function toggleWeekday(weekday: number, weekdays: number[]): number[] {
  if (weekday < 1 || weekday > 7) return weekdays;
  const days = new Set(weekdays.filter((d) => d >= 1 && d <= 7));
  if (days.has(weekday)) { if (days.size > 1) days.delete(weekday); } else days.add(weekday);
  return [...days].sort((a, b) => a - b);
}

/** Applies a new start or end; an edit that would make both equal is ignored. */
export function updateHours(hours: WorkingHours, change: { start?: number; end?: number }): WorkingHours {
  const start = change.start ?? hours.start;
  const end = change.end ?? hours.end;
  if (!(start >= 0 && start < 1440 && end >= 0 && end < 1440) || start === end) return hours;
  return { ...hours, start, end };
}
export const crossesMidnight = (hours: WorkingHours) => hours.end < hours.start;

/** Weekday numbers 1...7 starting at the locale's first weekday (Monday for Turkish, Sunday for US English). */
export function orderedWeekdays(firstWeekday: number): number[] {
  const first = firstWeekday >= 1 && firstWeekday <= 7 ? firstWeekday : 1;
  return Array.from({ length: 7 }, (_, i) => ((first - 1 + i) % 7) + 1);
}

// MARK: Presets (derived from the six timing values, never stored)

export type TimingPreset = 'quick' | 'balanced';
export function applyPreset(preset: TimingPreset, s: Settings): Settings {
  return {
    ...s,
    work: preset === 'quick' ? 1500 : 2700,
    shortBreak: preset === 'quick' ? 60 : 120,
    longBreak: 300,
    longEvery: 3,
    afk: 90,
    snooze: preset === 'quick' ? 300 : 600,
  };
}
export function matchPreset(s: Settings): TimingPreset | null {
  for (const p of ['quick', 'balanced'] as const) {
    const c = applyPreset(p, s);
    if (c.work === s.work && c.shortBreak === s.shortBreak && c.longBreak === s.longBreak && c.longEvery === s.longEvery
      && c.afk === s.afk && c.snooze === s.snooze) return p;
  }
  return null;
}

/** Localization key and arguments for a duration label (BreakDurationOptions.label). */
export function durationLabel(seconds: number): { key: string; values: number[] } {
  const total = Number.isFinite(seconds) && seconds > 0 ? Math.round(seconds) : 0;
  const m = Math.floor(total / 60), s = total % 60;
  if (m === 0) return { key: 'ui.duration.seconds', values: [s] };
  if (s === 0) return { key: 'ui.duration.minutes', values: [m] };
  return { key: 'ui.duration.minutesSeconds', values: [m, s] };
}
