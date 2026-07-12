/// The cozy UI sound effects the app can play. Each maps to a bundled WAV under
/// `assets/audio/sfx/` (synthesized by `tools/gen_sfx.mjs`). Keeping the asset
/// path on the enum lets [SfxService] preload every effect from a single loop
/// and lets tests assert the registry matches what's on disk.
enum SoundEffect {
  /// Light UI tick for taps on primary controls and quiz options.
  tap('tap.wav'),

  /// Bright two-note chime when an answer is correct.
  correct('correct.wav'),

  /// Gentle descending "not quite" — never harsh.
  wrong('wrong.wav'),

  /// Rising sweep + click when a path node unlocks.
  unlock('unlock.wav'),

  /// C-major arpeggio for the streak-celebration payoff.
  fanfare('fanfare.wav'),

  /// Warm whoosh + high sparkle for the streak flame.
  streak('streak.wav');

  const SoundEffect(this.fileName);

  /// Bare file name, e.g. `tap.wav`.
  final String fileName;

  /// Bundled asset path used with just_audio's `setAsset`.
  String get asset => 'assets/audio/sfx/$fileName';
}
