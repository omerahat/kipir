// Messages between extension views and the background. Views send intents; the background answers with a fresh
// snapshot and pushes snapshots to every connected view after each committed change.
import type { SchedulerAction } from '../core/engine';
import type { Snapshot, Prefs } from '../core/model';
import type { Settings } from '../core/settings';

export const PORT_NAME = 'kipir-view';

export type Intent =
  | { type: 'sync' }
  | { type: 'action'; action: SchedulerAction }
  | { type: 'meeting'; enabled: boolean; minutes?: number }
  | { type: 'navigate'; offset: number }
  | { type: 'settings'; patch: Partial<Settings> }
  | { type: 'prefs'; patch: Partial<Prefs> }
  | { type: 'noticeDisplayed' }
  | { type: 'openSettings' }
  | { type: 'testNotification' };

export interface IntentResult { snapshot: Snapshot; testResult?: string | null }

export type PortMessage = { type: 'snapshot'; snapshot: Snapshot };

const ACTIONS: readonly SchedulerAction[] = ['startBreak', 'snooze', 'skip', 'togglePause', 'toggleMeeting', 'reset'];

/** Runtime validation: messages are untrusted input even from our own pages. */
export function parseIntent(raw: unknown): Intent | null {
  if (typeof raw !== 'object' || raw === null) return null;
  const m = raw as Record<string, unknown>;
  switch (m.type) {
    case 'sync': case 'noticeDisplayed': case 'openSettings': case 'testNotification': return { type: m.type };
    case 'action': return ACTIONS.includes(m.action as SchedulerAction) ? { type: 'action', action: m.action as SchedulerAction } : null;
    case 'meeting':
      if (typeof m.enabled !== 'boolean') return null;
      if (m.minutes !== undefined && typeof m.minutes !== 'number') return null;
      return { type: 'meeting', enabled: m.enabled, minutes: m.minutes as number | undefined };
    case 'navigate': return m.offset === 1 || m.offset === -1 ? { type: 'navigate', offset: m.offset } : null;
    case 'settings': return typeof m.patch === 'object' && m.patch !== null ? { type: 'settings', patch: m.patch as Partial<Settings> } : null;
    case 'prefs': return typeof m.patch === 'object' && m.patch !== null ? { type: 'prefs', patch: m.patch as Partial<Prefs> } : null;
    default: return null;
  }
}
