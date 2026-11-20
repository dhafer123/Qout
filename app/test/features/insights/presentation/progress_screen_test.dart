import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/router.dart';
import 'package:qout/health/advice.dart' show Nutrient, PortionUnit;
import 'package:qout/health/diary.dart';

import '../../../helpers/fake_diary_repository.dart';
import '../../../helpers/pump_app.dart';

void main() {
  late FakeDiaryRepository diary;

  setUp(() => diary = FakeDiaryRepository());

  Future<void> openProgress(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpQoutApp(diary: diary);
    await tester.pushRoute(AppRoutes.progress);
    await tester.pumpAndSettle();
  }

  void eat({
    required DateTime at,
    required String name,
    required Map<Nutrient, double> per100,
    String? grade,
    int? nova,
  }) => diary.seed(
    DiaryEntry(
      id: 0,
      eatenAt: at,
      meal: Meal.lunch,
      ean: name,
      name: name,
      grade: grade,
      novaGroup: nova,
      unit: PortionUnit.gram,
      amount: 100,
      values: per100,
    ),
  );

  testWidgets('an empty week says what will appear', (tester) async {
    await openProgress(tester);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Nothing logged this week'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets('a logged week: energy chart, grades, processing, salt and '
      'sugars, top sources', (tester) async {
    final now = DateTime.now();
    eat(
      at: now,
      name: 'Biscuits',
      per100: const {
        Nutrient.energy: 2000,
        Nutrient.sugars: 40,
        Nutrient.salt: 7, // above the 6 g reference (no profile)
      },
      grade: 'E',
      nova: 4,
    );
    eat(
      at: now,
      name: 'Apple juice',
      per100: const {Nutrient.energy: 2000, Nutrient.sugars: 10},
      grade: 'B',
      nova: 1,
    );
    await openProgress(tester);

    expect(find.byType(BarChart), findsOneWidget);
    expect(find.textContaining('kcal on average'), findsOneWidget);
    expect(find.text('Your week by grade'), findsOneWidget);
    expect(find.text('A or B'), findsOneWidget);
    expect(find.text('D or E'), findsOneWidget);
    expect(find.text('50 %'), findsNWidgets(2));
    expect(
      find.textContaining('50 % of your energy came from ultra-processed'),
      findsOneWidget,
    );
    expect(find.text('1 of 1 logged day'), findsOneWidget); // salt
    expect(find.text('0 of 1 logged day'), findsOneWidget); // sugars
    expect(find.text('Top sources'), findsOneWidget);
    expect(find.text('40 g'), findsOneWidget); // biscuits' sugars
    expect(find.text('7.0 g'), findsOneWidget); // biscuits' salt
    expect(find.textContaining('not medical advice'), findsOneWidget);
  });

  testWidgets('earlier weeks, never the future', (tester) async {
    eat(
      at: DateTime.now(),
      name: 'Bread',
      per100: const {Nutrient.energy: 1000},
    );
    await openProgress(tester);
    final next = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Next week'),
        matching: find.byType(IconButton),
      ),
    );
    expect(next.onPressed, isNull);

    await tester.tap(find.byTooltip('Previous week'));
    await tester.pumpAndSettle();
    expect(find.text('This week'), findsNothing);
    expect(find.text('Nothing logged this week'), findsOneWidget);

    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    expect(find.text('This week'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
  });
}
