import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/features/settings/data/settings_repository.dart';

/// The theme mode saved when the app started: read in `main()` before the
/// first frame, so the first screen already has the right theme. System in
/// tests unless overridden.
final initialThemeModeProvider = Provider<ThemeMode>(
  (ref) => ThemeMode.system,
);

/// The theme mode the app uses now (T43b).
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(initialThemeModeProvider);

  /// Applies [mode] at once, then saves it. When saving fails the previous
  /// mode comes back (unless another choice was made meanwhile) and the
  /// error is rethrown for the caller to report.
  Future<void> choose(ThemeMode mode) async {
    final previous = state;
    if (mode == previous) return;
    state = mode;
    try {
      await ref.read(settingsRepositoryProvider).saveThemeMode(mode);
    } on Object {
      if (state == mode) state = previous;
      rethrow;
    }
  }
}
