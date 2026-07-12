import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api/repository_providers.dart';
import '../../shared/theme/theme_re_exports.dart';
import '../../shared/widgets/async_value_view.dart';
import 'library_controller.dart';

/// Add-book flow: search catalog → pick candidate → ground → add to library.
Future<void> showAddBookSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.night900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.9,
      child: _AddBookSheet(),
    ),
  );
}

class _AddBookSheet extends ConsumerStatefulWidget {
  const _AddBookSheet();
  @override
  ConsumerState<_AddBookSheet> createState() => _AddBookSheetState();
}

class _AddBookSheetState extends ConsumerState<_AddBookSheet> {
  final _titleController = TextEditingController();
  String? _addingId;
  bool _searched = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _runSearch(String v) {
    setState(() => _searched = true);
    ref.read(bookSearchControllerProvider.notifier).search(v);
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(bookSearchControllerProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add a book', style: AppType.title),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Title or author',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: _runSearch,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: _searched
                ? AsyncValueView<List<CatalogCandidate>>(
                    value: results,
                    data: (candidates) => candidates.isEmpty
                        ? const _EmptyState(
                            message: 'No matches — try another title.',
                          )
                        : ListView.separated(
                            itemCount: candidates.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (_, i) => _CandidateTile(
                              candidate: candidates[i],
                              adding: _addingId == candidates[i].sourceId,
                              onAdd: () => _addCandidate(candidates[i]),
                            ),
                          ),
                  )
                : const _EmptyState(
                    message: 'Search for a title or author',
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCandidate(CatalogCandidate candidate) async {
    setState(() => _addingId = candidate.sourceId);
    try {
      final library = ref.read(libraryRepositoryProvider);
      final grounded = await library.groundBook(
        title: candidate.title,
        author: candidate.authors.isEmpty ? null : candidate.authors.first,
        candidates: [candidate],
      );
      await library.addLibraryBook(bookId: grounded.bookId);
      ref.invalidate(libraryProvider);
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not add: $e')));
      }
    } finally {
      if (mounted) setState(() => _addingId = null);
    }
  }
}

/// A NightSky-tinted empty state with the sleepy owl and a prompt.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: NightSky(starCount: 18, moonRadius: 18),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OwlMascot(state: OwlState.sleepy, size: 96),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.candidate,
    required this.adding,
    required this.onAdd,
  });
  final CatalogCandidate candidate;
  final bool adding;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final authors = candidate.authors.join(', ');
    final year = candidate.publishedYear;
    final meta = [
      if (authors.isNotEmpty) authors,
      if (year != null) '$year',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.night800,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.night700),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cover(coverUrl: candidate.coverUrl),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label,
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(color: AppColors.inkMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          adding
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : ChunkyButton(
                  label: 'Add',
                  onPressed: onAdd,
                ),
        ],
      ),
    );
  }
}

/// A small book cover thumbnail; falls back to a book glyph in a tinted tile.
class _Cover extends StatelessWidget {
  const _Cover({required this.coverUrl});
  final String? coverUrl;

  static const double _w = 44;
  static const double _h = 62;

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
