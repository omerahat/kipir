// Port of SettingsView.swift. Same sections, controls, ranges and derived preset selector. "Launch at login" has no
// extension equivalent (Kıpır runs whenever Chrome runs) and is replaced by an explanation of that limit.
import { useState, type ReactNode } from 'react';
import type { Snapshot } from '../../core/model';
import type { Intent } from '../../background/messages';
import {
  applyPreset, crossesMidnight, durationLabel, effectiveNaturalBreakMinutes, LONG_BREAK_OPTIONS, matchPreset, NATURAL_BREAK_OPTIONS,
  naturalBreakIsRaised, orderedWeekdays, SHORT_BREAK_OPTIONS, toggleWeekday, updateHours, type Settings,
} from '../../core/settings';
import type { Lang, T } from '../../i18n';
import { BellIcon, WarningIcon } from '../components/Icons';
import { Switch } from '../components/Switch';

const pad = (n: number) => String(n).padStart(2, '0');
const toTime = (minutes: number) => `${pad(Math.floor(minutes / 60))}:${pad(minutes % 60)}`;
const fromTime = (value: string) => { const [h, m] = value.split(':').map(Number); return Number.isFinite(h) && Number.isFinite(m) ? h * 60 + m : NaN; };

function Field({ label, htmlFor, children, testId }: { label: ReactNode; htmlFor?: string; children: ReactNode; testId?: string }) {
  return <div className="field" data-testid={testId}>{htmlFor ? <label htmlFor={htmlFor}>{label}</label> : <span className="label">{label}</span>}{children}</div>;
}
function Toggle({ id, checked, onChange, disabled }: { id: string; checked: boolean; onChange: (v: boolean) => void; disabled?: boolean }) {
  return <Switch id={id} testId={id} checked={checked} disabled={disabled} onChange={onChange} />;
}
function Stepper({ id, label, value, display, min, max, step, onChange, t }: {
  id: string; label: string; value: number; display: string; min: number; max: number; step: number; onChange: (v: number) => void; t: T;
}) {
  return (
    <div className="stepper" role="group" aria-labelledby={`${id}-label`}>
      <button className="btn" aria-label={`${label} −`} disabled={value <= min} onClick={() => onChange(Math.max(min, value - step))} data-testid={`${id}-dec`}>−</button>
      <output id={id} aria-live="polite" data-testid={id}>{display}</output>
      <button className="btn" aria-label={`${label} +`} disabled={value >= max} onClick={() => onChange(Math.min(max, value + step))} data-testid={`${id}-inc`}>+</button>
      <span className="sr-only">{t('unit.minutes')}</span>
    </div>
  );
}

