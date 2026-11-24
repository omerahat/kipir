// Deterministic harness: a fake wall clock, an id counter and an in-memory engine state, persisted between steps the
// same way the controller does it (state value in, state value out).
import { initialState, Scheduler, type Activity, type EngineEvent, type EngineState, type SchedulerAction } from '../../src/core/engine';
import { defaultSettings, type Settings } from '../../src/core/settings';

export const T0 = new Date(2026, 10, 23, 10, 0, 0).getTime() / 1000; // Monday 10:00 local

export class Sim {
  t: number;
  state: EngineState;
  settings: Settings;
  events: EngineEvent[] = [];
  private ids = 0;

  constructor(patch: Partial<Settings> = {}, start = T0) {
    this.t = start;
    this.settings = { ...defaultSettings(), ...patch };
    this.state = initialState(this.settings, this.t);
    this.op((s) => s.restart(this.t, 'active'));
  }

  op(fn: (s: Scheduler) => void): Scheduler {
    const s = new Scheduler(this.state, this.settings, () => `id-${++this.ids}`);
    fn(s);
    this.state = s.state;
    this.settings = s.settings;
    this.events.push(...s.events);
    return s;
  }
  get view() { return new Scheduler(this.state, this.settings, () => 'x'); }
  get c() { return this.state.checkpoint; }

  /** Advances the clock with samples at most `step` seconds apart (the heartbeat alarm). */
  run(seconds: number, step = 60) {
    const end = this.t + seconds;
    while (this.t < end - 1e-9) {
      this.t = Math.min(end, this.t + step);
      this.op((s) => s.sample(this.t));
    }
    return this;
  }
  /** Jumps the clock without any sample in between (sleep, closed browser, delayed alarm). */
  jump(seconds: number) { this.t += seconds; return this; }
  sample() { this.op((s) => s.sample(this.t)); return this; }
  activity(a: Activity) { this.op((s) => s.observeActivity(this.t, a)); return this; }
  perform(a: SchedulerAction) { this.op((s) => s.perform(this.t, a)); return this; }
  take() { const e = this.events; this.events = []; return e; }
}
