// Switch bound to background state. It shows the user's choice immediately and drops the optimistic value as soon as
// the next snapshot arrives (or after one second), so it never flickers back while the background commits.
import { useEffect, useState } from 'react';

export function Switch({ id, checked, onChange, disabled, testId, label }: {
  id?: string; checked: boolean; onChange: (v: boolean) => void; disabled?: boolean; testId?: string; label?: string;
}) {
  const [pending, setPending] = useState<{ value: boolean; from: boolean } | null>(null);
  // Drop the optimistic value once the background reports a different value than when the user clicked.
  const settled = pending !== null && pending.from !== checked;
  useEffect(() => {
    if (!pending) return;
    const timer = window.setTimeout(() => setPending(null), 1000);
    return () => window.clearTimeout(timer);
  }, [pending]);
  const shown = pending && !settled ? pending.value : checked;
  return (
    <span className="switch">
      <input id={id} type="checkbox" role="switch" checked={shown} disabled={disabled} data-testid={testId} aria-label={label}
        onChange={(e) => { setPending({ value: e.target.checked, from: checked }); onChange(e.target.checked); }} />
      <span className="track"><span className="thumb" /></span>
    </span>
  );
}
