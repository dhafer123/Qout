import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/core/env/app_env.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/domain/product_result.dart';

import '../helpers/fake_product_repository.dart';
import '../helpers/fake_scan_history_repository.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';
import '../helpers/test_images.dart';

/// Flutter's accessibility guidelines on the main screens, in both themes:
/// tap targets of at least 48 dp, every tap target labelled, and readable
/// text contrast.
void main() {
  Future<void> checkGuidelines(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  for (final brightness in Brightness.values) {
    group(brightness.name, () {
      Future<void> configure(WidgetTester tester) async {
        tester.view
          ..physicalSize = const Size(1080, 2340)
          ..devicePixelRatio = 3;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearPlatformBrightnessTestValue();
        });
      }

      testWidgets('home with history', (tester) async {
        await configure(tester);
        final handle = tester.ensureSemantics();
        final history = FakeScanHistoryRepository()
          ..seed(
            '9557062321136',
            at: DateTime.utc(2026, 11, 13, 9),
            product: recordedProduct('product-general-graded'),
          )
          ..seed('6191234567897', at: DateTime.utc(2026, 11, 13, 10));
        // Prod: no debug banner over the app bar.
        await tester.pumpQoutApp(flavor: AppFlavor.prod, history: history);
        await tester.pumpAndSettle();

        await checkGuidelines(tester);
        handle.dispose();
      });

      testWidgets('product result', (tester) async {
        await configure(tester);
        final handle = tester.ensureSemantics();
        await tester.pumpQoutApp(
          flavor: AppFlavor.prod,
          overrides: [
            memoryProductImages(),
            productRepositoryProvider.overrideWithValue(
              FakeProductRepository(
                results: [
                  ProductResult.found(
                    product: ProductDetail.fromJson(
                      recordedProductJson('product-general-graded'),
                    ),
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

        await checkGuidelines(tester);
        handle.dispose();
      });

      testWidgets('sign in', (tester) async {
        await configure(tester);
        final handle = tester.ensureSemantics();
        await tester.pumpQoutApp(flavor: AppFlavor.prod);
        await tester.pushRoute(AppRoutes.signIn);
        await tester.pumpAndSettle();

        await checkGuidelines(tester);
        handle.dispose();
      });
    });
  }
}
