/// User-facing wording of the contribution flow (English for now).
library;

import 'package:qout/core/api/qout_api.dart' show PhotoKind;
import 'package:qout/features/contribute/domain/contribution_draft.dart';
import 'package:qout/features/contribute/domain/draft_values.dart';
import 'package:qout/scoring/scoring.dart';

String photoTitle(PhotoKind kind) => switch (kind) {
  PhotoKind.front => 'Front of the package',
  PhotoKind.nutrition => 'Nutrition table',
  PhotoKind.ingredients => 'Ingredients (optional)',
  PhotoKind.unrecognized => 'Photo',
};

String photoHint(PhotoKind kind) => switch (kind) {
  PhotoKind.front => 'Name and brand visible.',
  PhotoKind.nutrition => 'The whole table, straight on, filling the frame.',
  PhotoKind.ingredients => 'The ingredients list, readable.',
  PhotoKind.unrecognized => '',
};

String fieldLabel(NutrientField field) => switch (field) {
  NutrientField.energy => 'Energy',
  NutrientField.totalFat => 'Fat',
  NutrientField.saturatedFat => 'of which saturates',
  NutrientField.sugars => 'Sugars',
  NutrientField.fibre => 'Fibre (optional)',
  NutrientField.protein => 'Protein',
  NutrientField.salt => 'Salt',
  NutrientField.fvl => 'Fruit, vegetables and legumes (optional)',
};

String problemText(ValueProblem problem) => switch (problem) {
  ValueProblem.notANumber => 'Enter a number, like 12.5',
  ValueProblem.over100Grams => 'At most 100 g',
  ValueProblem.over100Percent => 'At most 100 %',
  ValueProblem.saturatesOverFat => "Can't be more than the fat",
  ValueProblem.required => 'Required: every label shows it',
};

/// Nutri-Score categories in plain words; membership is defined in the
/// Nutri-Score Q&A (docs/specs/), the contributor picks.
String categoryLabel(Category category) => switch (category) {
  Category.general => 'General food',
  Category.redMeat => 'Red meat',
  Category.cheese => 'Cheese',
  Category.fatsOilsNutsSeeds => 'Fats, oils, nuts and seeds',
  Category.beverage => 'Drink',
  Category.water => 'Plain water',
};

String categoryHint(Category category) => switch (category) {
  Category.general => 'Most foods.',
  Category.redMeat =>
    'Beef, lamb, pork and other red meat, and products made from them.',
  Category.cheese => 'All cheeses.',
  Category.fatsOilsNutsSeeds => 'Oils, butter, margarine, nuts and seeds.',
  Category.beverage => 'Juices, sodas, flavoured waters and other drinks.',
  Category.water => 'Mineral, spring or table water with nothing added.',
};

/// A field's name inside a sentence.
String fieldName(NutrientField field) => switch (field) {
  NutrientField.energy => 'energy',
  NutrientField.totalFat => 'fat',
  NutrientField.saturatedFat => 'saturates',
  NutrientField.sugars => 'sugars',
  NutrientField.fibre => 'fibre',
  NutrientField.protein => 'protein',
  NutrientField.salt => 'salt',
  NutrientField.fvl => 'fruit/vegetable/legume share',
};

/// What to fill in for a grade, from the engine's `missing` (spec names).
String missingForGrade(List<String> missing) {
  final names = [
    for (final field in NutrientField.values)
      if (missing.contains(field.key)) fieldName(field),
  ];
  return names.isEmpty
      ? 'Fill in the values to see the grade.'
      : 'To see the grade, fill in: ${names.join(', ')}.';
}
