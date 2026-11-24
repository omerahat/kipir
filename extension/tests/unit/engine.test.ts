import { describe, expect, it } from 'vitest';
import { GAP_LIMIT, HEARTBEAT, initialState, restoreState, Scheduler } from '../../src/core/engine';
import { defaultSettings } from '../../src/core/settings';
import { Sim, T0 } from './sim';

describe('active-time accounting', () => {
  it('accumulates active work and becomes due exactly at the target', () => {
    const s = new Sim({ work: 600 });
    s.run(599, 1);
    expect(s.c.phase).toBe('working');
    expect(s.view.remaining).toBeCloseTo(1);
    s.run(1, 1);
    expect(s.c.phase).toBe('due');
    expect(s.c.dueId).toBe('id-1');
    expect(s.view.remaining).toBe(0);
    s.run(1, 1);
    expect(s.c.dueId).toBe('id-1'); // one episode
  });

  it('crosses the boundary with a single coarse sample', () => {
    const s = new Sim({ work: 600 });
    s.run(540).jump(61).sample(); // 601 s in one 61 s sample
    expect(s.c.phase).toBe('due');
    expect(s.c.activeWork).toBeCloseTo(601);
  });

  it('keeps counting active use while due (DECISIONS 008)', () => {
    const s = new Sim({ work: 60 });
    s.run(120);
    expect(s.c.phase).toBe('due');
    expect(s.c.activeWork).toBeCloseTo(120);
    expect(s.c.today.activeSeconds).toBeCloseTo(120);
  });

  it('retracts the unconfirmed AFK tail when idle is detected', () => {
    const s = new Sim({ work: 2700, afk: 90 });
    s.run(600);
    s.activity('idle'); // last input was 90 s ago
    expect(s.c.activeWork).toBeCloseTo(510);
    expect(s.c.today.activeSeconds).toBeCloseTo(510);
    s.run(300);
    expect(s.c.activeWork).toBeCloseTo(510); // idle time never credited
    expect(s.view.status).toBe('idle');
    s.activity('active').run(60);
    expect(s.c.activeWork).toBeCloseTo(570);
  });

  it('never retracts more than was credited since the last confirmed input', () => {
    const s = new Sim({ afk: 90 });
    s.run(30);
    s.perform('togglePause').perform('togglePause'); // a click is input
    s.run(20);
    s.activity('idle');
    expect(s.c.activeWork).toBeCloseTo(30);
  });

  it('never credits unknown gaps (sleep, closed browser, delayed alarms)', () => {
    const s = new Sim();
    s.run(300);
    s.jump(GAP_LIMIT + 1).sample();
    expect(s.c.activeWork).toBeCloseTo(300);
    s.run(60);
    expect(s.c.activeWork).toBeCloseTo(360);
  });

  it('accepts a sample exactly at the gap limit and rejects one second more', () => {
    const a = new Sim(); a.jump(GAP_LIMIT).sample();
    expect(a.c.activeWork).toBeCloseTo(GAP_LIMIT);
    const b = new Sim(); b.jump(GAP_LIMIT + 1).sample();
    expect(b.c.activeWork).toBe(0);
  });

  it('fails closed on a backward clock and recovers afterwards', () => {
    const s = new Sim();
    s.run(120);
    s.jump(-3600).sample();
    expect(s.c.activeWork).toBeCloseTo(120);
    s.run(60);
    expect(s.c.activeWork).toBeCloseTo(180);
  });

  it('treats a wall-clock jump forward as unknown time', () => {
    const s = new Sim();
    s.run(60).jump(7200).sample();
    expect(s.c.activeWork).toBeCloseTo(60);
  });

  it('is idempotent for repeated samples at the same instant (duplicate alarms)', () => {
    const s = new Sim({ work: 60 });
    s.run(60);
    const before = structuredClone(s.state);
    s.sample().sample().sample();
    expect(s.state).toEqual(before);
  });

  it('locked time is suspended: no work credit and no break countdown', () => {
    const s = new Sim({ naturalBreak: 0 });
    s.run(60).activity('locked').run(600);
    expect(s.view.status).toBe('suspended');
    expect(s.c.activeWork).toBeCloseTo(60);
    s.activity('active');
    s.perform('startBreak');
    const before = s.c.breakRemaining;
    s.activity('locked').run(60);
    expect(s.c.breakRemaining).toBe(before);
  });

  it('keeps session work across a day boundary but resets daily totals and drops the crossing sample', () => {
    const late = new Date(2026, 10, 23, 23, 59, 30).getTime() / 1000;
    const s = new Sim({}, late - 600);
    s.run(600, 30);
    const work = s.c.activeWork;
    s.run(60, 60); // crosses midnight
    expect(s.c.today.day).toBe('2026-11-24');
    expect(s.c.today.activeSeconds).toBe(0);
    expect(s.c.activeWork).toBeCloseTo(work);
    s.run(60);
    expect(s.c.activeWork).toBeCloseTo(work + 60);
  });
});

