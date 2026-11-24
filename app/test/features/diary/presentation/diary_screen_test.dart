import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/history/presentation/scan_history_list.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';
import 'package:qout/features/product/presentation/product_screen.dart';

import '../../../helpers/fake_product_repository.dart';
import '../../../helpers/fake_scan_history_repository.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../home/presentation/home_screen_test.dart' show recordedFound;

void main() {
  late FakeScanHistoryRepository history;
  final t0 = DateTime.utc(2026, 11, 13, 9);

  setUp(() => history = FakeScanHistoryRepository());

  Future<void> openDiary(
    WidgetTester tester, {
    FakeProductRepository? products,
  }) async {
    // Tall enough for every row: the list builds only what is on screen.
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpQoutApp(
      history: history,
      overrides: [
        if (products != null)
          productRepositoryProvider.overrideWithValue(products),
      ],
    );
    await tester.pushRoute(AppRoutes.diary);
    await tester.pumpAndSettle();
  }

  Finder tile(String text) => find.ancestor(
    of: find.textContaining(text),
    matching: find.byType(HistoryTile),
  );

  testWidgets('the Diary tab opens from the bar', (tester) async {
    await tester.pumpQoutApp(history: history);
    await tester.tap(find.byKey(const ValueKey('tab-diary')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Diary'), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await openDiary(tester);

    expect(find.text('No scans yet'), findsOneWidget);
    // Only the icon: the onion is for an empty day or week.
    expect(
      find.byIcon(PhosphorIconsRegular.clockCounterClockwise),
      findsOneWidget,
    );
    expect(
      find.text('Scanned products appear here, also offline.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Clear history'), findsNothing);
  });

  testWidgets('newest first under a heading per day, with grade and name', (
    tester,
  ) async {
    history
      ..seed(
        '9557062321136',
        at: t0,
        product: recordedProduct('product-general-graded'),
      )
      ..seed(
        '6191416500452',
        at: t0.add(const Duration(minutes: 1)),
        product: recordedProduct('product-insufficient-data'),
      )
      ..seed('6191234567897', at: t0.add(const Duration(days: 1)));
    await openDiary(tester);

    final tiles = tester.widgetList<HistoryTile>(find.byType(HistoryTile));
    expect(tiles.map((t) => t.entry.ean), [
      '6191234567897',
      '6191416500452',
      '9557062321136',
    ]);
    // Two days, two headings (dates in the past: "Fri, Nov 13").
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^\w+, Nov \d+$').hasMatch(w.data ?? ''),
      ),
      findsNWidgets(2),
    );
    // Known product: grade, name, brand.
    expect(
      find.descendant(
        of: tile('Mister Potato'),
        matching: find.byWidgetPredicate(
          (w) => w is GradeBadge && w.grade == Grade.e,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tile('Mister Potato'),
        matching: find.text('Jbs qtw'),
      ),
      findsOneWidget,
    );
    // No name: "Unnamed product", the barcode instead of a brand.
    expect(
      find.descendant(
        of: tile('6191416500452'),
        matching: find.text('Unnamed product'),
      ),
      findsOneWidget,
    );
    // Never fetched: no grade.
    expect(
      find.descendant(
        of: tile('6191234567897'),
        matching: find.byWidgetPredicate(
          (w) => w is GradeBadge && w.grade == null,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tap reopens the product', (tester) async {
    history.seed('9557062321136', product: recordedProduct('product-water'));
    final products = FakeProductRepository(
      results: [recordedFound('product-water')],
    );
    await openDiary(tester, products: products);

    await tester.tap(find.byType(HistoryTile));
    await tester.pumpAndSettle();

    expect(find.byType(ProductScreen), findsOneWidget);
    expect(products.requested, ['9557062321136']);
  });

  testWidgets('swipe removes an entry, Undo brings it back', (tester) async {
    history
      ..seed('111', at: t0)
      ..seed('222', at: t0.add(const Duration(minutes: 1)));
    await openDiary(tester);

    await tester.drag(tile('222'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(tile('222'), findsNothing);
    expect(history.entries.map((e) => e.ean), ['111']);
    expect(find.text('Removed from history'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(history.entries.map((e) => e.ean), ['222', '111']);
    expect(tile('222'), findsOneWidget);
  });

  testWidgets('clear history asks first', (tester) async {
    history
      ..seed('111', at: t0)
      ..seed('222', at: t0.add(const Duration(minutes: 1)));
    await openDiary(tester);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Clear history?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(history.entries, hasLength(2));

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(history.entries, isEmpty);
    expect(find.text('No scans yet'), findsOneWidget);
  });
}
