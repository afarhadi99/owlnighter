import 'package:dio/dio.dart';

/// Injects the bearer token on every request. The token is read lazily via a
/// callback so the interceptor always sees the freshest value from the
/// SessionController without holding a stale copy.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokenProvider});

  /// Returns the current access token, or null when signed out.
  final String? Function() tokenProvider;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = tokenProvider();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }
}