describe('break cycle', () => {
  it('runs three short breaks then a long one, and completion credits exactly once', () => {
    const s = new Sim({ work: 60, shortBreak: 30, longBreak: 60, longEvery: 3 });
    const kinds: boolean[] = [];
    for (let i = 0; i < 4; i++) {
      s.run(60);
      expect(s.c.phase).toBe('due');
      s.perform('startBreak');
      kinds.push(s.c.isLongBreak);
      s.run(s.c.breakDuration, 15);
      expect(s.c.phase).toBe('working');
    }
    expect(kinds).toEqual([false, false, false, true]);
    expect(s.c.today.breaks).toBe(4);
    expect(s.c.completedShorts).toBe(0);
    expect(s.take().filter((e) => e.type === 'breakCompleted')).toHaveLength(4);
  });

  it('break completes at its boundary, not one second early', () => {
    const s = new Sim({ shortBreak: 30 });
    s.perform('startBreak');
    s.run(29, 1);
    expect(s.c.phase).toBe('onBreak');
    s.run(1, 1);
    expect(s.c.phase).toBe('working');
  });

  it('continues a break while idle (the user walked away)', () => {
    const s = new Sim({ shortBreak: 120 });
    s.perform('startBreak').activity('idle').run(120);
    expect(s.c.phase).toBe('working');
    expect(s.c.today.breaks).toBe(1);
  });

  it('skip and manual finish restart the interval without credit or cycle advance', () => {
    const s = new Sim({ work: 60 });
    s.run(60).perform('skip');
    expect(s.c.phase).toBe('working');
    expect(s.c.completedShorts).toBe(0);
    s.run(60).perform('startBreak').run(10).perform('skip');
    expect(s.c.today.breaks).toBe(0);
    expect(s.take().some((e) => e.type === 'breakCompleted')).toBe(false);
  });

  it('snooze adds active work from the current total and creates a new episode later', () => {
    const s = new Sim({ work: 60, snooze: 300 });
    s.run(60);
    const first = s.c.dueId;
    s.perform('snooze');
    expect(s.c.target).toBeCloseTo(360);
    expect(s.c.dueId).toBeNull();
    expect(s.view.remainingFraction).toBeCloseTo(1);
    s.run(300);
    expect(s.c.phase).toBe('due');
    expect(s.c.dueId).not.toBe(first);
  });

  it('a break started early is allowed; start is refused while paused or locked', () => {
    const s = new Sim();
    s.run(60).perform('togglePause').perform('startBreak');
    expect(s.c.phase).toBe('working');
    s.perform('togglePause').activity('locked').perform('startBreak');
    expect(s.c.phase).toBe('working');
    s.activity('active').perform('startBreak');
    expect(s.c.phase).toBe('onBreak');
  });

  it('reset clears the interval, cycle, pause and meeting but keeps today', () => {
    const s = new Sim({ work: 60, shortBreak: 30 });
    s.run(60).perform('startBreak').run(30).run(30);
    s.perform('togglePause'); s.op((x) => x.setMeeting(s.t, true, 15));
    s.perform('reset');
    expect(s.c).toMatchObject({ activeWork: 0, completedShorts: 0, paused: false, meeting: false, meetingDeadline: null, phase: 'working' });
    expect(s.c.today.breaks).toBe(1);
  });
});

