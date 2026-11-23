import 'package:drift/native.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/features/settings/data/settings_repository.dart';

class _MockSettingsDao extends Mock implements SettingsDao {}

void main() {
  late AppDatabase database;
  late SettingsRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = SettingsRepository(dao: database.settingsDao);
  });

  tearDown(() => database.close());

  test('System while nothing was chosen', () async {
    expect(await repository.themeMode(), ThemeMode.system);
  });

  test('every mode is saved and read back', () async {
    for (final mode in ThemeMode.values) {
      await repository.saveThemeMode(mode);
      expect(await repository.themeMode(), mode);
    }
  });

  test('stored as the mode name', () async {
    await repository.saveThemeMode(ThemeMode.dark);
    expect(await database.settingsDao.themeMode(), 'dark');
  });

  test('an unknown stored value reads as System', () async {
    await database.settingsDao.saveThemeMode('sepia');
    expect(await repository.themeMode(), ThemeMode.system);
  });

  test('a read failure gives System instead of failing', () async {
    final dao = _MockSettingsDao();
    when(dao.themeMode).thenThrow(StateError('database locked'));
    expect(
      await SettingsRepository(dao: dao).themeMode(),
      ThemeMode.system,
    );
  });

  test('parseThemeMode', () {
    expect(parseThemeMode('light'), ThemeMode.light);
    expect(parseThemeMode('dark'), ThemeMode.dark);
    expect(parseThemeMode('system'), ThemeMode.system);
    expect(parseThemeMode(null), ThemeMode.system);
    expect(parseThemeMode(''), ThemeMode.system);
    expect(parseThemeMode('Dark'), ThemeMode.system);
  });
}
