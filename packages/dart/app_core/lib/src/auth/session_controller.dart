import 'dart:async';

import 'auth_session.dart';

/// Where the current [AuthSession] lives. The app layer wires this to
/// flutter_secure_storage via [AuthRepository]; the controller itself is pure
/// Dart so it can be unit-tested without Flutter.
///
/// This is a plain [Stream]-backed controller rather than a Riverpod Notifier
/// so app_core stays framework-agnostic. The app wraps it in a provider.
class SessionController {
  SessionController({AuthSession? initial}) : _session = initial;

  final _controller = StreamController<AuthSession?>.broadcast();
  AuthSession? _session;

  AuthSession? get session => _session;
  bool get isAuthenticated => _session != null && !_session!.isExpired;

  /// Emits on every session change (sign-in, refresh, sign-out).
  Stream<AuthSession?> get changes => _controller.stream;

  void set(AuthSession session) {
    _session = session;
    _controller.add(session);
  }

  void updateTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) {
    final current = _session;
    if (current == null) return;
    _session = current.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
    _controller.add(_session);
  }

  void clear() {
    _session = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}