describe('pause', () => {
  it('freezes the countdown and resumes without losing or adding time', () => {
    const s = new Sim({ work: 600 });
    s.run(100);
    s.perform('togglePause');
    expect(s.view.status).toBe('paused');
    expect(s.view.countdownRate).toBe(0);
    s.run(3600).jump(10_000).sample();
    expect(s.c.activeWork).toBeCloseTo(100);
    s.perform('togglePause').run(50);
    expect(s.c.activeWork).toBeCloseTo(150);
  });

  it('repeated rapid pause/resume never drifts', () => {
    const s = new Sim();
    for (let i = 0; i < 50; i++) { s.perform('togglePause'); s.perform('togglePause'); }
    expect(s.c.activeWork).toBe(0);
    s.run(10, 1);
    expect(s.c.activeWork).toBeCloseTo(10);
  });

  it('pauses a break and its exercise cursor', () => {
    const s = new Sim({ shortBreak: 120 });
    s.perform('startBreak').run(40, 1).perform('togglePause').run(600);
    expect(s.c.breakRemaining).toBeCloseTo(80);
    expect(s.c.exercise).toEqual({ index: 1, elapsed: expect.closeTo(10) });
  });

  it('suppresses the reminder while paused but keeps the episode identity', () => {
    const s = new Sim({ work: 60 });
    s.run(60);
    const id = s.c.dueId;
    s.perform('togglePause');
    expect(s.view.reminderId).toBeNull();
    s.perform('togglePause');
    expect(s.view.reminderId).toBe(id);
  });
});

describe('meeting mode (DECISIONS 028)', () => {
  it('keeps the timer running and becomes due on schedule, but withholds the reminder', () => {
    const s = new Sim({ work: 120 });
    s.op((x) => x.setMeeting(s.t, true));
    s.run(120);
    expect(s.c.phase).toBe('due');
    expect(s.view.status).toBe('meeting');
    expect(s.view.reminderId).toBeNull();
    expect(s.view.breakDueActionable).toBe(true);
    s.op((x) => x.setMeeting(s.t, false));
    expect(s.view.reminderId).toBe(s.c.dueId);
  });

  it('expires a timed meeting at its deadline without touching progress or pause', () => {
    const s = new Sim();
    s.op((x) => x.setMeeting(s.t, true, 15));
    s.perform('togglePause');
    s.run(15 * 60);
    expect(s.c.meeting).toBe(false);
    expect(s.c.paused).toBe(true);
  });

  it('rejects unsupported durations and cancels on a large backward clock jump', () => {
    const s = new Sim();
    s.op((x) => x.setMeeting(s.t, true, 45));
    expect(s.c.meeting).toBe(false);
    s.op((x) => x.setMeeting(s.t, true, 60));
    s.jump(-7200).sample();
    expect(s.c.meeting).toBe(false);
  });

  it('toggling meeting does not drop unconfirmed credit or rebaseline', () => {
    const s = new Sim();
    s.run(30);
    s.op((x) => x.setMeeting(s.t, true));
    s.op((x) => x.setMeeting(s.t, false));
    s.run(30);
    expect(s.c.activeWork).toBeCloseTo(60);
  });

  it('a running break outranks meeting and completes silently-eligible', () => {
    const s = new Sim({ shortBreak: 30, breakEndSound: true });
    s.perform('startBreak');
    s.op((x) => x.setMeeting(s.t, true));
    expect(s.view.status).toBe('onBreak');
    s.run(30, 10);
    expect(s.c.today.breaks).toBe(1);
  });
});

describe('natural break (DECISIONS 018)', () => {
  it('restarts the interval after the effective threshold of verified away time and notifies on return', () => {
    const s = new Sim({ naturalBreak: 600, afk: 90 });
    s.run(900);
    s.activity('idle'); // away since 90 s ago
    s.run(509);
    expect(s.c.activeWork).toBeGreaterThan(0);
    s.run(1);
    expect(s.c.activeWork).toBe(0);
    expect(s.take().some((e) => e.type === 'naturalBreak')).toBe(false); // only on return
    s.run(600);
    s.activity('active');
    expect(s.take().filter((e) => e.type === 'naturalBreak')).toHaveLength(1);
    expect(s.c.today.activeSeconds).toBeCloseTo(810); // totals untouched
  });

  it('withdraws a pending due reminder and never counts as a completed break', () => {
    const s = new Sim({ work: 60, naturalBreak: 300 });
    s.run(120);
    expect(s.c.phase).toBe('due');
    s.activity('idle').run(600);
    expect(s.c.phase).toBe('working');
    expect(s.c.dueId).toBeNull();
    expect(s.c.today.breaks).toBe(0);
  });

  it('counts locked time as away time even across a long gap', () => {
    const s = new Sim({ naturalBreak: 600 });
    s.run(300).activity('locked').jump(3600).sample();
    expect(s.c.activeWork).toBe(0);
  });

  it('an unknown gap while unlocked-idle taints the chain', () => {
    const s = new Sim({ naturalBreak: 300, afk: 90 });
    s.run(300).activity('idle').jump(GAP_LIMIT + 1).sample().run(600);
    expect(s.c.activeWork).toBeGreaterThan(0);
  });

  it('off means never', () => {
    const s = new Sim({ naturalBreak: 0 });
    s.run(300).activity('idle').run(7200);
    expect(s.c.activeWork).toBeGreaterThan(0);
  });

  it('the effective threshold is at least AFK + 60 s', () => {
    const s = new Sim({ naturalBreak: 300, afk: 600 });
    s.run(900).activity('idle'); // away 600
    s.run(59);
    expect(s.c.activeWork).toBeGreaterThan(0);
    s.run(1);
    expect(s.c.activeWork).toBe(0);
  });

  it('pause and breaks do not accrue away time', () => {
    const s = new Sim({ naturalBreak: 300 });
    s.run(300).perform('togglePause').activity('idle').run(3600);
    expect(s.c.activeWork).toBeCloseTo(300);
  });

  it('a restart starts with a tainted chain', () => {
    const s = new Sim({ naturalBreak: 300, afk: 90 });
    s.run(600).activity('idle');
    s.op((x) => x.restart(s.t, 'idle'));
    s.run(3600);
    expect(s.c.activeWork).toBeGreaterThan(0);
  });
});

