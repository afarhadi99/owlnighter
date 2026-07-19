import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owlnighter/features/library/library_page.dart';
import 'package:owlnighter/services/api/repository_providers.dart';

/// A stub library repository returning a fixed, enriched list. Only
/// [listLibrary] is exercised by LibraryPage's render path.
class _StubLibraryRepo implements LibraryRepository {
  _StubLibraryRepo(this.books);
  final List<UserBook> books;

  @override
  Future<List<UserBook>> listLibrary() async => books;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Widget _host(LibraryRepository repo) => ProviderScope(
      overrides: [libraryRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: const LibraryPage(),
        // Force reduced motion so NightScaffold's NightSky star-twinkle ticker
        // renders static and pumpAndSettle can complete (it repeats forever
        // otherwise).
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );

void main() {
  group('LibraryPage', () {
    testWidgets('renders the real book title and author, not the raw id',
        (tester) async {
      final repo = _StubLibraryRepo(const [
        UserBook(
          id: 'ub1',
          bookId: '3ce25e75-0000-0000-0000-000000000000',
          status: UserBookStatus.active,
          title: 'The Left Hand of Darkness',
          authors: ['Ursula K. Le Guin'],
        ),
      ]);
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      // The redesigned journey card shows the real title both on the storybook
      // spine cover and as the card heading, so it renders more than once.
      expect(find.text('The Left Hand of Darkness'), findsWidgets);
      expect(find.text('Ursula K. Le Guin'), findsOneWidget);
      // The old "Book 3ce25e75" placeholder must be gone.
      expect(find.textContaining('Book 3ce25e75'), findsNothing);
    });

    testWidgets('falls back to a short id when the item is un-enriched',
        (tester) async {
      final repo = _StubLibraryRepo(const [
        UserBook(
          id: 'ub2',
          bookId: 'abcd1234efgh',
          status: UserBookStatus.active,
        ),
      ]);
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      // Short-id fallback shows on both the spine cover and the card heading.
      expect(find.text('Book abcd1234'), findsWidgets);
    });

    testWidgets('shows the empty state when the library is empty',
        (tester) async {
      await tester.pumpWidget(_host(_StubLibraryRepo(const [])));
      await tester.pumpAndSettle();
      expect(find.text('No books yet'), findsOneWidget);
    });
  });
}