export function SettingsPage({ snap, t, lang, send }: { snap: Snapshot; t: T; lang: Lang; send: (i: Intent) => Promise<{ testResult?: string | null } | null> }) {
  const s = snap.settings;
  const set = (patch: Partial<Settings>) => void send({ type: 'settings', patch });
  const dur = (seconds: number) => { const l = durationLabel(seconds); return t(l.key, ...l.values); };
  const preset = matchPreset(s);
  const [testResult, setTestResult] = useState<string | null>(null);
  const [testing, setTesting] = useState(false);
  const weekdayName = (day: number, style: 'short' | 'long') =>
    new Intl.DateTimeFormat(lang, { weekday: style }).format(new Date(2026, 10, 22 + (day - 1))); // 2026-11-22 is a Sunday
  const firstWeekday = lang === 'tr' ? 2 : 1;
  const hours = s.workingHours;
  const notifAttention = snap.notification.state === 'denied';

  const durationSelect = (id: string, value: number, options: readonly number[], onChange: (v: number) => void) => (
    <select id={id} value={value} onChange={(e) => onChange(Number(e.target.value))} data-testid={id}>
      {!options.includes(value) && <option value={value} disabled>{t('ui.duration.custom', dur(value))}</option>}
      {options.map((o) => <option key={o} value={o}>{dur(o)}</option>)}
    </select>
  );

  return (
    <main className="settings">
      <header>
        <img src="icons/icon-128.png" alt="" />
        <h1>{t('settings.title')}</h1>
      </header>

      <section className="section" aria-labelledby="s-timing">
        <h2 id="s-timing">{t('settings.timing')}</h2>
        <div className="group">
          <Field label={t('preset.title')}>
            <div className="segmented" role="group" aria-label={t('preset.title')}>
              <button aria-pressed={preset === 'quick'} onClick={() => set(applyPreset('quick', s))} data-testid="preset-quick">{t('preset.quick')}</button>
              <button aria-pressed={preset === 'balanced'} onClick={() => set(applyPreset('balanced', s))} data-testid="preset-balanced">{t('preset.balanced')}</button>
              <button aria-pressed={preset === null} disabled>{t('preset.custom')}</button>
            </div>
          </Field>
          <Field label={<span id="work-label">{t('setting.work')}</span>}>
            <Stepper id="work" label={t('setting.work')} value={s.work / 60} display={`${s.work / 60} ${t('unit.minutes')}`} min={1} max={240} step={1} onChange={(v) => set({ work: v * 60 })} t={t} />
          </Field>
          <Field label={t('setting.short')} htmlFor="short">{durationSelect('short', s.shortBreak, SHORT_BREAK_OPTIONS, (v) => set({ shortBreak: v }))}</Field>
          <Field label={t('setting.long')} htmlFor="long">{durationSelect('long', s.longBreak, LONG_BREAK_OPTIONS, (v) => set({ longBreak: v }))}</Field>
          <Field label={<span id="every-label">{t('setting.frequency')}</span>}>
            <Stepper id="every" label={t('setting.frequency')} value={s.longEvery} display={String(s.longEvery)} min={1} max={10} step={1} onChange={(v) => set({ longEvery: v })} t={t} />
          </Field>
          <Field label={<span id="afk-label">{t('setting.afk')}</span>}>
            <Stepper id="afk" label={t('setting.afk')} value={s.afk} display={`${s.afk} ${t('unit.seconds')}`} min={15} max={600} step={15} onChange={(v) => set({ afk: v })} t={t} />
          </Field>
          <Field label={<span id="snooze-label">{t('setting.snooze')}</span>}>
            <Stepper id="snooze" label={t('setting.snooze')} value={s.snooze / 60} display={`${s.snooze / 60} ${t('unit.minutes')}`} min={1} max={60} step={1} onChange={(v) => set({ snooze: v * 60 })} t={t} />
          </Field>
          <Field label={t('setting.breakEndSound')} htmlFor="breakEndSound"><Toggle id="breakEndSound" checked={s.breakEndSound} onChange={(v) => set({ breakEndSound: v })} /></Field>
          <div className="hint">{t('settings.accounting')}</div>
        </div>
      </section>

      <section className="section" aria-labelledby="s-breaks">
        <h2 id="s-breaks">{t('ui.settings.breaks')}</h2>
        <div className="group">
          <Field label={t('ui.naturalBreak.title')} htmlFor="natural">
            <select id="natural" value={s.naturalBreak} onChange={(e) => set({ naturalBreak: Number(e.target.value) })} data-testid="natural">
              {NATURAL_BREAK_OPTIONS.map((o) => <option key={o} value={o}>{o === 0 ? t('ui.naturalBreak.off') : dur(o)}</option>)}
            </select>
          </Field>
          <div className="hint">{t('ui.naturalBreak.note')}</div>
          {naturalBreakIsRaised(s) && <div className="hint">{t('ui.naturalBreak.effective', effectiveNaturalBreakMinutes(s))}</div>}
          <Field label={t('ui.focus.title')} htmlFor="focus">
            <select id="focus" value={s.exerciseFocus} onChange={(e) => set({ exerciseFocus: e.target.value as Settings['exerciseFocus'] })} data-testid="focus">
              {(['all', 'neckShoulders', 'back', 'hands'] as const).map((f) => <option key={f} value={f}>{t('ui.focus.' + f)}</option>)}
            </select>
          </Field>
        </div>
      </section>

      <section className="section" aria-labelledby="s-hours">
        <h2 id="s-hours">{t('ui.hours.section')}</h2>
        <div className="group">
          <Field label={t('ui.hours.enable')} htmlFor="hours-enabled">
            <Toggle id="hours-enabled" checked={hours.enabled} onChange={(v) => set({ workingHours: { ...hours, enabled: v } })} />
          </Field>
          {hours.enabled && (
            <>
              <Field label={t('ui.hours.days')}>
                <div className="days" role="group" aria-label={t('ui.hours.days')}>
                  {orderedWeekdays(firstWeekday).map((day) => (
                    <button key={day} aria-pressed={hours.weekdays.includes(day)} aria-label={weekdayName(day, 'long')}
                      onClick={() => set({ workingHours: { ...hours, weekdays: toggleWeekday(day, hours.weekdays) } })}>
                      {weekdayName(day, 'short')}
                    </button>
                  ))}
                </div>
              </Field>
              <Field label={t('ui.hours.start')} htmlFor="hours-start">
                <input id="hours-start" type="time" value={toTime(hours.start)} onChange={(e) => set({ workingHours: updateHours(hours, { start: fromTime(e.target.value) }) })} />
              </Field>
              <Field label={t('ui.hours.end')} htmlFor="hours-end">
                <input id="hours-end" type="time" value={toTime(hours.end)} onChange={(e) => set({ workingHours: updateHours(hours, { end: fromTime(e.target.value) }) })} />
              </Field>
              {crossesMidnight(hours) && <div className="hint">{t('ui.hours.overnight')}</div>}
            </>
          )}
          <div className="hint">{t('ui.hours.note')}</div>
        </div>
      </section>

      <section className="section" aria-labelledby="s-notif">
        <h2 id="s-notif">{t('settings.notifications')}</h2>
        <div className="group">
          <Field label={t('setting.notifications')} htmlFor="notifications">
            <Toggle id="notifications" checked={s.notifications} onChange={(v) => set({ notifications: v })} />
          </Field>
          <Field label={t('setting.sound')} htmlFor="sound">
            <Toggle id="sound" checked={s.sound} disabled={!s.notifications} onChange={(v) => set({ sound: v })} />
          </Field>
          <div className={`hint state-line ${notifAttention ? 'attention' : ''}`} data-testid="notif-state">
            {notifAttention ? <WarningIcon /> : <BellIcon off={snap.notification.state === 'off'} />}
            <span>{t('ui.notif.state.' + snap.notification.state)}</span>
          </div>
          {notifAttention && <div className="hint">{t('permission.denied')}</div>}
          <details>
            <summary>{t('ui.notif.diagnostics')}</summary>
            <div className="body">
              <span className="caption secondary">{t('ext.notif.osHint')}</span>
              <button className="btn" disabled={testing} data-testid="test-notification" onClick={async () => {
                setTesting(true); setTestResult(null);
                const r = await send({ type: 'testNotification' });
                setTesting(false); setTestResult(r?.testResult ?? 'notification.test.failed');
              }}>{t('notification.test.button')}</button>
              {testResult && <span className="caption secondary" role="status" data-testid="test-result">{t(testResult)}</span>}
            </div>
          </details>
        </div>
      </section>

      <section className="section" aria-labelledby="s-general">
        <h2 id="s-general">{t('settings.general')}</h2>
        <div className="group">
          <Field label={t('setting.language')} htmlFor="language">
            <select id="language" value={snap.prefs.language} onChange={(e) => void send({ type: 'prefs', patch: { language: e.target.value as 'system' | 'tr' | 'en' } })} data-testid="language">
              <option value="system">{t('language.system')}</option>
              <option value="tr" lang="tr">Türkçe</option>
              <option value="en" lang="en">English</option>
            </select>
          </Field>
          <Field label={t('setting.appearance')} htmlFor="appearance">
            <select id="appearance" value={s.appearance} onChange={(e) => set({ appearance: e.target.value as Settings['appearance'] })} data-testid="appearance">
              <option value="system">{t('appearance.system')}</option>
              <option value="light">{t('appearance.light')}</option>
              <option value="dark">{t('appearance.dark')}</option>
            </select>
          </Field>
          <Field label={t('ui.setting.menuBarStyle')} htmlFor="toolbar">
            <select id="toolbar" value={s.menuBarStyle} onChange={(e) => set({ menuBarStyle: e.target.value as Settings['menuBarStyle'] })} data-testid="toolbar">
              <option value="timer">{t('ui.menuBarStyle.timer')}</option>
              <option value="icon">{t('ui.menuBarStyle.icon')}</option>
            </select>
          </Field>
          <div className="hint"><strong>{t('ext.limits.title')}.</strong> {t('ext.limits.body')}</div>
          <div className="hint">{t('privacy.summary')}</div>
        </div>
      </section>
    </main>
  );
}
