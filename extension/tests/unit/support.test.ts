import { describe, expect, it } from 'vitest';
import { existsSync } from 'node:fs';
import { advanceCursor, displayRemaining, exerciseSequence, loopPeriod, MOVEMENTS, navigateCursor, poseBlend } from '../../src/core/exercises';
import {
  applyPreset, defaultSettings, durationLabel, effectiveNaturalBreak, matchPreset, orderedWeekdays, toggleWeekday,
  updateHours, validateSettings, workingHoursContains,
} from '../../src/core/settings';
import {
  badgeView, ceilMinutes, clockText, markNoticeDisplayed, nextNotice, noticeVisible, planNotifications, resolveLanguage, statusNoteKey,
} from '../../src/core/presentation';
import { format, tables, translator } from '../../src/i18n';
import { browserStrings } from '../../src/i18n/browser';
import { loadNativeStrings, nativeExerciseImages, parseStrings } from '../../scripts/native';
import { loadPersisted, project, buildSnapshot } from '../../src/core/model';

describe('exercise catalog (port of ExerciseTests)', () => {
  it('break 1 of the original guide is shoulders, chest, wrists, calves', () => {
    expect(exerciseSequence(false, 120, 'all', 1).map((e) => e.id)).toEqual(['shoulders', 'chest', 'wrists', 'calves']);
  });
  it('long breaks end with a walk taking 60%', () => {
    const seq = exerciseSequence(true, 300, 'all', 1);
    expect(seq.at(-1)).toEqual({ id: 'walk', duration: 180 });
    expect(seq.length).toBe(5);
  });
  it('durations are positive and sum to the total for any input', () => {
    for (const d of [10, 30, 45, 60, 120, 180, 300, 600, 900, 3600]) for (const f of ['all', 'neckShoulders', 'back', 'hands'] as const)
      for (let r = 0; r < 12; r++) for (const long of [false, true]) {
        const seq = exerciseSequence(long, d, f, r);
        expect(seq.every((e) => e.duration > 0)).toBe(true);
        expect(seq.reduce((a, e) => a + e.duration, 0)).toBeCloseTo(d);
        expect(new Set(seq.map((e) => e.id)).size).toBe(seq.length);
      }
  });
  it('rotation changes the first movement and focus prefers its area', () => {
    const firsts = [1, 2, 3, 4].map((r) => exerciseSequence(false, 120, 'all', r)[0].id);
    for (let i = 1; i < firsts.length; i++) expect(firsts[i]).not.toBe(firsts[i - 1]);
    expect(exerciseSequence(false, 60, 'hands', 1).map((e) => e.id)).toEqual(['wrists', 'fingers']);
    expect(exerciseSequence(false, 120, 'hands', 1).slice(0, 2).map((e) => e.id)).toEqual(['wrists', 'fingers']);
  });
  it('bad durations never crash or return empty', () => {
    for (const d of [0, -5, NaN, Infinity]) expect(exerciseSequence(false, d).length).toBeGreaterThan(0);
  });
  it('cursor advances, caps at the last movement and navigation resets elapsed', () => {
    const list = exerciseSequence(false, 120, 'all', 1);
    let c = advanceCursor(list, { index: 0, elapsed: 0 }, 35);
    expect(c).toEqual({ index: 1, elapsed: 5 });
    c = advanceCursor(list, c, 1000);
    expect(c.index).toBe(3);
    expect(navigateCursor(list, c, 1)).toEqual({ index: 3, elapsed: 0 });
    expect(navigateCursor(list, c, -1)).toEqual({ index: 2, elapsed: 0 });
    expect(displayRemaining(list, { index: 0, elapsed: 0 }, 10)).toBe(10);
    expect(displayRemaining(list, { index: 3, elapsed: 29 }, 50)).toBe(50);
  });
  it('loop period fits an even number of cycles and pose blend holds then fades', () => {
    expect(loopPeriod(30, 6)).toBeCloseTo(5);
    expect(loopPeriod(NaN, 6)).toBe(6);
    expect(poseBlend(0.1)).toBe(0);
    expect(poseBlend(0.6)).toBe(1);
    expect(poseBlend(0.44)).toBeGreaterThan(0);
    expect(poseBlend(NaN)).toBe(0);
  });
  it('every movement has both pose images in the native asset catalog and localized copy', () => {
    const images = nativeExerciseImages();
    for (const m of MOVEMENTS) {
      for (const pose of ['start', 'end']) expect(existsSync(images[`${m}-${pose}`])).toBe(true);
      for (const lang of ['tr', 'en'] as const) {
        expect(tables[lang][`exercise.${m}`]).toBeTruthy();
        expect(tables[lang][`exercise.${m}.instruction`]).toBeTruthy();
      }
    }
  });
});

