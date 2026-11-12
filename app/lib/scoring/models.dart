import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';

/// Algorithm version (updated Nutri-Score, 2023) plus our own revision.
///
/// Must equal `ENGINE_VERSION` in the Python engine
/// (`backend/app/modules/scoring/models.py`).
const scoringEngineVersion = 'nutriscore-2023.1';

/// Scoring category. Choosing it is the caller's job (docs/specs/README.md).
enum Category {
  general('general'),
  redMeat('red_meat'),
  cheese('cheese'),
  fatsOilsNutsSeeds('fats_oils_nuts_seeds'),
  beverage('beverage'),
  water('water')
  ;

  const Category(this.value);

  /// Name used in `scoring-spec/` and by the backend.
  final String value;

  static Category parse(String value) {
    for (final category in values) {
      if (category.value == value) return category;
    }
    throw ArgumentError.value(value, 'value', 'unknown scoring category');
  }
}

enum Grade {
  a('A'),
  b('B'),
  c('C'),
  d('D'),
  e('E')
  ;

  const Grade(this.letter);

  final String letter;
}

/// Spec field names (`scoring-spec/schema.json`) of the gram amounts.
const _gramFields = {
  'sugars_g',
  'saturated_fat_g',
  'total_fat_g',
  'salt_g',
  'fibre_g',
  'protein_g',
};
const _maxGrams = 100.0; // an amount per 100 g cannot exceed 100 g
const _maxPercent = 100.0;

/// Declared nutrition values per 100 g (100 mL for beverages); null means
/// "not declared".
///
/// Only the fields used by the category matter; missing ones make the result
/// [InsufficientData]. Impossible values (negative, NaN, infinite, more than
/// 100 g per 100 g, a percentage above 100) throw [ArgumentError].
///
/// A plain class rather than freezed: freezed cannot run validation in the
/// constructor of a release build (`@Assert` is debug-only).
@immutable
final class NutritionInput {
  NutritionInput({
    this.energyKj,
    this.sugarsG,
    this.saturatedFatG,
    this.totalFatG,
    this.saltG,
    this.fibreG,
    this.proteinG,
    this.fvlPercent,
    this.nonNutritiveSweeteners,
  }) {
    for (final field in amountFields) {
      _checkAmount(field, amount(field));
    }
  }

  final double? energyKj;
  final double? sugarsG;
  final double? saturatedFatG;
  final double? totalFatG;
  final double? saltG;
  final double? fibreG;
  final double? proteinG;

  /// Fruits, vegetables and legumes, % of the product (Q&A Appendix 2).
  final double? fvlPercent;

  /// Beverages only: contains a non-nutritive sweetener (Q&A Appendix 3).
  final bool? nonNutritiveSweeteners;

  /// Spec names of the numeric fields, in schema order.
  static const amountFields = [
    'energy_kj',
    'sugars_g',
    'saturated_fat_g',
    'total_fat_g',
    'salt_g',
    'fibre_g',
    'protein_g',
    'fvl_percent',
  ];

  /// The value of a numeric field by its spec name (`sugars_g`, ...).
  double? amount(String field) => switch (field) {
    'energy_kj' => energyKj,
    'sugars_g' => sugarsG,
    'saturated_fat_g' => saturatedFatG,
    'total_fat_g' => totalFatG,
    'salt_g' => saltG,
    'fibre_g' => fibreG,
    'protein_g' => proteinG,
    'fvl_percent' => fvlPercent,
    _ => throw ArgumentError.value(field, 'field', 'not a numeric field'),
  };

  /// Whether a field (by spec name) is declared.
  bool isDeclared(String field) => field == 'non_nutritive_sweeteners'
      ? nonNutritiveSweeteners != null
      : amount(field) != null;

  @override
  bool operator ==(Object other) =>
      other is NutritionInput &&
      other.nonNutritiveSweeteners == nonNutritiveSweeteners &&
      amountFields.every((f) => other.amount(f) == amount(f));

  @override
  int get hashCode => Object.hash(
    Object.hashAll(amountFields.map(amount)),
    nonNutritiveSweeteners,
  );

  @override
  String toString() {
    final declared = [
      for (final f in amountFields)
        if (amount(f) != null) '$f: ${amount(f)}',
      if (nonNutritiveSweeteners != null)
        'non_nutritive_sweeteners: $nonNutritiveSweeteners',
    ];
    return 'NutritionInput(${declared.join(', ')})';
  }
}

void _checkAmount(String name, double? value) {
  if (value == null) return;
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'must be a finite number >= 0');
  }
  if (_gramFields.contains(name) && value > _maxGrams) {
    throw ArgumentError.value(value, name, 'must be <= 100 g per 100 g');
  }
  if (name == 'fvl_percent' && value > _maxPercent) {
    throw ArgumentError.value(value, name, 'must be <= 100 %');
  }
}

/// Points per component: the "why this score" part of a result.
///
/// Keys are the spec component names (`energy`, `saturated_fat_ratio`, ...).
/// [positiveTotal] sums all three positive components, even when protein is
/// left out of the score ([proteinCounted] is false).
@freezed
abstract class Breakdown with _$Breakdown {
  const factory Breakdown({
    required Map<String, int> negative,
    required Map<String, int> positive,
    required int negativeTotal,
    required int positiveTotal,
    required bool proteinCounted,
    required int score,
  }) = _Breakdown;
}

/// A graded product ([NutriScore]) or missing inputs ([InsufficientData]).
@freezed
sealed class ScoreResult with _$ScoreResult {
  /// A graded product. [breakdown] is null for water (always A, no points).
  const factory ScoreResult.graded({
    required Category category,
    required Grade grade,
    required Breakdown? breakdown,
    @Default(scoringEngineVersion) String engineVersion,
  }) = NutriScore;

  /// No grade: [missing] lists the spec names of missing or unusable inputs,
  /// sorted.
  const factory ScoreResult.insufficientData({
    required Category category,
    required List<String> missing,
    @Default(scoringEngineVersion) String engineVersion,
  }) = InsufficientData;
}
