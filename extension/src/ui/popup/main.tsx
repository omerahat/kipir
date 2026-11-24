import { StrictMode, useCallback } from 'react';
import { createRoot } from 'react-dom/client';
import '../../styles/app.css';
import { chromeBridge, useKipir } from '../useKipir';
import { Popup } from './Popup';

const bridge = chromeBridge();
const surface = new URLSearchParams(location.search).get('surface') === 'window' ? 'window' : 'popup';

function App() {
  const { snap, receivedAt, t, send } = useKipir(bridge);
  const fire = useCallback((i: Parameters<typeof send>[0]) => void send(i), [send]);
  // Until the first snapshot arrives, reserve the panel width so the popup does not resize.
  if (!snap) return <main className="panel" aria-busy="true"><span className="sr-only">{t('ext.loading')}</span></main>;
  return <Popup snap={snap} receivedAt={receivedAt} t={t} send={fire} surface={surface} />;
}

createRoot(document.getElementById('root')!).render(<StrictMode><App /></StrictMode>);
