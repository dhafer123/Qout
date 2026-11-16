import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/contribute/presentation/contribute_screen.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';

import '../../../helpers/fake_contribution.dart';
import '../../../helpers/pump_app.dart';

const _ean = '6191234567897';

void main() {
  late FakeContribution fake;

  setUp(() {
    fake = FakeContribution(
      texts: {
        'front.jpg': 'Biscuits',
        'nutrition.jpg': cleanLabelText,
        'salt.jpg': saltMissingLabelText,
      },
    );
  });

  /// The flow for [_ean] on a tall screen (the whole form built).
  Future<void> open(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(800, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpQoutApp(overrides: fake.overrides);
    await tester.pushRoute(AppRoutes.contribute(_ean));
  }

  Finder tile(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(Card),
  );

  /// Takes [path] as the photo of the tile [title] with the camera.
  Future<void> take(WidgetTester tester, String title, String path) async {
    fake.photos.add(path);
    await tester.tap(
      find.descendant(of: tile(title), matching: find.text('Camera')),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> toReview(
    WidgetTester tester, {
    String nutrition = 'nutrition.jpg',
  }) async {
    await take(tester, 'Front of the package', 'front.jpg');
    await take(tester, 'Nutrition table', nutrition);
    await tester.tap(find.text('Continue'));
    await tester.pump();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  String text(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).controller!.text;

  Grade? grade(WidgetTester tester) =>
      tester.widget<GradeBadge>(find.byType(GradeBadge)).grade;

  group('photos', () {
    testWidgets('three photos, two needed to continue', (tester) async {
      fake.api.parseResults.add(recordedLabelParse('label-parse-ok'));
      await open(tester);

      expect(find.text('Add a product'), findsOneWidget);
      expect(find.textContaining('Barcode $_ean.'), findsOneWidget);
      expect(find.text('Name and brand visible.'), findsOneWidget);
      expect(find.text('Ingredients (optional)'), findsOneWidget);
      FilledButton continueButton() =>
          tester.widget(find.widgetWithText(FilledButton, 'Continue'));
      expect(continueButton().onPressed, isNull);

      await take(tester, 'Front of the package', 'front.jpg');
      expect(
        find.descendant(
          of: tile('Front of the package'),
          matching: find.text('Text read.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile('Front of the package'),
          matching: find.text('Retake'),
        ),
        findsOneWidget,
      );
      expect(continueButton().onPressed, isNull);

      await take(tester, 'Nutrition table', 'nutrition.jpg');
      expect(continueButton().onPressed, isNotNull);
    });

    testWidgets('from the gallery; a photo without text', (tester) async {
      await open(tester);
      fake.photos.add('blank.jpg');
      await tester.tap(
        find.descendant(
          of: tile('Ingredients (optional)'),
          matching: find.text('Gallery'),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('No text found on this photo.'), findsOneWidget);
    });

    testWidgets('shown as being read', (tester) async {
      fake.ocrGate = Completer<void>();
      await open(tester);
      await take(tester, 'Front of the package', 'front.jpg');
      expect(find.text('Reading the text…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      fake.ocrGate!.complete();
      await tester.pump();
      expect(find.text('Text read.'), findsOneWidget);
    });
  });

  group('review', () {
    testWidgets('the values read, with the provisional grade', (tester) async {
      fake.api.parseResults.add(recordedLabelParse('label-parse-ok'));
      await open(tester);
      await toReview(tester);

      expect(find.text('Check the values'), findsOneWidget);
      expect(
        find.text(
          'Read from the nutrition table. Check every value against the '
          'photo.',
        ),
        findsOneWidget,
      );
      expect(text(tester, 'Energy'), '1046');
      expect(text(tester, 'Fat'), '9.5');
      expect(text(tester, 'of which saturates'), '3.2');
      expect(text(tester, 'Sugars'), '12');
      expect(text(tester, 'Fibre (optional)'), '2.1');
      expect(text(tester, 'Protein'), '7.4');
      expect(text(tester, 'Salt'), '0.85');
      expect(text(tester, 'Fruit, vegetables and legumes (optional)'), '');
      expect(find.text('Nutrition per 100 g'), findsOneWidget);
      expect(find.text('Unverified'), findsOneWidget);
      // Labels don't show the fruit share; the engine needs it.
      expect(grade(tester), isNull);
      expect(
        find.text('To see the grade, fill in: fruit/vegetable/legume share.'),
        findsOneWidget,
      );

      await tester.tap(find.text('None (0 %)'));
      await tester.pump();
      expect(find.textContaining('Provisional grade'), findsOneWidget);
      expect(grade(tester), isNotNull);
    });

    testWidgets('back goes to the photos, then out', (tester) async {
      fake.api.parseResults.add(recordedLabelParse('label-parse-ok'));
      await open(tester);
      await toReview(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Add a product'), findsOneWidget);
      expect(find.text('Text read.'), findsNWidgets(2)); // photos kept

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ContributeScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('typed by hand when the table could not be read', (
      tester,
    ) async {
      await open(tester);
      await toReview(tester, nutrition: 'blank.jpg');

      expect(
        find.text(
          'The table could not be read. Type the values from the photo.',
        ),
        findsOneWidget,
      );
      expect(grade(tester), isNull);
      expect(
        find.text(
          'To see the grade, fill in: energy, saturates, sugars, protein, '
          'salt, fruit/vegetable/legume share.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Send for review'));
      await tester.pump();
      expect(
        find.text('Required: every label shows it'),
        findsNWidgets(6), // all but fibre and the fruit share
      );
      expect(
        find.text('Some values are missing or wrong: see the fields in red.'),
        findsOneWidget,
      );
      expect(fake.api.uploads, isEmpty);
    });

    testWidgets('a wrong value is shown and hides the grade', (tester) async {
      fake.api.parseResults.add(recordedLabelParse('label-parse-ok'));
      await open(tester);
      await toReview(tester);

      await tester.enterText(field('Salt'), '120');
      await tester.pump();
      expect(find.text('At most 100 g'), findsOneWidget);
      expect(grade(tester), isNull);
      expect(
        find.text('Correct the values marked in red to see the grade.'),
        findsOneWidget,
      );

      await tester.enterText(field('of which saturates'), '10');
      await tester.pump();
      expect(find.text("Can't be more than the fat"), findsOneWidget);
    });

    testWidgets('only digits and separators can be typed', (tester) async {
      fake.api.parseResults.add(recordedLabelParse('label-parse-ok'));
      await open(tester);
      await toReview(tester);

      await tester.enterText(field('Salt'), '1a,5 g');
      expect(text(tester, 'Salt'), '1,5');
    });

    testWidgets('energy in kcal, none of the fruit share', (tester) async {
      fake.api.parseResults.add(recordedLabelParse('label-parse-ok'));
      await open(tester);
      await toReview(tester);

      expect(find.text('kJ'), findsWidgets);
      await tester.tap(find.text('kcal')); // the unit button
      await tester.pump();
      expect(
        tester.widget<TextField>(field('Energy')).decoration!.suffixText,
        'kcal',
      );

      await tester.tap(find.text('None (0 %)'));
      await tester.pump();
      expect(text(tester, 'Fruit, vegetables and legumes (optional)'), '0');
    });

    testWidgets('kind of product and basis', (tester) async {
      fake.api.parseResults.add(recordedLabelParse('label-parse-ok'));
      await open(tester);
      await toReview(tester);

      expect(find.text('Most foods.'), findsOneWidget);
      expect(find.text('Contains sweeteners'), findsNothing);

      await tester.tap(find.text('General food'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drink').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Juices, sodas, flavoured waters and other drinks.'),
        findsOneWidget,
      );
      expect(find.text('Contains sweeteners'), findsOneWidget);
      await tester.tap(find.text('Contains sweeteners'));
      await tester.pump();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );

      await tester.tap(find.text('per 100 mL'));
      await tester.pump();
      expect(find.text('Nutrition per 100 mL'), findsOneWidget);
    });
  });

  group('LLM fallback', () {
    testWidgets('reads again, then fills the missing value', (tester) async {
      fake.api.parseResults.add(recordedLabelParse('label-parse-salt-missing'));
      fake.api.fallbackResults.addAll([
        LabelFallbackRead(
          id: '5f0c2a1e-8d3b-4c6a-9e1f-2b7d4a6c8e01',
          status: FallbackStatus.pending,
          createdAt: DateTime.utc(2026, 11, 16, 15),
        ),
        recordedFallback('label-fallback-done'),
      ]);
      await open(tester);
      await toReview(tester, nutrition: 'salt.jpg');

      expect(
        find.text(
          'Some values could not be read. Reading the table again, more '
          'carefully…',
        ),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(text(tester, 'Salt'), '');
      expect(find.text('Check this one against the photo'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();
      expect(
        find.text(
          'Read by AI from the nutrition table. Check every value against '
          'the photo.',
        ),
        findsOneWidget,
      );
      expect(text(tester, 'Salt'), '0.85');
      expect(find.text('Check this one against the photo'), findsNothing);
    });

    testWidgets('after an edit: offered, used on request', (tester) async {
      fake.api.parseResults.add(recordedLabelParse('label-parse-salt-missing'));
      fake.api.fallbackResults.add(recordedFallback('label-fallback-done'));
      await open(tester);
      await toReview(tester, nutrition: 'salt.jpg');

      await tester.enterText(field('Salt'), '0,8');
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();
      expect(
        find.text('A second reading found values. Use them instead of yours?'),
        findsOneWidget,
      );
      expect(text(tester, 'Salt'), '0,8');

      await tester.tap(find.text('Use these values'));
      await tester.pump();
      expect(text(tester, 'Salt'), '0.85');
      expect(find.text('Use these values'), findsNothing);
    });

    testWidgets('after an edit: offered, declined', (tester) async {
      fake.api.parseResults.add(recordedLabelParse('label-parse-salt-missing'));
      fake.api.fallbackResults.add(recordedFallback('label-fallback-done'));
      await open(tester);
      await toReview(tester, nutrition: 'salt.jpg');

      await tester.enterText(field('Salt'), '0,8');
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();
      await tester.tap(find.text('Keep mine'));
      await tester.pump();
      expect(text(tester, 'Salt'), '0,8');
      expect(find.text('Keep mine'), findsNothing);
    });
  });

  group('send', () {
    testWidgets('sent: thanks, then home', (tester) async {
      fake.api.parseResults.add(recordedLabelParse('label-parse-ok'));
      await open(tester);
      await toReview(tester);
      await tester.enterText(field('Product name (optional)'), 'Sablés');
      await tester.enterText(field('Brand (optional)'), 'Marque');

      await tester.tap(find.text('Send for review'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Thank you!'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
      final body = fake.api.submitted.single;
      expect(body.name, 'Sablés');
      expect(body.brand, 'Marque');

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(ContributeScreen), findsNothing);
    });

    testWidgets('sending shows progress; a failure, then try again', (
      tester,
    ) async {
      fake.api.parseResults.add(recordedLabelParse('label-parse-ok'));
      fake.api
        ..submitGate = Completer<void>()
        ..submitErrors.add(const ApiUnavailable('busy'));
      await open(tester);
      await toReview(tester);

      await tester.tap(find.text('Send for review'));
      await tester.pump();
      expect(find.text('Send for review'), findsNothing);
      final sendButton = find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(sendButton).onPressed, isNull);

      fake.api.submitGate!.complete();
      await tester.pump();
      await tester.pump();
      expect(
        find.text('The server is busy. Try again in a moment.'),
        findsOneWidget,
      );

      fake.api.submitGate = null;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Thank you!'), findsOneWidget);
      expect(fake.api.submitted, hasLength(2));
    });
  });
}
