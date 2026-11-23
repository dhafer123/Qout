import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qout/features/settings/data/settings_repository.dart';
import 'package:qout/features/settings/presentation/theme_mode_provider.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockSettingsRepository repository;

  setUpAll(() => registerFallbackValue(ThemeMode.system));

  setUp(() {
    repository = _MockSettingsRepository();
    when(() => repository.saveThemeMode(any())).thenAnswer((_) async {});
  });

  ProviderContainer container({ThemeMode? initial}) {
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(repository),
        if (initial != null)
          initialThemeModeProvider.overrideWithValue(initial),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts on the mode read at startup (System by default)', () {
    expect(container().read(themeModeProvider), ThemeMode.system);
    expect(
      container(initial: ThemeMode.dark).read(themeModeProvider),
      ThemeMode.dark,
    );
  });

  test('a choice applies at once and is saved', () async {
    final c = container();
    final saving = c.read(themeModeProvider.notifier).choose(ThemeMode.light);
    expect(c.read(themeModeProvider), ThemeMode.light);
    await saving;
    verify(() => repository.saveThemeMode(ThemeMode.light)).called(1);
  });

  test('choosing the current mode saves nothing', () async {
    final c = container(initial: ThemeMode.dark);
    await c.read(themeModeProvider.notifier).choose(ThemeMode.dark);
    verifyNever(() => repository.saveThemeMode(any()));
  });

  test('a failed save brings the previous mode back and reports', () async {
    when(
      () => repository.saveThemeMode(any()),
    ).thenAnswer((_) async => throw StateError('disk full'));
    final c = container(initial: ThemeMode.light);
    await expectLater(
      c.read(themeModeProvider.notifier).choose(ThemeMode.dark),
      throwsStateError,
    );
    expect(c.read(themeModeProvider), ThemeMode.light);
  });

  test('a failed save keeps a choice made meanwhile', () async {
    final first = Completer<void>();
    when(
      () => repository.saveThemeMode(ThemeMode.dark),
    ).thenAnswer((_) => first.future);
    final c = container();
    final controller = c.read(themeModeProvider.notifier);

    final dark = controller.choose(ThemeMode.dark);
    await controller.choose(ThemeMode.light);
    first.completeError(StateError('disk full'));
    await expectLater(dark, throwsStateError);

    expect(c.read(themeModeProvider), ThemeMode.light);
  });
}
