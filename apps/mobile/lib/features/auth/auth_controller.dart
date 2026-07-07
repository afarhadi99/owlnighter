import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api/auth_repository_impl.dart';

/// Drives the sign-in screen. Sign-in itself is owned by the backend auth
/// surface (see AuthRepositoryImpl TODOs); this controller manages the UI's
/// loading/error state around it.
class AuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signIn(
            email: email,
            password: password,
          );
    });
  }

  Future<void> magicLink(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithMagicLink(email),
    );
  }
}

final authControllerProvider =
    AutoDisposeAsyncNotifierProvider<AuthController, void>(AuthController.new);
