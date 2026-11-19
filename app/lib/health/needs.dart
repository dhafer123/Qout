/// Daily needs and the daily amounts advice compares products with.
///
/// Every number comes from `docs/specs/README.md`, section "Health advice"
/// (decisions H1-H7); the shared cases are in `scoring-spec/needs/`. Pure
/// Dart, no Flutter imports.
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qout/health/profile.dart';
import 'package:qout/scoring/exact_decimal.dart';

part 'needs.freezed.dart';

/// Where the daily amounts come from.
enum NeedsBasis {
  /// Computed from the profile (EFSA energy, WHO and EU amounts).
  personal('personal'),

  /// The EU reference intakes for an average adult (Annex XIII Part B).
  reference('reference')
  ;

  const NeedsBasis(this.value);

  final String value;
}

/// Why the reference intakes are used instead of a personal energy.
enum ReferenceReason {
  noProfile,

  /// The energy equations are sex-specific (decision H2).
  sexNotGiven,

  /// EFSA gives no adult values from 80 years (decision H1).
  age80OrOver,
}

/// WHO TRS 894, Table 2.1.
enum BmiCategory {
  underweight('underweight'),
  normal('normal'),
  preobese('preobese'),
  obeseClass1('obese_class_1'),
  obeseClass2('obese_class_2'),
  obeseClass3('obese_class_3')
  ;

  const BmiCategory(this.value);

  /// Name in `scoring-spec/needs/`.
  final String value;
}

@freezed
abstract class Bmi with _$Bmi {
  const factory Bmi({
    /// BMI × 10, rounded down (decision H6): 184 is shown 18.4.
    required int tenths,
    required BmiCategory category,
  }) = _Bmi;

  const Bmi._();

  /// As shown: `18.4`.
  String get display => '${tenths ~/ 10}.${tenths % 10}';
}

@freezed
abstract class DailyNeeds with _$DailyNeeds {
  const factory DailyNeeds({
    required NeedsBasis basis,

    /// Set when [basis] is [NeedsBasis.reference].
    required ReferenceReason? referenceReason,
    required int energyKj,
    required int fatG,
    required int saturatesG,
    required int sugarsG,
    required int saltG,

    /// Null without a profile.
    required Bmi? bmi,
  }) = _DailyNeeds;
}

/// The needs for [profile]; null: the profile was skipped.
DailyNeeds computeNeeds(Profile? profile) {
  if (profile == null) return _reference(ReferenceReason.noProfile, null);
  final bmi = bmiOf(heightCm: profile.heightCm, weightKg: profile.weightKg);
  final sex = profile.sex;
  if (sex == null) return _reference(ReferenceReason.sexNotGiven, bmi);
  if (profile.age > _oldestAgeWithEfsaValues) {
    return _reference(ReferenceReason.age80OrOver, bmi);
  }
  final energyKj = dailyEnergyKj(
    sex: sex,
    age: profile.age,
    heightCm: profile.heightCm,
    weightKg: profile.weightKg,
    activity: profile.activity,
  );
  final energy = ExactDecimal.fromInt(energyKj);
  return DailyNeeds(
    basis: NeedsBasis.personal,
    referenceReason: null,
    energyKj: energyKj,
    // EFSA reference intake range for total fat 20-35 % of energy (upper
    // end); WHO: saturates reduced to 10 % of energy (strong recommendation
    // 1). 37 kJ per g of fat: Regulation 1169/2011, Annex XIV.
    fatG: (_d('0.35') * energy).divideRoundHalfAwayFromZero(_kjPerGramFat),
    saturatesG: (_d('0.10') * energy).divideRoundHalfAwayFromZero(
      _kjPerGramFat,
    ),
    // Total sugars: the EU reference intake, not WHO's free-sugar limit
    // (decision H5). Salt: WHO, < 5 g/day.
    sugarsG: 90,
    saltG: 5,
    bmi: bmi,
  );
}

/// EFSA gives adult values up to 79 years (decision H1).
const _oldestAgeWithEfsaValues = 79;

/// Regulation 1169/2011, Annex XIII Part B: reference intakes for an average
/// adult.
DailyNeeds _reference(ReferenceReason reason, Bmi? bmi) => DailyNeeds(
  basis: NeedsBasis.reference,
  referenceReason: reason,
  energyKj: 8400,
  fatG: 70,
  saturatesG: 20,
  sugarsG: 90,
  saltG: 6,
  bmi: bmi,
);

/// Daily energy in kJ: resting energy expenditure from the Henry (2005)
/// equations with body mass and height (EFSA 2013, Appendix 2) times the
/// physical activity level, rounded to whole kJ, halves up (decision H4).
/// For the body mass as entered: no weight targets.
int dailyEnergyKj({
  required Sex sex,
  required int age,
  required double heightCm,
  required double weightKg,
  required ActivityLevel activity,
}) {
  final (a, b, c) = _henry(sex, age);
  final ree =
      _d(a) * ExactDecimal.fromDouble(weightKg) +
      _d(b) * _metres(heightCm) +
      _d(c);
  return (ree * activity.pal * ExactDecimal.fromInt(1000))
      .roundHalfAwayFromZero();
}

/// Henry (2005), MJ/day = a × body mass (kg) + b × height (m) + c. The age
/// bands overlap at 30 and 60; EFSA uses 18-30 for 18-29 years, 30-60 for
/// 30-59 and >= 60 for 60-79 (Table 12, footnote a).
(String, String, String) _henry(Sex sex, int age) => switch ((sex, age)) {
  (Sex.male, < 30) => ('0.0600', '1.31', '0.473'),
  (Sex.male, < 60) => ('0.0476', '2.26', '-0.574'),
  (Sex.male, _) => ('0.0478', '2.26', '-1.07'),
  (Sex.female, < 30) => ('0.0433', '2.57', '-1.18'),
  (Sex.female, < 60) => ('0.0342', '2.10', '-0.0486'),
  (Sex.female, _) => ('0.0356', '1.76', '0.0448'),
};

/// Body mass index (WHO TRS 894, Table 2.1), classified on the exact value
/// and shown rounded down to 0.1 so the number shown always lies in its
/// category (decision H6).
Bmi bmiOf({required double heightCm, required double weightKg}) {
  final metres = _metres(heightCm);
  final squared = metres * metres;
  final weight = ExactDecimal.fromDouble(weightKg);
  // weight < limit × height² is BMI < limit, without dividing.
  bool below(String limit) => weight < _d(limit) * squared;
  final category = below('18.5')
      ? BmiCategory.underweight
      : below('25')
      ? BmiCategory.normal
      : below('30')
      ? BmiCategory.preobese
      : below('35')
      ? BmiCategory.obeseClass1
      : below('40')
      ? BmiCategory.obeseClass2
      : BmiCategory.obeseClass3;
  return Bmi(
    tenths: (weight * ExactDecimal.fromInt(10)).divideFloor(squared),
    category: category,
  );
}

ExactDecimal _metres(double heightCm) =>
    ExactDecimal.fromDouble(heightCm) * _d('0.01');

final _kjPerGramFat = ExactDecimal.fromInt(37);

ExactDecimal _d(String value) => ExactDecimal.parse(value);
