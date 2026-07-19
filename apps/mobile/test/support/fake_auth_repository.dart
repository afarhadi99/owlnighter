import 'dart:async';

import 'package:app_core/app_core.dart';

/// A configurable fake [AuthRepository] so the signup/sign-in UI is testable
/// without a real Supabase session. Only [signUp]/[signIn]/[signInWithGoogle]
/// are exercised by the new referral-gated auth screens; the rest throw if
/// ever hit, so an accidental real call is a loud test failure rather than a
/// silent hang.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.signUpError,
    this.signInError,
    this.hangSignUp = false,
    AuthSession? session,
  }) : session = session ?? const AuthSession(userId: 'u1', accessToken: 't1');

  final AuthSession session;
  Object? signUpError;
  Object? signInError;

  /// Never resolves signUp — lets a test freeze on the loading state to
  /// assert the submit button disables instead of racing a fast fake future.
  bool hangSignUp;

  int signUpCalls = 0;
  int signInCalls = 0;
  int googleCalls = 0;
  int signOutCalls = 0;

  @override
  Future<AuthSession?> restore() async => null;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (signInError != null) throw signInError!;
    return session;
  }

  @override
  Future<AuthSession> signUp({
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    if (hangSignUp) return Completer<AuthSession>().future;
    if (signUpError != null) throw signUpError!;
    return session;
  }

  @override
  Future<void> signInWithGoogle() async {
    googleCalls++;
  }

  @override
  Future<AuthSession> signInWithMagicLink(String email) async =>
      throw UnimplementedError('not exercised by these tests');

  @override
  Future<AuthSession> refresh(AuthSession current) async =>
      throw UnimplementedError('not exercised by these tests');

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}
