import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qout/core/api/qout_api.dart' as api;
import 'package:qout/scoring/scoring.dart' show Category;

part 'existing_product.freezed.dart';

/// A product Qout already knows, whose missing values a contribution
/// completes: its name, brand and category prefill the form.
@freezed
abstract class ExistingProduct with _$ExistingProduct {
  const factory ExistingProduct({
    String? name,
    String? brand,

    /// Null when the product's category is not known to this app.
    Category? category,
  }) = _ExistingProduct;

  factory ExistingProduct.fromDetail(api.ProductDetail product) =>
      ExistingProduct(
        name: product.name,
        brand: product.brand,
        category: switch (product.category) {
          final api.Category category => _scoringCategory(category),
          null => null,
        },
      );
}

Category? _scoringCategory(api.Category category) {
  for (final value in Category.values) {
    if (value.value == category.value) return value;
  }
  return null; // api.Category.unrecognized
}
