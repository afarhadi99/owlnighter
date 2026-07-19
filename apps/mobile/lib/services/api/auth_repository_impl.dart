import 'dart:async';
import 'dart:convert';

import 'package:app_core/app_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'session_provider.dart';

const _kSessionKey = 'owlnighter.session.v1';

/// The fixed dev identity seeded in the local DB. The API maps
/// `Authorization: Bearer DEV` to this user (is_admin=true) under
/// `NODE_ENV=development`, so a session whose access token is literally `DEV`
/// authenticates as the dev user with no real credential exchange.
const _kDevUserId = '00000000-0000-4000-8000-0000000000de';
const _kDevAccessToken = 'DEV';

/// Native-scheme redirect Supabase lands back on after the Google OAuth
/// browser flow completes. Registered as an Android intent-filter (see
/// AndroidManifest.xml) and must also be added to the Supabase project's
/// "Additional Redirect URLs". supabase_flutter listens for this deep link
/// internally once `Supabase.initialize` has run — no manual deep-link route
/// is needed on top of go_router's existing ones.
const _kOAuthRedirect = 'owlnighterauth://login-callback';

/// Auth repository backed by flutter_secure_storage + Supabase Auth (GoTrue).
/// Only session tokens are persisted, and only here — never in Drift or
/// shared prefs. `AuthSession` (this repo's own model) is kept distinct from
/// Supabase's own `Session`/`User` types; every real Supabase call is mapped
/// into one via [_fromSupabase] before it touches [SessionController].
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.storage,
    required this.session,
  }) {
    // Google sign-in completes out-of-band (browser → deep link), so it
    // never returns a session synchronously like signIn/signUp do. This is
    // the only way to observe it landing. Explicit signIn/signUp already
    // persist their own session directly; re-persisting here on SIGNED_IN is
    // a harmless no-op overwrite for those paths.
    _authSub = supabase.Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final supaSession = data.session;
        if (supaSession == null) return;
        if (data.event == supabase.AuthChangeEvent.signedIn) {
          persist(_fromSupabase(supaSession));
        }
      },
    );
  }

  final FlutterSecureStorage storage;
  final SessionController session;
  late final StreamSubscription<supabase.AuthState> _authSub;

  @override
  Future<AuthSession?> restore() async {
    final raw = await storage.read(key: _kSessionKey);
    if (raw == null) return null;
    final restored =
        AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    session.set(restored);
    return restored;
  }

  /// Debug-only shortcut: mint the seeded dev session so the app can reach the
  /// live local API without a real login. The token (`DEV`) is what makes
  /// api_client send `Authorization: Bearer DEV`. Never used in release builds.
  Future<AuthSession> signInAsDev() async {
    const devSession = AuthSession(
      userId: _kDevUserId,
      accessToken: _kDevAccessToken,
      isAdmin: true,
    );
    await persist(devSession);
    return devSession;
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final response =
        await supabase.Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final authSession = _requireSession(response.session, action: 'Sign-in');
    await persist(authSession);
    return authSession;
  }

  @override
  Future<AuthSession> signUp({
    required String email,
    required String password,
  }) async {
    final response = await supabase.Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
    );
    // Supabase returns no session when the project requires email
    // confirmation — the account exists but can't authenticate yet. Surface
    // that clearly instead of crashing on a null session.
    final authSession = _requireSession(
      response.session,
      action: 'Sign-up',
      hint: 'Check your email to confirm the account, then sign in.',
    );
    await persist(authSession);
    return authSession;
  }

  @override
  Future<void> signInWithGoogle() async {
    await supabase.Supabase.instance.client.auth.signInWithOAuth(
      supabase.OAuthProvider.google,
      redirectTo: _kOAuthRedirect,
      authScreenLaunchMode: supabase.LaunchMode.externalApplication,
    );
    // No session yet: the browser flow completes asynchronously and is
    // captured by the onAuthStateChange listener registered in the
    // constructor, which persists it the same way signIn/signUp do.
  }

  @override
  Future<AuthSession> signInWithMagicLink(String email) async {
    // TODO(backend): trigger magic-link email; session arrives via deep link.
    throw UnimplementedError('Wire to magic-link endpoint.');
  }

  @override
  Future<AuthSession> refresh(AuthSession current) async {
    // TODO(backend): call token refresh; then _persist the rotated session.
    throw UnimplementedError('Wire to token refresh endpoint.');
  }

  @override
  Future<void> signOut() async {
    await storage.delete(key: _kSessionKey);
    session.clear();
    // Best-effort: also drop Supabase's own local session so a stale one
    // doesn't get silently restored/refreshed underneath us.
    unawaited(supabase.Supabase.instance.client.auth.signOut());
  }

  /// Persist + broadcast a freshly obtained session.
  Future<void> persist(AuthSession value) async {
    await storage.write(key: _kSessionKey, value: jsonEncode(value.toJson()));
    session.set(value);
  }

  /// Release the auth-state subscription. Called via `ref.onDispose` from
  /// [authRepositoryProvider].
  void dispose() {
    unawaited(_authSub.cancel());
  }

  AuthSession _requireSession(
    supabase.Session? supaSession, {
    required String action,
    String? hint,
  }) {
    if (supaSession == null) {
      throw StateError(
        '$action succeeded but returned no session.'
        '${hint != null ? ' $hint' : ''}',
      );
    }
    return _fromSupabase(supaSession);
  }

  /// Map a Supabase session to this repo's own [AuthSession]. `isAdmin` isn't
  /// knowable at sign-in/sign-up time — it's learned from the referral-code
  /// activation response and folded in afterward (see ActivationController).
  AuthSession _fromSupabase(supabase.Session supaSession) => AuthSession(
        userId: supaSession.user.id,
        accessToken: supaSession.accessToken,
        refreshToken: supaSession.refreshToken,
        expiresAt: supaSession.expiresAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                supaSession.expiresAt! * 1000,
              ),
      );
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

final authRepositoryProvider = Provider<AuthRepositoryImpl>((ref) {
  final repo = AuthRepositoryImpl(
    storage: ref.watch(secureStorageProvider),
    session: ref.watch(sessionControllerProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// Interface-typed view onto [authRepositoryProvider] — mirrors
/// quizCheckApiProvider/statsApiProvider in extras_api.dart. Feature
/// controllers that only need [AuthRepository]'s contract (not the debug-only
/// `signInAsDev`) depend on this instead, so tests can swap in a fake with
/// `overrideWithValue`.
final authRepositoryInterfaceProvider = Provider<AuthRepository>(
  (ref) => ref.watch(authRepositoryProvider),
);
