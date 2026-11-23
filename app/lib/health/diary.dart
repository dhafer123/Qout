/// The food diary (T42): what the user ate, and the day's totals against the
/// daily needs (T38). Pure Dart, no Flutter imports. No new nutrition values:
/// amounts come from the products' labels, targets from `computeNeeds`.
library;

import 'package:freezed_annotation/freezed_annotation.dart' show immutable;
import 'package:qout/health/advice.dart' show Nutrient, PortionUnit;
import 'package:qout/health/needs.dart';

/// When something was eaten. The guess from the time of day is only a
/// default the user can change.
enum Meal {
  breakfast('Breakfast'),
  lunch('Lunch'),
  snack('Snack'),
  dinner('Dinner')
  ;

  const Meal(this.label);

  final String label;
}

/// The meal guessed for [localTime]: breakfast before 10:30, lunch before
/// 15:00, a snack before 18:00, then dinner (an interface default, not a
/// dietary rule).
Meal guessMeal(DateTime localTime) {
  final minutes = localTime.hour * 60 + localTime.minute;
  if (minutes < 10 * 60 + 30) return Meal.breakfast;
  if (minutes < 15 * 60) return Meal.lunch;
  if (minutes < 18 * 60) return Meal.snack;
  return Meal.dinner;
}

/// Midnight (local) of the day [time] falls on.
DateTime dayOf(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// One thing eaten: a product with the amount eaten (its label's values
/// copied when it was logged, so later updates don't change the diary), or
/// a quick add with only its energy.
@immutable
class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.eatenAt,
    required this.meal,
    this.ean,
    this.name,
    this.brand,
    this.imageUrl,
    this.grade,
    this.novaGroup,
    this.unit,
    this.amount,
    this.servingQuantity,
    this.values = const {},
  });

  final int id;

  /// The day (and time) it counts for.
  final DateTime eatenAt;
  final Meal meal;

  /// Null for a quick add.
  final String? ean;
  final String? name;
  final String? brand;
  final String? imageUrl;

  /// The grade letter when logged (`A`..`E`); null: not graded, quick add.
  final String? grade;
  final int? novaGroup;

  /// Unit of [amount] and [servingQuantity]; null for a quick add.
  final PortionUnit? unit;

  /// How much was eaten, in [unit]; null for a quick add.
  final double? amount;

  /// The label's serving, to offer "1 serving" again when editing.
  final double? servingQuantity;

  /// Product: the label's values per 100 g or 100 mL (energy in kJ, the rest
  /// in g). Quick add: the energy eaten.
  final Map<Nutrient, double> values;

  bool get isQuickAdd => amount == null;

  /// What this entry gave: per 100 × amount / 100, or the quick add's
  /// energy. A value the label doesn't declare is left out.
  Map<Nutrient, double> get eaten {
    final amount = this.amount;
    if (amount == null) return values;
    return {
      for (final MapEntry(:key, :value) in values.entries)
        key: value * amount / 100,
    };
  }

  DiaryEntry copyWith({DateTime? eatenAt, Meal? meal, double? amount}) =>
      DiaryEntry(
        id: id,
        eatenAt: eatenAt ?? this.eatenAt,
        meal: meal ?? this.meal,
        ean: ean,
        name: name,
        brand: brand,
        imageUrl: imageUrl,
        grade: grade,
        novaGroup: novaGroup,
        unit: unit,
        amount: amount ?? this.amount,
        servingQuantity: servingQuantity,
        values: values,
      );

  @override
  bool operator ==(Object other) =>
      other is DiaryEntry &&
      other.id == id &&
      other.eatenAt == eatenAt &&
      other.meal == meal &&
      other.ean == ean &&
      other.name == name &&
      other.amount == amount &&
      other.unit == unit &&
      _sameValues(other.values, values);

  @override
  int get hashCode => Object.hash(id, eatenAt, meal, ean, name, amount, unit);

  @override
  String toString() =>
      'DiaryEntry($id, ${meal.name}, ${name ?? ean ?? 'quick add'}, '
      '$amount ${unit?.name}, $values)';
}

bool _sameValues(Map<Nutrient, double> a, Map<Nutrient, double> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

/// The sum of a set of entries.
@immutable
class Totals {
  const Totals({required this.amounts, required this.missing});

  /// Per nutrient: energy in kJ, the rest in g.
  final Map<Nutrient, double> amounts;

  /// Per nutrient, how many entries didn't declare it (quick adds count for
  /// everything but energy): the total is then a lower bound.
  final Map<Nutrient, int> missing;

  double of(Nutrient nutrient) => amounts[nutrient] ?? 0;

  static const empty = Totals(amounts: {}, missing: {});
}

/// Adds up [entries].
Totals totalsOf(Iterable<DiaryEntry> entries) {
  final amounts = <Nutrient, double>{};
  final missing = <Nutrient, int>{};
  for (final entry in entries) {
    final eaten = entry.eaten;
    for (final nutrient in Nutrient.values) {
      final value = eaten[nutrient];
      if (value == null) {
        missing[nutrient] = (missing[nutrient] ?? 0) + 1;
      } else {
        amounts[nutrient] = (amounts[nutrient] ?? 0) + value;
      }
    }
  }
  return Totals(amounts: amounts, missing: missing);
}

/// The daily amount for [nutrient] in [needs] (energy in kJ, the rest in g).
int dailyAmount(DailyNeeds needs, Nutrient nutrient) => switch (nutrient) {
  Nutrient.energy => needs.energyKj,
  Nutrient.fat => needs.fatG,
  Nutrient.saturates => needs.saturatesG,
  Nutrient.sugars => needs.sugarsG,
  Nutrient.salt => needs.saltG,
};

/// [total] as a share of the daily amount (1.0 = all of it).
double shareOfDay(double total, int daily) => daily <= 0 ? 0 : total / daily;

/// Whether [total] is above the daily amount for [nutrient]. Energy is a
/// need, not a limit, so it is never "above" here.
bool aboveReference(Nutrient nutrient, double total, int daily) =>
    nutrient != Nutrient.energy && total > daily;

/// Where a day's total stands against its daily amount, for its bar.
enum NutrientStatus {
  /// Under [warnShare] of the amount.
  ok,

  /// From [warnShare] of the amount; for sugars also above it.
  warn,

  /// Above the amount (fat, saturates, salt).
  over,
}

/// The share of a daily amount from which a bar turns amber: a display
/// choice, not a nutrition value (decision H8 in `docs/specs/README.md`).
const double warnShare = 0.7;

/// [total]'s status against [daily] (decision H8). Sugars' 90 g is a
/// reference intake, not a limit (H5), so sugars never go past
/// [NutrientStatus.warn].
NutrientStatus nutrientStatus(Nutrient nutrient, double total, int daily) {
  final share = shareOfDay(total, daily);
  if (share > 1 && nutrient != Nutrient.sugars) return NutrientStatus.over;
  if (share >= warnShare) return NutrientStatus.warn;
  return NutrientStatus.ok;
}
