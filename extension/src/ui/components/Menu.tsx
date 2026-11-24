// Minimal accessible menu button (the native popover uses borderless SwiftUI menus for meeting duration and "More").
import { useEffect, useId, useRef, useState, type ReactNode } from 'react';

export function MenuButton({ label, icon, items, direction = 'up', testId }: {
  label: string; icon: ReactNode; items: { label: string; onSelect: () => void; testId?: string }[];
  direction?: 'up' | 'down'; testId?: string;
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const id = useId();
  useEffect(() => {
    if (!open) return;
    const close = (e: MouseEvent) => { if (!ref.current?.contains(e.target as Node)) setOpen(false); };
    document.addEventListener('mousedown', close);
    ref.current?.querySelector<HTMLButtonElement>('[role="menuitem"]')?.focus();
    return () => document.removeEventListener('mousedown', close);
  }, [open]);
  const onKey = (e: React.KeyboardEvent) => {
    if (!open) return;
    const buttons = [...(ref.current?.querySelectorAll<HTMLButtonElement>('[role="menuitem"]') ?? [])];
    const i = buttons.indexOf(document.activeElement as HTMLButtonElement);
    if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); setOpen(false); ref.current?.querySelector<HTMLButtonElement>('button')?.focus(); }
    else if (e.key === 'ArrowDown') { e.preventDefault(); buttons[(i + 1) % buttons.length]?.focus(); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); buttons[(i - 1 + buttons.length) % buttons.length]?.focus(); }
  };
  return (
    <div className="menu-anchor" ref={ref} onKeyDown={onKey}>
      <button className="btn borderless icon" aria-label={label} title={label} aria-haspopup="menu" aria-expanded={open}
        aria-controls={id} onClick={() => setOpen((v) => !v)} data-testid={testId}>{icon}</button>
      {open && (
        <div className={`menu ${direction}`} role="menu" id={id}>
          {items.map((item) => (
            <button key={item.label} role="menuitem" data-testid={item.testId} onClick={() => { setOpen(false); item.onSelect(); }}>{item.label}</button>
          ))}
        </div>
      )}
    </div>
  );
}
