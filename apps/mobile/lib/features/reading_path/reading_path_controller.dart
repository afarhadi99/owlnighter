import 'package:app_core/app_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api/repository_providers.dart';

/// Loads and exposes a [ReadingPlan] for the path map. Family-scoped by planId.
final readingPathControllerProvider =
    FutureProvider.family<ReadingPlan, String>((ref, planId) async {
  final repo = ref.watch(planRepositoryProvider);
  return repo.getPlan(planId);
});
