import 'package:meta/meta.dart';

/// An authenticated session. Tokens are the only secret material; they must be
/// persisted via flutter_secure_storage in the app layer, never in Drift/prefs.
@immutable
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.isAdmin = false,
  });

  final String userId;
  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final bool isAdmin;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    bool? isAdmin,
  }) =>
      AuthSession(
        userId: userId,
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        expiresAt: expiresAt ?? this.expiresAt,
        isAdmin: isAdmin ?? this.isAdmin,
      );

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        userId: json['userId'] as String,
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String?,
        expiresAt: json['expiresAt'] == null
            ? null
            : DateTime.parse(json['expiresAt'] as String),
        isAdmin: json['isAdmin'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'accessToken': accessToken,
        if (refreshToken != null) 'refreshToken': refreshToken,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        'isAdmin': isAdmin,
      };
}
