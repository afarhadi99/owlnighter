import 'package:api_client/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_providers.dart';

/// Referral-code gate: every new account (email/password or Google) must
/// redeem an admin-issued code before a `profiles` row exists. Split out as an
/// interface — like [QuizCheckApi]/[StatsApi] in extras_api.dart — so the
/// signup/activation UI is testable without a network.
abstract interface class ReferralApi {
  /// Live "does this look redeemable" feedback while the user is still
  /// typing. Advisory only — the authoritative check is server-side, at
  /// activation.
  Future<({bool valid, String? reason})> validateReferralCode(String code);

  /// Whether the caller's Supabase session has an activated profile yet.
  Future<bool> getAuthStatus();

  /// Atomically consumes [referralCode] and creates the caller's profile.
  /// Idempotent — safe to call again for an already-activated user.
  Future<ActivatedProfile> activateAccount({
    required String referralCode,
    String? displayName,
  });
}

/// Forwards to the shared [OwlnighterApi] — same Dio instance/session as
/// every other endpoint.
class _OwlnighterReferralApi implements ReferralApi {
  _OwlnighterReferralApi(this._api);
  final OwlnighterApi _api;

  @override
  Future<({bool valid, String? reason})> validateReferralCode(String code) =>
      _api.validateReferralCode(code);

  @override
  Future<bool> getAuthStatus() => _api.getAuthStatus();

  @override
  Future<ActivatedProfile> activateAccount({
    required String referralCode,
    String? displayName,
  }) =>
      _api.activateAccount(
        referralCode: referralCode,
        displayName: displayName,
      );
}

final referralApiProvider = Provider<ReferralApi>(
  (ref) => _OwlnighterReferralApi(ref.watch(apiProvider)),
);
