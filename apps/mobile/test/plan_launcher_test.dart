import 'dart:async';

import 'package:api_client/api_client.dart' show ApiException;
import 'package:app_core/app_core.dart';
import 'package:design_system/design_system.dart'
    show ChunkyButton, ProgressRing;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owlnighter/features/reading_path/plan_launcher_controller.dart';
import 'package:owlnighter/features/reading_path/plan_launcher_page.dart';
import 'package:owlnighter/services/api/repository_providers.dart';

import 'support/fake_sfx.dart';

/// Builds a minimal full plan for getPlan / generate results.
ReadingPlan _plan(String planId, {String bookId = 'b1'}) => ReadingPlan(
      planId: planId,
      bookId: bookId,
      provider: AiProvider.gemini,
      providerModel: 'gemini-2.0',
      planVersion: 1,
      pacingMode: PacingMode.standard,
      nightlyGoalPages: 10,
      startsOn: DateTime(2026, 1, 1),
      steps: const [
        PlanStep(
          stepIndex: 0,
          title: 'Opening chapter',
          quizMode: QuizMode.grounded,
          prompt: 'p',
          confidence: 0.9,
        ),
      ],
      stepStates: const [
        PlanStepState(
          stepId: 's1',
          stepIndex: 0,
          status: StepStatus.available,
        ),
      ],
    );

PlanSummary _summary(String planId, {int version = 1, String bookId = 'b1'}) =>
    PlanSummary(
      planId: planId,
      bookId: bookId,
      planVersion: version,
      pacingMode: PacingMode.standard,
      nightlyGoalPages: 10,
      startsOn: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
    );

/// A configurable fake so tests can drive the reuse / generate / error paths
/// without any network. Records call counts so we can assert the AI call is
/// skipped on the reuse path.
class _FakePlanRepo implements PlanRepository {
  _FakePlanRepo({
    this.plans = const [],
    this.generateError,
    this.hangGenerate = false,
  });

  List<PlanSummary> plans;
  Object? generateError;
  bool hangGenerate;

  int listCalls = 0;
  int generateCalls = 0;

  @override
  Future<List<PlanSummary>> listPlans({required String bookId}) {
    listCalls++;
    return Future.value(List<PlanSummary>.of(plans));
  }

  @override
  Future<ReadingPlan> generatePlan({
    required String bookId,
    String goal = 'build nightly habit',
    String experience = 'returning',
    PacingMode pacingMode = PacingMode.standard,
    String? bedtimeLocal,
    int maxMinutes = 25,
    String timezone = 'UTC',
    AiProvider? provider,
    PlanIfExists ifExists = PlanIfExists.reuse,
  }) {
    generateCalls++;
    if (hangGenerate) return Completer<ReadingPlan>().future;
    if (generateError != null) return Future.error(generateError!);
    return Future.value(_plan('generated', bookId: bookId));
  }

  @override
  Future<ReadingPlan> getPlan(String planId) => Future.value(_plan(planId));

  @override
  Future<void> startStep(String stepId) async {}
}

Widget _host(PlanRepository repo, {String bookId = 'b1'}) => ProviderScope(
      overrides: [
        planRepositoryProvider.overrideWithValue(repo),
        // The reuse path renders ReadingPathPage; give it a silent SFX service
        // and reduced motion so its NightSky/PathScenery tickers don't hang
        // pumpAndSettle.
        overrideSfxWith(FakeSfxService()),
      ],
      child: MaterialApp(
        home: PlanLauncherPage(bookId: bookId),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );

ApiException _timeout() => ApiException(
      statusCode: null,
      code: 'timeout',
      message: 'The request timed out.',
    );

void main() {
  group('PlanLauncherPage', () {
    testWidgets('shows the full-screen crafting state while generating',
        (tester) async {
      // No existing plan + a generation that never returns → stays generating.
      final repo = _FakePlanRepo(plans: const [], hangGenerate: true);
      await tester.pumpWidget(_host(repo));
      // Let the resolve microtask + listPlans complete and move to generating.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Crafting your nightly path…'), findsOneWidget);
      expect(find.byType(ProgressRing), findsOneWidget);
      expect(repo.listCalls, 1);
      expect(repo.generateCalls, 1);
    });

    testWidgets('shows a retryable error, then recovers via listPlans on retry',
        (tester) async {
      // First open: no plan, generation fails (timeout) → error state.
      final repo = _FakePlanRepo(plans: const [], generateError: _timeout());
      await tester.pumpWidget(_host(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Couldn’t open your path'), findsOneWidget);
      // The retry CTA is now a ChunkyButton (label rendered uppercase).
      expect(find.widgetWithText(ChunkyButton, 'RETRY'), findsOneWidget);
      expect(repo.generateCalls, 1);

      // The server actually persisted the plan; a retry now finds it and never
      // regenerates — the exact fix for the reported bug.
      repo.plans = [_summary('p1')];
      await tester.tap(find.widgetWithText(ChunkyButton, 'RETRY'));
      await tester.pumpAndSettle();

      expect(find.text('Couldn’t open your path'), findsNothing);
      // The redesigned reading path leads with a "NOW READING" hero kicker.
      expect(find.text('NOW READING'), findsOneWidget);
      expect(find.text('Opening chapter'), findsWidgets);
      // Still only the one (failed) generate; retry reused the persisted plan.
      expect(repo.generateCalls, 1);
    });

    testWidgets('reuse fast path: an existing plan renders without generating',
        (tester) async {
      final repo = _FakePlanRepo(plans: [_summary('p1')]);
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      expect(find.text('NOW READING'), findsOneWidget);
      expect(find.text('Opening chapter'), findsWidgets);
      expect(repo.listCalls, 1);
      expect(repo.generateCalls, 0);
    });
  });

  group('PlanLauncher (reuse selection)', () {
    test('picks the highest planVersion and skips generation', () async {
      final repo = _FakePlanRepo(
        plans: [
          _summary('old', version: 1),
          _summary('newest', version: 3),
          _summary('mid', version: 2),
        ],
      );
      final container = ProviderContainer(
        overrides: [planRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        planLauncherProvider('b1'),
        (_, __) {},
        fireImmediately: true,
      );

      // Wait for the resolve microtask/futures to settle.
      for (var i = 0; i < 10 && !sub.read().isReady; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final state = sub.read();
      expect(state.isReady, isTrue);
      expect(state.planId, 'newest');
      expect(repo.generateCalls, 0);
    });
  });
}
