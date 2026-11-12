// Score rules per category, missing data, water, conversions. Mirrors
// backend/tests/unit/scoring/test_engine.py.

import 'package:flutter_test/flutter_test.dart';
import 'package:qout/scoring/scoring.dart';
import 'package:qout/scoring/spec_json.dart';

const zeroFood = <String, Object?>{
  'energy_kj': 0,
  'sugars_g': 0,
  'saturated_fat_g': 0,
  'salt_g': 0,
  'fibre_g': 0,
  'protein_g': 0,
  'fvl_percent': 0,
};
const zeroFats = <String, Object?>{
  'total_fat_g': 10,
  'sugars_g': 0,
  'saturated_fat_g': 0,
  'salt_g': 0,
  'fibre_g': 0,
  'protein_g': 0,
  'fvl_percent': 0,
};
const zeroBeverage = <String, Object?>{
  ...zeroFood,
  'non_nutritive_sweeteners': false,
};
const base = <Category, Map<String, Object?>>{
  Category.general: zeroFood,
  Category.redMeat: zeroFood,
  Category.cheese: zeroFood,
  Category.fatsOilsNutsSeeds: zeroFats,
  Category.beverage: zeroBeverage,
};

ScoreResult scoreSpec(Category category, Map<String, Object?> values) =>
    score(category, nutritionInputFromSpec(values));

/// Scores an all-zero product of [category] with [values] overridden.
(Grade, Breakdown) graded(
  Category category, [
  Map<String, Object?> values = const {},
]) {
  final result = scoreSpec(category, {...base[category]!, ...values});
  if (result is! NutriScore || result.breakdown == null) {
    fail('expected a breakdown, got $result');
  }
  return (result.grade, result.breakdown!);
}

