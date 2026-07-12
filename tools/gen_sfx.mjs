#!/usr/bin/env node
// owlnighter — SFX synthesizer (zero-dependency).
//
// Generates the app's cozy, night-sky UI sound effects as 16-bit PCM mono
// 44.1 kHz WAV files under apps/mobile/assets/audio/sfx/. No downloads, no
// libraries — every waveform is synthesized here so the set is reproducible and
// license-clean. Each file is kept small (well under 120 KB).
//
// Synthesis model (shared across the tuned cues):
//   * 2–3 detuned oscillators per note (±5 cents) so tones "shimmer" instead of
//     sounding like a dead sine — a chorus/ensemble effect;
//   * harmonic partials summed with amplitude ~ 1/n^1.5 (bell/marimba physics),
//     each partial given its OWN exponential decay that is faster for higher
//     partials (so the tone darkens as it rings out, like a struck bar);
//   * a soft 5–10 ms raised-cosine attack (no click on onset);
//   * a one-pole low-pass at ~4 kHz over the whole buffer to take the digital
//     edge off;
//   * a single 90 ms echo tap at -12 dB for a touch of room/space;
//   * 10 ms fades at both ends, then peak-normalize to ~-6 dBFS.
//
// Run:  node tools/gen_sfx.mjs
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SR = 44100; // sample rate
const TAU = Math.PI * 2;

// Target peak ≈ -6 dBFS  →  10^(-6/20) ≈ 0.501.
const PEAK = 0.5;
// Echo tap: 90 ms delay at -12 dB  →  10^(-12/20) ≈ 0.251.
const ECHO_DELAY_S = 0.09;
const ECHO_GAIN = 0.251;
// Global tone-shaping low-pass cutoff.
const LP_CUTOFF_HZ = 4000;
// Edge fades.
const FADE_S = 0.01;

// ---------------------------------------------------------------------------
// Small synth toolkit
// ---------------------------------------------------------------------------

/** A mono buffer of Float samples in [-1, 1], addressed by sample index. */
class Buf {
  constructor(seconds) {
    this.data = new Float32Array(Math.ceil(seconds * SR));
  }
  get length() {
    return this.data.length;
  }
  add(i, v) {
    if (i >= 0 && i < this.data.length) this.data[i] += v;
  }
}

const clamp = (v, lo, hi) => (v < lo ? lo : v > hi ? hi : v);
const lerp = (a, b, t) => a + (b - a) * t;

/** cents → frequency ratio. +5 cents = 2^(5/1200). */
const cents = (c) => Math.pow(2, c / 1200);

/** Short raised-cosine attack so nothing clicks on onset. */
const attackEnv = (t, a) => (t >= a ? 1 : 0.5 - 0.5 * Math.cos((Math.PI * t) / a));

/**
 * Struck-bar / bell note: detuned oscillator ensemble × harmonic partials, each
 * partial with amplitude 1/n^1.5 and its own (faster-for-higher) exp decay.
 *
 * opts: {
 *   freq, start, dur, gain,
 *   tau        base decay of the fundamental (s),
 *   atk        attack seconds (default 0.006),
 *   partials   how many harmonics (default 4),
 *   detune     ± cents spread for the 3-voice ensemble (default 5),
 *   voices     ensemble size (default 3),
 *   partialTau (n) => decay tau for partial n  (default: tau / n^0.6),
 * }
 */
function note(buf, opts) {
  const {
    freq,
    start = 0,
    dur,
    gain = 0.5,
    tau = dur * 0.5,
    atk = 0.006,
    partials = 4,
    detune = 5,
    voices = 3,
    partialTau = (n) => tau / Math.pow(n, 0.6),
  } = opts;

  const n0 = Math.floor(start * SR);
  const nSamp = Math.floor(dur * SR);

  // Ensemble of slightly detuned voices, symmetric around the center freq.
  const ratios = [];
  if (voices <= 1) {
    ratios.push(1);
  } else {
    for (let v = 0; v < voices; v++) {
      const spread = (v / (voices - 1)) * 2 - 1; // -1 .. +1
      ratios.push(cents(spread * detune));
    }
  }

  // Per-partial amplitude and decay, precomputed.
  const amp = [];
  const decTau = [];
  for (let p = 1; p <= partials; p++) {
    amp[p] = 1 / Math.pow(p, 1.5);
    decTau[p] = partialTau(p);
  }

  for (let i = 0; i < nSamp; i++) {
    const t = i / SR;
    const env = attackEnv(t, atk);
    let s = 0;
    for (const r of ratios) {
      const f = freq * r;
      for (let p = 1; p <= partials; p++) {
        const pd = Math.exp(-t / decTau[p]); // per-partial decay
        s += Math.sin(TAU * f * p * t) * amp[p] * pd;
      }
    }
    buf.add(n0 + i, (s / ratios.length) * gain * env);
  }
}

