import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted light/dark preference. Defaults to light. The app root
/// ([PetaFindsApp]) forces light for admins regardless of this value and
/// keeps `appBrightness` (which [AppColors] reads) in sync with the
/// resolved mode.
final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController();
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  static const _key = 'theme_mode_dark_v1';

  ThemeModeController() : super(ThemeMode.light) {
    _load();
  }

  bool get isDark => state == ThemeMode.dark;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_key) ?? false) state = ThemeMode.dark;
    } catch (_) {
      // Prefs unavailable — stay on the light default.
    }
  }

  Future<void> setDark(bool dark) async {
    state = dark ? ThemeMode.dark : ThemeMode.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, dark);
    } catch (_) {
      // Best-effort persistence; the in-memory state still applies.
    }
  }

  Future<void> toggle() => setDark(state != ThemeMode.dark);
}
