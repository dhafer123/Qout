import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/api/qout_api.dart' hide Allergen;
import 'package:qout/core/database/database.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/domain/product_result.dart';
import 'package:qout/features/profile/data/profile_repository.dart';
import 'package:qout/features/profile/presentation/profile_edit_screen.dart';
import 'package:qout/health/profile.dart';

import '../../../helpers/fake_product_repository.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

/// scoring-spec/needs: 10029 kJ, fat 95 g, saturates 27 g, sugars 90, salt 5.
Profile _profile({Set<Allergen> allergens = const {}}) => Profile(
  sex: Sex.female,
  age: 22,
  heightCm: 165,
  weightKg: 58,
  activity: ActivityLevel.active,
  allergens: allergens,
);

ProductResult _found(Map<String, Object?> json) => ProductResult.found(
  product: ProductDetail.fromJson(json),
  fetchedAt: DateTime.utc(2026, 11, 19),
  freshness: ProductFreshness.fresh,
);

/// The share row for [nutrient]: its label and value, as read aloud.
Finder _share(String nutrient, String value) =>
    find.bySemanticsLabel(RegExp('^$nutrient\\s+${RegExp.escape(value)}\$'));

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  /// Opens the product [fixture] (possibly edited) on a tall screen.
  Future<void> open(
    WidgetTester tester,
    Map<String, Object?> json, {
    Profile? profile,
    Set<String> avoided = const {},
    bool live = false,
  }) async {
    tester.view
      ..physicalSize = const Size(600, 3600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpQoutApp(
      database: database,
      profile: profile,
      avoidedAdditives: avoided,
      liveProfile: live,
      overrides: [
        productRepositoryProvider.overrideWithValue(
          FakeProductRepository(results: [_found(json)]),
        ),
      ],
    );
    await tester.pushRoute(AppRoutes.product('6194002510064'));
    await tester.pumpAndSettle();
  }

  Map<String, Object?> biscuit() =>
      recordedProductJson('product-serving-allergens');

  testWidgets('with a profile: allergens, then shares of a serving', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await open(
      tester,
      biscuit(),
      profile: _profile(allergens: {Allergen.milk, Allergen.nuts}),
    );

    expect(find.text('For you'), findsOneWidget);
    expect(
      find.text('Contains milk, which you listed as an allergy.'),
      findsOneWidget,
    );
    expect(
      find.text('May contain traces of nuts, which you listed as an allergy.'),
      findsOneWidget,
    );
    expect(
      find.text('1 serving (21.7 g) gives this share of your daily needs:'),
      findsOneWidget,
    );
    expect(find.text('On the label: 21.7g'), findsOneWidget);
    expect(_share('Energy', '4 %'), findsOneWidget);
    expect(_share('Fat', '5 %'), findsOneWidget);
    expect(_share('Saturated fat', '9 %'), findsOneWidget);
    expect(_share('Sugars', '6 %'), findsOneWidget);
    expect(_share('Salt', '1 %'), findsOneWidget);
    expect(find.text('Set up my profile'), findsNothing);
    expect(
      find.text('General information, not medical advice.'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('without a profile: the reference intakes, and set up', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await open(tester, biscuit());

    expect(
      find.text(
        '1 serving (21.7 g) gives this share of the reference intake for an '
        'average adult:',
      ),
      findsOneWidget,
    );
    expect(_share('Energy', '5 %'), findsOneWidget); // 42966 / 8400
    expect(find.textContaining('which you listed'), findsNothing);
    expect(
      find.text('Set up your profile to compare with your own needs.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Set up my profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileEditScreen), findsOneWidget);
    handle.dispose();
  });

  testWidgets('no serving: per 100 g', (tester) async {
    await open(tester, biscuit()..['serving'] = null);
    expect(
      find.textContaining('100 g gives this share of the reference intake'),
      findsOneWidget,
    );
    expect(find.textContaining('On the label'), findsNothing);
  });

  testWidgets('high EFSA flags, and partial nutrition still shares', (
    tester,
  ) async {
    await open(tester, recordedProductJson('product-insufficient-data'));
    expect(
      find.text(
        'E450 Diphosphates: EFSA found a high risk that some people take in '
        'more than the acceptable daily intake.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('gives this share'), findsOneWidget);
  });

  testWidgets('no nutrition: no shares', (tester) async {
    await open(tester, recordedProductJson('product-unknown-category'));
    expect(
      find.text("No nutrition values yet, so shares can't be shown."),
      findsOneWidget,
    );
    expect(find.textContaining('gives this share'), findsNothing);
  });

  testWidgets('no allergens listed: check the label', (tester) async {
    await open(
      tester,
      biscuit()
        ..['allergens'] = <String>[]
        ..['traces'] = <String>[],
      profile: _profile(allergens: {Allergen.eggs}),
    );
    expect(
      find.text(
        'Open Food Facts lists no allergens for this product. Check the label.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an additive the user avoids', (tester) async {
    await open(tester, biscuit(), avoided: {'E330'});
    expect(
      find.text('Contains E330 Citric acid, which you chose to avoid.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Stop avoiding E330'), findsOneWidget);
  });

  testWidgets('avoiding from the additives list, and stopping on the profile', (
    tester,
  ) async {
    // One-shot reads: a drift stream never delivers under the test clock.
    Future<String?> avoided() async =>
        (await database.profileDao.get())?.avoidedAdditives;
    await open(tester, biscuit(), live: true);

    await tester.scrollUntilVisible(
      find.byTooltip('Avoid E476'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Avoid E476'));
    await tester.pumpAndSettle();
    expect(
      find.text('You avoid E476: products with it are pointed out.'),
      findsOneWidget,
    );
    expect(await avoided(), '["E476"]');
    expect(find.byTooltip('Stop avoiding E476'), findsOneWidget);
    expect(
      find.text(
        'Contains E476 Polyglycerol polyricinoleate, which you chose to avoid.',
      ),
      findsOneWidget,
    );

    // The profile lists it; removing it there stops avoiding it.
    unawaited(
      GoRouter.of(tester.element(find.text('For you'))).push(AppRoutes.profile),
    );
    await tester.pumpAndSettle();
    expect(find.text('ADDITIVES YOU AVOID'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Stop avoiding E476'));
    await tester.pumpAndSettle();
    expect(find.text('ADDITIVES YOU AVOID'), findsNothing);
    expect(await avoided(), '[]');
    await tester.unmountQoutApp();
  });

  testWidgets('loading the profile shows nothing yet', (tester) async {
    tester.view
      ..physicalSize = const Size(600, 3600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpQoutApp(
      overrides: [
        profileProvider.overrideWith((ref) => const Stream.empty()),
        productRepositoryProvider.overrideWithValue(
          FakeProductRepository(results: [_found(biscuit())]),
        ),
      ],
    );
    await tester.pushRoute(AppRoutes.product('6194002510064'));
    await tester.pumpAndSettle();
    expect(find.text('For you'), findsNothing);
    expect(find.text('Why this score'), findsOneWidget);
  });
}
