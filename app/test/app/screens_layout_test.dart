import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/api/qout_api.dart' hide Allergen;
import 'package:qout/core/database/database.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/domain/product_result.dart';
import 'package:qout/features/product/presentation/product_photo.dart';
import 'package:qout/features/profile/data/profile_repository.dart';
import 'package:qout/health/profile.dart';

import '../helpers/fake_contribution.dart';
import '../helpers/fake_product_repository.dart';
import '../helpers/fake_scan_history_repository.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';
import '../helpers/test_images.dart';

/// The reworked screens in both themes, at normal and double text size, on
/// a small phone (360 × 640 dp). Any overflow fails the test.
void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      group('${brightness.name}, text ×$scale', () {
        Future<void> configure(WidgetTester tester) async {
          tester.view
            ..physicalSize = const Size(360, 640)
            ..devicePixelRatio = 1;
          tester.platformDispatcher
            ..platformBrightnessTestValue = brightness
            ..textScaleFactorTestValue = scale;
          addTearDown(() {
            tester.view.reset();
            tester.platformDispatcher
              ..clearPlatformBrightnessTestValue()
              ..clearTextScaleFactorTestValue();
          });
        }

        testWidgets('home with history and photos', (tester) async {
          await configure(tester);
          final withPhoto = recordedProductJson('product-general-graded')
            ..['image_url'] = 'https://media.example/p.jpg';
          final history = FakeScanHistoryRepository()
            ..seed(
              '9557062321136',
              at: DateTime.utc(2026, 11, 13, 9),
              product: ProductDetail.fromJson(withPhoto),
            )
            ..seed('6191234567897', at: DateTime.utc(2026, 11, 13, 10));
          await tester.pumpQoutApp(
            history: history,
            overrides: [memoryProductImages()],
          );
          await tester.pumpAndSettle();

          await tester.scrollUntilVisible(
            find.byType(ProductThumbnail),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(find.byType(HistoryTile), findsWidgets);
          expect(find.byType(ProductThumbnail), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        for (final fixture in [
          'product-general-graded',
          'product-beverage-graded',
          'product-insufficient-data',
          'product-water',
          'product-serving-allergens',
        ]) {
          testWidgets('product: $fixture', (tester) async {
            await configure(tester);
            final json = recordedProductJson(fixture)
              ..['image_url'] = 'https://media.example/p.jpg';
            await tester.pumpQoutApp(
              // "For you" with every kind of note and the personal shares.
              profile: Profile(
                sex: Sex.female,
                age: 22,
                heightCm: 165,
                weightKg: 58,
                activity: ActivityLevel.active,
                allergens: const {Allergen.milk, Allergen.nuts},
              ),
              avoidedAdditives: const {'E330', 'E476'},
              overrides: [
                memoryProductImages(),
                productRepositoryProvider.overrideWithValue(
                  FakeProductRepository(
                    results: [
                      ProductResult.found(
                        product: ProductDetail.fromJson(json),
                        fetchedAt: DateTime.utc(2026, 11, 13),
                        freshness: ProductFreshness.fresh,
                      ),
                    ],
                  ),
                ),
              ],
            );
            await tester.pushRoute(AppRoutes.product('123'));
            await tester.pumpAndSettle();

            // Scroll to the end: every section lays out without overflow.
            // At double text size the page is over 15 000 px long.
            await tester.scrollUntilVisible(
              find.text('Report an error'),
              600,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            expect(find.text('Report an error'), findsOneWidget);
            expect(tester.takeException(), isNull);
          });
        }

        testWidgets('sign in', (tester) async {
          await configure(tester);
          await tester.pumpQoutApp();
          await tester.pushRoute(AppRoutes.signIn);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('New here? Create an account'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(tester.takeException(), isNull);
        });

        testWidgets('contribution: photos, then the review form', (
          tester,
        ) async {
          await configure(tester);
          final fake = FakeContribution(
            texts: {'front.jpg': 'Biscuits', 'nutrition.jpg': cleanLabelText},
          );
          await tester.pumpQoutApp(overrides: fake.overrides);
          await tester.pushRoute(AppRoutes.contribute('6191234567897'));
          await tester.pumpAndSettle();

          for (final (title, path) in [
            ('Front of the package', 'front.jpg'),
            ('Nutrition table', 'nutrition.jpg'),
          ]) {
            final camera = find.descendant(
              of: find.ancestor(
                of: find.text(title),
                matching: find.byType(Card),
              ),
              matching: find.text('Camera'),
            );
            await tester.scrollUntilVisible(
              camera,
              100,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.ensureVisible(camera);
            await tester.pumpAndSettle();
            fake.photos.add(path);
            await tester.tap(camera);
            await tester.pump();
            await tester.pump();
          }
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
          expect(find.text('Check the values'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.textContaining('Fruit, vegetables'),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          expect(tester.takeException(), isNull);
        });

        testWidgets('welcome, every page', (tester) async {
          await configure(tester);
          await tester.pumpQoutApp(start: StartScreen.welcome);
          for (var page = 0; page < 2; page++) {
            expect(tester.takeException(), isNull);
            await tester.tap(find.text('Next'));
            await tester.pumpAndSettle();
          }
          expect(find.text('Set up my profile'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('profile form', (tester) async {
          await configure(tester);
          await tester.pumpQoutApp();
          await tester.pushRoute(AppRoutes.profileEdit);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Save'),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('Save')); // every error shown
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.unmountQoutApp();
        });

        testWidgets('profile with daily needs', (tester) async {
          await configure(tester);
          final database = AppDatabase(NativeDatabase.memory());
          addTearDown(database.close);
          await ProfileRepository(dao: database.profileDao).save(
            Profile(
              sex: Sex.female,
              age: 22,
              heightCm: 165,
              weightKg: 58,
              activity: ActivityLevel.active,
              allergens: const {Allergen.gluten, Allergen.sulphites},
            ),
          );
          await tester.pumpQoutApp(database: database, liveProfile: true);
          await tester.pushRoute(AppRoutes.profile);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Delete my profile'),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          expect(tester.takeException(), isNull);
          await tester.unmountQoutApp();
        });
      });
    }
  }
}
