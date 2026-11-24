// Port of BreakExerciseView.swift. Rendered inside the popup during a break; closing the popup never finishes it.
import { useEffect } from 'react';
import { advanceCursor, displayRemaining } from '../../core/exercises';
import type { Snapshot } from '../../core/model';
import { clockText } from '../../core/presentation';
import type { T } from '../../i18n';
import type { Intent } from '../../background/messages';
import { ExerciseAnimation } from './ExerciseAnimation';

export function ExerciseView({ snap, breakElapsed, t, send }: {
  snap: Snapshot; breakElapsed: number; t: T; send: (i: Intent) => void;
}) {
  const ex = snap.exercise!;
  const remaining = Math.max(0, snap.remaining - breakElapsed);
  const cursor = advanceCursor(ex.list, ex.cursor, Math.min(breakElapsed, snap.remaining));
  const current = ex.list[cursor.index];
  const last = cursor.index === ex.list.length - 1;
  const moveLeft = displayRemaining(ex.list, cursor, remaining);
  const progress = Math.min(1, Math.max(0, 1 - remaining / ex.breakDuration));

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement | null;
      if (e.defaultPrevented || e.metaKey || e.ctrlKey || e.altKey || target?.closest('input, select, textarea, [role="menu"], [role="dialog"]')) return;
      if (e.key === 'ArrowLeft') { e.preventDefault(); send({ type: 'navigate', offset: -1 }); }
      else if (e.key === 'ArrowRight') { e.preventDefault(); send({ type: 'navigate', offset: 1 }); }
      else if (e.key === ' ' && target?.tagName !== 'BUTTON') { e.preventDefault(); send({ type: 'action', action: 'togglePause' }); }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [send]);

  return (
    <section className="exercise" aria-label={t('status.onBreak')} data-testid="exercise">
      <div className="title-row">
        <span className="name" data-testid="exercise-name">{t(`exercise.${current.id}`)}</span>
        <span className="secondary mono">{cursor.index + 1} / {ex.list.length}</span>
      </div>
      <ExerciseAnimation key={`${current.id}-${cursor.index}`} movement={current.id} time={cursor.elapsed} duration={current.duration} t={t} />
      <p className="instruction">{t(`exercise.${current.id}.instruction`)}</p>
      <div className="move-time" role="timer" aria-label={`${t('exercise.remaining')}: ${clockText(moveLeft)}`}>
        <span aria-hidden="true">{clockText(moveLeft)}</span>
      </div>
      <div className="progress" role="progressbar" aria-label={t('exercise.progress')}
        aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(progress * 100)}>
        <div style={{ width: `${progress * 100}%` }} />
      </div>
      <div className="nav">
        <button className="btn" disabled={cursor.index === 0} onClick={() => send({ type: 'navigate', offset: -1 })} aria-keyshortcuts="ArrowLeft">{t('exercise.previous')}</button>
        <button className="btn" onClick={() => send({ type: 'action', action: 'togglePause' })} aria-keyshortcuts="Space" data-testid="exercise-pause">
          {t(snap.paused ? 'resume' : 'pause')}
        </button>
        <button className="btn" disabled={last} onClick={() => send({ type: 'navigate', offset: 1 })} aria-keyshortcuts="ArrowRight">{t('exercise.next')}</button>
      </div>
      <div className="ends">
        <button className="btn borderless" onClick={() => send(last ? { type: 'action', action: 'skip' } : { type: 'navigate', offset: 1 })}>{t('exercise.skip')}</button>
        <button className="btn borderless" onClick={() => send({ type: 'action', action: 'skip' })} data-testid="finish-break">{t('break.end')}</button>
      </div>
      <p className="safety">{t('exercise.safety')}</p>
    </section>
  );
}
