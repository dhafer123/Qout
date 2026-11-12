/// Nutri-Score computation (updated algorithm, 2023): N, P, score, grade.
///
/// Port of `backend/app/modules/scoring/engine.py`; both must give identical
/// results (`scoring-spec/`, CI job `scoring-parity`). Rules (Q&A V11
/// pp. 26-32):
/// - general foods and red meat: N < 11 -> N - P; otherwise N - fibre - FVL;
/// - red meat: protein points capped at 2;
/// - cheese: always N - P;
/// - fats, oils, nuts and seeds: N < 7 -> N - P; otherwise N - fibre - FVL;
/// - beverages: always N - P, sweeteners add 4 to N, never A;
/// - water: always A, no inputs.
library;

import 'package:qout/scoring/exact_decimal.dart';
import 'package:qout/scoring/models.dart';
import 'package:qout/scoring/tables.dart' as t;

const _foodFields = [
  'energy_kj',
  'sugars_g',
  'saturated_fat_g',
  'salt_g',
  'fibre_g',
  'protein_g',
  'fvl_percent',
];
const _fatsFields = [
  'total_fat_g',
  'sugars_g',
  'saturated_fat_g',
  'salt_g',
  'fibre_g',
  'protein_g',
  'fvl_percent',
];

/// Inputs each category needs (spec names); any missing gives
/// [InsufficientData] (decision 5).
const Map<Category, List<String>> requiredFields = {
  Category.general: _foodFields,
  Category.redMeat: _foodFields,
  Category.cheese: _foodFields,
  Category.fatsOilsNutsSeeds: _fatsFields,
  Category.beverage: [..._foodFields, 'non_nutritive_sweeteners'],
  Category.water: [],
};

/// Grades a product, or lists the inputs missing to do so.
ScoreResult score(Category category, NutritionInput input) {
  if (category == Category.water) {
    return const ScoreResult.graded(
      category: Category.water,
      grade: Grade.a,
      breakdown: null,
    );
  }

  final required = requiredFields[category]!;
  final missing = {
    for (final field in required)
      if (!input.isDeclared(field)) field,
  };
  if (category == Category.fatsOilsNutsSeeds && input.totalFatG == 0) {
    missing.add('total_fat_g'); // saturates/fat ratio undefined (decision 4)
  }
  if (missing.isNotEmpty) {
    return ScoreResult.insufficientData(
      category: category,
      missing: missing.toList()..sort(),
    );
  }

  ExactDecimal v(String field) => ExactDecimal.fromDouble(input.amount(field)!);
  return switch (category) {
    Category.fatsOilsNutsSeeds => _scoreFats(v),
    Category.beverage => _scoreBeverage(
      v,
      sweeteners: input.nonNutritiveSweeteners!,
    ),
    _ => _scoreFood(category, v),
  };
}

typedef _Values = ExactDecimal Function(String field);

ScoreResult _scoreFood(Category category, _Values v) {
  final negative = {
    'energy': t.energyKj.points(v('energy_kj')),
    'sugars': t.sugarsG.points(v('sugars_g')),
    'saturated_fat': t.saturatedFatG.points(v('saturated_fat_g')),
    'salt': t.saltG.points(v('salt_g')),
  };
  var protein = t.proteinG.points(v('protein_g'));
  if (category == Category.redMeat && protein > t.redMeatMaxProteinPoints) {
    protein = t.redMeatMaxProteinPoints;
  }
  final positive = {
    'protein': protein,
    'fibre': t.fibreG.points(v('fibre_g')),
    'fvl': t.fvlPercent.points(v('fvl_percent')),
  };
  final proteinCounted =
      category == Category.cheese || _sum(negative) < t.foodsProteinNLimit;
  return _graded(category, negative, positive, proteinCounted, t.foodsGrades);
}

ScoreResult _scoreFats(_Values v) {
  final saturated = v('saturated_fat_g');
  final negative = {
    'energy_from_saturates': t.energyFromSaturatesKj.points(
      saturated * t.kjPerGSaturatedFat,
    ),
    'sugars': t.sugarsG.points(v('sugars_g')),
    // saturates x 100 / total fat, compared without dividing.
    'saturated_fat_ratio': t.saturatedFatRatioPercent.pointsForRatio(
      saturated * _hundred,
      v('total_fat_g'),
    ),
    'salt': t.saltG.points(v('salt_g')),
  };
  final positive = {
    'protein': t.proteinG.points(v('protein_g')),
    'fibre': t.fibreG.points(v('fibre_g')),
    'fvl': t.fvlPercent.points(v('fvl_percent')),
  };
  final proteinCounted = _sum(negative) < t.fatsProteinNLimit;
  return _graded(
    Category.fatsOilsNutsSeeds,
    negative,
    positive,
    proteinCounted,
    t.fatsGrades,
  );
}

final _hundred = ExactDecimal.fromInt(100);

ScoreResult _scoreBeverage(_Values v, {required bool sweeteners}) {
  final negative = {
    'energy': t.beverageEnergyKj.points(v('energy_kj')),
    'sugars': t.beverageSugarsG.points(v('sugars_g')),
    'saturated_fat': t.beverageSaturatedFatG.points(v('saturated_fat_g')),
    'salt': t.saltG.points(v('salt_g')),
    'non_nutritive_sweeteners': sweeteners ? t.nonNutritiveSweetenersPoints : 0,
  };
  final positive = {
    'protein': t.beverageProteinG.points(v('protein_g')),
    'fibre': t.fibreG.points(v('fibre_g')),
    'fvl': t.beverageFvlPercent.points(v('fvl_percent')),
  };
  return _graded(Category.beverage, negative, positive, true, t.beverageGrades);
}

int _sum(Map<String, int> points) => points.values.fold(0, (a, b) => a + b);

ScoreResult _graded(
  Category category,
  Map<String, int> negative,
  Map<String, int> positive,
  bool proteinCounted,
  t.GradeBands bands,
) {
  final negativeTotal = _sum(negative);
  final positiveTotal = _sum(positive);
  final subtracted = proteinCounted
      ? positiveTotal
      : positiveTotal - positive['protein']!;
  final total = negativeTotal - subtracted;
  return ScoreResult.graded(
    category: category,
    grade: bands.grade(total),
    breakdown: Breakdown(
      negative: negative,
      positive: positive,
      negativeTotal: negativeTotal,
      positiveTotal: positiveTotal,
      proteinCounted: proteinCounted,
      score: total,
    ),
  );
}

// -----------------------------------------------------------------------------
// Unit conversions (docs/specs/README.md, "Constants for later tasks").

final _kjPerKcal = ExactDecimal.parse('4.2');
final _saltPerSodium = ExactDecimal.parse('2.5');

/// Energy in kJ from kcal: ROUND(kcal x 4.2, 0) like the official calculator
/// (halves away from zero).
int kjFromKcal(double kcal) {
  _checkConversion(kcal, 'kcal');
  return (ExactDecimal.fromDouble(kcal) * _kjPerKcal).roundHalfAwayFromZero();
}

/// Salt in g from sodium in g: sodium x 2.5, without float noise.
double saltFromSodium(double sodiumG) {
  _checkConversion(sodiumG, 'sodiumG');
  return (ExactDecimal.fromDouble(sodiumG) * _saltPerSodium).toDouble();
}

void _checkConversion(double value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'must be a finite number >= 0');
  }
}
