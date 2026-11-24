// Port of OnboardingView.swift: two short steps inside the panel, no window. Chrome grants the notifications
// permission at install time, so step 2 explains the state instead of requesting a permission.
import { useState } from 'react';
import type { Snapshot } from '../../core/model';
import type { T } from '../../i18n';
import type { Intent } from '../../background/messages';
import { CheckIcon, PuzzleIcon, ShieldIcon, TimerIcon, WarningIcon } from './Icons';

export function Onboarding({ snap, t, send }: { snap: Snapshot; t: T; send: (i: Intent) => void }) {
  const [step, setStep] = useState(0);
  return (
    <section className="card onboarding" aria-labelledby="onboarding-title" data-testid="onboarding">
      {step === 0 ? (
        <>
          <h2 id="onboarding-title">{t('ui.onboarding.title')}</h2>
          <div className="item"><PuzzleIcon /><span>{t('ui.onboarding.menubar')}</span></div>
          <div className="item"><TimerIcon /><span>{t('ui.onboarding.timing')}</span></div>
          <div className="item"><ShieldIcon /><span>{t('ui.onboarding.local')}</span></div>
          <div className="actions"><button className="btn prominent" onClick={() => setStep(1)}>{t('ui.onboarding.next')}</button></div>
        </>
      ) : (
        <>
          <h2 id="onboarding-title">{t('ui.onboarding.notif.title')}</h2>
          <span className="secondary">{t('ui.onboarding.notif.body')}</span>
          {snap.notification.permission === 'granted'
            ? <div className="item caption secondary"><CheckIcon /><span>{t('ui.onboarding.notif.done')}</span></div>
            : <div className="item caption"><WarningIcon /><span>{t('permission.denied')}</span></div>}
          <span className="caption secondary">{t('ext.notif.osHint')}</span>
          <div className="actions">
            <button className="btn prominent" onClick={() => send({ type: 'prefs', patch: { onboarded: true } })}>{t('welcome.done')}</button>
          </div>
        </>
      )}
    </section>
  );
}
