// Port of Kipir/Core/Exercises.swift. Deterministic catalog, rotation and playback cursor. Playback owns no clock: it
// only receives break-time deltas that the engine accepted.
import type { ExerciseFocus } from './settings';

export type BodyArea = 'neckShoulders' | 'back' | 'hands' | 'legs' | 'whole';
export type Movement =
  | 'shoulders' | 'chest' | 'wrists' | 'calves' | 'walk'
  | 'neckTilt' | 'shrug' | 'upperBack' | 'twist' | 'fingers' | 'march';

export const MOVEMENTS: readonly Movement[] = [
  'shoulders', 'chest', 'wrists', 'calves', 'walk', 'neckTilt', 'shrug', 'upperBack', 'twist', 'fingers', 'march',
];

export function movementArea(m: Movement): BodyArea {
  switch (m) {
    case 'shoulders': case 'shrug': case 'neckTilt': return 'neckShoulders';
    case 'chest': case 'upperBack': case 'twist': return 'back';
    case 'wrists': case 'fingers': return 'hands';
    case 'calves': case 'march': return 'legs';
    case 'walk': return 'whole';
  }
}

/** Natural length of one visual cycle in seconds. */
export function basePeriod(m: Movement): number {
  if (m === 'walk' || m === 'march') return 2;
  if (m === 'wrists' || m === 'fingers') return 5;
  return 6;
}

export interface ExerciseDefinition { id: Movement; duration: number }

/** Visual loop length that divides `duration` into an even number of equal cycles, so the wrist hand switch lands
 * on a loop boundary. */
export function loopPeriod(duration: number, base: number): number {
  if (!(Number.isFinite(duration) && duration > 0 && Number.isFinite(base) && base > 0)) {
    return Math.max(1, Number.isFinite(base) ? base : 4);
  }
  const pairs = Math.max(1, Math.round(duration / (2 * base)));
  return Math.max(1, duration / (2 * pairs));
}

const focusArea = (f: ExerciseFocus): BodyArea | null => (f === 'all' ? null : f);

export const BY_AREA: readonly { area: BodyArea; items: Movement[] }[] = [
  { area: 'neckShoulders', items: ['shoulders', 'neckTilt', 'shrug'] },
  { area: 'back', items: ['chest', 'upperBack', 'twist'] },
  { area: 'hands', items: ['wrists', 'fingers'] },
  { area: 'legs', items: ['calves', 'march'] },
];
const ROTATING: Movement[] = BY_AREA.flatMap((a) => a.items);

function pick(count: number, focus: ExerciseFocus, turn: number): Movement[] {
  let picked: Movement[] = [];
  const area = focusArea(focus);
  const own = area ? BY_AREA.find((a) => a.area === area)?.items : undefined;
  if (own) {
    const start = turn % own.length;
    picked = [...own.slice(start), ...own.slice(0, start)].slice(0, count);
    if (picked.length === count) return picked;
  }
  const general = BY_AREA.map((a) => a.items.filter((m) => !picked.includes(m)));
  const cursor = general.map(() => 0);
  const areaStart = turn % general.length;
  let step = 0;
  while (picked.length < count) {
    const a = (areaStart + step) % general.length;
    step += 1;
    const items = general[a];
    if (cursor[a] >= items.length) continue;
    picked.push(items[(turn + cursor[a]) % items.length]);
    cursor[a] += 1;
  }
  return picked;
}

/** Deterministic for equal inputs. Durations are positive and sum to `duration`; the last movement absorbs the
 * remainder. Long breaks spend 40% on rotating movements, then a walk for the other 60%. */
export function exerciseSequence(long: boolean, duration: number, focus: ExerciseFocus = 'all', rotation = 0): ExerciseDefinition[] {
  const total = Number.isFinite(duration) && duration > 0 ? duration : 1;
  const walkShare = long ? 0.6 : 0;
  const count = Math.min(ROTATING.length, Math.max(1, Math.round((total * (1 - walkShare)) / 30)));
  const movements = [...pick(count, focus, Math.max(0, rotation - 1)), ...(long ? (['walk'] as Movement[]) : [])];
  const each = (total * (1 - walkShare)) / count;
  let used = 0;
  return movements.map((id, index) => {
    const length = index === movements.length - 1 ? total - used : each;
    used += length;
    return { id, duration: length };
  });
}

/** Persisted playback cursor: index of the current movement and its elapsed seconds. */
export interface ExerciseCursor { index: number; elapsed: number }

export function advanceCursor(list: ExerciseDefinition[], cursor: ExerciseCursor, seconds: number): ExerciseCursor {
  if (!(Number.isFinite(seconds) && seconds > 0) || list.length === 0) return cursor;
  let { index, elapsed } = cursor;
  elapsed += seconds;
  while (elapsed >= list[index].duration && index < list.length - 1) {
    elapsed -= list[index].duration;
    index += 1;
  }
  return { index, elapsed: Math.min(elapsed, list[index].duration) };
}

export function navigateCursor(list: ExerciseDefinition[], cursor: ExerciseCursor, offset: number): ExerciseCursor {
  return { index: Math.min(list.length - 1, Math.max(0, cursor.index + offset)), elapsed: 0 };
}

/** Time shown on the movement countdown. The final movement fills the overall budget; earlier ones never show more
 * than the break itself has left. */
export function displayRemaining(list: ExerciseDefinition[], cursor: ExerciseCursor, breakRemaining: number): number {
  const current = list[cursor.index];
  const remaining = Math.max(0, current.duration - cursor.elapsed);
  if (!Number.isFinite(breakRemaining)) return remaining;
  const budget = Math.max(0, breakRemaining);
  return cursor.index === list.length - 1 ? budget : Math.min(remaining, budget);
}

/** Weight of the end pose (0 = start pose, 1 = end pose) at a loop position: each pose is held for most of its half
 * of the loop with a short eased crossfade. */
export function poseBlend(phase: number, fade = 0.12): number {
  if (!Number.isFinite(phase)) return 0;
  const f = phase - Math.floor(phase);
  const w = Math.min(Math.max(fade, 0.001), 0.5);
  const ease = (x: number) => { const t = Math.min(Math.max(x, 0), 1); return t * t * (3 - 2 * t); };
  if (f < 0.5 - w) return 0;
  if (f < 0.5) return ease((f - (0.5 - w)) / w);
  if (f < 1 - w) return 1;
  return 1 - ease((f - (1 - w)) / w);
}
