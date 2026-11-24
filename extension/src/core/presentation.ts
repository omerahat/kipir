// Ports of the presentation helpers in Kipir/Core/QualityOfLife.swift, adapted to Chrome surfaces.
import type { WorkStatus } from './engine';

/** Whole minutes rounded up, as in the native menu bar label. */
export function ceilMinutes(seconds: number): number {
  return Number.isFinite(seconds) ? Math.ceil(Math.max(0, seconds) / 60) : 0;
}

/** "mm:ss" with the remaining seconds rounded up (native `durationText`). */
export function clockText(seconds: number): string {
  const v = Math.max(0, Math.ceil(Number.isFinite(seconds) ? seconds - 1e-6 : 0));
  return `${String(Math.floor(v / 60)).padStart(2, '0')}:${String(v % 60).padStart(2, '0')}`;
}

export interface BadgeView {
  text: string;
  color: string;
  /** Key of the localized state shown in the tooltip. */
  statusKey: string;
}

/** Badge colors carry the state the native menu bar icon used to carry; text never depends on state alone, so the
 * tooltip always has the full summary. */
export const BADGE_COLORS: Record<WorkStatus, string> = {
  working: '#1F8FA3',
  idle: '#6B7480',
  paused: '#6B7480',
  meeting: '#5856D6',
  due: '#E07A2E',
  onBreak: '#2E9E6B',
  suspended: '#6B7480',
  offHours: '#6B7480',
};

/** Toolbar badge. Native: the visible text is always the remaining minutes, or "Break" once a break is due; the
 * icon-only style hides the minutes. A pause shows "II" because the badge cannot show a second symbol. */
export function badgeView(opts: { status: WorkStatus; remaining: number; breakDue: boolean; iconOnly: boolean; dueText: string }): BadgeView {
  const { status, remaining, breakDue, iconOnly } = opts;
  const showsDue = status === 'due' || (breakDue && status !== 'onBreak');
  let text: string;
  if (status === 'paused') text = 'II';
  else if (showsDue) text = opts.dueText;
  else if (iconOnly) text = '';
  else text = String(ceilMinutes(remaining));
  return { text, color: BADGE_COLORS[status], statusKey: 'status.' + status };
}

/** Which one-line state explanation the popup shows (native `PopoverStatusNote`). On the countdown screen it sits
 * below the primary controls; pause, break and meeting need none there. */
export function statusNoteKey(status: WorkStatus, onBreakScreen: boolean): string | null {
  if (status === 'working') return null;
  if (onBreakScreen) return 'ui.status.note.' + status;
  return status === 'paused' || status === 'onBreak' || status === 'meeting' ? null : 'ui.status.note.' + status;
}

// MARK: Transient notice

export type NoticeKind = { type: 'breakCompleted'; today: number } | { type: 'naturalBreak' };

/** Short-lived message under the timer. Pending (unseen) for up to 15 minutes so a popup opened later still shows
 * it, then visible for 6 s from the moment a popup displayed it. Wall-clock seconds. */
export interface Notice { kind: NoticeKind; postedAt: number; displayedAt: number | null }
export const NOTICE_LIFETIME = 6;
export const NOTICE_PENDING_LIFETIME = 15 * 60;

export function noticeVisible(n: Notice | null, now: number): boolean {
  if (!n || !Number.isFinite(now)) return false;
  if (n.displayedAt !== null) return now >= n.displayedAt - 1 && now < n.displayedAt + NOTICE_LIFETIME;
  return now >= n.postedAt - 1 && now < n.postedAt + NOTICE_PENDING_LIFETIME;
}
export function markNoticeDisplayed(n: Notice | null, now: number): Notice | null {
  if (!n || !noticeVisible(n, now)) return null;
  return n.displayedAt !== null ? n : { ...n, displayedAt: now };
}
export function nextNotice(current: Notice | null, events: { completed: number | null; naturalBreak: boolean }, now: number): Notice | null {
  if (events.completed !== null) return { kind: { type: 'breakCompleted', today: Math.max(0, events.completed) }, postedAt: now, displayedAt: null };
  if (events.naturalBreak) return { kind: { type: 'naturalBreak' }, postedAt: now, displayedAt: null };
  return noticeVisible(current, now) ? current : null;
}
export const noticeTextKey = (n: Notice) => (n.kind.type === 'breakCompleted' ? 'ui.notice.breakCompleted' : 'ui.notice.naturalBreak');

// MARK: Notifications

/** Chrome exposes only the extension-level permission ("granted" or "denied"); OS-level presentation (macOS
 * Notifications settings, Focus) cannot be read, so "active" never claims a banner was shown. */
export type NotificationPermission = 'granted' | 'denied' | 'unknown';
export type NotificationEffectiveState = 'off' | 'denied' | 'active' | 'needsPermission';

export function notificationState(enabled: boolean, permission: NotificationPermission): NotificationEffectiveState {
  if (!enabled) return 'off';
  if (permission === 'denied') return 'denied';
  if (permission === 'unknown') return 'needsPermission';
  return 'active';
}

export interface NotifyBook {
  /** The last due episode a reminder was attempted (or suppressed) for. Persisted: at most one attempt per episode. */
  lastAttempted: string | null;
  /** The reminder currently believed visible. */
  visible: string | null;
}

export type NotifyPlan = { clear: string | null; create: string | null; book: NotifyBook };

/** One synchronization step (native `NotificationManager.sync`). Meeting mode consumes the current episode so ending
 * the meeting never replays it; leaving the deliverable state withdraws the visible reminder. */
export function planNotifications(opts: {
  book: NotifyBook; enabled: boolean; permitted: boolean; meeting: boolean; dueId: string | null; reminderId: string | null;
}): NotifyPlan {
  let { lastAttempted, visible } = opts.book;
  if (opts.meeting && opts.dueId) lastAttempted = opts.dueId;
  let clear: string | null = null;
  if (visible && (visible !== opts.reminderId || !opts.enabled)) { clear = visible; visible = null; }
  let create: string | null = null;
  if (opts.enabled && opts.permitted && opts.reminderId && opts.reminderId !== lastAttempted) {
    create = opts.reminderId; lastAttempted = create; visible = create;
  }
  return { clear, create, book: { lastAttempted, visible } };
}

// MARK: Language

export type LanguagePreference = 'system' | 'tr' | 'en';
export function resolveLanguage(pref: unknown, preferred: readonly string[]): 'tr' | 'en' {
  if (pref === 'tr' || pref === 'en') return pref;
  for (const id of preferred) {
    const code = id.toLowerCase().split(/[-_]/)[0];
    if (code === 'tr' || code === 'en') return code;
  }
  return 'en';
}
