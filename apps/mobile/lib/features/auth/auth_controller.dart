import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api/auth_repository_impl.dart';

/// Drives the sign-in/sign-up screens. Manages the UI's loading/error state
/// around the real Supabase Auth calls in AuthRepositoryImpl.
class AuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns true on success (for callers that need to chain a follow-up step,
  /// e.g. signup immediately attempting referral-code activation).
  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await ref.read(authRepositoryInterfaceProvider).signIn(
            email: email,
            password: password,
          );
    });
    state = result;
    return !result.hasError;
  }

  Future<bool> signUp({required String email, required String password}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await ref.read(authRepositoryInterfaceProvider).signUp(
            email: email,
            password: password,
          );
    });
    state = result;
    return !result.hasError;
  }

  /// Launches the Google OAuth browser flow. The resulting session lands
  /// asynchronously (see AuthRepositoryImpl's onAuthStateChange listener) —
  /// this only reports whether the flow *launched* successfully.
  Future<bool> signInWithGoogle() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryInterfaceProvider).signInWithGoogle(),
    );
    state = result;
    return !result.hasError;
  }

  Future<void> magicLink(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryInterfaceProvider).signInWithMagicLink(email),
    );
  }

  /// Debug-only: authenticate as the seeded dev user (backs the
  /// "Continue as dev" button). No-op path in release since the button is only
  /// shown under kDebugMode.
  Future<void> continueAsDev() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signInAsDev();
    });
  }
}

final authControllerProvider =
    AutoDisposeAsyncNotifierProvider<AuthController, void>(AuthController.new);
