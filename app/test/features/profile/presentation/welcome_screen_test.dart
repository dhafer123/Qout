import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/ui/veggie.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';
import 'package:qout/features/profile/data/profile_repository.dart';
import 'package:qout/features/profile/presentation/profile_edit_screen.dart';
import 'package:qout/features/profile/presentation/welcome_art.dart';
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

  testWidgets('first run: four pages, then the profile (no skip)', (
    tester,
  ) async {
    await openFirstRun(tester);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Welcome to Qout'), findsOneWidget);
    expect(find.byType(GreetingArt), findsOneWidget);
    expect(find.bySemanticsLabel('Page 1 of 4'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Know what you eat'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('No account needed'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Advice for you, kept on your phone'), findsOneWidget);
    expect(find.byType(ShieldArt), findsOneWidget);
    expect(find.textContaining('never sent'), findsOneWidget);
    expect(
      find.text('Qout gives general information, not medical advice.'),
      findsOneWidget,
    );
    expect(find.text('Set up my profile'), findsOneWidget);
    // The profile is required (T31e): nothing skips past this page.
    expect(find.text('Skip').hitTestable(), findsNothing);
  });

  testWidgets('the greeting is in the brand green, its lip darker', (
    tester,
  ) async {
    await openFirstRun(tester);
    final lottie = tester.widget<Lottie>(
      find.descendant(
        of: find.byType(GreetingArt),
        matching: find.byType(Lottie),
      ),
    );
    final values = lottie.delegates!.values!;
    expect(values, same(GreetingArt.colours));
    expect(values, hasLength(5));
    final colours = values.map((d) => d.value).toSet();
    expect(colours, {qoutBrandGreen, GreetingArt.lip});
  });

  testWidgets('no vegetable stickers on any page (T44b)', (tester) async {
    await openFirstRun(tester);
    for (var page = 0; page < 4; page++) {
      expect(find.byType(VeggieArt), findsNothing);
      if (page < 3) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('skip: straight to the last page, still before the profile', (
    tester,
  ) async {
    await openFirstRun(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Advice for you, kept on your phone'), findsOneWidget);
    expect(find.bySemanticsLabel('Page 4 of 4'), findsOneWidget);
    expect(find.text('Set up my profile'), findsOneWidget);
    expect(find.text('Skip').hitTestable(), findsNothing);
    expect(find.text('Next'), findsNothing);
    expect(await repository.onboardingCompleted(), isFalse);
  });

  testWidgets('key phrases stand out in the accent', (tester) async {
    await openFirstRun(tester);
    final context = tester.element(find.byType(WelcomeScreen));
    final accent = QoutPalette.of(context).accentText;
    List<String> strongIn(String text) {
      final body = tester.widget<Text>(find.textContaining(text));
      final strong = <String>[];
      body.textSpan!.visitChildren((span) {
        if (span is TextSpan && span.style?.color == accent) {
          strong.add(span.text!);
        }
        return true;
      });
      return strong;
    }

    expect(strongIn('grades the food you buy'), ['Qout']);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(strongIn('Scan a food barcode'), ['A (best) to E']);
  });

  testWidgets('the illustrations play once, then hold still', (tester) async {
    await openFirstRun(tester);
    // pumpAndSettle returning at all means no animation loops; the grade
    // badges have all popped in.
    expect(find.byType(GreetingArt), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(GradeScaleArt), findsOneWidget);
    expect(find.byType(GradeBadge), findsNWidgets(5));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion: the last frame at once', (tester) async {
    tester.view
      ..physicalSize = const Size(400, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpQoutApp(database: database, start: StartScreen.welcome);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    // The shield is already drawn: its animation stands at the end.
    final shield = tester.widget<Lottie>(
      find.descendant(
        of: find.byType(ShieldArt),
        matching: find.byType(Lottie),
      ),
    );
    expect(shield.controller!.value, 1);
  });

  testWidgets('set up: the form, then home with the profile saved', (
    tester,
  ) async {
    await openFirstRun(tester);
    for (var page = 0; page < 3; page++) {
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
    await tester.tap(find.text('Female'));
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
