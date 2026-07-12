import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:owlnighter/services/sfx/sfx_service.dart';
import 'package:owlnighter/services/sfx/sound_effect.dart';

import 'support/fake_sfx.dart';

void main() {
  group('SoundEffect registry', () {
    test('every effect maps to a WAV that exists on disk', () {
      // `flutter test` runs with the package root as cwd, so the bundled asset
      // path resolves directly. This guards against the enum drifting away from
      // what tools/gen_sfx.mjs actually produced.
      for (final effect in SoundEffect.values) {
        final file = File(effect.asset);
        expect(
          file.existsSync(),
          isTrue,
          reason: '${effect.name} -> ${effect.asset} is missing',
        );
        expect(file.lengthSync(), greaterThan(0));
        // The build declares assets/audio/sfx/ and each file must live under it.
        expect(effect.asset, startsWith('assets/audio/sfx/'));
      }
    });

    test('there is exactly one WAV on disk per registered effect', () {
      final dir = Directory('assets/audio/sfx');
      expect(dir.existsSync(), isTrue);
      final wavs = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.wav'))
          .toList();
      expect(wavs.length, SoundEffect.values.length);
    });
  });

  group('SfxService', () {
    test('init preloads a player for every effect', () async {
      final service = SfxService(
        enabled: () => true,
        playerFactory: RecordingSfxPlayer.new,
      );
      await service.init();
      expect(service.loadedEffects.toSet(), SoundEffect.values.toSet());
      await service.dispose();
    });

    test('play replays the matching preloaded player when enabled', () async {
      final players = <RecordingSfxPlayer>[];
      final service = SfxService(
        enabled: () => true,
        playerFactory: () {
          final p = RecordingSfxPlayer();
          players.add(p);
          return p;
        },
      );
      await service.init();

      service.play(SoundEffect.correct);
      await Future<void>.delayed(Duration.zero);

      final totalReplays = players.fold<int>(0, (a, p) => a + p.replays);
      expect(totalReplays, 1);
      await service.dispose();
    });

    test('a disabled toggle gates playback (no replay)', () async {
      var enabled = true;
      final players = <RecordingSfxPlayer>[];
      final service = SfxService(
        enabled: () => enabled,
        playerFactory: () {
          final p = RecordingSfxPlayer();
          players.add(p);
          return p;
        },
      );
      await service.init();

      enabled = false;
      service.play(SoundEffect.tap);
      await Future<void>.delayed(Duration.zero);
      expect(players.fold<int>(0, (a, p) => a + p.replays), 0);

      enabled = true;
      service.play(SoundEffect.tap);
      await Future<void>.delayed(Duration.zero);
      expect(players.fold<int>(0, (a, p) => a + p.replays), 1);

      await service.dispose();
    });

    test('play never throws when a player fails to load or replay', () async {
      final service = SfxService(
        enabled: () => true,
        playerFactory: _ThrowingSfxPlayer.new,
      );
      // init swallows load failures; play swallows replay failures.
      await service.init();
      expect(() => service.play(SoundEffect.streak), returnsNormally);
      await service.dispose();
    });

    test('play is a no-op after dispose', () async {
      final players = <RecordingSfxPlayer>[];
      final service = SfxService(
        enabled: () => true,
        playerFactory: () {
          final p = RecordingSfxPlayer();
          players.add(p);
          return p;
        },
      );
      await service.init();
      await service.dispose();
      service.play(SoundEffect.tap);
      await Future<void>.delayed(Duration.zero);
      expect(players.fold<int>(0, (a, p) => a + p.replays), 0);
    });
  });
}

/// A player whose audio calls always fail — models an emulator/CI host with no
/// audio session.
class _ThrowingSfxPlayer implements SfxPlayer {
  @override
  Future<void> load(String asset) async => throw StateError('no audio session');

  @override
  Future<void> replay() async => throw StateError('no audio session');

  @override
  Future<void> dispose() async {}
}
