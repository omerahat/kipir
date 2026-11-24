// Small inline icons standing in for the SF Symbols the native app uses (figure.walk, pause.fill, person.2, ...).
import type { ReactNode } from 'react';

function Svg({ size = 16, children, label }: { size?: number; children: ReactNode; label?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}
      strokeLinecap="round" strokeLinejoin="round" aria-hidden={label ? undefined : true} role={label ? 'img' : undefined} aria-label={label}>
      {children}
    </svg>
  );
}

export const WalkIcon = ({ size = 22 }: { size?: number }) => (
  <Svg size={size}>
    <circle cx="13.5" cy="4" r="2" fill="currentColor" stroke="none" />
    <path d="M10 21l2.2-5.2L15 18v3M7 12.5l2.5-4.5h4l2.5 3.5 2.5 1M12.2 15.8L13.5 8" />
  </Svg>
);
export const PauseIcon = () => (<Svg><rect x="6.5" y="5" width="3.6" height="14" rx="1" fill="currentColor" stroke="none" /><rect x="13.9" y="5" width="3.6" height="14" rx="1" fill="currentColor" stroke="none" /></Svg>);
export const PlayIcon = () => (<Svg><path d="M8 5.5v13l10.5-6.5z" fill="currentColor" stroke="none" /></Svg>);
export const PeopleIcon = () => (<Svg><circle cx="9" cy="8" r="3" /><path d="M3.5 19c.6-3 2.8-5 5.5-5s4.9 2 5.5 5" /><circle cx="16.5" cy="9" r="2.4" /><path d="M16 14.2c2.3.2 4 1.9 4.5 4.8" /></Svg>);
export const ClockIcon = () => (<Svg><circle cx="12" cy="12" r="8.5" /><path d="M12 7.5V12l3 2" /></Svg>);
export const GearIcon = () => (<Svg><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z" /></Svg>);
export const EllipsisIcon = () => (<Svg><circle cx="12" cy="12" r="9" /><circle cx="8" cy="12" r=".6" fill="currentColor" /><circle cx="12" cy="12" r=".6" fill="currentColor" /><circle cx="16" cy="12" r=".6" fill="currentColor" /></Svg>);
export const CheckIcon = () => (<Svg size={14}><circle cx="12" cy="12" r="9" /><path d="M8 12.5l2.7 2.7L16 9.5" /></Svg>);
export const RestartIcon = () => (<Svg size={14}><path d="M20 12a8 8 0 1 1-2.4-5.7M20 4v4.5h-4.5" /></Svg>);
export const TimerIcon = () => (<Svg><circle cx="12" cy="13" r="8" /><path d="M12 9v4l2.5 1.5M10 2.5h4" /></Svg>);
export const ShieldIcon = () => (<Svg><path d="M12 3l7 3v5c0 4.5-3 8.3-7 10-4-1.7-7-5.5-7-10V6z" /><rect x="9.5" y="10.5" width="5" height="4.5" rx="1" /><path d="M10.5 10.5V9a1.5 1.5 0 0 1 3 0v1.5" /></Svg>);
export const PuzzleIcon = () => (<Svg><path d="M10 4a2 2 0 1 1 4 0v1h4v4h1a2 2 0 1 1 0 4h-1v5H6v-5H5a2 2 0 1 1 0-4h1V5h4z" /></Svg>);
export const BellIcon = ({ off = false }: { off?: boolean }) => (<Svg><path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15zM10 20a2 2 0 0 0 4 0" />{off && <path d="M4 4l16 16" />}</Svg>);
export const WarningIcon = () => (<Svg><path d="M12 4l9 16H3zM12 10v4M12 17v.5" /></Svg>);
