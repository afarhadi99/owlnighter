import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../shared/theme/theme_re_exports.dart';
import '../../shared/widgets/async_value_view.dart';
import 'add_book_sheet.dart';
import 'library_controller.dart';

/// The library tab: the user's books. Tapping a book opens its reading path;
/// the FAB starts the add-book search + ground flow.
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    return NightScaffold(
      title: 'Your library',
      showSky: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddBookSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add book'),
      ),
      body: AsyncValueView<List<UserBook>>(
        value: library,
        onRetry: () => ref.invalidate(libraryProvider),
        data: (books) => books.isEmpty
            ? const _EmptyLibrary()
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: books.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => _BookTile(book: books[i]),
              ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_stories_rounded,
                size: 56,
                color: AppColors.indigo400,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('No books yet', style: AppType.headline),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Add a book to build a nightly reading path.',
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
      );
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book});
  final UserBook book;

  @override
  Widget build(BuildContext context) {
    final author = book.authorLine;
    // Hand off to the launcher, which does get-or-create and owns the
    // full-screen loading/error states (no silent bounce back here).
    void open() => context.push(Routes.launch(book.bookId));
    return InkWell(
      onTap: open,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.night800,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.night700),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Cover(coverUrl: book.coverUrl),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    author ?? 'Status: ${book.status.wire}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ChunkyButton(
                    label: 'Continue',
                    icon: Icons.play_arrow_rounded,
                    onPressed: open,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small book cover: the real thumbnail when the list item carries one, else
/// a book glyph in a tinted tile. Network failures degrade to the glyph.
class _Cover extends StatelessWidget {
  const _Cover({required this.coverUrl});
  final String? coverUrl;

  static const double _w = 52;
  static const double _h = 74;

  @override
  Widget build(BuildContext context) {
    final url = coverUrl;
    final fallback = Container(
      width: _w,
      height: _h,
      decoration: BoxDecoration(
        color: AppColors.indigo500.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.menu_book_rounded, color: AppColors.indigo400),
    );
    if (url == null || url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Image.network(
        url,
        width: _w,
        height: _h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
