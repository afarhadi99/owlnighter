import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:offline/offline.dart';

import '../../services/offline_sync/offline_providers.dart';

/// Plays the nightly recap audio for a step. Offline-first: prefers the
/// prefetched local file (from local_audio_cache) and falls back to streaming
/// the storage URL only when no local copy exists.
class AudioController {
  AudioController(this._cache) : _player = AudioPlayer();

  final OfflineCache _cache;
  final AudioPlayer _player;

  Stream<PlayerState> get playerState => _player.playerStateStream;
  Stream<Duration> get position => _player.positionStream;
  Duration? get duration => _player.duration;

  /// The bundled fallback recap. Ensures the nightly player always has a source
  /// (a short silent clip) even before real TTS is prefetched, so play/pause is
  /// exercisable end-to-end on device.
  static const _fallbackAsset = 'assets/audio/placeholder_recap.wav';

  /// Load the recap for [stepId]. Order of preference: a prefetched local file,
  /// then a provided [remoteUrl] (e.g. a TTS storage URL), then the bundled
  /// placeholder asset. Always returns true — there is always a source.
  Future<bool> loadStepRecap(String stepId, {String? remoteUrl}) async {
    final localPath = await _cache.audioPathForStep(stepId);
    if (localPath != null) {
      await _player.setFilePath(localPath);
      return true;
    }
    if (remoteUrl != null) {
      await _player.setUrl(remoteUrl);
      return true;
    }
    await _player.setAsset(_fallbackAsset);
    return true;
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> seek(Duration to) => _player.seek(to);

  void dispose() => _player.dispose();
}

final audioControllerProvider = Provider<AudioController>((ref) {
  final controller = AudioController(ref.watch(offlineCacheProvider));
  ref.onDispose(controller.dispose);
  return controller;
});
