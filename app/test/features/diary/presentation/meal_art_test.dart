import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
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

/// WCAG contrast ratio of two opaque colours.
double _contrast(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
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

  for (final brightness in Brightness.values) {
    group('tints, ${brightness.name}', () {
      final theme = buildQoutTheme(brightness);
      final palette = theme.extension<QoutPalette>()!;
      final tints = Meal.values.map((m) => mealTint(palette, m)).toList();

      test('one per meal', () {
        expect(tints.toSet(), hasLength(Meal.values.length));
      });

      test('the text drawn on them stays readable (4.5:1)', () {
        final text = theme.textTheme;
        final colors = {
          'body': text.bodyMedium!.color!,
          'small': text.bodySmall!.color!,
          'title': text.titleSmall!.color!,
          'muted': palette.muted,
        };
        for (final (i, tint) in tints.indexed) {
          for (final MapEntry(:key, :value) in colors.entries) {
            expect(
              _contrast(value, tint),
              greaterThanOrEqualTo(4.5),
              reason: '$key on ${Meal.values[i].name}',
            );
          }
        }
      });
    });
  }

  group('on the screens', () {
    FakeDiaryRepository logged() {
      final diary = FakeDiaryRepository();
      for (final meal in [Meal.breakfast, Meal.snack]) {
        diary.seed(
          DiaryEntry(
            id: 0,
            eatenAt: DateTime.now(),
            meal: meal,
            name: meal.label,
            ean: '1',
            amount: 100,
            values: const {Nutrient.energy: 418.4},
          ),
        );
      }
      return diary;
    }

    Color tintOf(WidgetTester tester, String key) {
      final box = tester.widget<DecoratedBox>(find.byKey(ValueKey(key)));
      return (box.decoration as BoxDecoration).color!;
    }

    testWidgets('Today: each logged meal on its tint, with its picture', (
      tester,
    ) async {
      await tester.pumpQoutApp(diary: logged());
      final palette = QoutPalette.of(
        tester.element(find.text("Today's meals")),
      );

      expect(tintOf(tester, 'meal-row-breakfast'), palette.breakfastTint);
      expect(tintOf(tester, 'meal-row-snack'), palette.snackTint);
      expect(find.byKey(const ValueKey('meal-row-lunch')), findsNothing);
      expect(find.byKey(const ValueKey('meal-art-breakfast')), findsOneWidget);
      expect(find.byKey(const ValueKey('meal-art-snack')), findsOneWidget);
    });

    testWidgets('Diary: each meal heading on its tint, with its picture', (
      tester,
    ) async {
      await tester.pumpQoutApp(diary: logged());
      await tester.pushRoute(AppRoutes.diary);
      await tester.pumpAndSettle();
      final palette = QoutPalette.of(
        tester.element(find.byKey(const ValueKey('meal-heading-breakfast'))),
      );

      expect(tintOf(tester, 'meal-heading-breakfast'), palette.breakfastTint);
      expect(tintOf(tester, 'meal-heading-snack'), palette.snackTint);
      expect(find.byKey(const ValueKey('meal-heading-dinner')), findsNothing);
    });
  });
}
