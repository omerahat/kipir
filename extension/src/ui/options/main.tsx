import { StrictMode, useEffect } from 'react';
import { createRoot } from 'react-dom/client';
import '../../styles/app.css';
import { chromeBridge, useKipir } from '../useKipir';
import { SettingsPage } from './SettingsPage';

const bridge = chromeBridge();

function App() {
  const { snap, t, lang, send } = useKipir(bridge);
  useEffect(() => { document.title = t('settings.title'); }, [t]);
  if (!snap) return <main className="settings" aria-busy="true"><span className="sr-only">{t('ext.loading')}</span></main>;
  return <SettingsPage snap={snap} t={t} lang={lang} send={send} />;
}

createRoot(document.getElementById('root')!).render(<StrictMode><App /></StrictMode>);
