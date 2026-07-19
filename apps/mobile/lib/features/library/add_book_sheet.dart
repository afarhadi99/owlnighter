import 'dart:async';

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
      heightFactor: 0.92,
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

  /// The title being grounded, shown on the progress moment.
  String? _groundingTitle;
  bool _searched = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _runSearch(String v) {
    if (v.trim().isEmpty) return;
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
        top: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grab handle.
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const Text('Add a book', style: AppType.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Find a title and we’ll pace it into cozy nightly reads.',
            style: AppType.caption.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_addingId == null) _SearchField(controller: _titleController, onSubmit: _runSearch),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: _addingId != null
                ? _GroundingView(title: _groundingTitle ?? 'your book')
                : _searched
                    ? AsyncValueView<List<CatalogCandidate>>(
                        value: results,
                        data: (candidates) => candidates.isEmpty
                            ? const _EmptyState(
                                message: 'No matches — try another title.',
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.xs,
                                ),
                                itemCount: candidates.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: AppSpacing.sm + 2),
                                itemBuilder: (_, i) => _CandidateTile(
                                  candidate: candidates[i],
                                  onAdd: () => _addCandidate(candidates[i]),
                                ),
                              ),
                      )
                    : const _EmptyState(
                        message: 'Search for a title or author',
                        owlState: OwlState.greet,
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCandidate(CatalogCandidate candidate) async {
    setState(() {
      _addingId = candidate.sourceId;
      _groundingTitle = candidate.title;
    });
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
        setState(() {
          _addingId = null;
          _groundingTitle = null;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not add: $e')));
      }
    }
  }
}

/// The prototype's rounded search bar: a plum well with a search glyph, a text
/// field, and a clear button that appears once there's text.
class _SearchField extends StatefulWidget {
  const _SearchField({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.night800,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.line, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: AppColors.faint),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: widget.controller,
              textInputAction: TextInputAction.search,
              style: AppType.body.copyWith(color: AppColors.moon),
              cursorColor: AppColors.twilightHi,
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
                hintText: 'Title or author',
                hintStyle:
                    AppType.body.copyWith(color: AppColors.faint),
              ),
              onSubmitted: widget.onSubmit,
            ),
          ),
          if (hasText)
            GestureDetector(
              onTap: () => widget.controller.clear(),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.faint,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A NightSky-tinted empty state with the owl and a prompt. Uses [OwlState.greet]
/// for the initial "come search" invitation, and [OwlState.sleepy] once a
/// search has come back empty (nothing to be excited about).
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, this.owlState = OwlState.sleepy});
  final String message;
  final OwlState owlState;

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
              OwlMascot(state: owlState, size: 96),
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

/// The "grounding…" progress moment shown while a chosen book is being grounded
/// and added. A breathing ring around a book glyph, a serif headline, and the
/// real pipeline steps cycling to give the wait a sense of motion. Honors
/// reduced motion by holding a steady, non-animating state.
class _GroundingView extends StatefulWidget {
  const _GroundingView({required this.title});
  final String title;

  @override
  State<_GroundingView> createState() => _GroundingViewState();
}

class _GroundingViewState extends State<_GroundingView> {
  static const _steps = [
    'Finding the book',
    'Grounding it in the real text',
    'Pacing chapters into nights',
    'Lighting your first lamp',
  ];

  Timer? _cycle;
  int _active = 0;

