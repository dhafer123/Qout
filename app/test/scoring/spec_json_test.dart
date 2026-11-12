import 'package:flutter_test/flutter_test.dart';
import 'package:qout/scoring/scoring.dart';
import 'package:qout/scoring/spec_json.dart';

void main() {
  group('nutritionInputFromSpec', () {
    test('reads ints, doubles and the sweetener flag', () {
      final input = nutritionInputFromSpec({
        'energy_kj': 29,
        'sugars_g': 1.2,
        'non_nutritive_sweeteners': true,
      });
      expect(
        input,
        NutritionInput(
          energyKj: 29,
          sugarsG: 1.2,
          nonNutritiveSweeteners: true,
        ),
      );
    });

    test('null means not declared', () {
      expect(nutritionInputFromSpec({'salt_g': null}), NutritionInput());
    });

    test('rejects unknown keys', () {
      expect(
        () => nutritionInputFromSpec({'sodium_g': 1}),
        throwsArgumentError,
      );
    });

    test('rejects wrongly typed values', () {
      expect(
        () => nutritionInputFromSpec({'salt_g': '1'}),
        throwsArgumentError,
      );
      expect(
        () => nutritionInputFromSpec({'non_nutritive_sweeteners': 1}),
        throwsArgumentError,
      );
    });
  });

  group('expectedToSpec', () {
    test('water', () {
      expect(
        expectedToSpec(score(Category.water, NutritionInput())),
        {'grade': 'A'},
      );
    });

    test('assumed zero is written only when used', () {
      final undeclared = expectedToSpec(
        score(
          Category.general,
          NutritionInput(
            energyKj: 900,
            sugarsG: 5,
            saturatedFatG: 0,
            saltG: 0,
            proteinG: 0,
            fvlPercent: 0,
          ),
        ),
      );
      expect(undeclared['assumed_zero'], ['fibre_g']);
      expect(undeclared['score'], 3);
    });

    test('insufficient data', () {
      expect(
        expectedToSpec(score(Category.general, NutritionInput())),
        {
          'insufficient_data': [
            'energy_kj',
            'fvl_percent',
            'protein_g',
            'salt_g',
            'saturated_fat_g',
            'sugars_g',
          ],
        },
      );
    });
  });
}
