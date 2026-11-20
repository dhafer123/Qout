import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/profile/data/profile_repository.dart';
import 'package:qout/features/profile/presentation/profile_edit_screen.dart';
import 'package:qout/features/profile/presentation/welcome_screen.dart';
import 'package:qout/health/profile.dart';

import '../../../helpers/pump_app.dart';

void main() {
  late AppDatabase database;
  late ProfileRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = ProfileRepository(dao: database.profileDao);
  });

  tearDown(() => database.close());

  Future<void> openFirstRun(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(400, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpQoutApp(database: database, start: StartScreen.welcome);
  }

  testWidgets('first run: three pages, then the profile (no skip)', (
    tester,
  ) async {
    await openFirstRun(tester);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Know what you eat'), findsOneWidget);
    expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('No account needed'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Advice for you, kept on your phone'), findsOneWidget);
    expect(find.textContaining('never sent'), findsOneWidget);
    expect(
      find.text('Qout gives general information, not medical advice.'),
      findsOneWidget,
    );
    expect(find.text('Set up my profile'), findsOneWidget);
    // The profile is required (T31e).
    expect(find.textContaining('Skip'), findsNothing);
  });

  testWidgets('set up: the form, then home with the profile saved', (
    tester,
  ) async {
    await openFirstRun(tester);
    for (var page = 0; page < 2; page++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Set up my profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileEditScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Your profile'), findsOneWidget);

    // Back from the form: the welcome screens again, nothing saved.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(await repository.onboardingCompleted(), isFalse);

    await tester.tap(find.text('Set up my profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Woman'));
    await tester.enterText(find.widgetWithText(TextField, 'Age'), '22');
    await tester.enterText(find.widgetWithText(TextField, 'Height'), '165');
    await tester.enterText(find.widgetWithText(TextField, 'Weight'), '58');
    await tester.ensureVisible(find.text('Active'));
    await tester.tap(find.text('Active'));
    await tester.scrollUntilVisible(
      find.text('Save'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ProfileEditScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(await repository.onboardingCompleted(), isTrue);
    expect(
      await repository.get(),
      Profile(
        sex: Sex.female,
        age: 22,
        heightCm: 165,
        weightKg: 58,
        activity: ActivityLevel.active,
      ),
    );
    await tester.unmountQoutApp();
  });

  testWidgets('a profile saved: straight home', (tester) async {
    await tester.pumpQoutApp(database: database);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
  });

  testWidgets('no profile saved yet: the form, without a way back', (
    tester,
  ) async {
    await tester.pumpQoutApp(
      database: database,
      start: StartScreen.profileForm,
    );
    expect(find.byType(ProfileEditScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Your profile'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
  });

  group('start screen', () {
    test('first run: welcome', () async {
      expect(await repository.startScreen(), StartScreen.welcome);
    });

    test('welcome seen, no profile (skipped before T31e): the form', () async {
      await repository.completeOnboarding();
      expect(await repository.startScreen(), StartScreen.profileForm);
    });

    test('a profile: home; deleted again: the form', () async {
      await repository.save(
        Profile(
          sex: Sex.male,
          age: 30,
          heightCm: 180,
          weightKg: 75,
          activity: ActivityLevel.lowActive,
        ),
      );
      expect(await repository.startScreen(), StartScreen.home);
      await repository.delete();
      expect(await repository.startScreen(), StartScreen.profileForm);
    });
  });
}
