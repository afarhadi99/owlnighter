import 'package:api_client/api_client.dart';
import 'package:owlnighter/services/api/referral_api.dart';

/// A configurable fake [ReferralApi] for the signup/activation screens.
class FakeReferralApi implements ReferralApi {
  FakeReferralApi({
    ({bool valid, String? reason})? validateResult,
    this.activateError,
    this.activateResult,
    this.authStatus = true,
  }) : validateResult = validateResult ?? (valid: true, reason: null);

  ({bool valid, String? reason}) validateResult;
  Object? activateError;
  ActivatedProfile? activateResult;
  bool authStatus;

  int validateCalls = 0;
  int authStatusCalls = 0;
  int activateCalls = 0;
  String? lastActivatedCode;

  @override
  Future<({bool valid, String? reason})> validateReferralCode(
    String code,
  ) async {
    validateCalls++;
    return validateResult;
  }

  @override
  Future<bool> getAuthStatus() async {
    authStatusCalls++;
    return authStatus;
  }

  @override
  Future<ActivatedProfile> activateAccount({
    required String referralCode,
    String? displayName,
  }) async {
    activateCalls++;
    lastActivatedCode = referralCode;
    if (activateError != null) throw activateError!;
    return activateResult ??
        const ActivatedProfile(id: 'u1', displayName: null, isAdmin: false);
  }
}
