import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlnighter/services/sfx/sfx_service.dart';
import 'package:owlnighter/services/sfx/sound_effect.dart';

/// A silent [SfxPlayer] that records how many times it was asked to replay, so
/// tests can assert playback intent without touching a real audio session.
class RecordingSfxPlayer implements SfxPlayer {
  int loads = 0;
  int replays = 0;

  @override
  Future<void> load(String asset) async => loads++;

  @override
  Future<void> replay() async => replays++;

  @override
  Future<void> dispose() async {}
}

/// A silent [SfxService] for widget tests: every effect gets a recording player
/// and it never opens an audio session. [played] accumulates fired effects.
class FakeSfxService extends SfxService {
  FakeSfxService({bool enabled = true})
      : super(enabled: () => enabled, playerFactory: RecordingSfxPlayer.new);

  final List<SoundEffect> played = [];

  @override
  void play(SoundEffect effect) => played.add(effect);
}

/// Convenience override wiring [sfxServiceProvider] to a silent fake.
Override overrideSfxWith(SfxService service) =>
    sfxServiceProvider.overrideWithValue(service);
