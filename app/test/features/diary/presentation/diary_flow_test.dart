import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/router.dart';
import 'package:qout/features/diary/data/diary_repository.dart';
import 'package:qout/features/diary/presentation/diary_screen.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/health/advice.dart' show Nutrient;
import 'package:qout/health/diary.dart';
import 'package:qout/health/profile.dart';

import '../../../helpers/fake_diary_repository.dart';
import '../../../helpers/fake_product_repository.dart';
import '../../../helpers/pump_app.dart';
import '../../home/presentation/home_screen_test.dart' show recordedFound;

final _profile = Profile(
  sex: Sex.female,
  age: 22,
  heightCm: 165,
  weightKg: 58,
  activity: ActivityLevel.active,
);

void main() {
  late FakeDiaryRepository diary;

  setUp(() => diary = FakeDiaryRepository());

  Future<void> pump(WidgetTester tester, {String? product}) async {
    tester.view
      ..physicalSize = const Size(800, 2000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpQoutApp(
      diary: diary,
      profile: _profile,
      overrides: [
        if (product != null)
          productRepositoryProvider.overrideWithValue(
            FakeProductRepository(results: [recordedFound(product)]),
          ),
      ],
    );
  }

  Future<void> openProduct(WidgetTester tester) async {
    await tester.pushRoute(AppRoutes.product('6194002510064'));
    await tester.pumpAndSettle();
  }

  group('I ate this', () {
    testWidgets('one serving by default, then added', (tester) async {
      await pump(tester, product: 'product-serving-allergens');
      await openProduct(tester);

      await tester.tap(find.text('I ate this'));
      await tester.pumpAndSettle();
      expect(find.text('1 serving (21.7 g)'), findsOneWidget);
      // 1980 kJ per 100 g × 21.7 g = 429.66 kJ ≈ 103 kcal.
      expect(find.text('≈ 103 kcal'), findsOneWidget);

      await tester.tap(find.text('Add to diary'));
      await tester.pumpAndSettle();
      final entry = diary.entries.single;
      expect(entry.amount, 21.7);
      expect(entry.ean, '6194002510064');
      expect(find.text('Added to your diary'), findsOneWidget);
    });

    testWidgets('another amount: checked, then used', (tester) async {
      await pump(tester, product: 'product-serving-allergens');
      await openProduct(tester);
      await tester.tap(find.text('I ate this'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Other amount'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '0');
      await tester.tap(find.text('Add to diary'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Type an amount above 0'), findsOneWidget);
      expect(diary.entries, isEmpty);

      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '45,5');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dinner'));
      await tester.tap(find.text('Add to diary'));
      await tester.pumpAndSettle();
      expect(
        (diary.entries.single.amount, diary.entries.single.meal),
        (45.5, Meal.dinner),
      );
    });

    testWidgets('logged for yesterday: not on today', (tester) async {
      await pump(tester, product: 'product-serving-allergens');
      await openProduct(tester);
      await tester.tap(find.text('I ate this'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yesterday'));
      await tester.tap(find.text('Add to diary'));
      await tester.pumpAndSettle();

      final eaten = dayOf(diary.entries.single.eatenAt);
      final today = dayOf(DateTime.now());
      expect(eaten, DateTime(today.year, today.month, today.day - 1));
    });
  });

  testWidgets('quick add from Today counts its energy', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Quick add'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Energy'), 'abc');
    await tester.tap(find.text('Add to diary'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Type the kcal'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'What (optional)'),
      'Couscous',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Energy'), '450');
    await tester.tap(find.text('Add to diary'));
    await tester.pumpAndSettle();

    final entry = diary.entries.single;
    expect((entry.name, entry.isQuickAdd), ('Couscous', true));
    expect(find.text('450'), findsOneWidget); // the energy ring
    expect(find.textContaining('items'), findsNothing);
    expect(find.textContaining('· 1 item'), findsOneWidget); // meals card
  });

  testWidgets('Today: totals, and a reference passed said gently', (
    tester,
  ) async {
    // 30 g of salt per 100 g × 20 g = 6 g of salt, above the 5 g.
    diary.seed(
      DiaryEntry(
        id: 0,
        eatenAt: DateTime.now(),
        meal: guessMeal(DateTime.now()),
        ean: '1',
        name: 'Salty',
        amount: 20,
        values: const {Nutrient.energy: 1000, Nutrient.salt: 30},
      ),
    );
    await pump(tester);

    expect(find.text('48'), findsOneWidget); // 200 kJ ≈ 48 kcal
    expect(find.text('Above your daily reference'), findsOneWidget);
    expect(find.textContaining('6.0 / under 5 g'), findsOneWidget);
    expect(
      find.textContaining('Compared with your daily needs.'),
      findsOneWidget,
    );
  });

  group('the Diary tab', () {
    DiaryEntry seed(String name, Meal meal, {double amount = 100}) =>
        diary.seed(
          DiaryEntry(
            id: 0,
            eatenAt: DateTime.now(),
            meal: meal,
            ean: name,
            name: name,
            amount: amount,
            servingQuantity: 30,
            values: const {Nutrient.energy: 418.4},
          ),
        );

    Future<void> openDiary(WidgetTester tester) async {
      await pump(tester);
      await tester.pushRoute(AppRoutes.diary);
      await tester.pumpAndSettle();
    }

    testWidgets('entries under their meal, with portion and kcal', (
      tester,
    ) async {
      seed('Bread', Meal.breakfast);
      seed('Soup', Meal.dinner, amount: 30);
      await openDiary(tester);

      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('Lunch'), findsNothing);
      expect(find.byType(DiaryEntryTile), findsNWidgets(2));
      expect(find.text('100 g'), findsOneWidget);
      expect(find.text('1 serving (30 g)'), findsOneWidget);
      expect(find.text('100 kcal'), findsWidgets);
    });

    testWidgets('tap to change the portion', (tester) async {
      seed('Bread', Meal.breakfast);
      await openDiary(tester);

      await tester.tap(find.byType(DiaryEntryTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 serving (30 g)'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(diary.entries.single.amount, 30);
    });

    testWidgets('swipe removes, Undo brings back', (tester) async {
      final bread = seed('Bread', Meal.breakfast);
      await openDiary(tester);

      await tester.drag(find.byType(DiaryEntryTile), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(diary.entries, isEmpty);
      expect(find.text('Removed from your diary'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(diary.entries.single.id, bread.id);
      expect(find.byType(DiaryEntryTile), findsOneWidget);
    });

    testWidgets('the week strip: earlier weeks, never the future', (
      tester,
    ) async {
      seed('Bread', Meal.breakfast);
      await openDiary(tester);
      final next = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Next week'),
          matching: find.byType(IconButton),
        ),
      );
      expect(next.onPressed, isNull); // this week: nothing after it

      await tester.tap(find.byTooltip('Previous week'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing logged on this day'), findsOneWidget);
      expect(find.byType(DiaryEntryTile), findsNothing);
    });

    testWidgets('a quick add from the app bar lands on the shown day', (
      tester,
    ) async {
      await openDiary(tester);
      await tester.tap(find.byTooltip('Previous week'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quick add'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Energy'), '100');
      await tester.tap(find.text('Add to diary'));
      await tester.pumpAndSettle();

      final today = dayOf(DateTime.now());
      expect(
        dayOf(diary.entries.single.eatenAt),
        DateTime(today.year, today.month, today.day - 7),
      );
      expect(find.byType(DiaryEntryTile), findsOneWidget);
    });
  });

  testWidgets('Delete my diary asks, then empties it', (tester) async {
    diary.seed(
      quickAddEntry(kcal: 100, meal: Meal.snack, eatenAt: DateTime.now()),
    );
    await pump(tester);
    await tester.pushRoute(AppRoutes.profile);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Delete my diary'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.text('Delete my diary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(diary.entries, hasLength(1));

    await tester.tap(find.text('Delete my diary'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(diary.entries, isEmpty);
    expect(find.text('Diary deleted'), findsOneWidget);
  });
}
