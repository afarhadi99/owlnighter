import 'package:flutter/widgets.dart';

/// Reduced-motion helper. Centralizing the [MediaQuery.disableAnimations] read
/// means every motion widget respects the OS accessibility preference the same
/// way, and we never duplicate the null-fallback logic.
bool reduceMotionOf(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;