describe('working hours (DECISIONS 019/025)', () => {
  const hours = { enabled: true, weekdays: [2, 3, 4, 5, 6], start: 9 * 60, end: 17 * 60 };

  it('credits nothing and sends no reminder off hours', () => {
    const evening = new Date(2026, 10, 23, 17, 30).getTime() / 1000;
    const s = new Sim({ workingHours: hours, work: 60 }, evening);
    s.run(600);
    expect(s.view.status).toBe('offHours');
    expect(s.c.activeWork).toBe(0);
    expect(s.c.phase).toBe('working');
  });

  it('leaving the window discards the crossing sample and preserves the phase', () => {
    const s = new Sim({ workingHours: hours, work: 60 }, new Date(2026, 10, 23, 16, 58).getTime() / 1000);
    s.run(120);
    expect(s.c.phase).toBe('due');
    expect(s.view.reminderId).toBeNull();
    expect(s.view.status).toBe('offHours');
  });

  it('entering the window starts a fresh interval (Friday Due, Monday entry)', () => {
    const friday = new Date(2026, 10, 27, 16, 58).getTime() / 1000;
    const s = new Sim({ workingHours: hours, work: 60 }, friday);
    s.run(120);
    const old = s.c.dueId;
    s.jump(new Date(2026, 10, 30, 9, 0, 30).getTime() / 1000 - s.t).sample();
    expect(s.c.phase).toBe('working');
    expect(s.c.activeWork).toBe(0);
    s.run(60);
    expect(s.c.dueId).not.toBe(old);
  });

  it('a running break is never interrupted by the window', () => {
    const s = new Sim({ workingHours: hours, shortBreak: 300 }, new Date(2026, 10, 23, 16, 58).getTime() / 1000);
    s.perform('startBreak').run(300, 30);
    expect(s.c.today.breaks).toBe(1);
  });

  it('editing hours in settings never restarts the interval', () => {
    const s = new Sim({ work: 2700 });
    s.run(600);
    s.op((x) => x.updateSettings(s.t, { ...s.settings, workingHours: { ...hours, enabled: true, start: 0, end: 1 } }));
    expect(s.c.activeWork).toBeCloseTo(600);
  });
});

describe('settings changes', () => {
  it('changing work duration retargets the interval and can make it due', () => {
    const s = new Sim({ work: 2700 });
    s.run(600);
    s.op((x) => x.updateSettings(s.t, { ...s.settings, work: 300 }));
    expect(s.c.phase).toBe('due');
    s.op((x) => x.updateSettings(s.t, { ...s.settings, work: 3600 }));
    expect(s.c.phase).toBe('working');
  });

  it('never changes the duration of the current break or a snooze target', () => {
    const s = new Sim({ work: 60, shortBreak: 120 });
    s.run(60).perform('snooze');
    const target = s.c.target;
    s.op((x) => x.updateSettings(s.t, { ...s.settings, work: 1200 }));
    expect(s.c.target).toBe(target);
    s.run(600).perform('startBreak');
    s.op((x) => x.updateSettings(s.t, { ...s.settings, shortBreak: 30 }));
    expect(s.c.breakDuration).toBe(120);
  });
});