void main() {
  group('water', () {
    test('always A without points', () {
      expect(
        score(Category.water, NutritionInput()),
        const ScoreResult.graded(
          category: Category.water,
          grade: Grade.a,
          breakdown: null,
        ),
      );
    });

    test('ignores any values', () {
      final result = score(Category.water, NutritionInput(sugarsG: 50));
      expect(
        result,
        isA<NutriScore>().having((r) => r.grade, 'grade', Grade.a),
      );
    });
  });

  group('missing data', () {
    for (final MapEntry(key: category, value: values) in base.entries) {
      for (final field in values.keys) {
        test('${category.value} without $field', () {
          final result = scoreSpec(
            category,
            {...values}..remove(field),
          );
          expect(
            result,
            ScoreResult.insufficientData(category: category, missing: [field]),
          );
        });
      }

      test('${category.value} with nothing declared', () {
        final result = score(category, NutritionInput());
        expect(
          result,
          isA<InsufficientData>().having(
            (r) => r.missing,
            'missing',
            [...requiredFields[category]!]..sort(),
          ),
        );
      });
    }

    test('fats with zero total fat is unusable', () {
      final values = {...zeroFats, 'total_fat_g': 0}..remove('saturated_fat_g');
      expect(
        scoreSpec(Category.fatsOilsNutsSeeds, values),
        const ScoreResult.insufficientData(
          category: Category.fatsOilsNutsSeeds,
          missing: ['saturated_fat_g', 'total_fat_g'],
        ),
      );
    });

    test('inputs the category does not use are ignored', () {
      expect(
        graded(Category.general, {
          'total_fat_g': 50,
          'non_nutritive_sweeteners': true,
        }),
        graded(Category.general),
      );
    });

    test('fats do not need energy', () {
      expect(
        requiredFields[Category.fatsOilsNutsSeeds],
        isNot(contains('energy_kj')),
      );
      final (grade, b) = graded(Category.fatsOilsNutsSeeds);
      expect((b.score, grade), (0, Grade.b));
    });
  });

  group('general foods', () {
    test('N below 11 subtracts protein', () {
      final (_, b) = graded(Category.general, {
        'salt_g': 2.0,
        'sugars_g': 3.5,
        'protein_g': 13,
      });
      expect(
        (b.negativeTotal, b.positiveTotal, b.proteinCounted, b.score),
        (10, 5, true, 5),
      );
    });

    test('N from 11 ignores protein', () {
      final (grade, b) = graded(Category.general, {
        'salt_g': 2.1,
        'sugars_g': 3.5,
        'protein_g': 13,
        'fibre_g': 4.2,
      });
      expect(
        (b.negativeTotal, b.positiveTotal, b.proteinCounted),
        (11, 7, false),
      );
      expect((b.score, grade), (9, Grade.c));
    });

    test('best and worst', () {
      final (best, b1) = graded(Category.general, {
        'protein_g': 20,
        'fibre_g': 10,
        'fvl_percent': 100,
      });
      expect((b1.score, best), (-17, Grade.a));
      final (worst, b2) = graded(Category.general, {
        'energy_kj': 4000,
        'sugars_g': 60,
        'saturated_fat_g': 20,
        'salt_g': 5,
      });
      expect((b2.score, worst), (55, Grade.e));
    });
  });

  group('red meat and cheese', () {
    test('red meat protein is capped at 2', () {
      expect(
        graded(Category.redMeat, {'protein_g': 25}).$2.positive['protein'],
        2,
      );
      expect(
        graded(Category.general, {'protein_g': 25}).$2.positive['protein'],
        7,
      );
    });

    test('red meat N from 11 ignores protein', () {
      final (_, b) = graded(Category.redMeat, {
        'salt_g': 2.1,
        'sugars_g': 3.5,
        'protein_g': 25,
      });
      expect((b.proteinCounted, b.score), (false, 11));
    });

    test('cheese always subtracts protein', () {
      final values = {'salt_g': 2.1, 'sugars_g': 3.5, 'protein_g': 25};
      final (_, cheese) = graded(Category.cheese, values);
      expect(
        (cheese.negativeTotal, cheese.proteinCounted, cheese.score),
        (11, true, 4),
      );
      expect(graded(Category.general, values).$2.score, 11);
    });
  });

  group('fats, oils, nuts and seeds', () {
    test('energy from saturates is 37 kJ per gram', () {
      final low = graded(Category.fatsOilsNutsSeeds, {
        'saturated_fat_g': 3.24,
        'total_fat_g': 100,
      }).$2;
      final high = graded(Category.fatsOilsNutsSeeds, {
        'saturated_fat_g': 3.25,
        'total_fat_g': 100,
      }).$2;
      expect(low.negative['energy_from_saturates'], 0);
      expect(high.negative['energy_from_saturates'], 1);
    });

    test('ratio uses exact decimals (0.58 / 1 = 58 %)', () {
      expect(0.58 * 100, lessThan(58));
      final (_, b) = graded(Category.fatsOilsNutsSeeds, {
        'saturated_fat_g': 0.58,
        'total_fat_g': 1,
      });
      expect(b.negative['saturated_fat_ratio'], 9);
    });

    test('ratio on a threshold gets the higher points', () {
      final (_, b) = graded(Category.fatsOilsNutsSeeds, {
        'saturated_fat_g': 1.6,
        'total_fat_g': 10,
      });
      expect(b.negative['saturated_fat_ratio'], 2);
    });

    test('N from 7 ignores protein', () {
      final (_, b) = graded(Category.fatsOilsNutsSeeds, {
        'saturated_fat_g': 4,
        'total_fat_g': 100,
        'salt_g': 1.3,
        'protein_g': 13,
      });
      expect((b.negativeTotal, b.proteinCounted, b.score), (7, false, 7));
      final (_, below) = graded(Category.fatsOilsNutsSeeds, {
        'salt_g': 1.3,
        'protein_g': 13,
      });
      expect(
        (below.negativeTotal, below.proteinCounted, below.score),
        (6, true, 1),
      );
    });

    test('grade A needs -6', () {
      final (a, b1) = graded(Category.fatsOilsNutsSeeds, {
        'protein_g': 13,
        'fibre_g': 3.1,
      });
      expect((b1.score, a), (-6, Grade.a));
      final (b, b2) = graded(Category.fatsOilsNutsSeeds, {
        'protein_g': 13,
        'fibre_g': 3,
      });
      expect((b2.score, b), (-5, Grade.b));
    });
  });

  group('beverages', () {
    test('sweeteners add 4 points', () {
      final (_, without) = graded(Category.beverage);
      final (grade, b) = graded(Category.beverage, {
        'non_nutritive_sweeteners': true,
      });
      expect(without.negative['non_nutritive_sweeteners'], 0);
      expect(b.negative['non_nutritive_sweeteners'], 4);
      expect((b.score, grade), (4, Grade.c));
    });

    test('always subtracts protein', () {
      final (_, b) = graded(Category.beverage, {
        'energy_kj': 400,
        'sugars_g': 12,
        'protein_g': 3.5,
      });
      expect((b.negativeTotal, b.proteinCounted, b.score), (20, true, 13));
    });

    test('never A', () {
      final (grade, b) = graded(Category.beverage, {
        'protein_g': 3.5,
        'fibre_g': 8,
        'fvl_percent': 100,
      });
      expect((b.score, grade), (-18, Grade.b));
    });
  });

  group('result shape', () {
    test('breakdown maps are read-only', () {
      final (_, b) = graded(Category.general);
      expect(() => b.negative['sugars'] = 99, throwsUnsupportedError);
    });

    final names = {
      Category.general: {'energy', 'sugars', 'saturated_fat', 'salt'},
      Category.redMeat: {'energy', 'sugars', 'saturated_fat', 'salt'},
      Category.cheese: {'energy', 'sugars', 'saturated_fat', 'salt'},
      Category.fatsOilsNutsSeeds: {
        'energy_from_saturates',
        'sugars',
        'saturated_fat_ratio',
        'salt',
      },
      Category.beverage: {
        'energy',
        'sugars',
        'saturated_fat',
        'salt',
        'non_nutritive_sweeteners',
      },
    };
    for (final MapEntry(key: category, value: negative) in names.entries) {
      test('${category.value} component names', () {
        final (_, b) = graded(category);
        expect(b.negative.keys.toSet(), negative);
        expect(b.positive.keys.toSet(), {'protein', 'fibre', 'fvl'});
      });
    }
  });

  group('conversions', () {
    final kj = {
      0.0: 0, 100.0: 420, 1.0: 4, 0.5: 2, 2.5: 11, 7.5: 32, //
      12.5: 53, 80.1: 336, 900.0: 3780,
    };
    for (final MapEntry(key: kcal, value: expected) in kj.entries) {
      test('$kcal kcal -> $expected kJ', () {
        expect(kjFromKcal(kcal), expected);
      });
    }

    final salt = {
      0.0: 0.0, 0.4: 1.0, 1.0: 2.5, 0.08: 0.2, 0.56: 1.4, //
      1.36: 3.4,
    };
    for (final MapEntry(key: sodium, value: expected) in salt.entries) {
      test('$sodium g sodium -> $expected g salt', () {
        expect(saltFromSodium(sodium), expected);
      });
    }

    for (final bad in [-1.0, double.nan, double.infinity]) {
      test('rejects $bad', () {
        expect(() => kjFromKcal(bad), throwsArgumentError);
        expect(() => saltFromSodium(bad), throwsArgumentError);
      });
    }
  });
}