/** Filtered-noise whoosh: one-pole low-pass on white noise, swelling then out. */
function whoosh(buf, { start = 0, dur, gain = 0.4, cutoffStart = 0.03, cutoffEnd = 0.28, seed = 1 }) {
  const n0 = Math.floor(start * SR);
  const nSamp = Math.floor(dur * SR);
  let lp = 0;
  let s = seed >>> 0;
  const rnd = () => {
    s ^= s << 13;
    s ^= s >>> 17;
    s ^= s << 5;
    return ((s >>> 0) / 0xffffffff) * 2 - 1;
  };
  for (let i = 0; i < nSamp; i++) {
    const t = i / SR;
    const p = t / dur;
    const white = rnd();
    // Cutoff opens up over time so the whoosh "rises" in brightness.
    const cutoff = lerp(cutoffStart, cutoffEnd, p);
    lp += cutoff * (white - lp);
    const swell = Math.sin(Math.PI * clamp(p, 0, 1)); // in-then-out
    buf.add(n0 + i, lp * gain * swell);
  }
}

/** One-pole low-pass over the whole buffer at [fc] Hz. In place. */
function lowpass(buf, fc) {
  const alpha = 1 - Math.exp((-TAU * fc) / SR);
  let y = 0;
  for (let i = 0; i < buf.length; i++) {
    y += alpha * (buf.data[i] - y);
    buf.data[i] = y;
  }
}

/** Single feed-forward echo tap: out[i] += g · dry[i - delay]. In place. */
function echo(buf, delayS = ECHO_DELAY_S, g = ECHO_GAIN) {
  const d = Math.floor(delayS * SR);
  if (d <= 0) return;
  const dry = Float32Array.from(buf.data);
  for (let i = d; i < buf.length; i++) {
    buf.data[i] += g * dry[i - d];
  }
}

/** 10 ms raised-cosine fades at both ends so nothing clicks. In place. */
function fadeEnds(buf, fadeS = FADE_S) {
  const f = Math.floor(fadeS * SR);
  const n = buf.length;
  for (let i = 0; i < f && i < n; i++) {
    const g = 0.5 - 0.5 * Math.cos((Math.PI * i) / f);
    buf.data[i] *= g;
    buf.data[n - 1 - i] *= g;
  }
}

/** Gentle saturation, then peak-normalize to [peak]. In place. */
function finalize(buf, peak = PEAK) {
  let max = 0;
  for (let i = 0; i < buf.length; i++) {
    const v = Math.tanh(buf.data[i]);
    buf.data[i] = v;
    const a = Math.abs(v);
    if (a > max) max = a;
  }
  const g = max > 0 ? peak / max : 1;
  for (let i = 0; i < buf.length; i++) buf.data[i] *= g;
}

/** Standard post-chain: tone-shape LP → echo → fades → normalize. */
function master(buf, { lp = LP_CUTOFF_HZ, withEcho = true, peak = PEAK } = {}) {
  if (lp) lowpass(buf, lp);
  if (withEcho) echo(buf);
  fadeEnds(buf);
  finalize(buf, peak);
  return buf;
}

/** Encode a Buf to a 16-bit PCM mono WAV byte Buffer. */
function toWav(buf) {
  const n = buf.length;
  const bytesPerSample = 2;
  const dataSize = n * bytesPerSample;
  const out = Buffer.alloc(44 + dataSize);
  out.write('RIFF', 0);
  out.writeUInt32LE(36 + dataSize, 4);
  out.write('WAVE', 8);
  out.write('fmt ', 12);
  out.writeUInt32LE(16, 16);
  out.writeUInt16LE(1, 20); // PCM
  out.writeUInt16LE(1, 22); // mono
  out.writeUInt32LE(SR, 24);
  out.writeUInt32LE(SR * bytesPerSample, 28);
  out.writeUInt16LE(bytesPerSample, 32);
  out.writeUInt16LE(16, 34);
  out.write('data', 36);
  out.writeUInt32LE(dataSize, 40);
  for (let i = 0; i < n; i++) {
    const v = clamp(buf.data[i], -1, 1);
    out.writeInt16LE(Math.round(v * 32767), 44 + i * 2);
  }
  return out;
}

// Musical note frequencies (equal temperament, A4 = 440).
const N = {
  D3: 146.83,
  G3: 196.0,
  C4: 261.63,
  E4: 329.63,
  G4: 392.0,
  A4: 440.0,
  C5: 523.25,
  D5: 587.33,
  E5: 659.25,
  G5: 783.99,
  A5: 880.0,
  C6: 1046.5,
  E6: 1318.51,
  G6: 1567.98,
};

// ---------------------------------------------------------------------------
// The effects
// ---------------------------------------------------------------------------

/** tap — a short woody tick (2 partials, ~40 ms). Dry: no echo, gentle LP. */
function tap() {
  const b = new Buf(0.06);
  note(b, {
    freq: 900,
    dur: 0.045,
    gain: 0.9,
    tau: 0.018,
    atk: 0.003,
    partials: 2,
    voices: 2,
    detune: 4,
    partialTau: (n) => 0.018 / n, // upper partial dies fast → "tick", not "beep"
  });
  return master(b, { lp: 5000, withEcho: false, peak: 0.55 });
}

