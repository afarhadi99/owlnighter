import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Returns the push platform string expected by the API contract
/// (`"ios" | "android" | "web"`).
String currentPushPlatform() {
  if (kIsWeb) return 'web';
  if (Platform.isIOS) return 'ios';
  return 'android';
}