describe('settings (port of Settings.validated)', () => {
  it('uses the native defaults', () => {
    expect(defaultSettings()).toMatchObject({ work: 2700, shortBreak: 120, longBreak: 300, longEvery: 3, afk: 90, snooze: 600, notifications: true, sound: false, breakEndSound: false, naturalBreak: 600 });
  });
  it('recovers each invalid field independently', () => {
    const s = validateSettings({ work: 30, shortBreak: 99999, afk: 'x', longEvery: 11, appearance: 'neon', naturalBreak: 120, exerciseFocus: 'toes', sound: true, menuBarStyle: 'icon' });
    expect(s).toMatchObject({ work: 2700, shortBreak: 120, afk: 90, longEvery: 3, appearance: 'system', naturalBreak: 600, exerciseFocus: 'all', sound: true, menuBarStyle: 'icon' });
    expect(validateSettings(null)).toEqual(defaultSettings());
  });
  it('presets are derived and leave unrelated preferences alone', () => {
    const quick = applyPreset('quick', { ...defaultSettings(), sound: true });
    expect(quick).toMatchObject({ work: 1500, shortBreak: 60, longBreak: 300, snooze: 300, sound: true });
    expect(matchPreset(quick)).toBe('quick');
    expect(matchPreset(defaultSettings())).toBe('balanced');
    expect(matchPreset({ ...defaultSettings(), work: 1200 })).toBeNull();
  });
  it('effective natural break is clamped above AFK', () => {
    expect(effectiveNaturalBreak({ ...defaultSettings(), naturalBreak: 300, afk: 600 })).toBe(660);
    expect(effectiveNaturalBreak({ ...defaultSettings(), naturalBreak: 0 })).toBe(0);
  });
  it('working hours: boundaries, weekdays and overnight windows', () => {
    const h = { enabled: true, weekdays: [2], start: 540, end: 1020 };
    expect(workingHoursContains(h, new Date(2026, 10, 23, 9, 0))).toBe(true); // Monday 09:00
    expect(workingHoursContains(h, new Date(2026, 10, 23, 17, 0))).toBe(false);
    expect(workingHoursContains(h, new Date(2026, 10, 24, 10, 0))).toBe(false); // Tuesday
    const night = { enabled: true, weekdays: [2], start: 22 * 60, end: 6 * 60 };
    expect(workingHoursContains(night, new Date(2026, 10, 24, 3, 0))).toBe(true); // Tue 03:00 belongs to Monday
    expect(workingHoursContains(night, new Date(2026, 10, 23, 3, 0))).toBe(false);
    expect(workingHoursContains({ ...h, enabled: false }, new Date(2026, 10, 24, 3, 0))).toBe(true);
  });
  it('editing helpers never remove the last day or create an empty window', () => {
    expect(toggleWeekday(2, [2])).toEqual([2]);
    expect(toggleWeekday(1, [2])).toEqual([1, 2]);
    const h = { enabled: true, weekdays: [2], start: 540, end: 1020 };
    expect(updateHours(h, { start: 1020 })).toBe(h);
    expect(orderedWeekdays(2)).toEqual([2, 3, 4, 5, 6, 7, 1]);
  });
  it('duration labels', () => {
    expect(durationLabel(30)).toEqual({ key: 'ui.duration.seconds', values: [30] });
    expect(durationLabel(120)).toEqual({ key: 'ui.duration.minutes', values: [2] });
    expect(durationLabel(90)).toEqual({ key: 'ui.duration.minutesSeconds', values: [1, 30] });
  });
});