/** correct — bright marimba double-hit G5 → C6, ~90 ms apart ("ding-dun"). */
function correct() {
  const b = new Buf(0.55);
  note(b, { freq: N.G5, start: 0.0, dur: 0.34, gain: 0.6, tau: 0.16, partials: 4 });
  note(b, { freq: N.C6, start: 0.09, dur: 0.42, gain: 0.62, tau: 0.2, partials: 4 });
  // A soft octave shimmer above the second hit.
  note(b, { freq: N.C6 * 2, start: 0.1, dur: 0.3, gain: 0.12, tau: 0.14, partials: 2 });
  return master(b, { peak: 0.5 });
}

/** wrong — a soft, low, muted "dunk" (D3, heavy LP, ~200 ms). Gentle, kind. */
function wrong() {
  const b = new Buf(0.32);
  note(b, {
    freq: N.D3,
    dur: 0.22,
    gain: 0.7,
    tau: 0.12,
    atk: 0.01,
    partials: 3,
    voices: 2,
    detune: 3,
    partialTau: (n) => 0.12 / (n * n), // very dark: overtones vanish quickly
  });
  // Heavy low-pass makes it a muffled thud, never a harsh buzzer.
  return master(b, { lp: 900, withEcho: false, peak: 0.42 });
}

/** unlock — a quick sparkle arpeggio up (3 notes, 40 ms apart). */
function unlock() {
  const b = new Buf(0.5);
  const arp = [N.C5, N.E5, N.G5];
  arp.forEach((f, i) => {
    note(b, {
      freq: f,
      start: i * 0.04,
      dur: 0.34 - i * 0.04,
      gain: 0.5,
      tau: 0.14,
      partials: 3,
    });
  });
  // A bright top note to "land" the unlock.
  note(b, { freq: N.C6, start: 0.12, dur: 0.3, gain: 0.34, tau: 0.16, partials: 2 });
  return master(b, { peak: 0.5 });
}

/** fanfare — warm I–V–vi–I arpeggio (C–G–Am–C), ~1.1 s, with echo. */
function fanfare() {
  const b = new Buf(1.25);
  // Root motion of the four chords, each an arpeggiated triad.
  const chords = [
    { t: 0.0, notes: [N.C4, N.E4, N.G4] }, // I  (C major)
    { t: 0.26, notes: [N.G3, N.D5, N.G4] }, // V  (G major, voiced open)
    { t: 0.52, notes: [N.A4, N.C5, N.E5] }, // vi (A minor)
    { t: 0.78, notes: [N.C5, N.E5, N.G5] }, // I  (C major, up an octave)
  ];
  for (const { t, notes } of chords) {
    notes.forEach((f, i) => {
      note(b, {
        freq: f,
        start: t + i * 0.03,
        dur: 1.1 - t,
        gain: 0.34,
        tau: 0.5,
        partials: 4,
      });
    });
  }
  // A shimmer over the final chord.
  note(b, { freq: N.C6, start: 0.82, dur: 0.5, gain: 0.14, tau: 0.3, partials: 2 });
  return master(b, { peak: 0.5 });
}

/** streak — a filtered-noise whoosh rising into a bright chime. */
function streak() {
  const b = new Buf(0.9);
  whoosh(b, { start: 0.0, dur: 0.5, gain: 0.55, seed: 0x9e3779b9 });
  // The whoosh resolves into a rising two-note bright chime.
  note(b, { freq: N.G5, start: 0.34, dur: 0.4, gain: 0.5, tau: 0.22, partials: 4 });
  note(b, { freq: N.C6, start: 0.42, dur: 0.45, gain: 0.5, tau: 0.24, partials: 4 });
  note(b, { freq: N.E6, start: 0.48, dur: 0.4, gain: 0.3, tau: 0.2, partials: 3 });
  return master(b, { peak: 0.5 });
}

// ---------------------------------------------------------------------------
// Write them out
// ---------------------------------------------------------------------------

const __dirname = dirname(fileURLToPath(import.meta.url));
const outDir = join(__dirname, '..', 'apps', 'mobile', 'assets', 'audio', 'sfx');
mkdirSync(outDir, { recursive: true });

const effects = { tap, correct, wrong, unlock, fanfare, streak };
const LIMIT = 120 * 1024;
let ok = true;
for (const [name, fn] of Object.entries(effects)) {
  const wav = toWav(fn());
  const file = join(outDir, `${name}.wav`);
  writeFileSync(file, wav);
  const kb = (wav.length / 1024).toFixed(1);
  const flag = wav.length > LIMIT ? '  !! OVER 120KB' : '';
  if (wav.length > LIMIT) ok = false;
  console.log(`  wrote ${name}.wav  ${kb} KB${flag}`);
}
console.log(
  ok
    ? `\nAll ${Object.keys(effects).length} SFX written to ${outDir}`
    : '\nERROR: a file exceeded 120KB',
);
process.exit(ok ? 0 : 1);
