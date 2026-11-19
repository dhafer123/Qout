import 'package:qout/features/contribute/domain/draft_values.dart'
    show parseAmount;
import 'package:qout/health/profile.dart';

/// The sex question has a third answer: not given (decision H2).
enum SexChoice { female, male, notGiven }

extension SexChoiceX on SexChoice {
  Sex? get sex => switch (this) {
    SexChoice.female => Sex.female,
    SexChoice.male => Sex.male,
    SexChoice.notGiven => null,
  };

  static SexChoice of(Sex? sex) => switch (sex) {
    Sex.female => SexChoice.female,
    Sex.male => SexChoice.male,
    null => SexChoice.notGiven,
  };
}

/// What is wrong with one field of the profile form.
enum FormProblem {
  missing,
  notANumber,

  /// Under 18 (decision H1).
  underage,
  outOfRange,
}

/// The profile form as typed.
class ProfileFormValues {
  const ProfileFormValues({
    required this.sex,
    required this.age,
    required this.height,
    required this.weight,
    required this.activity,
    required this.allergens,
  });

  /// Pre-filled from [profile].
  factory ProfileFormValues.of(Profile profile) => ProfileFormValues(
    sex: SexChoiceX.of(profile.sex),
    age: '${profile.age}',
    height: _shown(profile.heightCm),
    weight: _shown(profile.weightKg),
    activity: profile.activity,
    allergens: profile.allergens,
  );

  static const empty = ProfileFormValues(
    sex: null,
    age: '',
    height: '',
    weight: '',
    activity: null,
    allergens: {},
  );

  final SexChoice? sex;
  final String age;
  final String height;
  final String weight;
  final ActivityLevel? activity;
  final Set<Allergen> allergens;

  static String _shown(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';
}

/// The profile in [values], or what is wrong with each field (`sex`, `age`,
/// `height`, `weight`, `activity`).
({Profile? profile, Map<String, FormProblem> problems}) readProfileForm(
  ProfileFormValues values,
) {
  final problems = <String, FormProblem>{};
  if (values.sex == null) problems['sex'] = FormProblem.missing;
  if (values.activity == null) problems['activity'] = FormProblem.missing;

  final ageText = values.age.trim();
  final age = int.tryParse(ageText);
  if (ageText.isEmpty) {
    problems['age'] = FormProblem.missing;
  } else if (age == null || ageText.length > 3) {
    problems['age'] = FormProblem.notANumber;
  }

  double? number(String field, String text) {
    try {
      final value = parseAmount(text);
      if (value == null) problems[field] = FormProblem.missing;
      return value;
    } on FormatException {
      problems[field] = FormProblem.notANumber;
      return null;
    }
  }

  final height = number('height', values.height);
  final weight = number('weight', values.weight);

  for (final MapEntry(:key, :value) in profileProblems(
    age: problems.containsKey('age') ? null : age,
    heightCm: height,
    weightKg: weight,
  ).entries) {
    problems[key] = switch (value) {
      ProfileProblem.underage => FormProblem.underage,
      ProfileProblem.outOfRange => FormProblem.outOfRange,
    };
  }
  if (problems.isNotEmpty) return (profile: null, problems: problems);
  return (
    profile: Profile(
      sex: values.sex!.sex,
      age: age!,
      heightCm: height!,
      weightKg: weight!,
      activity: values.activity!,
      allergens: values.allergens,
    ),
    problems: const {},
  );
}
