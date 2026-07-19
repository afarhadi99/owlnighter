import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../services/sfx/sfx_service.dart';
import '../../services/sfx/sound_effect.dart';
import '../../shared/theme/theme_re_exports.dart';
import 'activation_controller.dart';
import 'auth_controller.dart';

/// Signup screen: email + password + an admin-issued referral code. Every new
/// account needs one, so activation is attempted inline right after signup —
/// if the code turns out to be invalid/exhausted (a race with whoever else
/// redeemed it), the same screen lets the user retry just the code without
/// redoing signup (they already have a Supabase session by then).
class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});
  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();

  /// True once signUp has succeeded — a session exists, so a subsequent
  /// submit only retries activation (never re-runs signUp).
  bool _awaitingActivation = false;

  @override
  void initState() {
    super.initState();
    _codeFocus.addListener(() {
      if (!_codeFocus.hasFocus) {
        ref.read(referralCodeCheckControllerProvider.notifier).check(_code.text);
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    ref.read(sfxServiceProvider).play(SoundEffect.tap);
    final authNotifier = ref.read(authControllerProvider.notifier);
    final activationNotifier = ref.read(activationControllerProvider.notifier);

    if (!_awaitingActivation) {
      final signedUp = await authNotifier.signUp(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!signedUp) return; // error surfaced via authControllerProvider
      setState(() => _awaitingActivation = true);
    }

    final activated = await activationNotifier.activate(
      referralCode: _code.text.trim(),
      displayName:
          _displayName.text.trim().isEmpty ? null : _displayName.text.trim(),
    );
    if (activated && mounted) {
      context.go(Routes.library);
    }
    // On failure the activation controller's error state renders below, and
    // the button stays in "Activate" mode so the user can edit the code and
    // retry without redoing signup.
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final activationState = ref.watch(activationControllerProvider);
    final codeCheck = ref.watch(referralCodeCheckControllerProvider);
    final isLoading = authState.isLoading || activationState.isLoading;

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
                  Icons.nightlight_round,
                  size: 64,
                  color: AppColors.amber500,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Create your account',
                  style: AppType.display,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "You'll need a referral code from an owlnighter admin.",
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _email,
                  enabled: !_awaitingActivation,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _password,
                  enabled: !_awaitingActivation,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _displayName,
                  enabled: !_awaitingActivation,
                  decoration: const InputDecoration(
                    labelText: 'Display name (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _code,
                  focusNode: _codeFocus,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Referral code',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (codeCheck.isLoading) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Checking code…',
                    style: AppType.caption.copyWith(color: AppColors.inkMuted),
                  ),
                ] else if (codeCheck.hasValue && codeCheck.value != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    codeCheck.value!.valid
                        ? 'Looks good.'
                        : (codeCheck.value!.reason ?? "That code isn't valid."),
                    style: AppType.caption.copyWith(
                      color: codeCheck.value!.valid
                          ? AppColors.success500
                          : AppColors.danger500,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                RewardButton(
                  onTap: isLoading ? () {} : _submit,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.indigo500,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _awaitingActivation
                                ? 'Activate'
                                : 'Create account',
                            style:
                                AppType.label.copyWith(color: Colors.white),
                          ),
                  ),
                ),
                if (authState.hasError) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${authState.error}',
                    style:
                        AppType.caption.copyWith(color: AppColors.danger500),
                  ),
                ],
                if (activationState.hasError) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${activationState.error}',
                    style:
                        AppType.caption.copyWith(color: AppColors.danger500),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => ref
                          .read(authControllerProvider.notifier)
                          .signInWithGoogle(),
                  icon: const Icon(Icons.login),
                  label: const Text('Continue with Google'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => context.go(Routes.auth),
                  child: const Text('Already have an account? Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
