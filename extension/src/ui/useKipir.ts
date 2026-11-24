// View-side client. Views hold no timer authority: they keep the latest background snapshot, project it forward
// for smooth rendering, and ask the background to reconcile when a projected boundary is crossed.
import { useCallback, useEffect, useMemo, useState } from 'react';
import { PORT_NAME, type Intent, type IntentResult, type PortMessage } from '../background/messages';
import type { Snapshot } from '../core/model';
import { languageFor, translator, type Lang, type T } from '../i18n';

export interface Bridge {
  send(intent: Intent): Promise<IntentResult | null>;
  subscribe(listener: (s: Snapshot) => void): () => void;
}

export function chromeBridge(): Bridge {
  const listeners = new Set<(s: Snapshot) => void>();
  let port: chrome.runtime.Port | null = null;
  const connect = () => {
    port = chrome.runtime.connect({ name: PORT_NAME });
    port.onMessage.addListener((m: PortMessage) => { if (m?.type === 'snapshot') for (const l of listeners) l(m.snapshot); });
    // The worker can be restarted by Chrome; reconnect so pushes keep arriving.
    port.onDisconnect.addListener(() => { port = null; setTimeout(connect, 250); });
  };
  connect();
  return {
    async send(intent) {
      try {
        const r = (await chrome.runtime.sendMessage(intent)) as IntentResult | { error: string } | undefined;
        if (!r || 'error' in r) return null;
        for (const l of listeners) l(r.snapshot);
        return r;
      } catch { return null; }
    },
    subscribe(listener) { listeners.add(listener); return () => listeners.delete(listener); },
  };
}

/** Appearance preference applied to <html data-theme>. Mirrored in localStorage only so the next popup paints in
 * the right theme before the first snapshot arrives (theme-boot.js). */
function applyAppearance(value: string) {
  const root = document.documentElement;
  if (value === 'light' || value === 'dark') root.dataset.theme = value; else delete root.dataset.theme;
  try { localStorage.setItem('kipir.appearance', value); } catch { /* storage may be unavailable */ }
}

export function useKipir(bridge: Bridge) {
  const [state, setState] = useState<{ snap: Snapshot; at: number } | null>(null);
  useEffect(() => bridge.subscribe((snap) => setState({ snap, at: performance.now() })), [bridge]);
  useEffect(() => {
    void bridge.send({ type: 'sync' });
    const id = window.setInterval(() => void bridge.send({ type: 'sync' }), 20_000);
    return () => window.clearInterval(id);
  }, [bridge]);
  const snap = state?.snap ?? null;
  useEffect(() => { if (snap) applyAppearance(snap.settings.appearance); }, [snap]);
  useEffect(() => {
    if (snap) {
      document.documentElement.lang = languageFor(snap.prefs.language);
    }
  }, [snap]);
  const lang: Lang = snap ? languageFor(snap.prefs.language) : languageFor('system');
  const t: T = useMemo(() => translator(lang), [lang]);
  const send = useCallback((intent: Intent) => bridge.send(intent), [bridge]);
  return { snap, receivedAt: state?.at ?? 0, t, lang, send };
}

/** Seconds since the snapshot arrived, re-rendered at `fps` while `active`. Rendering only. */
export function useElapsed(receivedAt: number, active: boolean, fps = 4): number {
  const [now, setNow] = useState(() => performance.now());
  useEffect(() => {
    if (!active) return;
    let raf = 0, last = 0;
    const loop = (ts: number) => {
      if (ts - last >= 1000 / fps) { last = ts; setNow(performance.now()); }
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, [active, fps]);
  return active ? Math.max(0, (now - receivedAt) / 1000) : 0;
}
