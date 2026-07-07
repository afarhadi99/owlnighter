import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../shared/theme/theme_re_exports.dart';
import 'audio_controller.dart';

/// A compact play/pause card for the step's calm recap audio. Loads the
/// prefetched local file when available (offline-friendly).
class RecapPlayer extends ConsumerStatefulWidget {
  const RecapPlayer({super.key, required this.stepId, this.remoteUrl});
  final String stepId;
  final String? remoteUrl;

  @override
  ConsumerState<RecapPlayer> createState() => _RecapPlayerState();
}

class _RecapPlayerState extends ConsumerState<RecapPlayer> {
  bool _available = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final controller = ref.read(audioControllerProvider);
    final ok = await controller.loadStepRecap(
      widget.stepId,
      remoteUrl: widget.remoteUrl,
    );
    if (mounted) setState(() {
      _available = ok;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (!_available) return const SizedBox.shrink();

    final controller = ref.read(audioControllerProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            StreamBuilder<PlayerState>(
              stream: controller.playerState,
              builder: (context, snap) {
                final playing = snap.data?.playing ?? false;
                return IconButton.filled(
                  onPressed: () =>
                      playing ? controller.pause() : controller.play(),
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                );
              },
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Calm recap',
                style: AppType.label.copyWith(color: AppColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
