import 'package:app_core/app_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin_debug/admin_debug_page.dart';
import '../features/auth/auth_page.dart';
import '../features/library/library_page.dart';
import '../features/nightly_session/nightly_session_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/quiz/completion_page.dart';
import '../features/quiz/quiz_page.dart';
import '../features/reading_path/plan_launcher_page.dart';
import '../features/reading_path/reading_path_page.dart';
import '../features/settings/settings_page.dart';
import '../features/streaks/streaks_page.dart';
import '../services/api/session_provider.dart';
import '../shared/util/env.dart';
import 'home_shell.dart';

/// Route path constants — one source of truth for navigation + deep links.
abstract final class Routes {
  static const auth = '/auth';
  static const onboarding = '/onboarding';
  static const library = '/library';
  static const streaks = '/streaks';
  static const settings = '/settings';
  static const adminDebug = '/admin';

  /// Opens a book with get-or-create semantics (see [PlanLauncherPage]).
  static String launch(String bookId) => '/book/$bookId/launch';
  static String plan(String planId) => '/plan/$planId';

  /// The path with the `celebrate` flag set, so it plays the unlock cue when a
  /// newly-available node appears after finishing a night.
  static String planCelebrate(String planId) => '/plan/$planId?celebrate=1';
  static String step(String planId, String stepId) =>
      '/plan/$planId/step/$stepId';
  static String quiz(String planId, String stepId, String quizId) =>
      '/plan/$planId/step/$stepId/quiz/$quizId';

  /// The full-screen completion sequence (pass the [QuizResult] via `extra`).
  static String complete(String planId) => '/plan/$planId/complete';
}

/// The app router. go_router is the single deep-link entry point: universal
/// (https) links and the `readingpath://` scheme both resolve to these routes
/// (see services/deep_links). Auth state drives the redirect guard.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: Routes.library,
    // Redirect unauthenticated users to /auth (except while on auth/onboarding).
    redirect: (context, state) {
      final loggedIn = auth.valueOrNull != null;
      final loc = state.matchedLocation;
      final onAuthFlow =
          loc == Routes.auth || loc.startsWith(Routes.onboarding);
      if (!loggedIn && !onAuthFlow) return Routes.auth;
      if (loggedIn && loc == Routes.auth) return Routes.library;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.auth,
        builder: (_, __) => const AuthPage(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, __) => const OnboardingPage(),
      ),

      // Bottom-nav shell: library / streaks / settings.
      ShellRoute(
        builder: (_, __, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: Routes.library,
            builder: (_, __) => const LibraryPage(),
          ),
          GoRoute(
            path: Routes.streaks,
            builder: (_, __) => const StreaksPage(),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (_, __) => const SettingsPage(),
          ),
        ],
      ),

      // Book launcher: get-or-create a plan, then render its path map.
      GoRoute(
        path: '/book/:bookId/launch',
        builder: (_, state) => PlanLauncherPage(
          bookId: state.pathParameters['bookId']!,
        ),
      ),

      // Reading path map for a plan (the game-like node map).
      GoRoute(
        path: '/plan/:planId',
        builder: (_, state) => ReadingPathPage(
          planId: state.pathParameters['planId']!,
          justCompleted: state.uri.queryParameters['celebrate'] == '1',
        ),
        routes: [
          // The full-screen completion sequence after finishing a night.
          GoRoute(
            path: 'complete',
            builder: (_, state) => CompletionPage(
              planId: state.pathParameters['planId']!,
              result: state.extra! as QuizResult,
            ),
          ),
          // Deep-link target: readingpath://plan/{planId}/step/{stepId}
          GoRoute(
            path: 'step/:stepId',
            builder: (_, state) => NightlySessionPage(
              planId: state.pathParameters['planId']!,
              stepId: state.pathParameters['stepId']!,
            ),
            routes: [
              GoRoute(
                path: 'quiz/:quizId',
                builder: (_, state) => QuizPage(
                  planId: state.pathParameters['planId']!,
                  stepId: state.pathParameters['stepId']!,
                  quizId: state.pathParameters['quizId']!,
                ),
              ),
            ],
          ),
        ],
      ),

      if (AppEnv.enableAdminDebug)
        GoRoute(
          path: Routes.adminDebug,
          builder: (_, __) => const AdminDebugPage(),
        ),
    ],
  );
});
