import 'package:app_core/app_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api/repository_providers.dart';

/// The user's library, offline-first from the local cache.
final libraryProvider = FutureProvider<List<UserBook>>((ref) async {
  return ref.watch(libraryRepositoryProvider).listLibrary();
});

/// Search state for the add-book flow.
class BookSearchController
    extends AutoDisposeAsyncNotifier<List<CatalogCandidate>> {
  @override
  Future<List<CatalogCandidate>> build() async => const [];

  Future<void> search(String title, {String? author}) async {
    if (title.trim().isEmpty) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(libraryRepositoryProvider);
      final result = await repo.searchBooks(title: title, author: author);
      return result.candidates;
    });
  }
}

final bookSearchControllerProvider = AutoDisposeAsyncNotifierProvider<
    BookSearchController, List<CatalogCandidate>>(BookSearchController.new);
