import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/motion/motion.dart';
import '../../shared/theme/theme_re_exports.dart';
import 'auth_controller.dart';

/// Sign-in screen. Email + password with a magic-link alternative. The router
/// redirects here whenever there is no valid session.
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.nightlight_round,
                    size: 64, color: AppColors.amber500),
                const SizedBox(height: AppSpacing.md),
                Text('owlnighter', style: AppType.display,
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Read tonight. Keep your streak.',
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                RewardButton(
                  onTap: state.isLoading
                      ? () {}
                      : () => ref.read(authControllerProvider.notifier).signIn(
                            email: _email.text,
                            password: _password.text,
                          ),
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
                              strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Sign in',
                            style: AppType.label.copyWith(color: Colors.white)),
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
                  onPressed: () => ref
                      .read(authControllerProvider.notifier)
                      .magicLink(_email.text),
                  child: const Text('Email me a magic link'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
