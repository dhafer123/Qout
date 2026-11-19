import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/contribute/domain/existing_product.dart';
import 'package:qout/features/contribute/presentation/existing_product_provider.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/domain/product_result.dart';
import 'package:qout/features/product/presentation/product_providers.dart';
import 'package:qout/scoring/scoring.dart' as scoring;

import '../../../helpers/fake_product_repository.dart';
import '../../../helpers/fixtures.dart';

ProductDetail _product({String? category = 'beverage'}) =>
    ProductDetail.fromJson({
      ...recordedProductJson('product-insufficient-data'),
      'name': 'Chamia aux pistaches',
      'brand': 'Le Moulin',
      'category': category,
    });

ProductResult _found(ProductDetail product) => ProductResult.found(
  product: product,
  fetchedAt: DateTime.utc(2026, 11, 19),
  freshness: ProductFreshness.fresh,
);

void main() {
  group('ExistingProduct.fromDetail', () {
    test('name, brand and category', () {
      expect(
        ExistingProduct.fromDetail(_product()),
        const ExistingProduct(
          name: 'Chamia aux pistaches',
          brand: 'Le Moulin',
          category: scoring.Category.beverage,
        ),
      );
    });

    test('every category the engine knows', () {
      for (final category in scoring.Category.values) {
        expect(
          ExistingProduct.fromDetail(
            _product(category: category.value),
          ).category,
          category,
        );
      }
    });

    test('no category, or one this app does not know: none', () {
      expect(
        ExistingProduct.fromDetail(_product(category: null)).category,
        null,
      );
      expect(
        ExistingProduct.fromDetail(_product(category: 'insects')).category,
        null,
      );
    });
  });

  group('existingProductProvider', () {
    Future<ExistingProduct?> lookUp(List<ProductResult> results) async {
      final container = ProviderContainer(
        overrides: [
          productRepositoryProvider.overrideWithValue(
            FakeProductRepository(results: results),
          ),
        ],
      );
      addTearDown(container.dispose);
      const ean = '6194017503778';
      container.listen(existingProductProvider(ean), (_, _) {});
      await container.read(productResultProvider(ean).future);
      await pumpEventQueue();
      return container.read(existingProductProvider(ean));
    }

    test('a product found: the product', () async {
      expect(
        await lookUp([_found(_product())]),
        ExistingProduct.fromDetail(_product()),
      );
    });

    test('not found: none', () async {
      expect(
        await lookUp([const ProductResult.notFound(ean: '6194017503778')]),
        isNull,
      );
    });
  });
}
