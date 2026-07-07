import 'package:dio/dio.dart';

/// Normalized API error. Mirrors the server's `ApiError` envelope
/// (`{ error: { code, message, requestId?, details? } }`).
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.requestId,
    this.details,
  });

  final int? statusCode;
  final String code;
  final String message;
  final String? requestId;
  final Object? details;

  /// Build from a Dio failure, unwrapping the server error envelope when present.
  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    final data = response?.data;
    if (data is Map && data['error'] is Map) {
      final err = (data['error'] as Map).cast<String, dynamic>();
      return ApiException(
        statusCode: response?.statusCode,
        code: err['code'] as String? ?? 'unknown',
        message: err['message'] as String? ?? e.message ?? 'Request failed',
        requestId: err['requestId'] as String?,
        details: err['details'],
      );
    }
    return ApiException(
      statusCode: response?.statusCode,
      code: _codeForType(e.type),
      message: e.message ?? 'Network request failed',
    );
  }

  static String _codeForType(DioExceptionType type) => switch (type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'timeout',
        DioExceptionType.connectionError => 'offline',
        DioExceptionType.badResponse => 'bad_response',
        DioExceptionType.cancel => 'cancelled',
        _ => 'unknown',
      };

  /// True when the failure looks like a connectivity problem — the caller can
  /// fall back to the offline cache.
  bool get isOffline => code == 'offline' || code == 'timeout';

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
