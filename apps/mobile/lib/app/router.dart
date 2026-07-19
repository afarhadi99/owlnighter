import 'package:app_core/app_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin_debug/admin_debug_page.dart';
import '../features/auth/activate_page.dart';
import '../features/auth/auth_page.dart';
import '../features/auth/signup_page.dart';
import '../features/library/library_page.dart';
import '../features/nightly_session/nightly_session_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/quiz/completion_page.dart';
import '../features/quiz/quiz_page.dart';
import '../features/reading_path/plan_launcher_page.dart';
import '../features/reading_path/reading_path_page.dart';
import '../features/settings/settings_page.dart';
import '../features/streaks/streaks_page.dart';
import '../services/api/activation_status_provider.dart';
import '../services/api/session_provider.dart';
import '../shared/util/env.dart';
import 'home_shell.dart';

/// Route path constants — one source of truth for navigation + deep links.
abstract final class Routes {
  static const auth = '/auth';
  static const signup = '/signup';
  /// Referral-code redemption gate: shown whenever there's a live session but
  /// no `profiles` row yet (Google sign-in, or a failed inline signup
  /// activation). See activationStatusProvider.
  static const activate = '/activate';
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
  // Whether the signed-in user has redeemed a referral code yet (activated a
  // `profiles` row). `null` (still loading, or the check errored) means
  // "unknown" — the gate below only acts on a definitive true/false so a slow
  // network call never forces a wrong redirect.
  final activation = ref.watch(activationStatusProvider);

  return GoRouter(
    initialLocation: Routes.library,
    // Redirect unauthenticated users to /auth (except while on
    // auth/signup/onboarding), and gate signed-in-but-unactivated users to
    // /activate until they redeem a referral code.
    redirect: (context, state) {
      final loggedIn = auth.valueOrNull != null;
      final loc = state.matchedLocation;
      final onAuthFlow = loc == Routes.auth ||
          loc == Routes.signup ||
          loc.startsWith(Routes.onboarding);

      if (!loggedIn) {
        return onAuthFlow ? null : Routes.auth;
      }

      final activated = activation.valueOrNull;
      if (activated == false && loc != Routes.activate) return Routes.activate;
      if (activated == true && loc == Routes.activate) return Routes.library;
      if (loc == Routes.auth || loc == Routes.signup) return Routes.library;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.auth,
        builder: (_, __) => const AuthPage(),
      ),
      GoRoute(
        path: Routes.signup,
        builder: (_, __) => const SignupPage(),
      ),
      GoRoute(
        path: Routes.activate,
        builder: (_, __) => const ActivatePage(),
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