describe('scheduling', () => {
  it('wakes at the due boundary, the next badge minute, and never later than the heartbeat', () => {
    const s = new Sim({ work: 100 });
    s.run(10, 10);
    expect(s.view.nextWake(s.t) - s.t).toBeCloseTo(30); // 90 s left -> minute 2 -> 1 at 60 s
    s.run(40, 40);
    expect(s.view.nextWake(s.t) - s.t).toBeCloseTo(50);
    s.perform('togglePause');
    expect(s.view.nextWake(s.t) - s.t).toBe(HEARTBEAT);
  });

  it('wakes at a meeting deadline and at the natural-break threshold', () => {
    const s = new Sim({ naturalBreak: 600 });
    s.op((x) => x.setMeeting(s.t, true, 15));
    s.perform('togglePause');
    expect(s.view.nextWake(s.t)).toBeLessThanOrEqual(s.t + HEARTBEAT);
    const t = new Sim({ naturalBreak: 600 });
    t.run(300).activity('idle');
    expect(t.view.nextWake(t.t) - t.t).toBeCloseTo(60);
  });
});

describe('persistence', () => {
  it('round-trips through JSON and restores a break with its cursor', () => {
    const s = new Sim({ shortBreak: 120 });
    s.perform('startBreak').run(45, 5);
    const restored = restoreState(JSON.parse(JSON.stringify(s.state)), s.settings, s.t);
    expect(restored).toEqual(s.state);
  });

  it('falls back to a fresh session for corrupted checkpoints', () => {
    const settings = defaultSettings();
    for (const bad of [null, 42, 'x', {}, { checkpoint: { activeWork: -1 } }, { checkpoint: { ...initialState(settings, T0).checkpoint, phase: 'nope' } }]) {
      const r = restoreState(bad, settings, T0);
      expect(r.checkpoint.activeWork).toBe(0);
      expect(r.checkpoint.phase).toBe('working');
    }
  });

  it('repairs malformed optional fields without discarding the session', () => {
    const s = new Sim();
    s.run(300);
    const raw = JSON.parse(JSON.stringify(s.state));
    raw.checkpoint.exerciseRotation = 'many';
    raw.checkpoint.meetingDeadline = 'soon';
    raw.checkpoint.meeting = true;
    raw.runtime = 'garbage';
    const r = restoreState(raw, s.settings, s.t);
    expect(r.checkpoint.activeWork).toBeCloseTo(300);
    expect(r.checkpoint.exerciseRotation).toBe(0);
    expect(r.checkpoint.meeting).toBe(false);
    expect(r.runtime.lastSampleAt).toBeNull();
  });

  it('a service-worker restart (state reload) loses nothing; a browser restart credits nothing offline', () => {
    const s = new Sim();
    s.run(300);
    s.state = restoreState(JSON.parse(JSON.stringify(s.state)), s.settings, s.t);
    s.run(60);
    expect(s.c.activeWork).toBeCloseTo(360);
    s.jump(3600);
    s.op((x) => x.restart(s.t, 'active'));
    s.run(60);
    expect(s.c.activeWork).toBeCloseTo(420);
  });

  it('a due episode survives a restart with the same identity', () => {
    const s = new Sim({ work: 60 });
    s.run(60);
    const id = s.c.dueId;
    s.jump(600);
    s.op((x) => x.restart(s.t, 'active'));
    expect(s.c.dueId).toBe(id);
  });
});

describe('status priority', () => {
  it('suspended > paused > onBreak > meeting > offHours > due > idle/working', () => {
    const s = new Sim({ work: 60 });
    expect(s.view.status).toBe('working');
    s.run(60);
    expect(s.view.status).toBe('due');
    s.op((x) => x.setMeeting(s.t, true));
    expect(s.view.status).toBe('meeting');
    s.perform('startBreak');
    expect(s.view.status).toBe('onBreak');
    s.perform('togglePause');
    expect(s.view.status).toBe('paused');
    s.activity('locked');
    expect(s.view.status).toBe('suspended');
  });

  it('exposes a ring fraction that starts full and depletes to zero', () => {
    const s = new Sim({ work: 600 });
    expect(s.view.remainingFraction).toBe(1);
    s.run(150);
    expect(s.view.remainingFraction).toBeCloseTo(0.75);
    s.run(450);
    expect(s.view.remainingFraction).toBe(0);
    const sched = new Scheduler(s.state, s.settings, () => 'x');
    expect(sched.countdownRate).toBe(0);
  });
});
