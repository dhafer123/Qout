import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/features/diary/presentation/diary_screen.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/domain/product_result.dart';
import 'package:qout/features/product/presentation/product_screen.dart';
import 'package:qout/features/scan/presentation/scan_screen.dart';

import '../../../helpers/fake_product_repository.dart';
import '../../../helpers/fake_scan_history_repository.dart';
import '../../../helpers/fake_scanner_platform.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

void main() {
  group('greeting', () {
    test('by name, else by the time of day', () {
      final morning = DateTime(2026, 11, 20, 8);
      expect(greeting('Dhafer', morning), 'Hello, Dhafer');
      expect(greeting(null, morning), 'Good morning');
      expect(greeting(null, DateTime(2026, 11, 20, 12)), 'Good afternoon');
      expect(greeting(null, DateTime(2026, 11, 20, 18)), 'Good evening');
    });

    testWidgets('Today greets with the first name', (tester) async {
      await tester.pumpQoutApp(firstName: 'Dhafer');
      expect(find.text('Hello, Dhafer'), findsOneWidget);
      expect(find.text('D'), findsOneWidget); // the initial
    });
  });

  testWidgets("Scan now and the bar's scan button open the scanner", (
    tester,
  ) async {
    installFakeScanner();
    await tester.pumpQoutApp();

    await tester.tap(find.text('Scan now'));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(find.byKey(FakeScannerPlatform.cameraKey), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scan-button')));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsOneWidget);
  });

  testWidgets('a scanned code opens its product; back shows it on Today', (
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
    await tester.tap(find.text('Scan now'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      scanner.emitCode('6191234567897');
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(ProductScreen), findsOneWidget);
    expect(repository.requested.toSet(), {'6191234567897'});
    expect(find.text('Grade A'), findsOneWidget); // the water, loaded
    expect(find.byType(ScanScreen), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(history.entries.map((e) => e.ean), ['6191234567897']);
    expect(find.byType(RecentScanCard), findsOneWidget);
  });

  group('typing a barcode', () {
    testWidgets('a valid one opens the product and is kept in the history', (
      tester,
    ) async {
      final history = FakeScanHistoryRepository();
      final repository = FakeProductRepository(
        results: [recordedFound('product-water')],
      );
      await tester.pumpQoutApp(
        history: history,
        overrides: [productRepositoryProvider.overrideWithValue(repository)],
      );

      await tester.enterText(find.byType(BarcodeField), '6191 2345 67897');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.byType(ProductScreen), findsOneWidget);
      expect(repository.requested, ['6191234567897']);
      expect(history.entries.map((e) => e.ean), ['6191234567897']);
    });

    testWidgets('a typo is pointed out, nothing opens', (tester) async {
      final history = FakeScanHistoryRepository();
      await tester.pumpQoutApp(history: history);

      await tester.enterText(find.byType(BarcodeField), '6191234567890');
      await tester.tap(find.byTooltip('Open this barcode'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Check the digits'), findsOneWidget);
      expect(find.byType(ProductScreen), findsNothing);
      expect(history.entries, isEmpty);
    });
  });

  group('recently scanned', () {
    testWidgets('empty: says where scans appear, no See all', (tester) async {
      await tester.pumpQoutApp();
      expect(find.textContaining('No scans yet'), findsOneWidget);
      expect(find.text('See all'), findsNothing);
    });

    testWidgets('cards with the name; See all opens the Diary tab', (
      tester,
    ) async {
      final history = FakeScanHistoryRepository()
        ..seed(
          '9557062321136',
          product: recordedProduct('product-general-graded'),
        );
      await tester.pumpQoutApp(history: history);

      expect(find.byType(RecentScanCard), findsOneWidget);
      expect(find.text('Jbs qtw'), findsOneWidget);

      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryScreen), findsOneWidget);
    });

    testWidgets('a card reopens its product', (tester) async {
      final history = FakeScanHistoryRepository()
        ..seed('9557062321136', product: recordedProduct('product-water'));
      final products = FakeProductRepository(
        results: [recordedFound('product-water')],
      );
      await tester.pumpQoutApp(
        history: history,
        overrides: [productRepositoryProvider.overrideWithValue(products)],
      );

      await tester.ensureVisible(find.byType(RecentScanCard));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(RecentScanCard));
      await tester.pumpAndSettle();
      expect(find.byType(ProductScreen), findsOneWidget);
      expect(products.requested, ['9557062321136']);
    });
  });
}

ProductResult recordedFound(String fixture) => ProductResult.found(
  product: recordedProduct(fixture),
  fetchedAt: DateTime.utc(2026, 11, 13),
  freshness: ProductFreshness.fresh,
);
