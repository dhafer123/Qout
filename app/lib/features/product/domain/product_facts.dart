import 'package:qout/core/api/qout_api.dart' as api;
import 'package:qout/health/advice.dart';
import 'package:qout/health/profile.dart';

/// What the advice needs from an API product (T40).
ProductFacts productFacts(api.ProductDetail product) {
  final nutrition = product.nutrition;
  final serving = product.serving;
  return ProductFacts(
    basis: switch (nutrition?.basis) {
      api.NutritionBasis.per100g => PortionUnit.gram,
      api.NutritionBasis.per100ml => PortionUnit.millilitre,
      _ => null, // no nutrition, or a basis this app version doesn't know
    },
    per100: {
      Nutrient.energy: ?nutrition?.energyKj,
      Nutrient.fat: ?nutrition?.totalFatG,
      Nutrient.saturates: ?nutrition?.saturatedFatG,
      Nutrient.sugars: ?nutrition?.sugarsG,
      Nutrient.salt: ?nutrition?.saltG,
    },
    servingQuantity: serving?.quantity,
    servingUnit: switch (serving?.unit) {
      api.ServingUnit.g => PortionUnit.gram,
      api.ServingUnit.ml => PortionUnit.millilitre,
      _ => null,
    },
    allergens: _allergens(product.allergens),
    traces: _allergens(product.traces),
    additives: [
      for (final additive in product.additives)
        AdditiveFact(
          code: additive.code,
          name: additive.name,
          risk: switch (additive.overexposureRisk) {
            api.OverexposureRisk.high => AdditiveRisk.high,
            api.OverexposureRisk.moderate => AdditiveRisk.moderate,
            api.OverexposureRisk.none => AdditiveRisk.none,
            _ => AdditiveRisk.unknown,
          },
        ),
    ],
  );
}

/// The API's allergens as the profile's; values this version doesn't know
/// are dropped. Null stays null (not known yet).
Set<Allergen>? _allergens(List<api.Allergen>? allergens) => allergens == null
    ? null
    : {for (final allergen in allergens) ?Allergen.fromKey(allergen.value)};
