import 'package:flutter_test/flutter_test.dart';
import 'package:qout/scoring/scoring.dart';
import 'package:qout/scoring/spec_json.dart';

/// Values far beyond the last threshold of every table: each component gets
/// its maximum.
const _extreme = <String, Object?>{
  'energy_kj': 9000,
  'sugars_g': 99,
  'saturated_fat_g': 99,
  'total_fat_g': 99,
  'salt_g': 99,
  'fibre_g': 99,
  'protein_g': 99,
  'fvl_percent': 100,
  'non_nutritive_sweeteners': true,
};

void main() {
  test('the maximum of each component is what the engine awards at most', () {
    for (final category in Category.values.where((c) => c != Category.water)) {
      final result = score(category, nutritionInputFromSpec(_extreme));
      final breakdown = (result as NutriScore).breakdown!;
      for (final MapEntry(key: component, value: points) in {
        ...breakdown.negative,
        ...breakdown.positive,
      }.entries) {
        expect(
          maxComponentPoints(category, component),
          points,
          reason: '${category.value} $component',
        );
      }
    }
  });

  test('scales from the Q&A tables', () {
    expect(maxComponentPoints(Category.general, 'energy'), 10);
    expect(maxComponentPoints(Category.general, 'sugars'), 15);
    expect(maxComponentPoints(Category.general, 'salt'), 20);
    expect(maxComponentPoints(Category.general, 'protein'), 7);
    expect(maxComponentPoints(Category.general, 'fibre'), 5);
    expect(maxComponentPoints(Category.general, 'fvl'), 5);
    expect(maxComponentPoints(Category.redMeat, 'protein'), 2);
    expect(maxComponentPoints(Category.beverage, 'sugars'), 10);
    expect(maxComponentPoints(Category.beverage, 'fvl'), 6);
    expect(
      maxComponentPoints(Category.beverage, 'non_nutritive_sweeteners'),
      4,
    );
    expect(
      maxComponentPoints(Category.fatsOilsNutsSeeds, 'saturated_fat_ratio'),
      10,
    );
  });

  test('null for water and for components a category does not have', () {
    expect(maxComponentPoints(Category.water, 'energy'), isNull);
    expect(maxComponentPoints(Category.general, 'saturated_fat_ratio'), isNull);
    expect(maxComponentPoints(Category.fatsOilsNutsSeeds, 'energy'), isNull);
    expect(maxComponentPoints(Category.general, 'nope'), isNull);
  });
}
