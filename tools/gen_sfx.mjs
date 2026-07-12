#!/usr/bin/env node
// owlnighter — SFX synthesizer (zero-dependency).
//
// Generates the app's cozy, night-sky UI sound effects as 16-bit PCM mono
// 44.1 kHz WAV files under apps/mobile/assets/audio/sfx/. No downloads, no
// libraries — every waveform is synthesized here so the set is reproducible and
// license-clean. Each file is kept small (well under 120 KB).
//
// Run:  node tools/gen_sfx.mjs
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SR = 44100; // sample rate
const TAU = Math.PI * 2;

// ---------------------------------------------------------------------------
// Small synth toolkit
// ---------------------------------------------------------------------------

/** A mono buffer of Float samples in [-1, 1], addressed by time. */
class Buf {
  constructor(seconds) {
    this.data = new Float32Array(Math.ceil(seconds * SR));
  }
  get length() {
    return this.data.length;
  }
  /** Add `gain`-scaled sample at index i (clamped index ignored). */
  add(i, v) {
    if (i >= 0 && i < this.data.length) this.data[i] += v;
  }
}

const clamp = (v, lo, hi) => (v < lo ? lo : v > hi ? hi : v);
const lerp = (a, b, t) => a + (b - a) * t;

/** Exponential decay envelope: 1 → ~0 over `tau` seconds. */
const expDecay = (t, tau) => Math.exp(-t / tau);

/** Short raised-cosine attack so nothing clicks on onset. */
const attack = (t, a) => (t >= a ? 1 : 0.5 - 0.5 * Math.cos((Math.PI * t) / a));

/**
 * Layer a tone into `buf`.
 * opts: { freq | freqAt(t), start, dur, gain, tau, atk, harmonics:[{mult,gain}], vibrato:{rate,depth} }
 */
function tone(buf, opts) {
  const {
    freq,
    freqAt,
    start = 0,
    dur,
    gain = 0.5,
    tau = dur * 0.4,
    atk = 0.004,
    harmonics = [{ mult: 1, gain: 1 }],
    vibrato,
  } = opts;
  const n0 = Math.floor(start * SR);
  const n = Math.floor(dur * SR);
  // Track per-harmonic phase so a frequency sweep stays continuous.
  const phases = harmonics.map(() => 0);
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    let f = freqAt ? freqAt(t / dur) : freq;
    if (vibrato) f *= 1 + vibrato.depth * Math.sin(TAU * vibrato.rate * t);
    const env = expDecay(t, tau) * attack(t, atk);
    let s = 0;
    for (let h = 0; h < harmonics.length; h++) {
      phases[h] += (TAU * f * harmonics[h].mult) / SR;
      s += Math.sin(phases[h]) * harmonics[h].gain;
    }
    buf.add(n0 + i, s * gain * env);
  }
}

/** Filtered noise burst (whoosh). Simple one-pole low-pass on white noise. */
function whoosh(buf, { start = 0, dur, gain = 0.4, tau = dur * 0.5, cutoff = 0.25, seed = 1 }) {
  const n0 = Math.floor(start * SR);
  const n = Math.floor(dur * SR);
  let lp = 0;
  let s = seed >>> 0;
  const rnd = () => {
    // xorshift32 → [-1, 1]
    s ^= s << 13;
    s ^= s >>> 17;
    s ^= s << 5;
    return ((s >>> 0) / 0xffffffff) * 2 - 1;
  };
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const white = rnd();
    lp += cutoff * (white - lp); // low-pass
    // Swell in then decay so it reads as a soft "whoosh", not a hiss.
    const swell = Math.sin(Math.PI * clamp(t / dur, 0, 1));
    buf.add(n0 + i, lp * gain * swell * expDecay(t, tau));
  }
}

/** Soft-clip to tame any summed peaks, then normalize to `peak`. */
function finalize(buf, peak = 0.9) {
  let max = 0;
  for (let i = 0; i < buf.length; i++) {
    const v = Math.tanh(buf.data[i]); // gentle saturation
    buf.data[i] = v;
    const a = Math.abs(v);
    if (a > max) max = a;
  }
  const g = max > 0 ? peak / max : 1;
  for (let i = 0; i < buf.length; i++) buf.data[i] *= g;
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
  out.writeUInt32LE(16, 16); // fmt chunk size
  out.writeUInt16LE(1, 20); // PCM
  out.writeUInt16LE(1, 22); // mono
  out.writeUInt32LE(SR, 24);
  out.writeUInt32LE(SR * bytesPerSample, 28); // byte rate
  out.writeUInt16LE(bytesPerSample, 32); // block align
  out.writeUInt16LE(16, 34); // bits per sample
  out.write('data', 36);
  out.writeUInt32LE(dataSize, 40);
  for (let i = 0; i < n; i++) {
    const v = clamp(buf.data[i], -1, 1);
    out.writeInt16LE(Math.round(v * 32767), 44 + i * 2);
  }
  return out;
}

