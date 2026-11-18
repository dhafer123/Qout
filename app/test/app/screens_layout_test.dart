import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/domain/product_result.dart';
import 'package:qout/features/product/presentation/product_photo.dart';

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
        ]) {
          testWidgets('product: $fixture', (tester) async {
            await configure(tester);
            final json = recordedProductJson(fixture)
              ..['image_url'] = 'https://media.example/p.jpg';
            await tester.pumpQoutApp(
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
            await tester.scrollUntilVisible(
              find.text('Report an error'),
              300,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            expect(find.text('Report an error'), findsOneWidget);
            expect(tester.takeException(), isNull);
          });
        }
      });
    }
  }
}
