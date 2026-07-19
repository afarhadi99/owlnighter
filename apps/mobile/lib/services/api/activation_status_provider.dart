import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'referral_api.dart';
import 'session_provider.dart';

/// Whether the currently signed-in user has redeemed a referral code (i.e.
/// has a `profiles` row). Drives the router's activation gate — see
/// app/router.dart. Recomputes whenever [authStateProvider] changes (sign-in,
/// sign-out, refresh); after a successful activateAccount call, invalidate
/// this provider so the gate clears immediately.
///
/// No session → not gated (the router already sends signed-out users to
/// /auth before this ever matters).
final activationStatusProvider = FutureProvider<bool>((ref) async {
  final session = ref.watch(authStateProvider).valueOrNull;
  if (session == null) return true;
  return ref.read(referralApiProvider).getAuthStatus();
});
