// Every point table and grade band, at and around every threshold.
//
// Expected values are transcribed separately from the official calculator
// (docs/specs/nutri-score-calculator-2024-04-04.xlsx), like the Python tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:qout/scoring/exact_decimal.dart';
import 'package:qout/scoring/models.dart';
import 'package:qout/scoring/tables.dart';

ExactDecimal d(String text) => ExactDecimal.parse(text);

final ExactDecimal eps = d('0.001');

List<(String, int)> steps1(List<String> thresholds) => [
  for (var i = 0; i < thresholds.length; i++) (thresholds[i], i + 1),
];

final Map<String, (PointTable, List<(String, int)>)> leTables = {
  'energy_kj': (
    energyKj,
    steps1([
      '335', '670', '1005', '1340', '1675', '2010', '2345', '2680', //
      '3015', '3350',
    ]),
  ),
  'saturated_fat_g': (
    saturatedFatG,
    steps1([for (var n = 1; n <= 10; n++) '$n']),
  ),
  'sugars_g': (
    sugarsG,
    steps1([
      '3.4', '6.8', '10', '14', '17', '20', '24', '27', '31', '34', //
      '37', '41', '44', '48', '51',
    ]),
  ),
  'salt_g': (
    saltG,
    steps1([
      '0.2', '0.4', '0.6', '0.8', '1', '1.2', '1.4', '1.6', '1.8', //
      '2', '2.2', '2.4', '2.6', '2.8', '3', '3.2', '3.4', '3.6', '3.8', '4',
    ]),
  ),
  'protein_g': (
    proteinG,
    steps1(['2.4', '4.8', '7.2', '9.6', '12', '14', '17']),
  ),
  'fibre_g': (fibreG, steps1(['3', '4.1', '5.2', '6.3', '7.4'])),
  'fvl_percent': (fvlPercent, [('40', 1), ('60', 2), ('80', 5)]),
  'energy_from_saturates_kj': (
    energyFromSaturatesKj,
    steps1([for (var n = 1; n <= 10; n++) '${120 * n}']),
  ),
  'beverage_energy_kj': (
    beverageEnergyKj,
    steps1([
      '30', '90', '150', '210', '240', '270', '300', '330', '360', //
      '390',
    ]),
  ),
  'beverage_sugars_g': (
    beverageSugarsG,
    steps1(['0.5', '2', '3.5', '5', '6', '7', '8', '9', '10', '11']),
  ),
  'beverage_saturated_fat_g': (
    beverageSaturatedFatG,
    steps1([for (var n = 1; n <= 10; n++) '$n']),
  ),
  'beverage_protein_g': (
    beverageProteinG,
    steps1(['1.2', '1.5', '1.8', '2.1', '2.4', '2.7', '3']),
  ),
  'beverage_fvl_percent': (
    beverageFvlPercent,
    [('40', 2), ('60', 4), ('80', 6)],
  ),
};

void main() {
  for (final MapEntry(key: name, value: (table, rows)) in leTables.entries) {
    group(name, () {
      test('has exactly the expected thresholds', () {
        expect(table.thresholds, [for (final (t, _) in rows) d(t)]);
        expect(table.steps, [for (final (_, p) in rows) p]);
        expect(table.strict, isFalse);
      });

      for (var i = 0; i < rows.length; i++) {
        final (threshold, points) = rows[i];
        test('$threshold: on it gets the lower points', () {
          final below = i == 0 ? 0 : rows[i - 1].$2;
          final t = d(threshold);
          expect(table.points(t - eps), below);
          expect(table.points(t), below);
          expect(table.points(t + eps), points);
        });
      }

      test('zero and huge values', () {
        expect(table.points(d('0')), 0);
        expect(table.points(d('100000')), rows.last.$2);
        expect(table.maxPoints, rows.last.$2);
      });
    });
  }

  group('saturated fat ratio (strict)', () {
    final ratio = ['10', '16', '22', '28', '34', '40', '46', '52', '58', '64'];

    test('thresholds', () {
      expect(saturatedFatRatioPercent.strict, isTrue);
      expect(saturatedFatRatioPercent.thresholds, ratio.map(d).toList());
      expect(saturatedFatRatioPercent.points(d('0')), 0);
      expect(saturatedFatRatioPercent.points(d('100')), 10);
    });

    for (var i = 0; i < ratio.length; i++) {
      test('${ratio[i]} %: on it gets the higher points', () {
        final t = d(ratio[i]);
        expect(saturatedFatRatioPercent.points(t - eps), i);
        expect(saturatedFatRatioPercent.points(t), i + 1);
        expect(saturatedFatRatioPercent.points(t + eps), i + 1);
      });
    }

    test('ratio is compared without dividing', () {
      // 0.58 / 1 = 58 % exactly: 9 points (strict), not 8.
      expect(saturatedFatRatioPercent.pointsForRatio(d('58'), d('1')), 9);
      expect(saturatedFatRatioPercent.pointsForRatio(d('160'), d('10')), 2);
      expect(saturatedFatRatioPercent.pointsForRatio(d('159.9'), d('10')), 1);
    });
  });

  test('beverage salt at 3.2 g gets 15 points (decision 3)', () {
    expect(saltG.points(d('3.2')), 15);
    expect(saltG.points(d('3.21')), 16);
  });

  test('constants', () {
    expect(redMeatMaxProteinPoints, 2);
    expect(foodsProteinNLimit, 11);
    expect(fatsProteinNLimit, 7);
    expect(kjPerGSaturatedFat, d('37'));
    expect(nonNutritiveSweetenersPoints, 4);
  });

  group('grade bands', () {
    final cases = <String, (GradeBands, List<(int, Grade)>)>{
      'foods': (
        foodsGrades,
        [
          (-15, Grade.a), (0, Grade.a), (1, Grade.b), (2, Grade.b), //
          (3, Grade.c), (10, Grade.c), (11, Grade.d), (18, Grade.d), //
          (19, Grade.e), (40, Grade.e),
        ],
      ),
      'fats': (
        fatsGrades,
        [
          (-17, Grade.a), (-6, Grade.a), (-5, Grade.b), (2, Grade.b), //
          (3, Grade.c), (10, Grade.c), (11, Grade.d), (18, Grade.d), //
          (19, Grade.e), (55, Grade.e),
        ],
      ),
      'beverages': (
        beverageGrades,
        [
          (-18, Grade.b), (2, Grade.b), (3, Grade.c), (6, Grade.c), //
          (7, Grade.d), (9, Grade.d), (10, Grade.e), (49, Grade.e),
        ],
      ),
    };
    for (final MapEntry(key: name, value: (bands, rows)) in cases.entries) {
      for (final (score, grade) in rows) {
        test('$name: $score -> ${grade.letter}', () {
          expect(bands.grade(score), grade);
        });
      }
    }
  });

  group('PointTable validation', () {
    test('rejects unsorted or repeated thresholds', () {
      expect(() => PointTable(['2', '1']), throwsArgumentError);
      expect(() => PointTable(['1', '1']), throwsArgumentError);
    });

    test('rejects mismatched steps', () {
      expect(() => PointTable(['1', '2'], steps: [1]), throwsArgumentError);
    });
  });
}
