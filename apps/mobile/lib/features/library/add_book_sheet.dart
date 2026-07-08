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
  bool _adding = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
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
            onSubmitted: (v) =>
                ref.read(bookSearchControllerProvider.notifier).search(v),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: AsyncValueView<List<CatalogCandidate>>(
              value: results,
              data: (candidates) => ListView.builder(
                itemCount: candidates.length,
                itemBuilder: (_, i) => _CandidateTile(
                  candidate: candidates[i],
                  adding: _adding,
                  onAdd: () => _addCandidate(candidates[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCandidate(CatalogCandidate candidate) async {
    setState(() => _adding = true);
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
      if (mounted) setState(() => _adding = false);
    }
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
    return ListTile(
      title: Text(candidate.title),
      subtitle: Text(candidate.authors.join(', ')),
      trailing: adding
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(),
            )
          : TextButton(onPressed: onAdd, child: const Text('Add')),
    );
  }
}
