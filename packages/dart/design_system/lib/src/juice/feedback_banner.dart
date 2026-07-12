import 'package:flutter/material.dart';

import '../tokens.dart';
import '../motion/reduced_motion.dart';

/// Whether a [FeedbackBanner] reports a correct or incorrect answer.
enum FeedbackKind { success, error }

/// The bottom-anchored result banner that springs up after a quiz answer — the
/// instant per-question feedback loop from the game-app pattern.
///
/// * [FeedbackKind.success] — green-tinted, an icon + [title] heading row
///   (e.g. "Nicely done!").
/// * [FeedbackKind.error] — red-tinted, the [title] plus a "Correct answer:"
///   detail line built from [correctAnswer].
///
/// It hosts a trailing [action] slot — typically a success/danger [ChunkyButton]
/// labelled CONTINUE. The banner slides + springs up on appear; reduced motion
/// fades only. Drive appearance by mounting/unmounting the widget (e.g. inside
/// an [AnimatedSwitcher]) or toggling [visible].
class FeedbackBanner extends StatefulWidget {
  const FeedbackBanner({
    super.key,
    required this.kind,
    required this.title,
    this.correctAnswer,
    this.correctAnswerLabel = 'Correct answer:',
    this.action,
    this.visible = true,
  });

  final FeedbackKind kind;
  final String title;

  /// Shown on the error variant after [correctAnswerLabel].
  final String? correctAnswer;

  /// Localizable prefix for the correct-answer detail line.
  final String correctAnswerLabel;

  /// Trailing action, e.g. a CONTINUE [ChunkyButton].
  final Widget? action;

  /// Drives the enter/exit transition.
  final bool visible;

  @override
  State<FeedbackBanner> createState() => _FeedbackBannerState();
}

class _FeedbackBannerState extends State<FeedbackBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.base,
  );

  @override
  void initState() {
    super.initState();
    if (widget.visible) _controller.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _drive();
  }

  @override
  void didUpdateWidget(covariant FeedbackBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) _drive();
  }

  void _drive() {
    if (reduceMotionOf(context)) {
      _controller.value = widget.visible ? 1 : 0;
      return;
    }
    if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final isSuccess = widget.kind == FeedbackKind.success;
    final accent = isSuccess ? AppColors.successJuice : AppColors.danger500;
    final tint = accent.withValues(alpha: 0.16);
    final heading =
        isSuccess ? AppColors.successJuiceEdge : AppColors.dangerEdge;

    final banner = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: tint,
        border: Border(top: BorderSide(color: accent, width: 2)),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration:
                    BoxDecoration(color: accent, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(
                  isSuccess ? Icons.check_rounded : Icons.close_rounded,
                  size: 20,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.title,
                  style: AppType.headline.copyWith(
                    color: heading,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (!isSuccess && widget.correctAnswer != null) ...[
            const SizedBox(height: AppSpacing.sm),
            RichText(
              text: TextSpan(
                style: AppType.body.copyWith(color: heading),
                children: [
                  TextSpan(
                    text: '${widget.correctAnswerLabel} ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: widget.correctAnswer),
                ],
              ),
            ),
          ],
          if (widget.action != null) ...[
            const SizedBox(height: AppSpacing.md),
            widget.action!,
          ],
        ],
      ),
    );

    if (reduce) {
      return FadeTransition(opacity: _controller, child: banner);
    }

    final slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.bounce),
    );
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(position: slide, child: banner),
    );
  }
}
