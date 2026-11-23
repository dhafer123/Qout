import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/api/api_providers.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/ui/veggie.dart';
import 'package:qout/features/auth/domain/auth_session.dart';
import 'package:qout/features/auth/presentation/sign_in_screen.dart';
import 'package:qout/features/contribute/presentation/contribute_screen.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/domain/product_result.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';
import 'package:qout/features/product/presentation/product_photo.dart';
import 'package:qout/features/product/presentation/product_screen.dart';
import 'package:qout/features/scan/presentation/scan_screen.dart';

import '../../../helpers/fake_alternatives_repository.dart';
import '../../../helpers/fake_auth_api.dart';
import '../../../helpers/fake_product_repository.dart';
import '../../../helpers/fake_scanner_platform.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/in_memory_token_store.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/veggie_finder.dart';

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
  late FakeAlternativesRepository alternatives;
  late AppDatabase database;
  late InMemoryTokenStore tokens;
  late FakeAuthApi authApi;

  setUp(() {
    repository = FakeProductRepository();
    alternatives = FakeAlternativesRepository();
    tokens = InMemoryTokenStore();
    authApi = FakeAuthApi();
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  /// Opens the result screen for [ean] on a tall screen (whole page built).
  Future<void> openProduct(
    WidgetTester tester, [
    String ean = '123',
    List<Override> overrides = const [],
  ]) async {
    tester.view
      ..physicalSize = const Size(800, 4000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpQoutApp(
      database: database,
      alternatives: alternatives,
      tokens: tokens,
      overrides: [
        productRepositoryProvider.overrideWithValue(repository),
        authApiProvider.overrideWithValue(authApi),
        ...overrides,
      ],
    );
    await tester.pushRoute(AppRoutes.product(ean));
  }

  group('product found', () {
    testWidgets('photo from our storage above the name', (tester) async {
      const url = 'https://media.qout.example/products/9557062321136/front.jpg';
      final json = recordedProductJson('product-general-graded')
        ..['image_url'] = url;
      repository.results = [
        ProductResult.found(
          product: ProductDetail.fromJson(json),
          fetchedAt: _fetchedAt,
          freshness: ProductFreshness.fresh,
        ),
      ];
      final requested = <String>[];
      await openProduct(tester, '9557062321136', [
        productImageProvider.overrideWithValue((url) {
          requested.add(url);
          return const _NoImage();
        }),
      ]);

      expect(requested, [url]);
      final photo = find.byType(ProductPhoto);
      expect(photo, findsOneWidget);
      expect(
        tester.getTopLeft(photo).dy,
        lessThan(tester.getTopLeft(find.text('Jbs qtw')).dy),
      );
    });

    testWidgets('no photo URL: no photo', (tester) async {
      repository.results = [_found('product-general-graded')];
      await openProduct(tester, '9557062321136');

      expect(find.byType(Image), findsNothing);
    });

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
      expect(find.text('COUNTS AGAINST IT'), findsOneWidget);
      expect(find.text('22 PTS'), findsOneWidget);
      expect(find.text('COUNTS IN ITS FAVOUR'), findsOneWidget);
      expect(find.text('0 PTS'), findsOneWidget);
      expect(_component('energy', 'Energy', '6 / 10', '2056 kJ'), findsOne);
      expect(
        _component('saturated_fat', 'Saturated fat', '10 / 10', '12.5 g'),
        findsOne,
      );
      expect(_component('salt', 'Salt', '6 / 20', '1.23 g'), findsOne);
      expect(
        _component('protein', 'Protein (not counted)', '2 / 7', null),
        findsOne,
      );
      expect(find.text('22 against − 0 in favour'), findsOneWidget);
      expect(find.text('22 pts · E'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label ==
                  'Total: 22 against minus 0 in favour makes 22 points, '
                      'grade E',
        ),
        findsOneWidget,
      );
      // Grade card.
      expect(find.text('Grade E'), findsOneWidget);
      expect(
        find.text('On a scale from A (best) to E (worst)'),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('grade-track-E'))).height,
        greaterThan(
          tester.getSize(find.byKey(const ValueKey('grade-track-A'))).height,
        ),
      );
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
      expect(_row('of which saturates', '12.5 g'), findsOneWidget);
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
      expect(
        _component(
          'non_nutritive_sweeteners',
          'Sweeteners',
          '4 / 4',
          'Contains sweeteners',
        ),
        findsOne,
      );
      expect(_row('Sweeteners', 'Yes'), findsOneWidget);
      expect(_component('protein', 'Protein', '0 / 7', null), findsOne);
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

  group('missing values', () {
    const ean = '6194017503778';
    const addValues = 'Add the nutrition values';

    /// A known product without a grade, with a name and brand.
    ProductResult incomplete() => ProductResult.found(
      product: ProductDetail.fromJson({
        ...recordedProductJson('product-insufficient-data'),
        'ean': ean,
        'name': 'Chamia aux pistaches',
        'brand': 'Le Moulin',
      }),
      fetchedAt: _fetchedAt,
      freshness: ProductFreshness.fresh,
    );

    void signIn() => tokens.session = AuthSession(
      email: 'a@example.tn',
      accessToken: 'access',
      accessExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
      refreshToken: 'refresh',
      refreshExpiresAt: DateTime.now().add(const Duration(days: 30)),
    );

    for (final fixture in [
      'product-insufficient-data',
      'product-unknown-category',
    ]) {
      testWidgets('offered when there is no grade: $fixture', (tester) async {
        repository.results = [_found(fixture)];
        await openProduct(tester);

        expect(find.text(addValues), findsOneWidget);
        expect(
          find.textContaining('adding the values from a photo'),
          findsOneWidget,
        );
      });
    }

    for (final fixture in [
      'product-general-graded',
      'product-beverage-graded',
      'product-water',
    ]) {
      testWidgets('not offered for a graded product: $fixture', (
        tester,
      ) async {
        repository.results = [_found(fixture)];
        await openProduct(tester);

        expect(find.text(addValues), findsNothing);
      });
    }

    testWidgets('needs an account', (tester) async {
      repository.results = [incomplete()];
      await openProduct(tester, ean);

      await tester.tap(find.text(addValues));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(
        find.textContaining('Sign in to add nutrition values'),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ContributeScreen), findsNothing);
      expect(find.text(addValues), findsOneWidget);
    });

    testWidgets('signed in: completes the known product', (tester) async {
      signIn();
      repository.results = [incomplete()];
      await openProduct(tester, ean);

      await tester.tap(find.text(addValues));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsNothing);
      expect(find.byType(ContributeScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(addValues),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Chamia aux pistaches cannot be graded yet'),
        findsOneWidget,
      );
      // The lookup was not made again.
      expect(repository.requested, [ean]);
    });
  });

  group('no product', () {
    testWidgets('unknown product: adding it needs an account', (
      tester,
    ) async {
      repository.results = [const ProductResult.notFound(ean: '6191234567897')];
      await openProduct(tester, '6191234567897');

      expect(find.text('We do not know this product yet'), findsOneWidget);
      expect(find.textContaining('Barcode 6191234567897'), findsOneWidget);
      expect(findVeggie(VeggieFor.unknown), findsOneWidget);

      await tester.tap(find.text('Add this product'));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.textContaining('Sign in to add products'), findsOneWidget);

      // Back without signing in: nothing else happens.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('We do not know this product yet'), findsOneWidget);
      expect(find.byType(ContributeScreen), findsNothing);
    });

    testWidgets('unknown product: after signing in, adding continues', (
      tester,
    ) async {
      repository.results = [const ProductResult.notFound(ean: '6191234567897')];
      authApi.loginResults.add(pair('1'));
      await openProduct(tester, '6191234567897');
      await tester.tap(find.text('Add this product'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'a@example.tn',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'a long password',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsNothing);
      expect(find.byType(ContributeScreen), findsOneWidget);
      expect(
        find.textContaining('Barcode 6191234567897. Take'),
        findsOneWidget,
      );

      // Back from adding: the product page again.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('We do not know this product yet'), findsOneWidget);
    });

    testWidgets('unknown product: signed in already, no detour', (
      tester,
    ) async {
      tokens.session = AuthSession(
        email: 'a@example.tn',
        accessToken: 'access',
        accessExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
        refreshToken: 'refresh',
        refreshExpiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      repository.results = [const ProductResult.notFound(ean: '6191234567897')];
      await openProduct(tester, '6191234567897');

      await tester.tap(find.text('Add this product'));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsNothing);
      expect(find.byType(ContributeScreen), findsOneWidget);
      // A new product, not a known one being completed.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Add a product'),
        ),
        findsOneWidget,
      );
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

  group('better choices', () {
    const oats = AlternativeProduct(
      ean: '6191234567897',
      name: 'Oat crackers',
      brand: 'Saida',
      grade: Grade.b,
    );
    const rice = AlternativeProduct(
      ean: '6191234567880',
      name: 'Rice cakes',
      grade: Grade.a,
    );

    testWidgets('shown with grade, name and brand', (tester) async {
      repository.results = [_found('product-general-graded')];
      alternatives.items = [oats, rice];
      await openProduct(tester, '9557062321136');
      await tester.pump();

      expect(alternatives.requested, ['9557062321136']);
      expect(find.text('Better choices'), findsOneWidget);
      expect(find.text('Oat crackers'), findsOneWidget);
      expect(find.text('Saida'), findsOneWidget);
      expect(find.text('Rice cakes'), findsOneWidget);
      expect(_badge(Grade.b), findsOneWidget);
      expect(_badge(Grade.a), findsOneWidget);
    });

    testWidgets('tap opens the alternative', (tester) async {
      repository.results = [_found('product-general-graded')];
      alternatives.items = [oats];
      await openProduct(tester, '9557062321136');
      await tester.pump();

      repository.results = [_found('product-water')];
      await tester.tap(find.text('Oat crackers'));
      await tester.pumpAndSettle();

      expect(repository.requested, ['9557062321136', '6191234567897']);
      expect(find.text('Plain water is always graded A.'), findsOneWidget);
    });

    testWidgets('hidden when there are none', (tester) async {
      repository.results = [_found('product-general-graded')];
      await openProduct(tester, '9557062321136');
      await tester.pump();

      expect(alternatives.requested, ['9557062321136']);
      expect(find.text('Better choices'), findsNothing);
    });

    testWidgets('hidden when they cannot be fetched (offline)', (
      tester,
    ) async {
      repository.results = [_found('product-general-graded')];
      alternatives
        ..items = [oats]
        ..error = const ApiConnectionError('offline');
      await openProduct(tester, '9557062321136');
      await tester.pump();

      expect(find.text('Better choices'), findsNothing);
      expect(find.text('Jbs qtw'), findsOneWidget); // the result is unaffected
    });

    for (final (fixture, why) in [
      ('product-water', 'grade A'),
      ('product-insufficient-data', 'no grade'),
      ('product-unknown-category', 'not scored'),
    ]) {
      testWidgets('not asked for: $why', (tester) async {
        repository.results = [_found(fixture)];
        alternatives.items = [oats];
        await openProduct(tester);
        await tester.pump();

        expect(find.text('Better choices'), findsNothing);
        expect(alternatives.requested, isEmpty);
      });
    }
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
      expect(await database.outboxDao.all(), isEmpty);
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
      final rows = await tester.runAsync(database.outboxDao.all);
      final [row] = rows!;
      expect(row.kind, 'error_report');
      expect(row.payload, contains('"ean":"9557062321136"'));
      expect(row.payload, contains('"reasons":["nutrition"]'));
      expect(row.payload, contains('"comment":"Salt is 0.3 g"'));
    });
  });

  testWidgets('the app bar shows the name once it has scrolled away', (
    tester,
  ) async {
    repository.results = [_found('product-general-graded')];
    await openProduct(tester);
    // Not tall here: the page must scroll.
    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();

    final inAppBar = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Jbs qtw'),
    );
    expect(inAppBar, findsNothing);
    expect(find.text('Jbs qtw'), findsOneWidget); // the header

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(inAppBar, findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(inAppBar, findsNothing);
  });
}

/// A row showing [label] and [value] side by side.
Finder _row(String label, String value) => find.byWidgetPredicate(
  (widget) =>
      (widget is Row || widget is Wrap) &&
      _children(widget).length == 2 &&
      _text(_children(widget).first) == label &&
      _text(_children(widget).last) == value,
);

List<Widget> _children(Widget widget) => switch (widget) {
  Row(:final children) || Wrap(:final children) => children,
  _ => const [],
};

String? _text(Widget widget) => switch (widget) {
  Text(:final data) => data,
  Expanded(child: Text(:final data)) => data,
  _ => null,
};

/// A score component row: its label, points and (when declared) amount.
Finder _component(String name, String label, String points, String? amount) {
  final row = find.byKey(ValueKey('component-$name'));
  return find.byWidgetPredicate((widget) {
    if (widget.key != ValueKey('component-$name')) return false;
    bool has(String text) => find
        .descendant(of: row, matching: find.text(text))
        .evaluate()
        .isNotEmpty;
    return has(label) && has(points) && (amount == null || has(amount));
  });
}

/// The grade badge showing [grade] (null: no grade).
Finder _badge(Grade? grade) => find.byWidgetPredicate(
  (widget) => widget is GradeBadge && widget.grade == grade,
);

/// The "checking for updates" bar under the app bar.
final Finder _refreshBar = find.descendant(
  of: find.byType(AppBar),
  matching: find.byType(LinearProgressIndicator),
);

/// An image that never finishes loading (the test checks layout only).
class _NoImage extends ImageProvider<_NoImage> {
  const _NoImage();

  @override
  Future<_NoImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_NoImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}