describe('presentation', () => {
  it('rounds minutes up and formats clocks', () => {
    expect(ceilMinutes(0)).toBe(0);
    expect(ceilMinutes(1)).toBe(1);
    expect(ceilMinutes(2640)).toBe(44);
    expect(ceilMinutes(2641)).toBe(45);
    expect(clockText(2700)).toBe('45:00');
    expect(clockText(59.2)).toBe('01:00');
    expect(clockText(-3)).toBe('00:00');
  });
  it('badge shows minutes, a due label, II for pause and nothing in icon-only mode', () => {
    const base = { remaining: 2641, breakDue: false, iconOnly: false, dueText: 'Mola' };
    expect(badgeView({ ...base, status: 'working' }).text).toBe('45');
    expect(badgeView({ ...base, status: 'due', remaining: 0 }).text).toBe('Mola');
    expect(badgeView({ ...base, status: 'meeting', breakDue: true }).text).toBe('Mola');
    expect(badgeView({ ...base, status: 'onBreak', breakDue: false, remaining: 90 }).text).toBe('2');
    expect(badgeView({ ...base, status: 'paused' }).text).toBe('II');
    expect(badgeView({ ...base, status: 'working', iconOnly: true }).text).toBe('');
  });
  it('status notes never sit above the ring for pause, break or meeting (DECISIONS 031)', () => {
    expect(statusNoteKey('paused', false)).toBeNull();
    expect(statusNoteKey('meeting', false)).toBeNull();
    expect(statusNoteKey('idle', false)).toBe('ui.status.note.idle');
    expect(statusNoteKey('paused', true)).toBe('ui.status.note.paused');
    expect(statusNoteKey('working', true)).toBeNull();
  });
  it('notice pends 15 minutes, then lives 6 s from display; a newer event replaces it', () => {
    const n = nextNotice(null, { completed: 3, naturalBreak: true }, 100)!;
    expect(n.kind).toEqual({ type: 'breakCompleted', today: 3 });
    expect(noticeVisible(n, 100 + 899)).toBe(true);
    expect(noticeVisible(n, 100 + 900)).toBe(false);
    const shown = markNoticeDisplayed(n, 200)!;
    expect(markNoticeDisplayed(shown, 203)).toEqual(shown);
    expect(noticeVisible(shown, 205.9)).toBe(true);
    expect(noticeVisible(shown, 206)).toBe(false);
    expect(nextNotice(shown, { completed: null, naturalBreak: true }, 201)!.kind.type).toBe('naturalBreak');
  });
  it('notification plan: at most one attempt per episode, meeting consumes, leaving due withdraws', () => {
    const book = { lastAttempted: null, visible: null };
    let p = planNotifications({ book, enabled: true, permitted: true, meeting: false, dueId: 'a', reminderId: 'a' });
    expect(p.create).toBe('a');
    p = planNotifications({ book: p.book, enabled: true, permitted: true, meeting: false, dueId: 'a', reminderId: 'a' });
    expect(p.create).toBeNull();
    p = planNotifications({ book: p.book, enabled: true, permitted: true, meeting: true, dueId: 'a', reminderId: null });
    expect(p.clear).toBe('a');
    const m = planNotifications({ book: { lastAttempted: null, visible: null }, enabled: true, permitted: true, meeting: true, dueId: 'b', reminderId: null });
    expect(m.book.lastAttempted).toBe('b');
    expect(planNotifications({ book: m.book, enabled: true, permitted: true, meeting: false, dueId: 'b', reminderId: 'b' }).create).toBeNull();
    expect(planNotifications({ book, enabled: false, permitted: true, meeting: false, dueId: 'c', reminderId: 'c' }).create).toBeNull();
    expect(planNotifications({ book, enabled: true, permitted: false, meeting: false, dueId: 'c', reminderId: 'c' }).create).toBeNull();
  });
  it('language: explicit choice, then browser languages in order, then English', () => {
    expect(resolveLanguage('tr', ['en-US'])).toBe('tr');
    expect(resolveLanguage('system', ['de-DE', 'tr-TR', 'en'])).toBe('tr');
    expect(resolveLanguage(undefined, ['fr'])).toBe('en');
  });
  it('projection runs the countdown only at rate 1 and flags the boundary', () => {
    const doc = loadPersisted(undefined, 1000);
    const snap = buildSnapshot(doc, 1000, 'granted');
    expect(project(snap, 10).remaining).toBe(2690); // working and active: the countdown runs
    const paused = { ...snap, countdownRate: 0 as const, workRate: 0 as const };
    expect(project(paused, 100).remaining).toBe(2700);
    expect(project({ ...snap, countdownRate: 1, remaining: 5 }, 6).boundaryReached).toBe(true);
  });
});

