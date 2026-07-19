import 'package:app_core/app_core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:owlnighter/features/reading_path/reading_path_page.dart';
import 'package:owlnighter/services/api/repository_providers.dart';
import 'package:owlnighter/services/sfx/sound_effect.dart';

import 'support/fake_sfx.dart';

/// Serves a fixed plan so the path map renders deterministically. Only
/// [getPlan] is exercised by the reading-path screen.
class _StubPlanRepo implements PlanRepository {
  _StubPlanRepo(this.plan);
  final ReadingPlan plan;

  @override
  Future<ReadingPlan> getPlan(String planId) async => plan;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

ReadingPlan _plan() => ReadingPlan(
      planId: 'p1',
      bookId: 'b1',
      provider: AiProvider.groq,
      providerModel: 'test',
      planVersion: 1,
      pacingMode: PacingMode.standard,
      nightlyGoalPages: 20,
      startsOn: DateTime(2026, 7, 1),
      steps: const [
        PlanStep(
          stepIndex: 0,
          title: 'Chapter One',
          quizMode: QuizMode.grounded,
          prompt: 'Read chapter one.',
          confidence: 0.9,
        ),
        PlanStep(
          stepIndex: 1,
          title: 'Chapter Two',
          quizMode: QuizMode.grounded,
          prompt: 'Read chapter two.',
          confidence: 0.9,
        ),
      ],
      stepStates: const [
        PlanStepState(
          stepId: 's0',
          stepIndex: 0,
          status: StepStatus.available,
        ),
        PlanStepState(
          stepId: 's1',
          stepIndex: 1,
          status: StepStatus.locked,
        ),
      ],
    );

Widget _host(PlanRepository repo, FakeSfxService sfx) {
  // A minimal router so the node's `context.push` to the step route resolves
  // (tapping a node navigates); the step target is a bare placeholder.
  final router = GoRouter(
    initialLocation: '/plan/p1',
    routes: [
      GoRoute(
        path: '/plan/:planId',
        builder: (_, state) =>
            ReadingPathPage(planId: state.pathParameters['planId']!),
        routes: [
          GoRoute(
            path: 'step/:stepId',
            builder: (_, __) => const Scaffold(body: Text('step')),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      planRepositoryProvider.overrideWithValue(repo),
      overrideSfxWith(sfx),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      // Force reduced motion so the NightSky/PathScenery tickers stop and
      // pumpAndSettle can complete (they repeat() forever otherwise).
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    ),
  );
}

void main() {
  group('ReadingPathPage', () {
    testWidgets('renders the night-sky + scenery layers behind the trail',
        (tester) async {
      await tester.pumpWidget(_host(_StubPlanRepo(_plan()), FakeSfxService()));
      await tester.pumpAndSettle();

      // The new art layers are present behind the painted path.
      expect(find.byType(NightSky), findsOneWidget);
      expect(find.byType(PathScenery), findsOneWidget);
      // The redesigned trail renders one node per step: each carries its
      // "NIGHT n" kicker and the step title.
      expect(find.text('NIGHT 1'), findsOneWidget);
      expect(find.text('NIGHT 2'), findsOneWidget);
      expect(find.text('Chapter One'), findsOneWidget);
      expect(find.text('Chapter Two'), findsOneWidget);
    });

    testWidgets('tapping the available node plays the tap cue', (tester) async {
      final sfx = FakeSfxService();
      await tester.pumpWidget(_host(_StubPlanRepo(_plan()), sfx));
      await tester.pumpAndSettle();

      // Tap the available (tonight's) node — it carries the open-book icon.
      // The locked second node has a lock icon and is not tappable.
      await tester.tap(find.byIcon(Icons.auto_stories_rounded));
      await tester.pump();

      expect(sfx.played, contains(SoundEffect.tap));
    });
  });
}
