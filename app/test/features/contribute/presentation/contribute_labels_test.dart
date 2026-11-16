import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/qout_api.dart' show PhotoKind;
import 'package:qout/features/contribute/domain/contribution_draft.dart';
import 'package:qout/features/contribute/domain/draft_values.dart';
import 'package:qout/features/contribute/presentation/contribute_labels.dart';
import 'package:qout/scoring/scoring.dart';

void main() {
  test('every photo kind, field, problem and category has wording', () {
    for (final kind in PhotoKind.values) {
      expect(photoTitle(kind), isNotEmpty);
      photoHint(kind); // empty for an unknown kind
    }
    expect(photoHint(PhotoKind.unrecognized), isEmpty);
    for (final field in NutrientField.values) {
      expect(fieldLabel(field), isNotEmpty);
      expect(fieldName(field), isNotEmpty);
    }
    for (final problem in ValueProblem.values) {
      expect(problemText(problem), isNotEmpty);
    }
    for (final category in Category.values) {
      expect(categoryLabel(category), isNotEmpty);
      expect(categoryHint(category), isNotEmpty);
    }
  });

  test('what is missing for a grade, in form order', () {
    expect(
      missingForGrade(['salt_g', 'energy_kj']),
      'To see the grade, fill in: energy, salt.',
    );
    // Nothing the form asks for (the sweetener switch always answers).
    expect(
      missingForGrade(['non_nutritive_sweeteners']),
      'Fill in the values to see the grade.',
    );
  });
}
