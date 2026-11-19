import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/qout_api.dart' as api;
import 'package:qout/features/product/domain/product_facts.dart';
import 'package:qout/health/advice.dart';
import 'package:qout/health/profile.dart';

import '../../../helpers/fixtures.dart';

void main() {
  test('a recorded product with a serving and allergens', () {
    final facts = productFacts(recordedProduct('product-serving-allergens'));
    expect(facts.basis, PortionUnit.gram);
    expect(
      (facts.servingQuantity, facts.servingUnit),
      (21.7, PortionUnit.gram),
    );
    expect(facts.per100, {
      Nutrient.energy: 1980,
      Nutrient.fat: 23,
      Nutrient.saturates: 10.9,
      Nutrient.sugars: 23,
      Nutrient.salt: 0.30775,
    });
    expect(facts.allergens, {
      Allergen.gluten,
      Allergen.soybeans,
      Allergen.milk,
    });
    expect(facts.traces, {Allergen.nuts});
    expect(facts.additives.map((a) => a.code), contains('E330'));
  });

  test('stored before T40: allergens not known; risks mapped', () {
    final facts = productFacts(recordedProduct('product-insufficient-data'));
    expect((facts.allergens, facts.traces), (null, null));
    expect(facts.servingQuantity, isNull);
    expect(
      facts.additives.firstWhere((a) => a.code == 'E450').risk,
      AdditiveRisk.high,
    );
    expect(
      facts.additives.firstWhere((a) => a.code == 'E322').risk,
      AdditiveRisk.unknown,
    );
  });

  test('no nutrition: no basis, no amounts', () {
    final facts = productFacts(recordedProduct('product-unknown-category'));
    expect(facts.basis, isNull);
    expect(facts.per100, isEmpty);
  });

  test('beverages are per 100 mL; unknown values are dropped', () {
    final json = recordedProductJson('product-beverage-graded')
      ..['serving'] = {'quantity': 330, 'unit': 'ml', 'size': '1 can'}
      ..['allergens'] = ['milk', 'kiwi'];
    final facts = productFacts(api.ProductDetail.fromJson(json));
    expect(facts.basis, PortionUnit.millilitre);
    expect(facts.servingUnit, PortionUnit.millilitre);
    expect(facts.allergens, {Allergen.milk});
  });
}
