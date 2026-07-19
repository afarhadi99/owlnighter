import 'dart:math' as math;

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

import '../../services/api/extras_api.dart';
import '../../shared/theme/theme_re_exports.dart';
import '../../shared/widgets/quiz_mode_badge.dart';

/// Renders one quiz question with the appropriate input for its kind.
///
/// Wave-2 redesign: a serif question stem over big, lettered answer cards (A,
/// B, C…). Selecting an option lifts it into a twilight-violet state; once the
/// answer is CHECKed the options lock and play the instant-feedback beat — the
/// chosen option glows warm-green when correct or shakes red when wrong, and if
/// wrong the correct option is revealed in green. Motion collapses under
/// reduced-motion.
class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.question,
    required this.selected,
    required this.onSelect,
    this.verdict,
  });

  final QuizQuestion question;
  final String? selected;
  final ValueChanged<String> onSelect;

  /// Instant-feedback verdict, present once the answer has been CHECKed. When
  /// set the inputs are locked.
  final QuizCheckResult? verdict;

  bool get _locked => verdict != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        QuizModeBadge(mode: question.quizMode),
        const SizedBox(height: AppSpacing.md),
        Text(
          question.prompt,
          style: AppType.headline.copyWith(fontSize: 21, height: 1.35),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(child: _input(context)),
      ],
    );
  }

  Widget _input(BuildContext context) {
    switch (question.kind) {
      case QuizQuestionKind.multipleChoice:
        return _choices(question.options ?? const []);
      case QuizQuestionKind.trueFalse:
        return _choices(const ['True', 'False']);
      case QuizQuestionKind.shortAnswer:
        return _shortAnswer();
    }
  }

  Widget _choices(List<String> options) {
    return ListView.separated(
      itemCount: options.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm + 4),
      itemBuilder: (context, i) {
        final option = options[i];
        final isSelected = selected == option;
        final isCorrectOption =
            verdict != null && option == verdict!.correctAnswer;
        return _OptionTile(
          // Key by option so the tile keeps its own animation state across the
          // idle -> verdict transition (and re-triggers the feedback beat).
          key: ValueKey('${question.id}:$option'),
          letter: String.fromCharCode(65 + i), // A, B, C…
          label: option,
          selected: isSelected,
          state: _tileState(isSelected, isCorrectOption),
          onTap: _locked ? null : () => onSelect(option),
        );
      },
    );
  }

  /// The visual state for one option given the verdict.
  _OptionState _tileState(bool isSelected, bool isCorrectOption) {
    if (verdict == null) {
      return isSelected ? _OptionState.selected : _OptionState.idle;
    }
    // After checking: reveal the correct option in green; if the reader picked
    // a wrong one, mark it red.
    if (isCorrectOption) return _OptionState.correct;
    if (isSelected) return _OptionState.wrong;
    return _OptionState.idle;
  }

  Widget _shortAnswer() {
    return TextField(
      minLines: 3,
      maxLines: 6,
      enabled: !_locked,
      onChanged: onSelect,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Type your answer…',
      ),
    );
  }
}

enum _OptionState { idle, selected, correct, wrong }

/// A single lettered answer card. Runs the feedback beat (a warm glow pulse on
/// correct, a horizontal shake on wrong) once when its [state] becomes a graded
/// one. Both collapse under reduced motion.
class _OptionTile extends StatefulWidget {
  const _OptionTile({
    super.key,
    required this.letter,
    required this.label,
    required this.selected,
    required this.state,
    required this.onTap,
  });
  final String letter;
  final String label;
  final bool selected;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile>
    with SingleTickerProviderStateMixin {
  // Created eagerly in initState (not lazily at first paint) so it always
  // exists by dispose. Under reduced motion the feedback beat never runs, so a
  // lazy `late final` would be first touched in dispose() — which creates a
  // Ticker during unmount and crashes on an unsafe ancestor lookup.
  late final AnimationController _feedback;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _feedback = AnimationController(vsync: this, duration: AppMotion.slow);
  }

  @override
  void didUpdateWidget(covariant _OptionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fire the feedback beat once, on the transition into a graded state.
    final becameGraded = oldWidget.state != widget.state &&
        (widget.state == _OptionState.correct ||
            widget.state == _OptionState.wrong);
    if (becameGraded && !reduceMotionOf(context)) {
      _feedback.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  ({Color fill, Color border, Color key, Color keyInk, IconData? icon})
      get _style {
    switch (widget.state) {
      case _OptionState.idle:
        return (
          fill: AppColors.night700,
          border: AppColors.line,
          key: AppColors.night700,
          keyInk: AppColors.faint,
          icon: null,
        );
      case _OptionState.selected:
        return (
          fill: AppColors.indigo500.withValues(alpha: 0.14),
          border: AppColors.indigo400,
          key: AppColors.indigo500,
          keyInk: Colors.white,
          icon: null,
        );
      case _OptionState.correct:
        return (
          fill: AppColors.successJuice.withValues(alpha: 0.16),
          border: AppColors.successJuice,
          key: AppColors.successJuice,
          keyInk: AppColors.successJuiceEdge,
          icon: Icons.check_rounded,
        );
      case _OptionState.wrong:
        return (
          fill: AppColors.danger500.withValues(alpha: 0.14),
          border: AppColors.danger500,
          key: AppColors.danger500,
          keyInk: Colors.white,
          icon: Icons.close_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    final reduce = reduceMotionOf(context);
    final pressedSink = _pressed && widget.onTap != null && !reduce;

    Widget card = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: s.fill,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: s.border, width: 1.5),
      ),
      child: Row(
        children: [
          // The lettered key box (turns into a ✓ / ✗ badge once graded).
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.state == _OptionState.idle
                  ? Colors.transparent
                  : s.key,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: s.key, width: 1.5),
            ),
            child: s.icon != null
                ? Icon(s.icon, size: 18, color: s.keyInk)
                : Text(
                    widget.letter,
                    style: AppType.label.copyWith(
                      color: s.keyInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(widget.label, style: AppType.body),
          ),
        ],
      ),
    );

    // Feedback beat: correct pulses a warm glow, wrong shakes horizontally.
    if (!reduce) {
      card = AnimatedBuilder(
        animation: _feedback,
        builder: (context, child) {
          final t = _feedback.value;
          double dx = 0;
          BoxShadow? glow;
          if (widget.state == _OptionState.wrong && t > 0 && t < 1) {
            // Damped shake: a few oscillations that settle to zero.
            dx = math.sin(t * math.pi * 5) * 8 * (1 - t);
          } else if (widget.state == _OptionState.correct && t > 0 && t < 1) {
            final pulse = math.sin(t * math.pi); // 0→1→0
            glow = BoxShadow(
              color: AppColors.successJuice.withValues(alpha: 0.5 * pulse),
              blurRadius: 18 * pulse,
              spreadRadius: 3 * pulse,
            );
          }
          return Transform.translate(
            offset: Offset(dx, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: glow == null ? null : [glow],
              ),
              child: child,
            ),
          );
        },
        child: card,
      );
    }

    // Press micro-interaction (scale-down) only while tappable.
    card = AnimatedScale(
      scale: pressedSink ? 0.985 : 1,
      duration: AppMotion.instant,
      child: card,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:
          widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp:
          widget.onTap != null ? (_) => setState(() => _pressed = false) : null,
      onTapCancel:
          widget.onTap != null ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: card,
    );
  }
}