describe('localization', () => {
  it('parses Apple .strings files with comments and escapes', () => {
    expect(parseStrings('/* c */\n"a" = "x \\"y\\"\\n";\n// line\n"b"="%d dk";')).toEqual({ a: 'x "y"\n', b: '%d dk' });
  });
  it('uses the native tables as the source and keeps Turkish and English keys in parity', () => {
    const native = loadNativeStrings();
    expect(Object.keys(native.tr).sort()).toEqual(Object.keys(native.en).sort());
    expect(Object.keys(browserStrings.tr).sort()).toEqual(Object.keys(browserStrings.en).sort());
    expect(tables.tr['notification.title']).toBe('Kıpır zamanı!');
    expect(tables.tr['break.start']).toBe(native.tr['break.start']);
  });
  it('formats %d, %@ and positional arguments', () => {
    expect(format('%d dk %d sn', [1, 30])).toBe('1 dk 30 sn');
    expect(format('Özel (%@)', ['2 dk'])).toBe('Özel (2 dk)');
    expect(format('%2$d/%1$d', [1, 2])).toBe('2/1');
    expect(translator('en')('menubar.minutes', 44)).toBe('44 min');
    expect(translator('tr')('missing.key')).toBe('missing.key');
  });
  it('every key the UI uses exists in both languages', async () => {
    const { readFileSync, readdirSync } = await import('node:fs');
    const { join } = await import('node:path');
    const files: string[] = [];
    const walk = (d: string) => { for (const f of readdirSync(d, { withFileTypes: true })) { if (f.isDirectory()) walk(join(d, f.name)); else files.push(join(d, f.name)); } };
    walk(join(__dirname, '../../src'));
    const keys = new Set<string>();
    for (const f of files.filter((x) => /\.(ts|tsx)$/.test(x))) {
      for (const m of readFileSync(f, 'utf8').matchAll(/\bt\(\s*'([a-zA-Z0-9_.]+[a-zA-Z0-9_])'\s*[,)]/g)) keys.add(m[1]);
    }
    expect(keys.size).toBeGreaterThan(40);
    // Keys built from a prefix at runtime.
    for (const st of ['working', 'idle', 'paused', 'meeting', 'due', 'onBreak', 'suspended', 'offHours']) { keys.add('status.' + st); if (st !== 'working') keys.add('ui.status.note.' + st); }
    for (const f of ['all', 'neckShoulders', 'back', 'hands']) keys.add('ui.focus.' + f);
    for (const n of ['off', 'denied', 'active', 'needsPermission']) keys.add('ui.notif.state.' + n);
    for (const k of ['ui.duration.seconds', 'ui.duration.minutes', 'ui.duration.minutesSeconds', 'ui.notice.breakCompleted', 'ui.notice.naturalBreak',
      'notification.test.disabled', 'notification.test.submitted', 'notification.test.failed', 'permission.denied', 'pose.start', 'pose.end']) keys.add(k);
    for (const k of keys) for (const lang of ['tr', 'en'] as const) expect(tables[lang][k], `${lang}:${k}`).toBeTruthy();
  });
});
