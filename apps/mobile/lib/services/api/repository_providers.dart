import 'package:app_core/app_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../offline_sync/offline_providers.dart';
import 'api_providers.dart';
import 'repositories_impl.dart';

/// Repository providers. Features depend ONLY on these interface-typed
/// providers, never on the API client or Drift directly. That keeps the
/// dependency arrow pointing inward (UI → repo interface) and lets tests swap
/// in fakes with `overrideWithValue`.

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepositoryImpl(
    api: ref.watch(apiProvider),
    cache: ref.watch(offlineCacheProvider),
  );
});

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepositoryImpl(
    api: ref.watch(apiProvider),
    cache: ref.watch(offlineCacheProvider),
  );
});

final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  return QuizRepositoryImpl(
    api: ref.watch(apiProvider),
    cache: ref.watch(offlineCacheProvider),
    syncQueue: ref.watch(syncQueueProvider),
  );
});
