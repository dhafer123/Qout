import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/env/app_env.dart';
import 'package:qout/features/home/presentation/home_screen.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('boots and shows the home screen', (tester) async {
    await tester.pumpQoutApp();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Qout'), findsOneWidget);
  });

  testWidgets('uses the light theme when the platform is light', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpQoutApp();

    final theme = Theme.of(tester.element(find.byType(HomeScreen)));
    expect(theme.brightness, Brightness.light);
  });

  testWidgets('follows the platform dark mode', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpQoutApp();

    final theme = Theme.of(tester.element(find.byType(HomeScreen)));
    expect(theme.brightness, Brightness.dark);
    expect(
      theme.colorScheme,
      ColorScheme.fromSeed(
        seedColor: qoutSeedColor,
        brightness: Brightness.dark,
      ),
    );
  });

  testWidgets('shows the debug banner only outside prod', (tester) async {
    // One database for both pumps (drift warns about two open at once).
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpQoutApp(database: database);
    expect(find.byType(CheckedModeBanner), findsOneWidget);

    await tester.pumpQoutApp(flavor: AppFlavor.prod, database: database);
    expect(find.byType(CheckedModeBanner), findsNothing);
  });
}
