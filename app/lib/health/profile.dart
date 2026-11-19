import 'package:freezed_annotation/freezed_annotation.dart' show immutable;
import 'package:qout/scoring/exact_decimal.dart';

/// Sex, for the sex-specific energy equations. Not given: `null` (the EU
/// reference intakes are used, decision H2 in `docs/specs/README.md`).
enum Sex {
  male('male'),
  female('female')
  ;

  const Sex(this.value);

  /// Name in `scoring-spec/needs/` and in storage.
  final String value;

  static Sex? parse(String? value) => switch (value) {
    null => null,
    _ => values.firstWhere(
      (sex) => sex.value == value,
      orElse: () => throw FormatException('unknown sex', value),
    ),
  };
}

/// EFSA's physical activity levels (EFSA 2013, §5.3.1.2): the factor that
/// multiplies resting energy expenditure.
enum ActivityLevel {
  lowActive('1.4'),
  moderatelyActive('1.6'),
  active('1.8'),
  veryActive('2.0')
  ;

  const ActivityLevel(this._pal);

  final String _pal;

  /// The physical activity level, exactly.
  ExactDecimal get pal => ExactDecimal.parse(_pal);

  /// As written in `scoring-spec/needs/` and stored: `1.4`, `1.6`, ...
  String get value => _pal;

  static ActivityLevel parse(String value) => values.firstWhere(
    (level) => level.pal == ExactDecimal.parse(value),
    orElse: () => throw FormatException('unknown activity level', value),
  );
}

/// The substances or products causing allergies or intolerances of
/// Regulation (EU) 1169/2011, Annex II (p. L 304/43), in its order.
enum Allergen {
  gluten('gluten'),
  crustaceans('crustaceans'),
  eggs('eggs'),
  fish('fish'),
  peanuts('peanuts'),
  soybeans('soybeans'),
  milk('milk'),
  nuts('nuts'),
  celery('celery'),
  mustard('mustard'),
  sesame('sesame'),
  sulphites('sulphites'),
  lupin('lupin'),
  molluscs('molluscs')
  ;

  const Allergen(this.key);

  /// Stable key in storage.
  final String key;

  /// Unknown keys (from a newer version) are dropped.
  static Allergen? fromKey(String key) {
    for (final allergen in values) {
      if (allergen.key == key) return allergen;
    }
    return null;
  }
}

/// Input checks (decision H7): they only catch typing errors.
abstract final class ProfileLimits {
  static const minAge = 18;
  static const maxAge = 120;
  static const minHeightCm = 100;
  static const maxHeightCm = 250;
  static const minWeightKg = 30;
  static const maxWeightKg = 300;
}

/// What is wrong with one field of a profile.
enum ProfileProblem {
  /// Younger than 18: Qout's advice is for adults (decision H1).
  underage,
  outOfRange,
}

/// The given fields that fail the checks (decision H7), by name: `age`,
/// `height`, `weight`. Empty: valid. A field left out (null) is not checked.
Map<String, ProfileProblem> profileProblems({
  int? age,
  double? heightCm,
  double? weightKg,
}) => {
  if (age != null && age < ProfileLimits.minAge)
    'age': ProfileProblem.underage
  else if (age != null && age > ProfileLimits.maxAge)
    'age': ProfileProblem.outOfRange,
  if (heightCm != null &&
      !_within(heightCm, ProfileLimits.minHeightCm, ProfileLimits.maxHeightCm))
    'height': ProfileProblem.outOfRange,
  if (weightKg != null &&
      !_within(weightKg, ProfileLimits.minWeightKg, ProfileLimits.maxWeightKg))
    'weight': ProfileProblem.outOfRange,
};

bool _within(double value, int min, int max) =>
    value.isFinite && value >= min && value <= max;

/// What the daily needs are computed from. Plain immutable class, not
/// freezed, so the checks run in release builds too (like `NutritionInput`).
@immutable
class Profile {
  /// Throws [ArgumentError] when [profileProblems] finds any.
  Profile({
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.activity,
    Set<Allergen> allergens = const {},
  }) : allergens = Set.unmodifiable(allergens) {
    final problems = profileProblems(
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
    );
    if (problems.isNotEmpty) {
      throw ArgumentError('invalid profile: $problems');
    }
  }

  final Sex? sex;

  /// Whole years.
  final int age;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activity;

  /// Not used for the needs; matched against products (T40).
  final Set<Allergen> allergens;

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.sex == sex &&
      other.age == age &&
      other.heightCm == heightCm &&
      other.weightKg == weightKg &&
      other.activity == activity &&
      other.allergens.length == allergens.length &&
      other.allergens.containsAll(allergens);

  @override
  String toString() =>
      'Profile(sex: ${sex?.value}, age: $age, heightCm: $heightCm, '
      'weightKg: $weightKg, pal: ${activity.value}, '
      'allergens: ${allergens.map((a) => a.key).toList()..sort()})';

  @override
  int get hashCode => Object.hash(
    sex,
    age,
    heightCm,
    weightKg,
    activity,
    Object.hashAllUnordered(allergens),
  );
}

/// The age now of someone who was [ageWhenEntered] on [enteredAt]: one more
/// year on each anniversary of that date (the profile stores the age and when
/// it was entered, not a birth date).
int ageNow({
  required int ageWhenEntered,
  required DateTime enteredAt,
  required DateTime now,
}) {
  var years = now.year - enteredAt.year;
  final beforeAnniversary =
      now.month < enteredAt.month ||
      (now.month == enteredAt.month && now.day < enteredAt.day);
  if (beforeAnniversary) years--;
  return ageWhenEntered + (years < 0 ? 0 : years);
}
