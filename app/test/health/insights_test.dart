import 'package:flutter_test/flutter_test.dart';
import 'package:qout/health/advice.dart' show Nutrient, PortionUnit;
import 'package:qout/health/diary.dart';
import 'package:qout/health/insights.dart';
import 'package:qout/health/needs.dart';

// The EU reference intakes (no profile): salt 6 g, sugars 90 g, energy
// 8400 kJ (T38).
final DailyNeeds _needs = computeNeeds(null);
final _monday = DateTime(2026, 11, 16);

var _id = 0;

/// 100 g of a product with [per100] values, on day [day] (0 = Monday).
DiaryEntry _eat(
  int day, {
  required Map<Nutrient, double> per100,
  String? grade,
  int? nova,
  String? ean,
  String? name,
  double amount = 100,
}) => DiaryEntry(
  id: ++_id,
  eatenAt: DateTime(2026, 11, 16 + day, 12),
  meal: Meal.lunch,
  ean: ean ?? 'p$_id',
  name: name ?? 'Product $_id',
  grade: grade,
  novaGroup: nova,
  unit: PortionUnit.gram,
  amount: amount,
  values: per100,
);

DiaryEntry _quick(int day, double kj) => DiaryEntry(
  id: ++_id,
  eatenAt: DateTime(2026, 11, 16 + day, 19),
  meal: Meal.dinner,
  values: {Nutrient.energy: kj},
);

void main() {
  test('mondayOf: the Monday of the week, Sunday included', () {
    expect(mondayOf(DateTime(2026, 11, 16)), _monday); // a Monday
    expect(mondayOf(DateTime(2026, 11, 22, 23)), _monday); // Sunday night
    expect(mondayOf(DateTime(2026, 11, 23)), DateTime(2026, 11, 23));
    expect(mondayOf(DateTime(2026, 3, 4)), DateTime(2026, 3, 2));
  });

  test('an empty week', () {
    final week = weekInsights(const [], _monday, _needs);
    expect(week.isEmpty, isTrue);
    expect(week.energyKjPerDay, List.filled(7, 0));
    expect(week.energyShareByGrade, isEmpty);
    expect(week.nova4Share, isNull);
    expect(week.averageKjOnLoggedDays, 0);
  });

  test('energy per day, and the average on logged days', () {
    final week = weekInsights(
      [
        _eat(0, per100: const {Nutrient.energy: 1000}),
        _eat(0, per100: const {Nutrient.energy: 500}),
        _quick(2, 2000),
      ],
      _monday,
      _needs,
    );
    expect(week.energyKjPerDay, [1500, 0, 2000, 0, 0, 0, 0]);
    expect(week.daysLogged, 2);
    expect(week.averageKjOnLoggedDays, 1750);
  });

  test('entries outside the week are left out', () {
    final week = weekInsights(
      [
        _eat(-1, per100: const {Nutrient.energy: 1000}), // Sunday before
        _eat(7, per100: const {Nutrient.energy: 1000}), // Monday after
      ],
      _monday,
      _needs,
    );
    expect(week.isEmpty, isTrue);
  });

  test('shares by grade are of the energy; quick adds are not graded', () {
    final week = weekInsights(
      [
        _eat(0, per100: const {Nutrient.energy: 1000}, grade: 'A'),
        _eat(1, per100: const {Nutrient.energy: 1000}, grade: 'B'),
        _eat(1, per100: const {Nutrient.energy: 1000}, grade: 'C'),
        _eat(2, per100: const {Nutrient.energy: 500}, grade: 'E'),
        _quick(3, 500),
      ],
      _monday,
      _needs,
    );
    final shares = week.energyShareByGrade;
    expect(shares[GradeGroup.ab], closeTo(0.5, 1e-9));
    expect(shares[GradeGroup.c], closeTo(0.25, 1e-9));
    expect(shares[GradeGroup.de], closeTo(0.125, 1e-9));
    expect(shares[GradeGroup.notGraded], closeTo(0.125, 1e-9));
    expect(shares.values.reduce((a, b) => a + b), closeTo(1, 1e-9));
  });

  test('the ultra-processed share, and what is not known', () {
    final week = weekInsights(
      [
        _eat(0, per100: const {Nutrient.energy: 3000}, nova: 4),
        _eat(0, per100: const {Nutrient.energy: 1000}, nova: 1),
        _quick(1, 1000),
      ],
      _monday,
      _needs,
    );
    expect(week.nova4Share, closeTo(0.6, 1e-9));
    expect(week.novaUnknownShare, closeTo(0.2, 1e-9));
  });

  test('days above the salt and the sugars references', () {
    final week = weekInsights(
      [
        // Monday: 7 g of salt (above 6), 50 g of sugars.
        _eat(0, per100: const {Nutrient.salt: 7, Nutrient.sugars: 50}),
        // Tuesday: exactly 6 g of salt (not above), 95 g of sugars (above).
        _eat(1, per100: const {Nutrient.salt: 6, Nutrient.sugars: 95}),
        // Wednesday: 4 + 3 g of salt over two entries (above).
        _eat(2, per100: const {Nutrient.salt: 4}),
        _eat(2, per100: const {Nutrient.salt: 3}),
      ],
      _monday,
      _needs,
    );
    expect(_needs.saltG, 6);
    expect(_needs.sugarsG, 90);
    expect(week.daysAboveSalt, 2);
    expect(week.daysAboveSugars, 1);
  });

  test('top sources: summed per product, most first, three at most', () {
    final week = weekInsights(
      [
        _eat(0, per100: const {Nutrient.sugars: 10}, ean: 'a', name: 'A'),
        _eat(1, per100: const {Nutrient.sugars: 10}, ean: 'a', name: 'A'),
        _eat(1, per100: const {Nutrient.sugars: 30}, ean: 'b', name: 'B'),
        _eat(2, per100: const {Nutrient.sugars: 5}, ean: 'c', name: 'C'),
        _eat(2, per100: const {Nutrient.sugars: 5}, ean: 'd', name: 'D'),
        _eat(3, per100: const {Nutrient.sugars: 0}, ean: 'e', name: 'E'),
      ],
      _monday,
      _needs,
    );
    expect(week.topSugars, const [
      TopSource(name: 'B', grams: 30),
      TopSource(name: 'A', grams: 20),
      TopSource(name: 'C', grams: 5), // logged before D
    ]);
    expect(week.topSalt, isEmpty);
  });
}
