// Port of Kipir/UI/CountdownRing.swift. The accent arc is the remaining share of the countdown, anchored at
// 12 o'clock: it starts full and its free end recedes counterclockwise until nothing is left at zero. The fraction
// comes from the projected background snapshot; the ring owns no time of its own.
import type { ReactNode } from 'react';

const SIZE = 174;
const STROKE = 8;
const R = (SIZE - STROKE) / 2;
const C = 2 * Math.PI * R;

export function ringDashOffset(fraction: number): number {
  const f = Number.isFinite(fraction) ? Math.min(1, Math.max(0, fraction)) : 0;
  return C * (1 - f);
}

export function CountdownRing({ fraction, smooth, children }: { fraction: number; smooth: boolean; children?: ReactNode }) {
  const f = Number.isFinite(fraction) ? Math.min(1, Math.max(0, fraction)) : 0;
  return (
    <div className="ring-wrap">
      <svg width={SIZE} height={SIZE} viewBox={`0 0 ${SIZE} ${SIZE}`} aria-hidden="true">
        <circle cx={SIZE / 2} cy={SIZE / 2} r={R} fill="none" stroke="var(--teal-track)" strokeWidth={STROKE} />
        {f > 0 && (
          <circle
            data-testid="ring-arc"
            cx={SIZE / 2} cy={SIZE / 2} r={R} fill="none" stroke="var(--teal)" strokeWidth={STROKE} strokeLinecap="round"
            strokeDasharray={C} strokeDashoffset={ringDashOffset(f)}
            transform={`rotate(-90 ${SIZE / 2} ${SIZE / 2})`}
            style={{ transition: smooth ? 'stroke-dashoffset 260ms linear' : 'none' }}
          />
        )}
      </svg>
      <div className="ring-center">{children}</div>
    </div>
  );
}
