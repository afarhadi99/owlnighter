import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

import '../../services/api/extras_api.dart';
import '../../shared/theme/theme_re_exports.dart';
import '../../shared/widgets/quiz_mode_badge.dart';

/// Renders one quiz question with the appropriate input for its kind.
///
/// Once [verdict] is set (the answer has been CHECKed) the options lock and
/// restyle for the instant-feedback loop: the chosen option turns green when
/// correct or red when wrong, and — if wrong — the correct option is revealed
/// in green.
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

  /// Instant-feedback verdict, present once the answer is checked. When set the
  /// inputs are locked.
  final QuizCheckResult? verdict;

  bool get _locked => verdict != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        QuizModeBadge(mode: question.quizMode),
        const SizedBox(height: AppSpacing.md),
        Text(question.prompt, style: AppType.headline),
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
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final option = options[i];
        final isSelected = selected == option;
        final isCorrectOption =
            verdict != null && option == verdict!.correctAnswer;
        return _OptionTile(
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

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.state,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final _OptionState state;
  final VoidCallback? onTap;

  ({Color fill, Color border, Color ink, IconData icon}) get _style {
    switch (state) {
      case _OptionState.idle:
        return (
          fill: AppColors.night800,
          border: AppColors.night700,
          ink: AppColors.inkMuted,
          icon: Icons.radio_button_unchecked_rounded,
        );
      case _OptionState.selected:
        return (
          fill: AppColors.indigo500.withValues(alpha: 0.18),
          border: AppColors.indigo500,
          ink: AppColors.indigo400,
          icon: Icons.radio_button_checked_rounded,
        );
      case _OptionState.correct:
        return (
          fill: AppColors.successJuice.withValues(alpha: 0.2),
          border: AppColors.successJuice,
          ink: AppColors.successJuice,
          icon: Icons.check_circle_rounded,
        );
      case _OptionState.wrong:
        return (
          fill: AppColors.danger500.withValues(alpha: 0.2),
          border: AppColors.danger500,
          ink: AppColors.danger500,
          icon: Icons.cancel_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: s.fill,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: s.border, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(s.icon, color: s.ink),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppType.body)),
          ],
        ),
      ),
    );
  }
}
