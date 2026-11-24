// Port of MenuBarView.swift: the main panel. Layout rules from DECISIONS 031: nothing above the Pause/Resume row
// changes size with state, state notes and meeting details only appear below their controls, and both action buttons
// share the row equally so they keep constant frames whatever their label says.
import { useEffect, useRef, useState } from 'react';
import { project, type Snapshot } from '../../core/model';
import { ceilMinutes, clockText, noticeTextKey, statusNoteKey } from '../../core/presentation';
import { MEETING_DURATIONS } from '../../core/settings';
import type { Intent } from '../../background/messages';
import type { T } from '../../i18n';
import { CountdownRing } from '../components/CountdownRing';
import { ExerciseView } from '../components/ExerciseView';
import { CheckIcon, ClockIcon, EllipsisIcon, GearIcon, PauseIcon, PeopleIcon, PlayIcon, RestartIcon, WalkIcon } from '../components/Icons';
import { MenuButton } from '../components/Menu';
import { Onboarding } from '../components/Onboarding';
import { Switch } from '../components/Switch';
import { useElapsed } from '../useKipir';

const reducedMotion = () => typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches;

export function Popup({ snap, receivedAt, t, send, surface }: {
  snap: Snapshot; receivedAt: number; t: T; send: (i: Intent) => void; surface: 'popup' | 'window';
}) {
  const onBreak = snap.phase === 'onBreak' && snap.exercise !== null;
  const running = snap.countdownRate === 1 || snap.workRate === 1;
  const elapsed = useElapsed(receivedAt, running, onBreak ? 30 : 4);
  const p = project(snap, elapsed);
  const [confirmReset, setConfirmReset] = useState(false);

  // Reaching a projected boundary asks the background to reconcile (it stays the authority).
  const asked = useRef(0);
  useEffect(() => {
    if (p.boundaryReached && asked.current !== receivedAt) { asked.current = receivedAt; send({ type: 'sync' }); }
  }, [p.boundaryReached, receivedAt, send]);

  // A notice's visible lifetime starts when a panel actually shows it.
  const noticeId = snap.notice?.postedAt;
  const noticeShown = snap.notice?.displayedAt != null;
  useEffect(() => { if (noticeId !== undefined && !noticeShown) send({ type: 'noticeDisplayed' }); }, [noticeId, noticeShown, send]);

  const note = statusNoteKey(snap.status, onBreak);
  const statusText = t('status.' + snap.status);

  return (
    <main className={`panel ${surface === 'window' ? 'window' : ''}`} data-phase={snap.phase} data-status={snap.status}>
      <header className="header">
        <span className="brand-icon"><WalkIcon /></span>
        <span className="brand">{t('app.name')}</span>
        <span className="spacer" />
        <span className="capsule" data-testid="status">{statusText}</span>
      </header>

      {!snap.prefs.onboarded && <Onboarding snap={snap} t={t} send={send} />}

      {onBreak ? (
        <>
          {note && <p className="note" data-testid="status-note">{t(note)}</p>}
          <ExerciseView snap={snap} breakElapsed={p.breakElapsed} t={t} send={send} />
        </>
      ) : (
        <>
          <div role="timer" aria-label={`${t('timer.untilBreak')}: ${clockText(p.remaining)}`} data-testid="countdown">
            <CountdownRing fraction={p.fraction} smooth={!reducedMotion()}>
              <span className="ring-time" aria-hidden="true" data-testid="remaining">{clockText(p.remaining)}</span>
              <span className="caption secondary" aria-hidden="true">{t('timer.untilBreak')}</span>
            </CountdownRing>
          </div>
          <div className="summary">
            <span className="lead">{t(snap.nextBreakIsLong ? 'next.long' : 'next.short')}</span>
            <span className="caption secondary mono">{t('timer.confirmed')} {clockText(p.activeWork)}</span>
          </div>
          <div className="row" data-testid="primary-row">
            <button className="btn large fill" onClick={() => send({ type: 'action', action: 'togglePause' })} data-testid="pause">
              {snap.paused ? <PlayIcon /> : <PauseIcon />}{t(snap.paused ? 'resume' : 'pause')}
            </button>
            <button className={`btn large fill ${snap.breakDueActionable ? 'prominent' : ''}`} data-testid="start-break"
              disabled={!snap.breakDueActionable && (snap.paused || snap.locked)}
              onClick={() => send({ type: 'action', action: 'startBreak' })}>
              {t('break.start')}
            </button>
          </div>
          {snap.breakDueActionable && (
            <div className="due-row">
              <button className="btn" onClick={() => send({ type: 'action', action: 'snooze' })} data-testid="snooze">{t('snooze')}</button>
              <button className="btn" onClick={() => send({ type: 'action', action: 'skip' })} data-testid="skip">{t('skip')}</button>
            </div>
          )}
          {snap.notice && (
            <div className="notice" role="status" data-testid="notice">
              {snap.notice.kind.type === 'breakCompleted' ? <CheckIcon /> : <RestartIcon />}
              <span>{snap.notice.kind.type === 'breakCompleted' ? t(noticeTextKey(snap.notice), snap.notice.kind.today) : t(noticeTextKey(snap.notice))}</span>
            </div>
          )}
          {note && <p className="note" data-testid="status-note">{t(note)}</p>}
          <div className="card today">
            <div>
              <div className="label">{t('today.title')}</div>
              <div className="big">{clockText(p.todayActive)}</div>
              <div className="caption2 secondary">{t('today.active')}</div>
            </div>
            <div>
              <div className="count" data-testid="today-breaks">{snap.today.breaks}</div>
              <div className="caption2 secondary">{t('today.breaks')}</div>
            </div>
          </div>
        </>
      )}

      <div className="meeting-row" data-testid="meeting-row">
        <label>
          <span className="brand-icon"><PeopleIcon /></span>
          <span style={{ flex: 1 }}>{t('meeting')}</span>
          <Switch checked={snap.meeting} testId="meeting-toggle" onChange={(enabled) => send({ type: 'meeting', enabled })} />
        </label>
        <MenuButton label={t('meeting.duration')} icon={<ClockIcon />} testId="meeting-duration"
          items={[
            ...MEETING_DURATIONS.map((m) => ({ label: t('menubar.minutes', m), testId: `meeting-${m}`, onSelect: () => send({ type: 'meeting', enabled: true, minutes: m }) })),
            { label: t('meeting.indefinite'), onSelect: () => send({ type: 'meeting', enabled: true }) },
          ]} />
      </div>
      {snap.meeting && (
        <div className="meeting-extra" data-testid="meeting-extra">
          <span className="caption secondary">{t('ui.status.note.meeting')}</span>
          <div className="line">
            <span>{snap.meetingRemaining !== null ? t('meeting.remaining', ceilMinutes(snap.meetingRemaining - elapsed)) : t('meeting.indefinite')}</span>
            <button className="btn small" onClick={() => send({ type: 'meeting', enabled: false })}>{t('meeting.end')}</button>
          </div>
        </div>
      )}

      <div className="divider" />
      <footer className="footer">
        <button className="btn borderless" onClick={() => send({ type: 'openSettings' })} data-testid="open-settings"><GearIcon />{t('settings')}</button>
        <MenuButton label={t('more')} icon={<EllipsisIcon />} testId="more"
          items={[{ label: t('session.reset'), testId: 'reset', onSelect: () => setConfirmReset(true) }]} />
      </footer>

      {confirmReset && (
        <div className="scrim" onKeyDown={(e) => { if (e.key === 'Escape') setConfirmReset(false); }}>
          <div className="dialog" role="alertdialog" aria-modal="true" aria-labelledby="reset-title" aria-describedby="reset-body">
            <h2 id="reset-title">{t('session.reset')}</h2>
            <p id="reset-body">{t('session.resetMessage')}</p>
            <div className="row">
              <button className="btn" autoFocus onClick={() => setConfirmReset(false)}>{t('cancel')}</button>
              <button className="btn destructive" data-testid="confirm-reset" onClick={() => { setConfirmReset(false); send({ type: 'action', action: 'reset' }); }}>{t('ext.reset.confirm')}</button>
            </div>
          </div>
        </div>
      )}
    </main>
  );
}
