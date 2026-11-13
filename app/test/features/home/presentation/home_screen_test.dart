import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/domain/product_result.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';
import 'package:qout/features/product/presentation/product_screen.dart';
import 'package:qout/features/scan/presentation/scan_screen.dart';

import '../../../helpers/fake_product_repository.dart';
import '../../../helpers/fake_scan_history_repository.dart';
import '../../../helpers/fake_scanner_platform.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('shows a Scan button', (tester) async {
    await tester.pumpQoutApp();

    expect(
      find.ancestor(
        of: find.text('Scan'),
        matching: find.bySubtype<FilledButton>(),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
  });

  testWidgets('Scan opens the scanner', (tester) async {
    installFakeScanner();
    await tester.pumpQoutApp();

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.byType(ScanScreen), findsOneWidget);
    expect(find.byKey(FakeScannerPlatform.cameraKey), findsOneWidget);
  });

  testWidgets('a scanned code opens its product; back returns home', (
    tester,
  ) async {
    final scanner = installFakeScanner();
    final history = FakeScanHistoryRepository();
    final repository = FakeProductRepository(
      results: [recordedFound('product-water')],
    );
    await tester.pumpQoutApp(
      history: history,
      overrides: [productRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      scanner.emitCode('6191234567897');
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(ProductScreen), findsOneWidget);
    expect(repository.requested, ['6191234567897']);
    expect(find.text('Plain water is always graded A.'), findsOneWidget);
    expect(find.byType(ScanScreen), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(history.entries.map((e) => e.ean), ['6191234567897']);
    expect(find.byType(HistoryTile), findsOneWidget);
    expect(find.textContaining('6191234567897'), findsOneWidget);
  });

  group('history', () {
    late FakeScanHistoryRepository history;
    final t0 = DateTime.utc(2026, 11, 13, 9);

    setUp(() => history = FakeScanHistoryRepository());

    Future<void> pumpHome(
      WidgetTester tester, {
      FakeProductRepository? products,
    }) => tester.pumpQoutApp(
      history: history,
      overrides: [
        if (products != null)
          productRepositoryProvider.overrideWithValue(products),
      ],
    );

    Finder tile(String text) => find.ancestor(
      of: find.textContaining(text),
      matching: find.byType(HistoryTile),
    );

    testWidgets('empty state', (tester) async {
      await pumpHome(tester);

      expect(find.text('No scans yet'), findsOneWidget);
      expect(
        find.text('Scanned products appear here, also offline.'),
        findsOneWidget,
      );
      expect(find.byTooltip('More'), findsNothing);
    });

    testWidgets('newest first, with grade, name and brand', (tester) async {
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
        ..seed('6191234567897', at: t0.add(const Duration(minutes: 2)));
      await pumpHome(tester);

      final tiles = tester.widgetList<HistoryTile>(find.byType(HistoryTile));
      expect(tiles.map((t) => t.entry.ean), [
        '6191234567897',
        '6191416500452',
        '9557062321136',
      ]);
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
      // No grade, no name: barcode instead of a brand.
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
      expect(find.text('No scans yet'), findsNothing);
    });

    testWidgets('tap reopens the product', (tester) async {
      history.seed('9557062321136', product: recordedProduct('product-water'));
      final products = FakeProductRepository(
        results: [recordedFound('product-water')],
      );
      await pumpHome(tester, products: products);

      await tester.tap(find.byType(HistoryTile));
      await tester.pumpAndSettle();

      expect(find.byType(ProductScreen), findsOneWidget);
      expect(products.requested, ['9557062321136']);
    });

    testWidgets('swipe removes an entry, Undo brings it back', (tester) async {
      history
        ..seed('111', at: t0)
        ..seed('222', at: t0.add(const Duration(minutes: 1)));
      await pumpHome(tester);

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
      await pumpHome(tester);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear history'));
      await tester.pumpAndSettle();
      expect(find.text('Clear history?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(history.entries, hasLength(2));

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(history.entries, isEmpty);
      expect(find.text('No scans yet'), findsOneWidget);
    });
  });
}

ProductResult recordedFound(String fixture) => ProductResult.found(
  product: recordedProduct(fixture),
  fetchedAt: DateTime.utc(2026, 11, 13),
  freshness: ProductFreshness.fresh,
);
