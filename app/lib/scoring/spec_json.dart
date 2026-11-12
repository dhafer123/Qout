/// Conversions between the engine and the golden case format
/// (`scoring-spec/README.md`): inputs and `expected` blocks keyed by spec
/// names. Used by the golden tests and the parity runner.
library;

import 'package:qout/scoring/models.dart';

/// A golden case `input` object as a [NutritionInput].
///
/// Throws [ArgumentError] for unknown keys or wrongly typed values rather
/// than ignoring them.
NutritionInput nutritionInputFromSpec(Map<String, Object?> json) {
  for (final key in json.keys) {
    if (!NutritionInput.amountFields.contains(key) &&
        key != 'non_nutritive_sweeteners') {
      throw ArgumentError.value(key, 'json', 'unknown input field');
    }
  }
  double? amount(String key) => switch (json[key]) {
    null => null,
    final num n => n.toDouble(),
    final other => throw ArgumentError.value(other, key, 'must be a number'),
  };
  final sweeteners = switch (json['non_nutritive_sweeteners']) {
    null => null,
    final bool b => b,
    final other => throw ArgumentError.value(
      other,
      'non_nutritive_sweeteners',
      'must be a bool',
    ),
  };
  return NutritionInput(
    energyKj: amount('energy_kj'),
    sugarsG: amount('sugars_g'),
    saturatedFatG: amount('saturated_fat_g'),
    totalFatG: amount('total_fat_g'),
    saltG: amount('salt_g'),
    fibreG: amount('fibre_g'),
    proteinG: amount('protein_g'),
    fvlPercent: amount('fvl_percent'),
    nonNutritiveSweeteners: sweeteners,
  );
}

/// The golden `expected` block for an engine result.
Map<String, Object?> expectedToSpec(ScoreResult result) => switch (result) {
  InsufficientData(:final missing) => {'insufficient_data': missing},
  NutriScore(:final grade, breakdown: null) => {'grade': grade.letter},
  NutriScore(:final grade, breakdown: final Breakdown b) => {
    'negative': b.negative,
    'positive': b.positive,
    'negative_total': b.negativeTotal,
    'positive_total': b.positiveTotal,
    'protein_counted': b.proteinCounted,
    'score': b.score,
    'grade': grade.letter,
  },
};
