import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api/activation_status_provider.dart';
import '../../services/api/referral_api.dart';
import '../../services/api/session_provider.dart';

/// Drives the activation gate (redeem-referral-code) submit. Used by both the
/// standalone activation screen and the signup screen's inline retry — the
/// same call either way, since activation is idempotent and only needs a live
/// session (from signUp/signIn/Google) plus a code.
class ActivationController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns true on success. Errors are also surfaced via [state] for a
  /// `state.hasError` / `state.error` read in the UI.
  Future<bool> activate({
    required String referralCode,
    String? displayName,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final profile = await ref.read(referralApiProvider).activateAccount(
            referralCode: referralCode,
            displayName: displayName,
          );
      // The activate response is the first place we learn isAdmin; fold it
      // into the persisted session (defaults to false everywhere else, same
      // as signInAsDev's convention for a freshly-established session).
      final controller = ref.read(sessionControllerProvider);
      final current = controller.session;
      if (current != null) {
        controller.set(current.copyWith(isAdmin: profile.isAdmin));
      }
      // Clears the router's activation gate as soon as this resolves.
      ref.invalidate(activationStatusProvider);
    });
    state = result;
    return !result.hasError;
  }
}

final activationControllerProvider =
    AutoDisposeAsyncNotifierProvider<ActivationController, void>(
  ActivationController.new,
);

/// Live "does this code look redeemable" feedback while the user is still
/// typing a referral code — advisory only, the authoritative check is
/// server-side at activation. Null state means "not checked yet".
class ReferralCodeCheckController
    extends AutoDisposeAsyncNotifier<({bool valid, String? reason})?> {
  @override
  ({bool valid, String? reason})? build() => null;

  Future<void> check(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      state = const AsyncData(null);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(referralApiProvider).validateReferralCode(trimmed),
    );
  }
}

final referralCodeCheckControllerProvider = AutoDisposeAsyncNotifierProvider<
    ReferralCodeCheckController, ({bool valid, String? reason})?>(
  ReferralCodeCheckController.new,
);