  @override
  void initState() {
    super.initState();
    // Advance the highlighted step on a gentle cadence for a sense of progress;
    // the last step stays lit until the real add completes and the sheet pops.
    _cycle = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted) return;
      setState(() {
        if (_active < _steps.length - 1) _active++;
      });
    });
  }

  @override
  void dispose() {
    _cycle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 130,
              height: 130,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: CircularProgressIndicator(
                      strokeWidth: 8,
                      value: reduce ? 0.35 : null,
                      backgroundColor: AppColors.night600,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.twilightHi,
                      ),
                    ),
                  ),
                  _BreathingIcon(reduce: reduce),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Grounding your book…',
              textAlign: TextAlign.center,
              style: AppType.title,
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                'Pacing “${widget.title}” into cozy nightly reads — this can '
                'take a moment.',
                textAlign: TextAlign.center,
                style: AppType.caption.copyWith(color: AppColors.inkMuted),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            for (var i = 0; i < _steps.length; i++)
              _GroundStep(
                label: _steps[i],
                index: i,
                active: i == _active,
                done: i < _active,
              ),
          ],
        ),
      ),
    );
  }
}

class _BreathingIcon extends StatefulWidget {
  const _BreathingIcon({required this.reduce});
  final bool reduce;

  @override
  State<_BreathingIcon> createState() => _BreathingIconState();
}

class _BreathingIconState extends State<_BreathingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduce) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const icon = Icon(
      Icons.auto_stories_rounded,
      size: 40,
      color: AppColors.twilightHi,
    );
    if (widget.reduce) return icon;
    return ScaleTransition(
      scale: Tween(begin: 0.92, end: 1.08).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: icon,
    );
  }
}

/// One step in the grounding pipeline: a numbered/checked dot and a label whose
/// emphasis reflects pending / active / done.
class _GroundStep extends StatelessWidget {
  const _GroundStep({
    required this.label,
    required this.index,
    required this.active,
    required this.done,
  });

  final String label;
  final int index;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final Color labelColor =
        done ? AppColors.inkMuted : (active ? AppColors.moon : AppColors.faint);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.success500 : Colors.transparent,
              border: Border.all(
                color: done
                    ? AppColors.success500
                    : (active ? AppColors.twilightHi : AppColors.line),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: done
                ? const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Color(0xFF053D29),
                  )
                : Text(
                    '${index + 1}',
                    style: AppType.caption.copyWith(
                      color: active ? AppColors.twilightHi : AppColors.faint,
                      fontSize: 12,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Text(
            label,
            style: AppType.body.copyWith(color: labelColor, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.candidate,
    required this.onAdd,
  });
  final CatalogCandidate candidate;
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
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.night800,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Cover(title: candidate.title, coverUrl: candidate.coverUrl),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.headline.copyWith(fontSize: 15.5),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(color: AppColors.faint),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ChunkyButton(label: 'Add', onPressed: onAdd),
        ],
      ),
    );
  }
}

/// A small storybook book cover: the real thumbnail when present, else a
/// tinted spine-and-title card in the cozy style (matches the library card).
class _Cover extends StatelessWidget {
  const _Cover({required this.title, required this.coverUrl});
  final String title;
  final String? coverUrl;

  static const double _w = 46;
  static const double _h = 66;

  static const List<List<Color>> _spines = [
    [Color(0xFF2F6D4F), Color(0xFF17492F)],
    [Color(0xFF3A2D6B), Color(0xFF1C1746)],
    [Color(0xFF8A3B2E), Color(0xFF5A2019)],
    [Color(0xFF3F6D8A), Color(0xFF204152)],
    [Color(0xFF6A3A63), Color(0xFF331A37)],
    [Color(0xFFB5761F), Color(0xFF6E3D0D)],
  ];

  @override
  Widget build(BuildContext context) {
    final url = coverUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Image.network(
          url,
          width: _w,
          height: _h,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final colors = _spines[title.hashCode.abs() % _spines.length];
    return Container(
      width: _w,
      height: _h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(3),
          bottomLeft: Radius.circular(3),
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 7, 5, 6),
        child: Text(
          title,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppType.serifFamily,
            fontFamilyFallback: AppType.serifFallback,
            fontSize: 8,
            height: 1.15,
            fontWeight: FontWeight.w700,
            color: Color(0xF2FFFFFF),
          ),
        ),
      ),
    );
  }
}
