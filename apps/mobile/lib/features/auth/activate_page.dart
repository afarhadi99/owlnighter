import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api/auth_repository_impl.dart'
    show authRepositoryInterfaceProvider;
import '../../services/sfx/sfx_service.dart';
import '../../services/sfx/sound_effect.dart';
import '../../shared/theme/theme_re_exports.dart';
import 'activation_controller.dart';

/// Activation gate: shown whenever there's a live session but no `profiles`
/// row yet (see the router's redirect + activationStatusProvider). This is
/// where a fresh Google sign-in lands (it never collects a code up front),
/// and it's also the fallback if the signup screen's inline activation
/// attempt failed — either way the code field starts blank.
class ActivatePage extends ConsumerStatefulWidget {
  const ActivatePage({super.key});
  @override
  ConsumerState<ActivatePage> createState() => _ActivatePageState();
}

class _ActivatePageState extends ConsumerState<ActivatePage> {
  final _code = TextEditingController();
  final _displayName = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    ref.read(sfxServiceProvider).play(SoundEffect.tap);
    await ref.read(activationControllerProvider.notifier).activate(
          referralCode: _code.text.trim(),
          displayName: _displayName.text.trim().isEmpty
              ? null
              : _displayName.text.trim(),
        );
    // On success the router's activation gate clears itself (the controller
    // invalidates activationStatusProvider) and redirects away from here.
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activationControllerProvider);

    return NightScaffold(
      showSky: false,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.key_rounded,
                  size: 64,
                  color: AppColors.amber500,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'One more step',
                  style: AppType.display,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Enter your referral code to activate your account.',
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Referral code',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _displayName,
                  decoration: const InputDecoration(
                    labelText: 'Display name (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                RewardButton(
                  onTap: state.isLoading ? () {} : _submit,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.indigo500,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: state.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Activate',
                            style:
                                AppType.label.copyWith(color: Colors.white),
                          ),
                  ),
                ),
                if (state.hasError) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${state.error}',
                    style:
                        AppType.caption.copyWith(color: AppColors.danger500),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () =>
                      ref.read(authRepositoryInterfaceProvider).signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
