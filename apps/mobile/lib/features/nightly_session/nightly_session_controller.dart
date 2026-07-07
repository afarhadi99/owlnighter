import 'package:app_core/app_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api/repository_providers.dart';
import '../../services/offline_sync/offline_providers.dart';

/// Resolves the [PlanStep] for a nightly session. Offline-first: reads the
/// prefetched step from the local cache so the session opens with no network
/// (the blueprint's hard rule). Family-keyed by stepId.
final nightlyStepProvider =
    FutureProvider.family<PlanStep?, String>((ref, stepId) async {
  final cache = ref.watch(offlineCacheProvider);
  return cache.planStep(stepId);
});

/// State of generating tonight's quiz. Kept as an AsyncNotifier so the UI can
/// show a spinner on the "Start quiz" button and surface errors inline.
class QuizGenController extends AutoDisposeAsyncNotifier<QuizInstance?> {
  @override
  Future<QuizInstance?> build() async => null;

  Future<QuizInstance> generate(
    String stepId, {
    String? userProvidedText,
    int questionCount = 4,
    bool regenerate = false,
  }) async {
    final repo = ref.read(quizRepositoryProvider);
    state = const AsyncLoading();
    final quiz = await repo.generateStepQuiz(
      stepId: stepId,
      userProvidedText: userProvidedText,
      questionCount: questionCount,
      regenerate: regenerate,
    );
    state = AsyncData(quiz);
    return quiz;
  }
}

final quizGenControllerProvider =
    AutoDisposeAsyncNotifierProvider<QuizGenController, QuizInstance?>(
  QuizGenController.new,
);
