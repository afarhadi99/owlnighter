/// Deep-link parsing. Two link forms per the blueprint:
///   - Universal/app links: https://<host>/plan/{planId}/step/{stepId}
///   - Native scheme:        readingpath://plan/{planId}/step/{stepId}
///
/// go_router handles the *navigation*; this module only normalizes inbound URIs
/// (from push opens, email links, admin "open on device") to an in-app route
/// path go_router understands, so there is a single entry path.

abstract final class DeepLinks {
  static const String scheme = 'readingpath';

  /// Convert any supported inbound [uri] to a go_router location, or null if it
  /// isn't a recognized deep link.
  static String? toRouteLocation(Uri uri) {
    // readingpath://plan/{planId}/step/{stepId}
    if (uri.scheme == scheme) {
      // host = "plan", pathSegments = [planId, "step", stepId]
      final segs = [uri.host, ...uri.pathSegments]
          .where((s) => s.isNotEmpty)
          .toList();
      return _planStepLocation(segs);
    }
    // https://<host>/plan/{planId}/step/{stepId}
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      return _planStepLocation(uri.pathSegments);
    }
    return null;
  }

  static String? _planStepLocation(List<String> segs) {
    // Expect: [plan, planId, step, stepId]
    if (segs.length >= 4 && segs[0] == 'plan' && segs[2] == 'step') {
      final planId = segs[1];
      final stepId = segs[3];
      return '/plan/$planId/step/$stepId';
    }
    // Expect: [plan, planId]
    if (segs.length >= 2 && segs[0] == 'plan') {
      return '/plan/${segs[1]}';
    }
    return null;
  }

  /// Build the outbound native-scheme link for a step (used by share/admin).
  static Uri stepLink(String planId, String stepId) =>
      Uri.parse('$scheme://plan/$planId/step/$stepId');
}
