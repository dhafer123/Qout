import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/scoring/scoring.dart' as scoring;
import 'package:qout/scoring/tables.dart' as tables;

part 'score_explanation.freezed.dart';

/// One component of a Nutri-Score breakdown: [points] out of [maxPoints]
/// (null when the category isn't known to this app).
@freezed
abstract class ScoreComponent with _$ScoreComponent {
  const factory ScoreComponent({
    /// Breakdown key: `energy`, `saturated_fat_ratio`, `fvl`, ...
    required String name,
    required int points,
    int? maxPoints,
  }) = _ScoreComponent;
}

/// "Why this score": the API's score breakdown, read into what the result
/// screen shows. The breakdown is the golden `expected` format
/// (`scoring-spec/README.md`).
@freezed
sealed class ScoreExplanation with _$ScoreExplanation {
  /// Points per component. [score] = [negativeTotal] minus the subtracted
  /// positive points ([positiveTotal] without protein when [proteinCounted]
  /// is false).
  const factory ScoreExplanation.graded({
    required Grade grade,
    required List<ScoreComponent> negative,
    required List<ScoreComponent> positive,
    required int negativeTotal,
    required int positiveTotal,
    required bool proteinCounted,
    required int score,

    /// The negative-points limit from which protein stops counting, for the
    /// categories that have one (general foods, red meat, fats).
    int? proteinNLimit,

    /// Undeclared inputs counted as 0 points (decision 8: `fibre_g`).
    @Default(<String>[]) List<String> assumedZero,
  }) = GradedExplanation;

  /// Plain water: always A, no points.
  const factory ScoreExplanation.water() = WaterExplanation;

  /// A grade whose breakdown this app can't read (e.g. from a newer backend).
  const factory ScoreExplanation.gradeOnly({required Grade grade}) =
      GradeOnlyExplanation;

  /// No grade: these inputs (spec names, e.g. `salt_g`) are missing or
  /// unusable.
  const factory ScoreExplanation.insufficientData({
    required List<String> missing,
  }) = InsufficientDataExplanation;

  /// No score at all: the product's scoring category is unknown.
  const factory ScoreExplanation.notScored() = NotScoredExplanation;
}

extension GradedExplanationPoints on GradedExplanation {
  /// The positive points actually subtracted from [negativeTotal].
  int get subtracted => proteinCounted
      ? positiveTotal
      : positiveTotal -
            positive
                .where((c) => c.name == 'protein')
                .fold(0, (sum, c) => sum + c.points);
}

extension ScoreExplanationGrade on ScoreExplanation {
  /// The grade to show (water is A); null when there is none.
  Grade? get displayGrade => switch (this) {
    GradedExplanation(:final grade) ||
    GradeOnlyExplanation(:final grade) => grade,
    WaterExplanation() => Grade.a,
    InsufficientDataExplanation() || NotScoredExplanation() => null,
  };
}

/// Display order of the components; unknown ones follow in API order.
const _negativeOrder = [
  'energy',
  'energy_from_saturates',
  'sugars',
  'saturated_fat',
  'saturated_fat_ratio',
  'salt',
  'non_nutritive_sweeteners',
];
const _positiveOrder = ['protein', 'fibre', 'fvl'];

/// Reads the score of [product] into a [ScoreExplanation].
ScoreExplanation explainScore(ProductDetail product) {
  final score = product.score;
  if (score == null) return const ScoreExplanation.notScored();
  final breakdown = score.breakdown;
  if (breakdown['insufficient_data'] case final List<Object?> missing) {
    return ScoreExplanation.insufficientData(
      missing: missing.whereType<String>().toList(),
    );
  }
  final grade = score.grade;
  if (grade == null || grade == Grade.unrecognized) {
    return const ScoreExplanation.notScored();
  }
  if (product.category == Category.water) {
    return const ScoreExplanation.water();
  }
  return _graded(grade, _scoringCategory(product.category), breakdown) ??
      ScoreExplanation.gradeOnly(grade: grade);
}

ScoreExplanation? _graded(
  Grade grade,
  scoring.Category? category,
  Map<String, Object?> b,
) {
  if ((
        b['negative'],
        b['positive'],
        b['negative_total'],
        b['positive_total'],
        b['protein_counted'],
        b['score'],
      )
      case (
        final Map<Object?, Object?> negative,
        final Map<Object?, Object?> positive,
        final int negativeTotal,
        final int positiveTotal,
        final bool proteinCounted,
        final int score,
      )) {
    final negativeComponents = _components(negative, _negativeOrder, category);
    final positiveComponents = _components(positive, _positiveOrder, category);
    if (negativeComponents == null || positiveComponents == null) return null;
    return ScoreExplanation.graded(
      grade: grade,
      negative: negativeComponents,
      positive: positiveComponents,
      negativeTotal: negativeTotal,
      positiveTotal: positiveTotal,
      proteinCounted: proteinCounted,
      score: score,
      proteinNLimit: switch (category) {
        scoring.Category.general ||
        scoring.Category.redMeat => tables.foodsProteinNLimit,
        scoring.Category.fatsOilsNutsSeeds => tables.fatsProteinNLimit,
        _ => null,
      },
      assumedZero: switch (b['assumed_zero']) {
        final List<Object?> fields => fields.whereType<String>().toList(),
        _ => const [],
      },
    );
  }
  return null;
}

/// Components in display order, or null if a value isn't a whole number.
List<ScoreComponent>? _components(
  Map<Object?, Object?> points,
  List<String> order,
  scoring.Category? category,
) {
  final names = [
    ...order.where(points.containsKey),
    ...points.keys.whereType<String>().where((k) => !order.contains(k)),
  ];
  final components = <ScoreComponent>[];
  for (final name in names) {
    final value = points[name];
    if (value is! int) return null;
    components.add(
      ScoreComponent(
        name: name,
        points: value,
        maxPoints: category == null
            ? null
            : scoring.maxComponentPoints(category, name),
      ),
    );
  }
  return components;
}

scoring.Category? _scoringCategory(Category? category) {
  if (category == null || category == Category.unrecognized) return null;
  return scoring.Category.parse(category.value);
}
