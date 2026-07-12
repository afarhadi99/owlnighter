import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted "sound effects on/off" preference. Defaults to enabled and is
/// written through to [SharedPreferences] on every toggle. The current value is
/// held synchronously in state so [SfxService] can gate playback with a cheap
/// `ref.read` at fire time.
class SoundSettingsController extends StateNotifier<bool> {
  SoundSettingsController(this._prefsFuture) : super(_defaultEnabled) {
    _load();
  }

  static const _key = 'sfx.soundEnabled';
  static const _defaultEnabled = true;

  final Future<SharedPreferences> _prefsFuture;

  Future<void> _load() async {
    try {
      final prefs = await _prefsFuture;
      state = prefs.getBool(_key) ?? _defaultEnabled;
    } catch (_) {
      // Preferences unavailable (e.g. plugin missing in a test host): keep the
      // in-memory default rather than throwing.
    }
  }

  /// Flip the preference and persist it (best-effort).
  Future<void> toggle() => setEnabled(!state);

  Future<void> setEnabled(bool value) async {
    state = value;
    try {
      final prefs = await _prefsFuture;
      await prefs.setBool(_key, value);
    } catch (_) {
      // Persist failures are non-fatal; the in-memory state still gates SFX.
    }
  }
}

/// Async handle to the platform's [SharedPreferences]. Overridable in tests via
/// `SharedPreferences.setMockInitialValues({})`.
final sharedPreferencesProvider = Provider<Future<SharedPreferences>>(
  (ref) => SharedPreferences.getInstance(),
);

/// Whether UI sound effects are enabled. Toggle via `.notifier`.
final soundEnabledProvider =
    StateNotifierProvider<SoundSettingsController, bool>(
  (ref) => SoundSettingsController(ref.watch(sharedPreferencesProvider)),
);
