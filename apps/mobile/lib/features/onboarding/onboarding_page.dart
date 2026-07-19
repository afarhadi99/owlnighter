import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../services/sfx/sfx_service.dart';
import '../../services/sfx/sound_effect.dart';
import '../../shared/theme/theme_re_exports.dart';

/// Warm, storybook onboarding: a few value-prop panes (serif headlines, owl,
/// lamp motif) over the night sky, a page indicator, and a chunky "Begin" CTA.
/// Preserves the real completion flow — the last pane navigates into the
/// library (the app's home), just as before.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  static const _panes = <_PaneData>[
    _PaneData(
      art: _PaneArt.owl,
      title: 'A book at bedtime,\nkept gently alive',
      body:
          'owlnighter turns the book you’re reading into a glowing nightly '
          'path — and an owl who stays up with you.',
    ),
    _PaneData(
      art: _PaneArt.flame,
      title: 'Read a little\nevery night',
      body:
          'Each night is a short, paced read — just enough to keep the story '
          'moving without keeping you up.',
    ),
    _PaneData(
      art: _PaneArt.quiz,
      title: 'A gentle quiz\nlocks it in',
      body:
          'Three easy questions confirm tonight’s reading and keep your streak '
          'alive. It’s a check, never a test.',
    ),
    _PaneData(
      art: _PaneArt.streak,
      title: 'Keep your\nstreak alive',
      body:
          'Every night you read lights a lamp. String them together and watch '
          'the flame grow taller.',
    ),
  ];

  bool get _isLast => _page >= _panes.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _advance() {
    ref.read(sfxServiceProvider).play(SoundEffect.tap);
    if (_isLast) {
      context.go(Routes.library);
    } else {
      _controller.nextPage(
        duration: AppMotion.base,
        curve: AppMotion.standard,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return NightScaffold(
      // The night sky sets the bedtime tone behind the panes.
      automaticallyImplyLeading: false,
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _panes.length,
              itemBuilder: (_, i) => _Pane(data: _panes[i]),
            ),
          ),
          // Page indicator: the active dot stretches into a twilight lozenge.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _panes.length; i++)
                AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.standard,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color:
                        i == _page ? AppColors.twilightHi : AppColors.night600,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: ChunkyButton(
              label: _isLast ? 'Begin' : 'Next',
              fullWidth: true,
              onPressed: _advance,
            ),
          ),
        ],
      ),
    );
  }
}

enum _PaneArt { owl, flame, quiz, streak }

class _PaneData {
  const _PaneData({
    required this.art,
    required this.title,
    required this.body,
  });
  final _PaneArt art;
  final String title;
  final String body;
}

class _Pane extends StatelessWidget {
  const _Pane({required this.data});
  final _PaneData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 150, child: Center(child: _art())),
          const SizedBox(height: AppSpacing.xl),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: AppType.display.copyWith(fontSize: 28, height: 1.2),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _art() {
    switch (data.art) {
      case _PaneArt.owl:
        return const OwlMascot(state: OwlState.greet, size: 132);
      case _PaneArt.flame:
        return const FlameFlicker(intensity: 0.85, size: 132);
      case _PaneArt.quiz:
        return const Icon(
          Icons.checklist_rounded,
          size: 96,
          color: AppColors.twilightHi,
        );
      case _PaneArt.streak:
        return const Icon(
          Icons.local_fire_department_rounded,
          size: 96,
          color: AppColors.lamp,
        );
    }
  }
}
