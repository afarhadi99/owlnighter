import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api/repository_providers.dart';

/// Which phase the launcher is in — drives the copy shown on the loading
/// screen. Resolving is a cheap list lookup; generating is the (slow) AI call.
enum PlanLaunchPhase { resolving, generating }

/// State for opening a book's reading path. Get-or-create in one place:
///  1. [resolving] — `listPlans(bookId)` to find an existing plan.
///  2. if one exists → [planId] is set, no AI call (the reuse fast path).
///  3. otherwise [generating] → `generatePlan(bookId)`, then [planId].
/// A failure surfaces via [error] with the phase it failed in, so the UI can
/// show a full-screen retry (never a silent bounce back to the library).
@immutable
class PlanLaunchState {
  const PlanLaunchState({required this.phase, this.planId, this.error});

  final PlanLaunchPhase phase;
  final String? planId;
  final Object? error;

  bool get isReady => planId != null;
  bool get isError => error != null;
}

class PlanLauncher extends AutoDisposeFamilyNotifier<PlanLaunchState, String> {
  @override
  PlanLaunchState build(String bookId) {
    // Kick off resolution once when the provider is first read.
    Future.microtask(_resolve);
    return const PlanLaunchState(phase: PlanLaunchPhase.resolving);
  }

  Future<void> _resolve() async {
    final repo = ref.read(planRepositoryProvider);
    try {
      final existing = await repo.listPlans(bookId: arg);
      if (existing.isNotEmpty) {
        // listPlans returns newest planVersion first, but don't rely on order.
        final latest = existing.reduce(
          (a, b) => b.planVersion > a.planVersion ? b : a,
        );
        state = PlanLaunchState(
          phase: PlanLaunchPhase.resolving,
          planId: latest.planId,
        );
        return;
      }
      // No plan yet → author one. ifExists:reuse is a server-side safety net
      // against a race; the client only reaches here when the list was empty.
      state = const PlanLaunchState(phase: PlanLaunchPhase.generating);
      final plan = await repo.generatePlan(bookId: arg);
      state = PlanLaunchState(
        phase: PlanLaunchPhase.generating,
        planId: plan.planId,
      );
    } on Object catch (e) {
      state = PlanLaunchState(phase: state.phase, error: e);
    }
  }

  /// Retry after a failure. Because the server persists the plan even when the
  /// client times out, a retry usually finds it via [listPlans] and navigates
  /// straight through without a second (billable) generation.
  void retry() {
    state = const PlanLaunchState(phase: PlanLaunchPhase.resolving);
    Future.microtask(_resolve);
  }
}

final planLauncherProvider =
    AutoDisposeNotifierProviderFamily<PlanLauncher, PlanLaunchState, String>(
  PlanLauncher.new,
);
