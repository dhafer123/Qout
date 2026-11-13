import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/product/domain/score_explanation.dart';

import '../../../helpers/fixtures.dart';

/// A recorded product with [category] and a score built from [breakdown].
ProductDetail withScore(
  Map<String, Object?> breakdown, {
  Category? category = Category.general,
  Grade? grade = Grade.b,
}) {
  final json = recordedProductJson('product-general-graded');
  return ProductDetail.fromJson({
    ...json,
    'category': category?.value,
    'score': {
      ...(json['score']! as Map<String, Object?>),
      'grade': grade?.value,
      'breakdown': breakdown,
    },
  });
}

const _foods = <String, Object?>{
  'negative': {'energy': 3, 'sugars': 1, 'saturated_fat': 2, 'salt': 1},
  'positive': {'protein': 4, 'fibre': 2, 'fvl': 0},
  'negative_total': 7,
  'positive_total': 6,
  'protein_counted': true,
  'score': 1,
  'grade': 'B',
};

void main() {
  group('recorded API responses', () {
    test('general food: every component with its scale', () {
      final explanation = explainScore(
        recordedProduct('product-general-graded'),
      );

      expect(
        explanation,
        const ScoreExplanation.graded(
          grade: Grade.e,
          negative: [
            ScoreComponent(name: 'energy', points: 6, maxPoints: 10),
            ScoreComponent(name: 'sugars', points: 0, maxPoints: 15),
            ScoreComponent(name: 'saturated_fat', points: 10, maxPoints: 10),
            ScoreComponent(name: 'salt', points: 6, maxPoints: 20),
          ],
          positive: [
            ScoreComponent(name: 'protein', points: 2, maxPoints: 7),
            ScoreComponent(name: 'fibre', points: 0, maxPoints: 5),
            ScoreComponent(name: 'fvl', points: 0, maxPoints: 5),
          ],
          negativeTotal: 22,
          positiveTotal: 2,
          proteinCounted: false,
          score: 22,
          proteinNLimit: 11,
          assumedZero: ['fibre_g'],
        ),
      );
    });

    test('protein not counted is not subtracted', () {
      final explanation =
          explainScore(recordedProduct('product-general-graded'))
              as GradedExplanation;

      expect(explanation.subtracted, 0);
      expect(explanation.negativeTotal - explanation.subtracted, 22);
    });

    test('beverage: sweeteners among the negative points', () {
      final explanation =
          explainScore(recordedProduct('product-beverage-graded'))
              as GradedExplanation;

      expect(explanation.grade, Grade.e);
      expect(explanation.negative.map((c) => c.name), [
        'energy',
        'sugars',
        'saturated_fat',
        'salt',
        'non_nutritive_sweeteners',
      ]);
      expect(
        explanation.negative.last,
        const ScoreComponent(
          name: 'non_nutritive_sweeteners',
          points: 4,
          maxPoints: 4,
        ),
      );
      expect(explanation.positive.last.maxPoints, 6); // beverage FVL scale
      expect(explanation.proteinCounted, isTrue);
      expect(explanation.proteinNLimit, isNull);
      expect(explanation.subtracted, 0);
      expect(explanation.assumedZero, isEmpty);
    });

    test('water', () {
      expect(
        explainScore(recordedProduct('product-water')),
        const ScoreExplanation.water(),
      );
    });

    test('insufficient data lists the missing inputs', () {
      expect(
        explainScore(recordedProduct('product-insufficient-data')),
        const ScoreExplanation.insufficientData(
          missing: ['salt_g', 'sugars_g'],
        ),
      );
    });

    test('unknown category: not scored', () {
      expect(
        explainScore(recordedProduct('product-unknown-category')),
        const ScoreExplanation.notScored(),
      );
    });
  });

  group('categories', () {
    test('red meat: protein out of 2', () {
      final explanation =
          explainScore(withScore(_foods, category: Category.redMeat))
              as GradedExplanation;

      expect(explanation.positive.first.maxPoints, 2);
      expect(explanation.proteinNLimit, 11);
    });

    test('cheese: protein always counts, no limit', () {
      final explanation =
          explainScore(withScore(_foods, category: Category.cheese))
              as GradedExplanation;

      expect(explanation.proteinNLimit, isNull);
      expect(explanation.subtracted, 6);
    });

    test('fats: their own negative components and protein limit', () {
      final explanation =
          explainScore(
                withScore(const {
                  'negative': {
                    'salt': 0,
                    'sugars': 0,
                    'saturated_fat_ratio': 3,
                    'energy_from_saturates': 10,
                  },
                  'positive': {'fvl': 0, 'fibre': 0, 'protein': 1},
                  'negative_total': 13,
                  'positive_total': 1,
                  'protein_counted': false,
                  'score': 13,
                }, category: Category.fatsOilsNutsSeeds),
              )
              as GradedExplanation;

      expect(explanation.negative.map((c) => c.name), [
        'energy_from_saturates',
        'sugars',
        'saturated_fat_ratio',
        'salt',
      ]);
      expect(explanation.negative.every((c) => c.maxPoints != null), isTrue);
      expect(explanation.proteinNLimit, 7);
      expect(explanation.subtracted, 0);
    });

    test('unrecognized category: points without a scale', () {
      final explanation =
          explainScore(withScore(_foods, category: Category.unrecognized))
              as GradedExplanation;

      expect(explanation.negative.every((c) => c.maxPoints == null), isTrue);
      expect(explanation.proteinNLimit, isNull);
    });
  });

  group('unusual breakdowns', () {
    test('unknown components follow the known ones', () {
      final explanation =
          explainScore(
                withScore({
                  ..._foods,
                  'negative': {'novelty': 1, 'salt': 1, 'energy': 3},
                }),
              )
              as GradedExplanation;

      expect(explanation.negative.map((c) => c.name), [
        'energy',
        'salt',
        'novelty',
      ]);
      expect(explanation.negative.last.maxPoints, isNull);
    });

    test('a breakdown that does not read gives the grade alone', () {
      for (final broken in <Map<String, Object?>>[
        const {'grade': 'B'},
        {..._foods, 'score': '1'},
        {..._foods, 'negative': 'lots'},
        {
          ..._foods,
          'positive': {'protein': 1.5},
        },
      ]) {
        expect(
          explainScore(withScore(broken)),
          const ScoreExplanation.gradeOnly(grade: Grade.b),
          reason: '$broken',
        );
      }
    });

    test('no grade and no missing list: not scored', () {
      expect(
        explainScore(withScore(_foods, grade: null)),
        const ScoreExplanation.notScored(),
      );
      expect(
        explainScore(withScore(_foods, grade: Grade.unrecognized)),
        const ScoreExplanation.notScored(),
      );
    });

    test('missing entries that are not names are skipped', () {
      expect(
        explainScore(
          withScore(const {
            'insufficient_data': ['salt_g', 3, null],
          }, grade: null),
        ),
        const ScoreExplanation.insufficientData(missing: ['salt_g']),
      );
    });
  });
}
