import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/database/database_provider.dart';

/// App preferences (T43b), on the phone only. Not personal data: deleting
/// the profile or the diary keeps them.
class SettingsRepository {
  SettingsRepository({required SettingsDao dao}) : _dao = dao;

  final SettingsDao _dao;

  /// The chosen theme mode; [ThemeMode.system] while none was chosen, or
  /// when the stored value is unknown or can't be read (a preference never
  /// stops the app from starting).
  Future<ThemeMode> themeMode() async {
    try {
      return parseThemeMode(await _dao.themeMode());
    } on Object {
      return ThemeMode.system;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) => _dao.saveThemeMode(mode.name);
}

/// [value] as stored (a [ThemeMode] name); [ThemeMode.system] otherwise.
ThemeMode parseThemeMode(String? value) =>
    ThemeMode.values.asNameMap()[value] ?? ThemeMode.system;

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(dao: ref.watch(appDatabaseProvider).settingsDao),
);
