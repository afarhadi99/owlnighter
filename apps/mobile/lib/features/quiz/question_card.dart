import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';

import '../../shared/theme/theme_re_exports.dart';
import '../../shared/widgets/quiz_mode_badge.dart';

/// Renders one quiz question with the appropriate input for its kind.
class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.question,
    required this.selected,
    required this.onSelect,
  });

  final QuizQuestion question;
  final String? selected;
  final ValueChanged<String> onSelect;

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
        return _OptionTile(
          label: option,
          selected: isSelected,
          onTap: () => onSelect(option),
        );
      },
    );
  }

  Widget _shortAnswer() {
    return TextField(
      minLines: 3,
      maxLines: 6,
      onChanged: onSelect,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Type your answer…',
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.indigo500.withValues(alpha: 0.18)
              : AppColors.night800,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.indigo500 : AppColors.night700,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.indigo400 : AppColors.inkMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppType.body)),
          ],
        ),
      ),
    );
  }
}
