"use client";

/**
 * Tiny WebAudio sound effects for the console — no audio assets. Each call
 * builds a couple of `OscillatorNode`s with a short gain envelope and tears
 * itself down; if `AudioContext` is unavailable (SSR, old browser, autoplay
 * policy) every function silently no-ops. Respects a small mute toggle
 * persisted to localStorage (see the Sidebar footer).
 */

const MUTE_KEY = "owlnighter:sfx-muted";
export const SFX_MUTE_EVENT = "owlnighter:sfx-mute-changed";

export function isMuted(): boolean {
  if (typeof window === "undefined") return true;
  try {
    return window.localStorage.getItem(MUTE_KEY) === "1";
  } catch {
    return false;
  }
}

export function setMuted(muted: boolean): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(MUTE_KEY, muted ? "1" : "0");
  } catch {
    // ignore storage failures (private browsing etc.)
  }
  window.dispatchEvent(new CustomEvent(SFX_MUTE_EVENT, { detail: muted }));
}

type Note = { freq: number; start: number; duration: number };

function getAudioContextCtor(): typeof AudioContext | undefined {
  if (typeof window === "undefined") return undefined;
  return window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
}

function playNotes(notes: Note[]): void {
  if (isMuted()) return;
  const AudioCtx = getAudioContextCtor();
  if (!AudioCtx) return;

  try {
    const ctx = new AudioCtx();
    const now = ctx.currentTime;

    for (const { freq, start, duration } of notes) {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "sine";
      osc.frequency.value = freq;

      const t0 = now + start;
      const t1 = t0 + duration;
      gain.gain.setValueAtTime(0.0001, t0);
      gain.gain.exponentialRampToValueAtTime(0.22, t0 + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, t1);

      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(t0);
      osc.stop(t1 + 0.02);
    }

    const totalMs = (Math.max(...notes.map((n) => n.start + n.duration)) + 0.1) * 1000;
    window.setTimeout(() => {
      ctx.close().catch(() => {});
    }, totalMs);
  } catch {
    // AudioContext blocked/unsupported — no-op.
  }
}

/** Two-note ascending "ding", ~0.25s. Use on successful actions. */
export function chime(): void {
  playNotes([
    { freq: 880, start: 0, duration: 0.12 },
    { freq: 1318.5, start: 0.1, duration: 0.15 },
  ]);
}

/** Two-note descending tone, ~0.25s. Use on failed actions. */
export function error(): void {
  playNotes([
    { freq: 392, start: 0, duration: 0.12 },
    { freq: 293.66, start: 0.1, duration: 0.15 },
  ]);
}
