import 'dart:convert';

import 'package:app_core/app_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_provider.dart';

const _kSessionKey = 'owlnighter.session.v1';

/// Auth repository backed by flutter_secure_storage. Only session tokens are
/// persisted, and only here — never in Drift or shared prefs.
///
/// NOTE: sign-in is stubbed against the API's auth surface (Supabase Auth in
/// the blueprint). The token exchange endpoints are owned by the backend
/// component; this wires the persistence + SessionController side and leaves a
/// clear seam for the real calls.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.storage,
    required this.session,
  });

  final FlutterSecureStorage storage;
  final SessionController session;

  @override
  Future<AuthSession?> restore() async {
    final raw = await storage.read(key: _kSessionKey);
    if (raw == null) return null;
    final restored =
        AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    session.set(restored);
    return restored;
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    // TODO(backend): exchange credentials with Supabase Auth / API and map the
    // response to AuthSession. Persisted + broadcast below is the stable part.
    throw UnimplementedError(
      'Wire to auth endpoint; persist via _persist(session).',
    );
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
  }

  /// Persist + broadcast a freshly obtained session. Called by the concrete
  /// sign-in/refresh implementations once wired.
  Future<void> persist(AuthSession value) async {
    await storage.write(key: _kSessionKey, value: jsonEncode(value.toJson()));
    session.set(value);
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

final authRepositoryProvider = Provider<AuthRepositoryImpl>((ref) {
  return AuthRepositoryImpl(
    storage: ref.watch(secureStorageProvider),
    session: ref.watch(sessionControllerProvider),
  );
});
