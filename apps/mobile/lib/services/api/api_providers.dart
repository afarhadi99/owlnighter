import 'package:api_client/api_client.dart';
import 'package:app_core/app_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/util/env.dart';
import 'session_provider.dart';

/// The composition root for network access. The API client reads the bearer
/// token lazily from the [SessionController] so it always sends the freshest
/// token after a refresh.
final apiProvider = Provider<OwlnighterApi>((ref) {
  final session = ref.watch(sessionControllerProvider);
  return OwlnighterApi(
    baseUrl: AppEnv.apiBaseUrl,
    tokenProvider: () => session.session?.accessToken,
  );
});
