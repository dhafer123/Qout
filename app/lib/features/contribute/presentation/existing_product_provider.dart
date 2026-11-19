import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/features/contribute/domain/existing_product.dart';
import 'package:qout/features/product/domain/product_result.dart';
import 'package:qout/features/product/presentation/product_providers.dart';

/// The product behind a barcode when Qout already knows it (its values are
/// being completed), from the lookup the product screen made; null for an
/// unknown product or while the lookup has no answer.
final AutoDisposeProviderFamily<ExistingProduct?, String>
existingProductProvider = Provider.autoDispose.family<ExistingProduct?, String>(
  (ref, ean) => switch (ref.watch(productResultProvider(ean)).valueOrNull) {
    ProductFound(:final product) => ExistingProduct.fromDetail(product),
    _ => null,
  },
);
