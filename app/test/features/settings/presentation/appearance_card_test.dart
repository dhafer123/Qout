import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/features/profile/data/profile_repository.dart';
import 'package:qout/features/settings/data/settings_repository.dart';
import 'package:qout/features/settings/presentation/theme_mode_provider.dart';
import 'package:qout/health/profile.dart';

import '../../../helpers/pump_app.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

final _profile = Profile(
  sex: Sex.male,
  age: 23,
  heightCm: 178,
  weightKg: 65,
  activity: ActivityLevel.active,
);

void main() {
  late AppDatabase database;

  setUpAll(() => registerFallbackValue(ThemeMode.system));

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  /// The Profile tab on a tall screen, the phone in [phone] mode, the
  /// appearance card in view.
  Future<void> openProfile(
    WidgetTester tester, {
    Brightness phone = Brightness.light,
    ThemeMode initial = ThemeMode.system,
    bool liveProfile = false,
    SettingsRepository? settings,
  }) async {
    tester.view
      ..physicalSize = const Size(500, 2400)
      ..devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = phone;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });
    await tester.pumpQoutApp(
      database: database,
      profile: _profile,
      liveProfile: liveProfile,
      overrides: [
        initialThemeModeProvider.overrideWithValue(initial),
        if (settings != null)
          settingsRepositoryProvider.overrideWithValue(settings),
      ],
    );
    await tester.pushRoute(AppRoutes.profile);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Dark'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  /// The brightness the app is drawn in now.
  Brightness appBrightness(WidgetTester tester) =>
      Theme.of(tester.element(find.text('Appearance'))).brightness;

  /// The segment shown as selected.
  Set<ThemeMode> selected(WidgetTester tester) => tester
      .widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>),
      )
      .selected;

  Future<void> choose(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('System by default: the app follows the phone', (tester) async {
    await openProfile(tester, phone: Brightness.dark);
    expect(selected(tester), {ThemeMode.system});
    expect(appBrightness(tester), Brightness.dark);
    await tester.unmountQoutApp();
  });

  testWidgets('Dark on a light phone: dark at once, and saved', (
    tester,
  ) async {
    await openProfile(tester);
    expect(appBrightness(tester), Brightness.light);

    await choose(tester, 'Dark');
    expect(selected(tester), {ThemeMode.dark});
    expect(appBrightness(tester), Brightness.dark);
    expect(
      await tester.runAsync(() => database.settingsDao.themeMode()),
      'dark',
    );
    await tester.unmountQoutApp();
  });

  testWidgets('Light on a dark phone, then back to System', (tester) async {
    await openProfile(tester, phone: Brightness.dark);

    await choose(tester, 'Light');
    expect(appBrightness(tester), Brightness.light);

    await choose(tester, 'System');
    expect(appBrightness(tester), Brightness.dark);
    expect(
      await tester.runAsync(() => database.settingsDao.themeMode()),
      'system',
    );
    await tester.unmountQoutApp();
  });

  testWidgets('the mode read at startup is used and shown', (tester) async {
    await openProfile(tester, initial: ThemeMode.dark);
    expect(selected(tester), {ThemeMode.dark});
    expect(appBrightness(tester), Brightness.dark);
    await tester.unmountQoutApp();
  });

  testWidgets('a failed save keeps the previous mode and says so', (
    tester,
  ) async {
    final settings = _MockSettingsRepository();
    when(
      () => settings.saveThemeMode(any()),
    ).thenAnswer((_) async => throw StateError('disk full'));
    await openProfile(tester, settings: settings);

    await choose(tester, 'Dark');
    expect(find.text('The appearance could not be saved'), findsOneWidget);
    expect(selected(tester), {ThemeMode.system});
    expect(appBrightness(tester), Brightness.light);
    await tester.unmountQoutApp();
  });

  testWidgets('deleting the profile keeps the appearance', (tester) async {
    await tester.runAsync(
      () => ProfileRepository(dao: database.profileDao).save(_profile),
    );
    await openProfile(tester, liveProfile: true);
    await choose(tester, 'Dark');

    await tester.scrollUntilVisible(
      find.text('Delete my profile'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Delete my profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Back on the profile form, still dark.
    expect(
      Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
      Brightness.dark,
    );
    expect(
      await tester.runAsync(() => database.settingsDao.themeMode()),
      'dark',
    );
    await tester.unmountQoutApp();
  });
}
