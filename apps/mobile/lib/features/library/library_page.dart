import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../shared/theme/theme_re_exports.dart';
import '../../shared/widgets/async_value_view.dart';
import 'add_book_sheet.dart';
import 'library_controller.dart';

/// The library tab: the user's books as little "journey" cards — a lamplit
/// progress bar per book, a serif title, and a status badge. Tapping a card
/// opens its reading path; the add-a-book affordance starts the search + ground
/// flow.
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    return NightScaffold(
      // The serif header lives in the body so it matches the prototype's
      // "Your shelf / Your library" hero.
      automaticallyImplyLeading: false,
      body: AsyncValueView<List<UserBook>>(
        value: library,
        onRetry: () => ref.invalidate(libraryProvider),
        data: (books) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            const _LibraryHeader(),
            const SizedBox(height: AppSpacing.md),
            if (books.isEmpty)
              const _EmptyLibrary()
            else
              for (final book in books) ...[
                _JourneyCard(book: book),
                const SizedBox(height: AppSpacing.md),
              ],
            _AddBookRow(onTap: () => showAddBookSheet(context)),
          ],
        ),
      ),
    );
  }
}

/// The "Your shelf / Your library" hero header.
class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR SHELF',
          style: AppType.caption.copyWith(
            color: AppColors.lamp,
            letterSpacing: 2.4,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text('Your library', style: AppType.title),
        const SizedBox(height: 6),
        Text(
          'Every book is a little journey. Keep one lamp lit at a time.',
          style: AppType.caption.copyWith(color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          children: [
            const OwlMascot(state: OwlState.greet, size: 96),
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
      );
}

/// A single book's "journey" card: cover, serif title + author, a status badge,
/// and a lamplit "Night X of Y" progress bar.
class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.book});
  final UserBook book;

  /// Best-effort nights math from the book's paging fields. Returns null when
  /// the data isn't rich enough to speak in nights (we then show pages, or
  /// nothing).
  ({int current, int total})? get _nights {
    final pages = book.pageCount;
    final perNight = book.targetNightlyPages;
    if (pages == null || perNight == null || perNight <= 0) return null;
    final total = (pages / perNight).ceil().clamp(1, 9999);
    final read = book.currentPage ?? 0;
    final current = (read / perNight).ceil().clamp(0, total);
    return (current: current, total: total);
  }

  double get _progress {
    if (book.status == UserBookStatus.completed) return 1;
    final pages = book.pageCount;
    final read = book.currentPage;
    if (pages == null || pages <= 0 || read == null) return 0;
    return (read / pages).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    void open() => context.push(Routes.launch(book.bookId));
    final finished = book.status == UserBookStatus.completed;
    final nights = _nights;
    final pct = (_progress * 100).round();

    final progressLabel = finished
        ? (nights != null ? 'All ${nights.total} nights read' : 'Finished')
        : (nights != null
            ? 'Night ${nights.current.clamp(1, nights.total)} of ${nights.total}'
            : (book.pageCount != null && book.currentPage != null
                ? 'Page ${book.currentPage} of ${book.pageCount}'
                : 'Reading'));

    return InkWell(
      onTap: open,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md - 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.night700, AppColors.night800],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Cover(title: book.displayTitle, coverUrl: book.coverUrl),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.headline,
                  ),
                  if (book.authorLine != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      book.authorLine!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption.copyWith(color: AppColors.faint),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  _StatusBadge(status: book.status),
                  const SizedBox(height: AppSpacing.sm + 2),
                  _LamplitProgress(
                    value: _progress,
                    finished: finished,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        progressLabel,
                        style: AppType.caption.copyWith(
                          color: AppColors.inkMuted,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: AppType.caption.copyWith(
                          color: AppColors.lamp,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

/// The lamplit progress track: a plum well with a warm lamp-gold fill (or a
/// green "finished" fill).
class _LamplitProgress extends StatelessWidget {
  const _LamplitProgress({required this.value, required this.finished});
  final double value;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: 7,
        decoration: BoxDecoration(
          color: AppColors.night600,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.line, width: 0.5),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: finished
                    ? const [AppColors.successJuiceEdge, AppColors.success500]
                    : const [AppColors.lampGlow, AppColors.lamp],
              ),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
      ),
    );
  }
}

/// Status pill: reading (twilight), resting/paused (muted), finished (good).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final UserBookStatus status;

  @override
  Widget build(BuildContext context) {
    final (String text, Color fg, Color bg, Color border) = switch (status) {
      UserBookStatus.active => (
          '● Reading tonight',
          AppColors.twilightHi,
          const Color(0x298E82F2),
          const Color(0x668E82F2),
        ),
      UserBookStatus.completed => (
          '✓ Finished',
          AppColors.good,
          const Color(0x2452E0A6),
          const Color(0x6652E0A6),
        ),
      UserBookStatus.paused => (
          'Resting',
          AppColors.inkMuted,
          const Color(0x1F9E97C4),
          AppColors.line,
        ),
      UserBookStatus.archived => (
          'Archived',
          AppColors.faint,
          const Color(0x1F9E97C4),
          AppColors.line,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: AppType.caption.copyWith(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// A small storybook book cover: the real thumbnail when present, else a
/// tinted spine-and-title card in the cozy style.
class _Cover extends StatelessWidget {
  const _Cover({required this.title, required this.coverUrl});
  final String title;
  final String? coverUrl;

  static const double _w = 60;
  static const double _h = 88;

  // A small palette of cozy spine gradients, chosen deterministically from the
  // title so a given book keeps the same colour.
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
      // Decode at the thumbnail's device-pixel size rather than the source
      // image's native resolution — covers come from Google Books/OpenLibrary
      // and are frequently much larger than this 60x88 slot, so without this
      // every card in the library list decodes (and keeps resident) a far
      // bigger bitmap than it ever paints.
      final dpr = MediaQuery.devicePixelRatioOf(context);
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Image.network(
          url,
          width: _w,
          height: _h,
          fit: BoxFit.cover,
          cacheWidth: (_w * dpr).round(),
          cacheHeight: (_h * dpr).round(),
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
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
          topRight: Radius.circular(7),
          bottomRight: Radius.circular(7),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xB3000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Spine highlight.
          Positioned(
            left: 5,
            top: 0,
            bottom: 0,
            child: Container(width: 1.5, color: const Color(0x24FFFFFF)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 6, 8),
            child: Text(
              title,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppType.serifFamily,
                fontFamilyFallback: AppType.serifFallback,
                fontSize: 9.5,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: Color(0xF2FFFFFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dashed "Add a book to your nights" affordance at the foot of the list.
class _AddBookRow extends StatelessWidget {
  const _AddBookRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: DottedBorderBox(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: AppColors.twilight,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add, size: 18, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Text(
                'Add a book to your nights',
                style: AppType.label.copyWith(color: AppColors.twilightHi),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A rounded dashed-border container in the twilight accent, for the add-book
/// affordance.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
        color: AppColors.line,
        radius: AppRadius.lg,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.twilight.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: child,
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        dashed.addPath(
          metric.extractPath(d, (d + 6).clamp(0.0, metric.length)),
          Offset.zero,
        );
        d += 11;
      }
    }
    canvas.drawPath(
      dashed,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) =>
      old.color != color || old.radius != radius;
}
