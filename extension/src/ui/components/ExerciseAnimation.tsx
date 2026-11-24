// Port of ExerciseAnimationView.swift: two illustrated key poses per movement, held and briefly crossfaded on a loop.
// Both poses come from the native asset catalog, where each pair was cropped with one shared rectangle, and are drawn
// into the same fixed box with object-fit: contain, so the figure never shifts or rescales between poses.
// Visual time is the accepted movement elapsed time projected from the snapshot; it never drives scheduling.
import { useEffect, useState } from 'react';
import { basePeriod, loopPeriod, poseBlend, type Movement } from '../../core/exercises';
import type { T } from '../../i18n';

export const poseUrl = (m: Movement, pose: 'start' | 'end') => `exercises/${m}-${pose}.png`;

function useReducedMotion(): boolean {
  const query = '(prefers-reduced-motion: reduce)';
  const [reduced, setReduced] = useState(() => typeof matchMedia !== 'undefined' && matchMedia(query).matches);
  useEffect(() => {
    const mq = matchMedia(query);
    const on = () => setReduced(mq.matches);
    mq.addEventListener('change', on);
    return () => mq.removeEventListener('change', on);
  }, []);
  return reduced;
}

export function ExerciseAnimation({ movement, time, duration, t }: { movement: Movement; time: number; duration: number; t: T }) {
  const reduced = useReducedMotion();
  const label = `${t('exercise.' + movement)}. ${t('exercise.' + movement + '.instruction')}`;
  if (reduced) {
    return (
      <div className="pose-card" role="img" aria-label={label}>
        <div className="pose-stills">
          <figure><img src={poseUrl(movement, 'start')} alt="" /><figcaption>{t('pose.start')}</figcaption></figure>
          <figure><img src={poseUrl(movement, 'end')} alt="" /><figcaption>{t('pose.end')}</figcaption></figure>
        </div>
      </div>
    );
  }
  const blend = poseBlend(time / loopPeriod(duration, basePeriod(movement)));
  // The wrist stretch switches hands halfway through the movement.
  const mirrored = movement === 'wrists' && time >= duration / 2;
  return (
    <div className="pose-card" role="img" aria-label={label}>
      <div className="pose-stage" style={{ transform: mirrored ? 'scaleX(-1)' : undefined }}>
        <img src={poseUrl(movement, 'start')} alt="" style={{ opacity: 1 - blend }} draggable={false} />
        <img src={poseUrl(movement, 'end')} alt="" style={{ opacity: blend }} draggable={false} />
      </div>
    </div>
  );
}
