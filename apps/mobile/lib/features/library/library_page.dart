import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../services/api/repository_providers.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Your library')),
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

class _BookTile extends ConsumerStatefulWidget {
  const _BookTile({required this.book});
  final UserBook book;

  @override
  ConsumerState<_BookTile> createState() => _BookTileState();
}

class _BookTileState extends ConsumerState<_BookTile> {
  bool _opening = false;

  /// Open the book's reading path. There is no plan-lookup-by-book endpoint, so
  /// we call plans/generate, which creates-or-refreshes the plan and returns
  /// its id — then navigate to the path map.
  Future<void> _open() async {
    setState(() => _opening = true);
    try {
      final plan = await ref
          .read(planRepositoryProvider)
          .generatePlan(bookId: widget.book.bookId);
      if (!mounted) return;
      context.push(Routes.plan(plan.planId));
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open book: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.menu_book_rounded),
        title: Text('Book ${book.bookId.substring(0, 8)}'),
        subtitle: Text('Status: ${book.status.wire}'),
        trailing: _opening
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap: _opening ? null : _open,
      ),
    );
  }
}
