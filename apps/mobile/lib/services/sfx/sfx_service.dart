import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'sound_effect.dart';
import 'sound_settings.dart';

/// A tiny playback surface for one preloaded sound effect. Abstracted so tests
/// can inject a silent, call-recording fake in place of a real audio player.
abstract class SfxPlayer {
  /// Preload [asset] so [replay] is instant. May throw if no audio session is
  /// available; [SfxService.init] swallows that.
  Future<void> load(String asset);

  /// Restart the loaded clip from the beginning (fire-and-forget playback).
  Future<void> replay();

  Future<void> dispose();
}

/// [SfxPlayer] backed by a just_audio [AudioPlayer].
class JustAudioSfxPlayer implements SfxPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> load(String asset) => _player.setAsset(asset);

  @override
  Future<void> replay() async {
    await _player.seek(Duration.zero);
    await _player.play();
  }

  @override
  Future<void> dispose() => _player.dispose();
}

/// Preloads one player per [SoundEffect] and plays them fire-and-forget. Gated
/// by a caller-supplied [enabled] getter (wired to [soundEnabledProvider]) so a
/// disabled toggle stops sound at the source. Every audio call is wrapped in
/// try/catch: on an emulator or CI host without an audio session, SFX simply
/// no-op instead of throwing into the UI.
class SfxService {
  SfxService({
    required bool Function() enabled,
    SfxPlayer Function()? playerFactory,
  })  : _enabled = enabled,
        _playerFactory = playerFactory ?? JustAudioSfxPlayer.new;

  final bool Function() _enabled;
  final SfxPlayer Function() _playerFactory;
  final Map<SoundEffect, SfxPlayer> _players = {};
  bool _initialized = false;
  bool _disposed = false;

  /// The set of effects with a ready player. Exposed for tests.
  Iterable<SoundEffect> get loadedEffects => _players.keys;

  /// Preload every effect. Idempotent and best-effort — a failed load leaves
  /// that effect as a silent no-op rather than aborting the rest.
  Future<void> init() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    for (final effect in SoundEffect.values) {
      final player = _playerFactory();
      _players[effect] = player;
      try {
        await player.load(effect.asset);
      } catch (_) {
        // Emulator/CI without an audio session: keep the player registered so
        // play() stays a clean no-op, but don't surface the failure.
      }
    }
  }

  /// Play [effect] once. No-ops when sound is disabled, before [init], or when
  /// the underlying player fails — never throws.
  void play(SoundEffect effect) {
    if (_disposed || !_enabled()) return;
    final player = _players[effect];
    if (player == null) return;
    unawaited(_safeReplay(player));
  }

  Future<void> _safeReplay(SfxPlayer player) async {
    try {
      await player.replay();
    } catch (_) {
      // Ignore transient playback errors.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final player in _players.values) {
      try {
        await player.dispose();
      } catch (_) {}
    }
    _players.clear();
  }
}

/// App-wide [SfxService]. Reads the live [soundEnabledProvider] value at fire
/// time and preloads players eagerly (best-effort).
final sfxServiceProvider = Provider<SfxService>((ref) {
  final service = SfxService(
    enabled: () => ref.read(soundEnabledProvider),
  );
  unawaited(service.init());
  ref.onDispose(service.dispose);
  return service;
});
