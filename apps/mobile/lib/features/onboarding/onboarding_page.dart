import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../shared/theme/theme_re_exports.dart';

/// Lightweight onboarding: a few value-prop panes → into the library. Kept
/// simple; real onboarding would capture goal, pacing, and bedtime to seed the
/// first plan.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  static const _panes = [
    ('Read a little every night', Icons.nightlight_round),
    ('A quick quiz locks it in', Icons.quiz_rounded),
    ('Keep your streak alive', Icons.local_fire_department_rounded),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _panes.length,
                itemBuilder: (_, i) => _Pane(
                  title: _panes[i].$1,
                  icon: _panes[i].$2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: RewardButton(
                onTap: () {
                  if (_page < _panes.length - 1) {
                    _controller.nextPage(
                      duration: AppMotion.base,
                      curve: AppMotion.enter,
                    );
                  } else {
                    context.go(Routes.library);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.indigo500,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    _page < _panes.length - 1 ? 'Next' : 'Get started',
                    style: AppType.label.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pane extends StatelessWidget {
  const _Pane({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 96, color: AppColors.amber500),
          const SizedBox(height: AppSpacing.xl),
          Text(title, textAlign: TextAlign.center, style: AppType.title),
        ],
      ),
    );
  }
}
