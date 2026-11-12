import 'package:flutter_test/flutter_test.dart';
import 'package:qout/scoring/models.dart';

const gramFields = [
  'sugars_g',
  'saturated_fat_g',
  'total_fat_g',
  'salt_g',
  'fibre_g',
  'protein_g',
];

/// Builds an input with one numeric field (spec name) set.
NutritionInput withField(String field, double value) => switch (field) {
  'energy_kj' => NutritionInput(energyKj: value),
  'sugars_g' => NutritionInput(sugarsG: value),
  'saturated_fat_g' => NutritionInput(saturatedFatG: value),
  'total_fat_g' => NutritionInput(totalFatG: value),
  'salt_g' => NutritionInput(saltG: value),
  'fibre_g' => NutritionInput(fibreG: value),
  'protein_g' => NutritionInput(proteinG: value),
  'fvl_percent' => NutritionInput(fvlPercent: value),
  _ => throw ArgumentError(field),
};

void main() {
  group('NutritionInput', () {
    test('everything defaults to not declared', () {
      final input = NutritionInput();
      for (final field in NutritionInput.amountFields) {
        expect(input.amount(field), isNull);
        expect(input.isDeclared(field), isFalse);
      }
      expect(input.isDeclared('non_nutritive_sweeteners'), isFalse);
    });

    test('accepts valid values and reads them by spec name', () {
      final input = NutritionInput(
        energyKj: 3700,
        sugarsG: 100,
        saturatedFatG: 0,
        totalFatG: 100,
        saltG: 2.5,
        fibreG: 3,
        proteinG: 12.5,
        fvlPercent: 100,
        nonNutritiveSweeteners: false,
      );
      expect(input.amount('salt_g'), 2.5);
      expect(input.amount('energy_kj'), 3700);
      expect(input.isDeclared('non_nutritive_sweeteners'), isTrue);
      expect(input.isDeclared('saturated_fat_g'), isTrue);
    });

    test('unknown field names are an error', () {
      expect(() => NutritionInput().amount('sodium_g'), throwsArgumentError);
    });

    for (final field in NutritionInput.amountFields) {
      for (final bad in [-0.1, double.nan, double.infinity]) {
        test('$field rejects $bad', () {
          expect(
            () => withField(field, bad),
            throwsA(
              isA<ArgumentError>().having((e) => e.name, 'name', field),
            ),
          );
        });
      }
    }

    for (final field in gramFields) {
      test('$field rejects more than 100 g', () {
        expect(withField(field, 100).amount(field), 100);
        expect(() => withField(field, 100.01), throwsArgumentError);
      });
    }

    test('fvl_percent rejects more than 100 %', () {
      expect(() => NutritionInput(fvlPercent: 100.5), throwsArgumentError);
    });

    test('energy has no gram limit', () {
      expect(NutritionInput(energyKj: 3700).energyKj, 3700);
    });

    test('value equality', () {
      expect(NutritionInput(sugarsG: 1), NutritionInput(sugarsG: 1));
      expect(
        NutritionInput(sugarsG: 1).hashCode,
        NutritionInput(sugarsG: 1).hashCode,
      );
      expect(NutritionInput(sugarsG: 1), isNot(NutritionInput(sugarsG: 2)));
      expect(
        NutritionInput(nonNutritiveSweeteners: true),
        isNot(NutritionInput(nonNutritiveSweeteners: false)),
      );
      expect(NutritionInput() == Object(), isFalse);
    });

    test('toString lists declared values', () {
      expect(
        NutritionInput(saltG: 0.5, nonNutritiveSweeteners: true).toString(),
        'NutritionInput(salt_g: 0.5, non_nutritive_sweeteners: true)',
      );
    });
  });

  group('Category', () {
    test('values match the golden cases and the backend', () {
      expect(Category.values.map((c) => c.value), [
        'general',
        'red_meat',
        'cheese',
        'fats_oils_nuts_seeds',
        'beverage',
        'water',
      ]);
    });

    test('parse', () {
      expect(Category.parse('red_meat'), Category.redMeat);
      expect(() => Category.parse('meat'), throwsArgumentError);
    });
  });

  test('grade letters', () {
    expect(Grade.values.map((g) => g.letter).join(), 'ABCDE');
  });

  test('results carry the engine version', () {
    const water = ScoreResult.graded(
      category: Category.water,
      grade: Grade.a,
      breakdown: null,
    );
    expect(water.engineVersion, 'nutriscore-2023.1');
    const missing = ScoreResult.insufficientData(
      category: Category.general,
      missing: ['fibre_g'],
    );
    expect(missing.engineVersion, scoringEngineVersion);
  });
}
