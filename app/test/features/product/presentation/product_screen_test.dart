import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/database/database_provider.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/domain/product_result.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';
import 'package:qout/features/product/presentation/product_screen.dart';
import 'package:qout/features/scan/presentation/scan_screen.dart';

import '../../../helpers/fake_product_repository.dart';
import '../../../helpers/fake_scanner_platform.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

final _fetchedAt = DateTime.utc(2026, 11, 12, 18);

ProductResult _found(
  String fixture, [
  ProductFreshness freshness = ProductFreshness.fresh,
  QoutApiException? refreshError,
]) => ProductResult.found(
  product: recordedProduct(fixture),
  fetchedAt: _fetchedAt,
  freshness: freshness,
  refreshError: refreshError,
);

void main() {
  late FakeProductRepository repository;
  late AppDatabase database;

  setUp(() {
    repository = FakeProductRepository();
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  /// Opens the result screen for [ean] on a tall screen (whole page built).
  Future<void> openProduct(WidgetTester tester, [String ean = '123']) async {
    tester.view
      ..physicalSize = const Size(800, 4000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpQoutApp(
      overrides: [
        productRepositoryProvider.overrideWithValue(repository),
        appDatabaseProvider.overrideWithValue(database),
      ],
    );
    await tester.pushRoute(AppRoutes.product(ean));
  }

  group('product found', () {
    testWidgets('full result: grade, breakdown, nutrition, NOVA, additives', (
      tester,
    ) async {
      repository.results = [_found('product-general-graded')];
      await openProduct(tester, '9557062321136');

      expect(repository.requested, ['9557062321136']);
      // Header.
      expect(_badge(Grade.e), findsOneWidget);
      expect(find.text('Jbs qtw'), findsOneWidget);
      expect(find.text('Mister Potato'), findsOneWidget);
      expect(find.text('Barcode 9557062321136'), findsOneWidget);
      // Why this score.
      expect(find.text('Why this score'), findsOneWidget);
      expect(find.text('Negative points: 22'), findsOneWidget);
      expect(find.text('Positive points: 2'), findsOneWidget);
      expect(_row('Energy', '6 / 10'), findsOneWidget);
      expect(_row('Saturated fat', '10 / 10'), findsOneWidget);
      expect(_row('Salt', '6 / 20'), findsOneWidget);
      expect(_row('Protein (not counted)', '2 / 7'), findsOneWidget);
      expect(find.text('Score: 22 − 0 = 22, grade E'), findsOneWidget);
      expect(
        find.textContaining('with 11 or more negative points'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Fibre is not declared, so it counts as 0'),
        findsOneWidget,
      );
      // Nutrition per 100 g.
      expect(find.text('Nutrition per 100 g'), findsOneWidget);
      expect(_row('Energy', '2056 kJ / 491 kcal'), findsOneWidget);
      expect(_row('Fat', '25 g'), findsOneWidget);
      expect(_row('of which saturated', '12.5 g'), findsOneWidget);
      expect(_row('Salt', '1.23 g'), findsOneWidget);
      expect(_row('Fibre', '–'), findsOneWidget);
      expect(find.text('Sweeteners'), findsNothing);
      // NOVA, additives, source.
      expect(find.text('Group 4: Ultra-processed foods'), findsOneWidget);
      expect(find.text('Additives (2)'), findsOneWidget);
      expect(
        find.text('E320 · Butylated hydroxyanisole (bha)'),
        findsOneWidget,
      );
      expect(find.text('Not evaluated'), findsNWidgets(2));
      expect(find.text('Open Food Facts · Not verified yet'), findsOneWidget);
      expect(find.textContaining('Updated '), findsOneWidget);
      expect(find.text('Report an error'), findsOneWidget);
      // Fresh: no progress bar, no offline banner.
      expect(_refreshBar, findsNothing);
      expect(find.textContaining('Showing the version saved'), findsNothing);
    });

    testWidgets('beverage: per 100 mL, sweeteners', (tester) async {
      repository.results = [_found('product-beverage-graded')];
      await openProduct(tester);

      expect(find.text('Nutrition per 100 mL'), findsOneWidget);
      expect(_row('Sweeteners', '4 / 4'), findsOneWidget);
      expect(_row('Sweeteners', 'Yes'), findsOneWidget);
      expect(_row('Protein', '0 / 7'), findsOneWidget);
      expect(find.textContaining('Protein does not count'), findsNothing);
      expect(find.textContaining('Fibre is not declared'), findsNothing);
    });

    testWidgets('water: always A', (tester) async {
      repository.results = [_found('product-water')];
      await openProduct(tester);

      expect(_badge(Grade.a), findsOneWidget);
      expect(find.text('Plain water is always graded A.'), findsOneWidget);
    });

    testWidgets('insufficient data: no grade, what is missing', (
      tester,
    ) async {
      repository.results = [_found('product-insufficient-data')];
      await openProduct(tester);

      expect(_badge(null), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
      expect(find.text('Unnamed product'), findsOneWidget);
      expect(
        find.text(
          'Not enough data to grade this product. Missing: salt, sugars.',
        ),
        findsOneWidget,
      );
      expect(_row('Salt', '–'), findsOneWidget);
      expect(
        find.text('Some values are missing from the source.'),
        findsOneWidget,
      );
      expect(
        find.text('High risk of exceeding the acceptable daily intake (EFSA)'),
        findsNWidgets(2),
      );
    });

    testWidgets('unknown category: not scored, no data', (tester) async {
      repository.results = [_found('product-unknown-category')];
      await openProduct(tester);

      expect(_badge(null), findsOneWidget);
      expect(
        find.textContaining('its food category is unknown'),
        findsOneWidget,
      );
      expect(
        find.text('No nutrition values for this product yet.'),
        findsOneWidget,
      );
      expect(find.text('Unknown'), findsOneWidget); // NOVA
      expect(find.text('No additives listed.'), findsOneWidget);
    });
  });

  group('cached product', () {
    testWidgets('offline: the saved version, with when it was saved', (
      tester,
    ) async {
      repository.results = [
        _found(
          'product-general-graded',
          ProductFreshness.refreshFailed,
          const ApiConnectionError('offline'),
        ),
      ];
      await openProduct(tester);

      expect(
        find.textContaining('You are offline. Showing the version saved on'),
        findsOneWidget,
      );
      expect(find.text('Jbs qtw'), findsOneWidget);
      expect(_badge(Grade.e), findsOneWidget);
    });

    testWidgets('server down: the saved version', (tester) async {
      repository.results = [
        _found(
          'product-general-graded',
          ProductFreshness.refreshFailed,
          const ApiUnavailable('down'),
        ),
      ];
      await openProduct(tester);

      expect(
        find.textContaining('Qout could not be reached. Showing the version'),
        findsOneWidget,
      );
    });

    testWidgets('refreshing: shown at once, progress until refreshed', (
      tester,
    ) async {
      final results = StreamController<ProductResult>();
      addTearDown(results.close);
      repository.controller = results;
      await openProduct(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      results.add(
        _found('product-general-graded', ProductFreshness.refreshing),
      );
      await tester.pump();
      expect(find.text('Jbs qtw'), findsOneWidget);
      expect(_refreshBar, findsOneWidget);

      results.add(_found('product-general-graded'));
      await tester.pump();
      expect(find.text('Jbs qtw'), findsOneWidget);
      expect(_refreshBar, findsNothing);
    });
  });

  group('no product', () {
    testWidgets('unknown product: offers to add it', (tester) async {
      repository.results = [const ProductResult.notFound(ean: '6191234567897')];
      await openProduct(tester, '6191234567897');

      expect(find.text('We do not know this product yet'), findsOneWidget);
      expect(find.textContaining('Barcode 6191234567897'), findsOneWidget);

      await tester.tap(find.text('Add this product'));
      await tester.pump();
      expect(find.text('Adding products is coming soon.'), findsOneWidget);
    });

    testWidgets('unknown product: scan another opens the scanner', (
      tester,
    ) async {
      installFakeScanner();
      repository.results = [const ProductResult.notFound(ean: '6191234567897')];
      await openProduct(tester);

      await tester.tap(find.text('Scan another barcode'));
      await tester.pumpAndSettle();
      expect(find.byType(ScanScreen), findsOneWidget);
      expect(find.byType(ProductScreen), findsNothing);
    });

    testWidgets('invalid barcode: the reason', (tester) async {
      repository.results = [
        const ProductResult.invalidBarcode(
          ean: '6191234567890',
          message: 'wrong check digit',
        ),
      ];
      await openProduct(tester);

      expect(find.text('This barcode is not valid'), findsOneWidget);
      expect(find.text('6191234567890: wrong check digit'), findsOneWidget);
      expect(find.text('Scan another barcode'), findsOneWidget);
    });

    testWidgets('offline and not saved: retry looks up again', (
      tester,
    ) async {
      repository.results = [
        const ProductResult.unavailable(
          ean: '123',
          error: ApiConnectionError('offline'),
        ),
      ];
      await openProduct(tester);

      expect(find.text('You are offline'), findsOneWidget);
      expect(find.textContaining('not saved on your phone'), findsOneWidget);

      repository.results = [_found('product-water')];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(repository.requested, ['123', '123']);
      expect(find.text('Plain water is always graded A.'), findsOneWidget);
    });

    testWidgets('server unavailable: when to try again', (tester) async {
      repository.results = [
        const ProductResult.unavailable(
          ean: '123',
          error: ApiUnavailable('busy', retryAfter: Duration(seconds: 30)),
        ),
      ];
      await openProduct(tester);

      expect(find.text('Qout is unavailable right now'), findsOneWidget);
      expect(find.text('Try again in 30 seconds.'), findsOneWidget);
    });

    testWidgets('server unavailable without a delay', (tester) async {
      repository.results = [
        const ProductResult.unavailable(
          ean: '123',
          error: ApiBadResponse(418, 'teapot'),
        ),
      ];
      await openProduct(tester);

      expect(find.text('Try again in a moment.'), findsOneWidget);
    });

    testWidgets('an unexpected failure can be retried', (tester) async {
      final results = StreamController<ProductResult>();
      addTearDown(results.close);
      repository.controller = results;
      await openProduct(tester);

      results.addError(StateError('boom'));
      await tester.pump();
      expect(find.text('Something went wrong'), findsOneWidget);

      repository
        ..controller = null
        ..results = [_found('product-water')];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Plain water is always graded A.'), findsOneWidget);
    });
  });

  group('report an error', () {
    Future<void> openReport(WidgetTester tester) async {
      repository.results = [_found('product-general-graded')];
      await openProduct(tester, '9557062321136');
      await tester.tap(find.text('Report an error'));
      await tester.pumpAndSettle();
    }

    testWidgets('needs a reason', (tester) async {
      await openReport(tester);

      await tester.tap(find.text('Send report'));
      await tester.pump();

      expect(find.text('Choose at least one.'), findsOneWidget);
      expect(await database.outboxDao.pending(), isEmpty);
    });

    testWidgets('"something else" needs details', (tester) async {
      await openReport(tester);

      await tester.tap(find.text('Something else'));
      await tester.tap(find.text('Send report'));
      await tester.pump();
      expect(find.text('Say what is wrong.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Wrong photo');
      await tester.pump();
      expect(find.text('Say what is wrong.'), findsNothing);
    });

    testWidgets('a valid report is queued and confirmed', (tester) async {
      await openReport(tester);

      await tester.tap(find.text('Nutrition values'));
      await tester.enterText(find.byType(TextField), 'Salt is 0.3 g');
      await tester.tap(find.text('Send report'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text('Send report'), findsNothing);
      expect(
        find.textContaining('Thanks! Your report is saved'),
        findsOneWidget,
      );
      final rows = await tester.runAsync(database.outboxDao.pending);
      final [row] = rows!;
      expect(row.kind, 'error_report');
      expect(row.payload, contains('"ean":"9557062321136"'));
      expect(row.payload, contains('"reasons":["nutrition"]'));
      expect(row.payload, contains('"comment":"Salt is 0.3 g"'));
    });
  });
}

/// A row showing [label] and [value] side by side.
Finder _row(String label, String value) => find.byWidgetPredicate(
  (widget) =>
      widget is Row &&
      widget.children.length == 2 &&
      _text(widget.children.first) == label &&
      _text(widget.children.last) == value,
);

String? _text(Widget widget) => switch (widget) {
  Text(:final data) => data,
  Expanded(child: Text(:final data)) => data,
  _ => null,
};

/// The grade badge showing [grade] (null: no grade).
Finder _badge(Grade? grade) => find.byWidgetPredicate(
  (widget) => widget is GradeBadge && widget.grade == grade,
);

/// The "checking for updates" bar under the app bar.
final Finder _refreshBar = find.descendant(
  of: find.byType(AppBar),
  matching: find.byType(LinearProgressIndicator),
);