// ---------------------------------------------------------------------------
// The effects
// ---------------------------------------------------------------------------

// A soft harmonic stack (fundamental + gentle overtones) for chime-like tones.
const CHIME = [
  { mult: 1, gain: 1.0 },
  { mult: 2, gain: 0.28 },
  { mult: 3, gain: 0.12 },
];

function tap() {
  const b = new Buf(0.05);
  tone(b, { freq: 1100, dur: 0.035, gain: 0.8, tau: 0.010, atk: 0.002 });
  finalize(b, 0.7);
  return b;
}

function correct() {
  const b = new Buf(0.5);
  // Two-note rising chime: A5 → E6.
  tone(b, { freq: 880, start: 0.0, dur: 0.22, gain: 0.6, tau: 0.12, harmonics: CHIME });
  tone(b, { freq: 1318.51, start: 0.09, dur: 0.34, gain: 0.6, tau: 0.18, harmonics: CHIME });
  finalize(b, 0.85);
  return b;
}

function wrong() {
  const b = new Buf(0.22);
  // Gentle descending buzz — a soft "not quite", never harsh.
  tone(b, {
    freqAt: (p) => lerp(200, 150, p),
    dur: 0.16,
    gain: 0.55,
    tau: 0.10,
    atk: 0.006,
    harmonics: [
      { mult: 1, gain: 1.0 },
      { mult: 2, gain: 0.15 },
    ],
  });
  finalize(b, 0.6);
  return b;
}

function unlock() {
  const b = new Buf(0.4);
  // Rising sweep 420 → 940 Hz …
  tone(b, {
    freqAt: (p) => lerp(420, 940, p * p),
    dur: 0.28,
    gain: 0.5,
    tau: 0.18,
    harmonics: CHIME,
    vibrato: { rate: 6, depth: 0.01 },
  });
  // … capped by a bright little "click" that lands the unlock.
  tone(b, { freq: 1500, start: 0.24, dur: 0.06, gain: 0.5, tau: 0.02, atk: 0.001 });
  finalize(b, 0.8);
  return b;
}

function fanfare() {
  const b = new Buf(1.0);
  // C-major arpeggio C5-E5-G5-C6, layered harmonics, long ringing decay.
  const notes = [
    { f: 523.25, t: 0.0 },
    { f: 659.25, t: 0.14 },
    { f: 783.99, t: 0.28 },
    { f: 1046.5, t: 0.42 },
  ];
  for (const { f, t } of notes) {
    tone(b, {
      freq: f,
      start: t,
      dur: 0.9 - t,
      gain: 0.42,
      tau: 0.55,
      harmonics: [
        { mult: 1, gain: 1.0 },
        { mult: 2, gain: 0.3 },
        { mult: 3, gain: 0.16 },
        { mult: 4, gain: 0.08 },
      ],
    });
  }
  // A shimmer above the final chord.
  tone(b, { freq: 2093, start: 0.42, dur: 0.5, gain: 0.14, tau: 0.3, harmonics: CHIME });
  finalize(b, 0.9);
  return b;
}

function streak() {
  const b = new Buf(0.7);
  // Warm rising whoosh …
  whoosh(b, { start: 0.0, dur: 0.42, gain: 0.5, tau: 0.3, cutoff: 0.18, seed: 0x9e3779b9 });
  // … resolving into a high sparkle chime.
  tone(b, { freq: 1174.66, start: 0.26, dur: 0.4, gain: 0.5, tau: 0.24, harmonics: CHIME });
  tone(b, { freq: 1760, start: 0.34, dur: 0.34, gain: 0.34, tau: 0.2, harmonics: CHIME });
  finalize(b, 0.85);
  return b;
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
console.log(ok ? `\nAll ${Object.keys(effects).length} SFX written to ${outDir}` : '\nERROR: a file exceeded 120KB');
process.exit(ok ? 0 : 1);
