import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/features/profile/data/profile_repository.dart';
import 'package:qout/features/profile/presentation/profile_edit_screen.dart';
import 'package:qout/features/profile/presentation/profile_screen.dart';
import 'package:qout/health/profile.dart';

import '../../../helpers/pump_app.dart';

final _profile = Profile(
  sex: Sex.female,
  age: 22,
  heightCm: 165,
  weightKg: 58,
  activity: ActivityLevel.active,
  allergens: const {Allergen.sesame, Allergen.milk},
);

void main() {
  late AppDatabase database;
  late ProfileRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = ProfileRepository(dao: database.profileDao);
  });

  tearDown(() => database.close());

  /// Opens [route] on a tall screen; the profile is read from [database].
  Future<void> open(WidgetTester tester, String route) async {
    tester.view
      ..physicalSize = const Size(500, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpQoutApp(database: database, liveProfile: true);
    await tester.pushRoute(route);
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  group('profile screen', () {
    testWidgets('opened from the profile button on home', (tester) async {
      await open(tester, AppRoutes.home);
      await tester.tap(find.byKey(const ValueKey('tab-profile')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      await tester.unmountQoutApp();
    });

    testWidgets('no profile: the EU reference intakes, and set up', (
      tester,
    ) async {
      await open(tester, AppRoutes.profile);
      expect(find.text('No profile yet'), findsOneWidget);
      expect(find.text('Daily reference'), findsOneWidget);
      expect(find.text('2008 kcal'), findsOneWidget);
      expect(find.text('8400 kJ a day'), findsOneWidget);
      expect(find.text('up to 70 g'), findsOneWidget); // fat
      expect(find.text('up to 20 g'), findsOneWidget); // saturates
      expect(find.text('6 g'), findsOneWidget); // salt
      expect(find.textContaining('Without a profile'), findsNothing); // folded
      await tester.tap(find.text('Where these come from'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Without a profile'), findsOneWidget);
      expect(find.text('Delete my profile'), findsNothing);

      await tester.tap(find.text('Set up my profile'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileEditScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Edit profile'), findsOneWidget);
      await tester.unmountQoutApp();
    });

    testWidgets('a profile: what was entered, and the personal needs', (
      tester,
    ) async {
      await repository.save(_profile);
      await open(tester, AppRoutes.profile);

      expect(find.text('Woman'), findsOneWidget);
      expect(find.text('22 years'), findsOneWidget);
      expect(find.text('165 cm'), findsOneWidget);
      expect(find.text('58 kg'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Milk, Sesame'), findsOneWidget);
      expect(
        find.text('21.3, within the WHO normal range (18.5–24.9)'),
        findsOneWidget,
      );
      // scoring-spec/needs/cases/personal--female-22-active.json
      expect(find.text('Your daily needs'), findsOneWidget);
      expect(find.text('2397 kcal'), findsOneWidget);
      expect(find.text('10029 kJ a day'), findsOneWidget);
      expect(find.text('up to 95 g'), findsOneWidget);
      expect(find.text('up to 27 g'), findsOneWidget);
      expect(find.text('Sugars (reference)'), findsOneWidget);
      expect(find.text('90 g'), findsOneWidget);
      expect(find.text('under 5 g'), findsOneWidget);
      await tester.tap(find.text('How these are worked out'));
      await tester.pumpAndSettle();
      expect(find.textContaining('EFSA (2013)'), findsOneWidget);
      await tester.unmountQoutApp();
    });

    testWidgets('sex not given: the reference intakes, and why', (
      tester,
    ) async {
      await repository.save(
        Profile(
          sex: null,
          age: 35,
          heightCm: 170,
          weightKg: 65,
          activity: ActivityLevel.moderatelyActive,
        ),
      );
      await open(tester, AppRoutes.profile);
      expect(find.text('Prefer not to say'), findsOneWidget);
      expect(find.text('2008 kcal'), findsOneWidget);
      await tester.tap(find.text('Where these come from'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('without your sex Qout uses the EU reference'),
        findsOneWidget,
      );
      await tester.unmountQoutApp();
    });

    testWidgets('delete asks first, then asks for a new profile', (
      tester,
    ) async {
      await repository.save(_profile);
      await open(tester, AppRoutes.profile);

      await tester.tap(find.text('Delete my profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await repository.get(), isNotNull);

      await tester.tap(find.text('Delete my profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(await repository.get(), isNull);
      expect(await repository.onboardingCompleted(), isTrue);
      // Required (T31e): the empty form, with no way back without saving.
      expect(find.byType(ProfileEditScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Your profile'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byType(ProfileScreen), findsNothing);
      await tester.unmountQoutApp();
    });
  });

  group('profile form', () {
    testWidgets('everything is required but allergies', (tester) async {
      await open(tester, AppRoutes.profileEdit);
      await save(tester);

      expect(find.text('Choose one, or "Prefer not to say".'), findsOneWidget);
      expect(find.text('Required.'), findsNWidgets(3)); // age, height, weight
      expect(
        find.text('Choose the level closest to your usual day.'),
        findsOneWidget,
      );
      expect(await repository.get(), isNull);
      await tester.unmountQoutApp();
    });

    testWidgets('adults only, and values out of range', (tester) async {
      await open(tester, AppRoutes.profileEdit);
      await tester.enterText(field('Age'), '17');
      await tester.enterText(field('Height'), '99');
      await tester.enterText(field('Weight'), '1.2.3');
      await save(tester);

      expect(
        find.text("Qout's advice is for adults (18 and over)."),
        findsOneWidget,
      );
      expect(
        find.text('Enter a height between 100 and 250 cm.'),
        findsOneWidget,
      );
      expect(find.text('Enter a number.'), findsOneWidget);
      await tester.unmountQoutApp();
    });

    testWidgets('only digits can be typed for the age', (tester) async {
      await open(tester, AppRoutes.profileEdit);
      await tester.enterText(field('Age'), '3a5,');
      expect(
        tester.widget<TextField>(field('Age')).controller!.text,
        '35',
      );
      await tester.unmountQoutApp();
    });

    testWidgets('saves with a decimal comma, allergies included', (
      tester,
    ) async {
      await open(tester, AppRoutes.profileEdit);
      await tester.tap(find.text('Man'));
      await tester.enterText(field('Age'), '45');
      await tester.enterText(field('Height'), '178');
      await tester.enterText(field('Weight'), '81,5');
      await tester.tap(find.text('Low active'));
      await tester.tap(find.text('Peanuts'));
      await tester.tap(find.text('Fish'));
      await tester.pump();
      await tester.tap(find.text('Fish')); // off again
      await save(tester);

      expect(find.byType(ProfileEditScreen), findsNothing);
      expect(find.text('Profile saved'), findsOneWidget);
      expect(
        await repository.get(),
        Profile(
          sex: Sex.male,
          age: 45,
          heightCm: 178,
          weightKg: 81.5,
          activity: ActivityLevel.lowActive,
          allergens: const {Allergen.peanuts},
        ),
      );
      await tester.unmountQoutApp();
    });

    testWidgets('editing starts from the saved profile', (tester) async {
      await repository.save(_profile);
      await open(tester, AppRoutes.profile);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      String text(String label) =>
          tester.widget<TextField>(field(label)).controller!.text;
      expect(
        (text('Age'), text('Height'), text('Weight')),
        ('22', '165', '58'),
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Woman'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Sesame'))
            .selected,
        isTrue,
      );

      await tester.enterText(field('Weight'), '60');
      await save(tester);
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('60 kg'), findsOneWidget);
      expect((await repository.get())!.allergens, _profile.allergens);
      await tester.unmountQoutApp();
    });

    testWidgets('the optional first name is saved, trimmed, and shown', (
      tester,
    ) async {
      await repository.save(_profile);
      await open(tester, AppRoutes.profileEdit);
      await tester.enterText(field('First name (optional)'), '  Dhafer ');
      await tester.scrollUntilVisible(
        find.text('Save'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await save(tester);
      expect((await database.profileDao.get())!.firstName, 'Dhafer');
      expect(await repository.get(), _profile); // the rest unchanged
      await tester.unmountQoutApp();
    });

    testWidgets('deleting the profile forgets the name too', (tester) async {
      await repository.save(_profile);
      await repository.saveFirstName('Dhafer');
      await repository.delete();
      expect((await database.profileDao.get())!.firstName, isNull);
    });

    testWidgets('says advice is not tailored for pregnancy', (tester) async {
      await open(tester, AppRoutes.profileEdit);
      expect(find.textContaining('Pregnant or breastfeeding?'), findsOneWidget);
      await tester.unmountQoutApp();
    });
  });
}
