// Offscreen document (reason AUDIO_PLAYBACK): MV3 service workers have no audio. Sounds are synthesized, so no audio
// asset is bundled. The native app plays the quiet system "Tink" at 25% gain; this is a comparably soft tone.
// Chrome closes an AUDIO_PLAYBACK document after 30 s of silence; we also close it ourselves after playing.
let ctx: AudioContext | null = null;
let closeTimer: number | undefined;

function tone(at: number, freq: number, duration: number, gain: number) {
  const c = ctx!;
  const osc = c.createOscillator();
  const env = c.createGain();
  osc.type = 'sine';
  osc.frequency.setValueAtTime(freq, at);
  env.gain.setValueAtTime(0.0001, at);
  env.gain.exponentialRampToValueAtTime(gain, at + 0.01);
  env.gain.exponentialRampToValueAtTime(0.0001, at + duration);
  osc.connect(env).connect(c.destination);
  osc.start(at);
  osc.stop(at + duration + 0.02);
}

async function play(kind: 'reminder' | 'breakEnd') {
  ctx ??= new AudioContext();
  if (ctx.state === 'suspended') await ctx.resume();
  const t = ctx.currentTime + 0.02;
  if (kind === 'breakEnd') {
    tone(t, 1568, 0.35, 0.12);
  } else {
    tone(t, 880, 0.4, 0.14);
    tone(t + 0.16, 1319, 0.5, 0.12);
  }
  window.clearTimeout(closeTimer);
  closeTimer = window.setTimeout(() => window.close(), 2000);
}

chrome.runtime.onMessage.addListener((message: unknown) => {
  const m = message as { target?: string; sound?: string };
  if (m?.target !== 'offscreen') return;
  if (m.sound === 'reminder' || m.sound === 'breakEnd') void play(m.sound).catch(() => window.close());
});
