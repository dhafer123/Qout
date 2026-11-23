import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/router.dart';
import 'package:qout/features/diary/presentation/meal_art.dart';
import 'package:qout/health/advice.dart' show Nutrient;
import 'package:qout/health/diary.dart';

import '../../../helpers/fake_diary_repository.dart';
import '../../../helpers/pump_app.dart';

/// Width and height from a PNG's header.
(int, int) _pngSize(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  return (data.getUint32(16), data.getUint32(20));
}

void main() {
  group('pictures', () {
    test('every meal has its PNG, small enough for 80 dp at most', () {
      for (final meal in Meal.values) {
        final file = File(mealPicture(meal));
        expect(file.existsSync(), isTrue, reason: meal.name);
        final bytes = file.readAsBytesSync();
        expect(bytes.sublist(1, 4), 'PNG'.codeUnits, reason: meal.name);
        final (width, height) = _pngSize(bytes);
        expect(max(width, height), inInclusiveRange(160, 240));
      }
    });

    test('no picture without a meal', () {
      final names = Directory('assets/illustrations/meals')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(names, {for (final m in Meal.values) '${m.name}.png'});
    });

    test('bundled with the app', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      for (final meal in Meal.values) {
        final data = await rootBundle.load(mealPicture(meal));
        expect(data.lengthInBytes, greaterThan(1000), reason: meal.name);
      }
    });
  });

  testWidgets('MealArt: the picture at its size, hidden from screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: MealArt(Meal.lunch, size: 44))),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/illustrations/meals/lunch.png',
    );
    expect(tester.getSize(find.byType(Image)), const Size(44, 44));
    expect(
      tester.getSemantics(find.byType(MealArt)),
      isNot(matchesSemantics(isImage: true)),
    );
    handle.dispose();
  });

  group('on the screens', () {
    FakeDiaryRepository logged() {
      final diary = FakeDiaryRepository();
      for (final meal in [Meal.breakfast, Meal.breakfast, Meal.snack]) {
        diary.seed(
          DiaryEntry(
            id: 0,
            eatenAt: DateTime.now(),
            meal: meal,
            name: 'Food',
            ean: '1',
            amount: 100,
            values: const {Nutrient.energy: 418.4},
          ),
        );
      }
      return diary;
    }

    Finder inRow(Meal meal, Finder finder) => find.descendant(
      of: find.byKey(ValueKey('meal-row-${meal.name}')),
      matching: finder,
    );

    testWidgets('Today: all four meals, logged ones with items and kcal', (
      tester,
    ) async {
      await tester.pumpQoutApp(diary: logged());

      for (final meal in Meal.values) {
        expect(inRow(meal, find.text(meal.label)), findsOneWidget);
        expect(
          inRow(meal, find.byKey(ValueKey('meal-art-${meal.name}'))),
          findsOneWidget,
        );
      }
      expect(inRow(Meal.breakfast, find.text('2 items')), findsOneWidget);
      expect(inRow(Meal.breakfast, find.text('200 kcal')), findsOneWidget);
      expect(inRow(Meal.snack, find.text('1 item')), findsOneWidget);
      expect(inRow(Meal.breakfast, find.text('Add')), findsNothing);
      // Empty meals offer "+ Add".
      expect(inRow(Meal.lunch, find.text('Nothing yet')), findsOneWidget);
      expect(inRow(Meal.dinner, find.text('Add')), findsOneWidget);

      // kcal and + Add sit against the row's right edge.
      final row = tester.getRect(find.byKey(const ValueKey('meal-row-lunch')));
      final kcal = tester.getRect(
        find.byKey(const ValueKey('meal-kcal-breakfast')),
      );
      final add = tester.getRect(
        inRow(Meal.dinner, find.byWidgetPredicate((w) => w is TextButton)),
      );
      expect(kcal.right, closeTo(row.right, 0.5));
      expect(add.right, closeTo(row.right, 0.5));
    });

    testWidgets("Today: an empty meal's + Add quick adds to that meal", (
      tester,
    ) async {
      final diary = FakeDiaryRepository();
      tester.view
        ..physicalSize = const Size(500, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpQoutApp(diary: diary);

      await tester.tap(inRow(Meal.dinner, find.text('Add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Energy'), '300');
      await tester.tap(find.text('Add to diary'));
      await tester.pumpAndSettle();

      expect(diary.entries.single.meal, Meal.dinner);
      expect(inRow(Meal.dinner, find.text('1 item')), findsOneWidget);
    });

    testWidgets('Today: + Add is named for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpQoutApp();
      expect(find.bySemanticsLabel('Add to lunch'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Diary: each meal heading with its picture, no tint', (
      tester,
    ) async {
      await tester.pumpQoutApp(diary: logged());
      await tester.pushRoute(AppRoutes.diary);
      await tester.pumpAndSettle();

      for (final meal in [Meal.breakfast, Meal.snack]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('meal-heading-${meal.name}')),
            matching: find.byKey(ValueKey('meal-art-${meal.name}')),
          ),
          findsOneWidget,
        );
      }
      expect(find.byKey(const ValueKey('meal-heading-dinner')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('meal-heading-breakfast')),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });
  });
}
