/// Nutri-Score point tables and grade bands (updated algorithm, 2023).
///
/// Same values as the Python engine (`backend/app/modules/scoring/tables.py`),
/// every one from docs/specs/: "Q&A" is nutri-score-qa-v11.pdf, "2022 report"
/// the foods report, "2023 report" the beverages report.
///
/// Reading a table (docs/specs/README.md, decision 1): a value exactly on a
/// threshold gets the lower points. The saturates/fat ratio of the fats
/// category is the exception, written with "<" (decision 2). Beverage salt of
/// exactly 3.2 g gets 15 points like any other threshold (decision 3).
library;

import 'package:qout/scoring/exact_decimal.dart';
import 'package:qout/scoring/models.dart';

/// Ascending thresholds; crossing the i-th one (1-based) gives `steps[i - 1]`
/// points. With [strict], a value equal to a threshold already crosses it.
final class PointTable {
  PointTable(List<String> thresholds, {List<int>? steps, this.strict = false})
    : thresholds = List.unmodifiable(thresholds.map(ExactDecimal.parse)),
      steps = List.unmodifiable(
        steps ?? [for (var i = 1; i <= thresholds.length; i++) i],
      ) {
    for (var i = 1; i < this.thresholds.length; i++) {
      if (this.thresholds[i] <= this.thresholds[i - 1]) {
        throw ArgumentError('thresholds must be strictly ascending');
      }
    }
    if (this.steps.length != this.thresholds.length) {
      throw ArgumentError('one step per threshold');
    }
  }

  final List<ExactDecimal> thresholds;
  final List<int> steps;
  final bool strict;

  int get maxPoints => steps.last;

  /// Points for [value].
  int points(ExactDecimal value) => pointsForRatio(value, _one);

  /// Points for `numerator / denominator` (denominator > 0), compared by
  /// cross-multiplying so nothing is rounded.
  int pointsForRatio(ExactDecimal numerator, ExactDecimal denominator) {
    var crossed = 0;
    for (final threshold in thresholds) {
      final scaled = threshold * denominator;
      final isCrossed = strict ? scaled <= numerator : scaled < numerator;
      if (!isCrossed) break;
      crossed++;
    }
    return crossed == 0 ? 0 : steps[crossed - 1];
  }
}

final _one = ExactDecimal.fromInt(1);

/// Highest score (inclusive) per grade, best first; higher gets [worst].
final class GradeBands {
  const GradeBands(this.upperBounds, {required this.worst});

  final List<(int, Grade)> upperBounds;
  final Grade worst;

  Grade grade(int score) {
    for (final (upper, grade) in upperBounds) {
      if (score <= upper) return grade;
    }
    return worst;
  }
}

List<String> _multiples(int step, int count) => [
  for (var n = 1; n <= count; n++) '${step * n}',
];

// -----------------------------------------------------------------------------
// Shared by general foods, red meat, cheese and fats/oils/nuts/seeds.

/// Q&A Table 5; 2022 report recap. 0-15 points.
final sugarsG = PointTable([
  '3.4', '6.8', '10', '14', '17', '20', '24', '27', '31', '34', '37', '41', //
  '44', '48', '51',
]);

/// Q&A Tables 5, 7 and 9 (same salt scale everywhere). 0-20 points:
/// 0.2, 0.4, ..., 4.0.
final saltG = PointTable([
  for (var n = 1; n <= 20; n++) (ExactDecimal.fromInt(n) * _fifth).toString(),
]);
final _fifth = ExactDecimal.parse('0.2');

/// Q&A Tables 6 and 8. 0-7 points.
final proteinG = PointTable(['2.4', '4.8', '7.2', '9.6', '12', '14', '17']);

/// Q&A Tables 6, 8 and 10 (same fibre scale everywhere). 0-5 points.
final fibreG = PointTable(['3.0', '4.1', '5.2', '6.3', '7.4']);

/// Q&A Tables 6 and 8: 0, 1, 2 or 5 points (> 40 %, > 60 %, > 80 %).
final fvlPercent = PointTable(['40', '60', '80'], steps: [1, 2, 5]);

// -----------------------------------------------------------------------------
// General foods, red meat, cheese.

/// Q&A Table 5. 0-10 points: 335, 670, ..., 3350.
final energyKj = PointTable(_multiples(335, 10));

/// Q&A Table 5. 0-10 points: 1, 2, ..., 10.
final saturatedFatG = PointTable(_multiples(1, 10));

/// Q&A Table 6, footnote: red meat gets at most 2 protein points.
const redMeatMaxProteinPoints = 2;

/// Q&A p. 28: with N >= 11 (and not cheese), protein is not subtracted.
const foodsProteinNLimit = 11;

/// 2022 report §1.8.2 p. 50.
const foodsGrades = GradeBands([
  (0, Grade.a),
  (2, Grade.b),
  (10, Grade.c),
  (18, Grade.d),
], worst: Grade.e);

// -----------------------------------------------------------------------------
// Fats, oils, nuts and seeds.

/// Q&A Table 7: energy from saturates (kJ) = saturated fat (g) x 37.
final kjPerGSaturatedFat = ExactDecimal.fromInt(37);

/// Q&A Table 7. 0-10 points: 120, 240, ..., 1200.
final energyFromSaturatesKj = PointTable(_multiples(120, 10));

/// Q&A Table 7: saturates / lipids in %, written with "<" (decision 2).
final saturatedFatRatioPercent = PointTable([
  '10', '16', '22', '28', '34', '40', '46', '52', '58', '64', //
], strict: true);

/// Q&A p. 30: with N >= 7, protein is not subtracted.
const fatsProteinNLimit = 7;

/// 2022 report §2.4.3 p. 73.
const fatsGrades = GradeBands([
  (-6, Grade.a),
  (2, Grade.b),
  (10, Grade.c),
  (18, Grade.d),
], worst: Grade.e);

// -----------------------------------------------------------------------------
// Beverages (per 100 mL).

/// Q&A Table 9; 2023 report p. 73. 0-10 points.
final beverageEnergyKj = PointTable([
  '30', '90', '150', '210', '240', '270', '300', '330', '360', '390', //
]);

/// Q&A Table 9. 0-10 points.
final beverageSugarsG = PointTable([
  '0.5', '2', '3.5', '5', '6', '7', '8', '9', '10', '11', //
]);

/// Q&A Table 9: same scale as foods. 0-10 points.
final PointTable beverageSaturatedFatG = saturatedFatG;

/// Q&A Table 9: presence of non-nutritive sweeteners.
const nonNutritiveSweetenersPoints = 4;

/// Q&A Table 10. 0-7 points.
final beverageProteinG = PointTable([
  '1.2', '1.5', '1.8', '2.1', '2.4', '2.7', '3.0', //
]);

/// Q&A Table 10: 0, 2, 4 or 6 points (> 40 %, > 60 %, > 80 %).
final beverageFvlPercent = PointTable(['40', '60', '80'], steps: [2, 4, 6]);

/// 2023 report §6.7.3 p. 48 and p. 74. Only water is A (engine).
const beverageGrades = GradeBands([
  (2, Grade.b),
  (6, Grade.c),
  (9, Grade.d),
], worst: Grade.e);
