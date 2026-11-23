import 'package:flutter_test/flutter_test.dart';
import 'package:qout/health/advice.dart' show Nutrient, PortionUnit;
import 'package:qout/health/diary.dart';
import 'package:qout/health/needs.dart';
import 'package:qout/health/profile.dart';

DiaryEntry _product({
  required double amount,
  Map<Nutrient, double> values = const {
    Nutrient.energy: 2000,
    Nutrient.fat: 20,
    Nutrient.saturates: 10,
    Nutrient.sugars: 30,
    Nutrient.salt: 1.5,
  },
  Meal meal = Meal.lunch,
}) => DiaryEntry(
  id: 1,
  eatenAt: DateTime(2026, 11, 20, 12),
  meal: meal,
  ean: '6191234567897',
  unit: PortionUnit.gram,
  amount: amount,
  values: values,
);

void main() {
  group('guessMeal', () {
    test('by the time of day, at the boundaries', () {
      Meal at(int h, int m) => guessMeal(DateTime(2026, 11, 20, h, m));
      expect(at(0, 0), Meal.breakfast);
      expect(at(10, 29), Meal.breakfast);
      expect(at(10, 30), Meal.lunch);
      expect(at(14, 59), Meal.lunch);
      expect(at(15, 0), Meal.snack);
      expect(at(17, 59), Meal.snack);
      expect(at(18, 0), Meal.dinner);
      expect(at(23, 59), Meal.dinner);
    });
  });

  test('dayOf: local midnight', () {
    expect(dayOf(DateTime(2026, 11, 20, 23, 59)), DateTime(2026, 11, 20));
  });

  group('what an entry gave', () {
    test('per 100 × amount / 100', () {
      final eaten = _product(amount: 30).eaten;
      expect(eaten[Nutrient.energy], closeTo(600, 1e-9));
      expect(eaten[Nutrient.salt], closeTo(0.45, 1e-9));
    });

    test('a value the label lacks stays out', () {
      final eaten = _product(
        amount: 50,
        values: const {Nutrient.energy: 1000},
      ).eaten;
      expect(eaten.keys, [Nutrient.energy]);
    });

    test('a quick add: its energy only', () {
      final entry = DiaryEntry(
        id: 2,
        eatenAt: DateTime(2026, 11, 20, 8),
        meal: Meal.breakfast,
        values: const {Nutrient.energy: 836.8},
      );
      expect(entry.isQuickAdd, isTrue);
      expect(entry.eaten, {Nutrient.energy: 836.8});
    });
  });

  group('totalsOf', () {
    test('sums, and counts entries missing a value', () {
      final totals = totalsOf([
        _product(amount: 100),
        _product(amount: 50, values: const {Nutrient.energy: 1000}),
      ]);
      expect(totals.of(Nutrient.energy), closeTo(2500, 1e-9));
      expect(totals.of(Nutrient.sugars), closeTo(30, 1e-9));
      expect(totals.missing[Nutrient.sugars], 1);
      expect(totals.missing[Nutrient.energy], isNull);
    });

    test('nothing logged: zero everywhere', () {
      expect(totalsOf(const []).of(Nutrient.salt), 0);
    });
  });

  group('against the daily needs (T38)', () {
    final needs = computeNeeds(
      Profile(
        sex: Sex.female,
        age: 22,
        heightCm: 165,
        weightKg: 58,
        activity: ActivityLevel.active,
      ),
    );

    test('the daily amount per nutrient comes from the needs', () {
      expect(dailyAmount(needs, Nutrient.energy), needs.energyKj);
      expect(dailyAmount(needs, Nutrient.fat), needs.fatG);
      expect(dailyAmount(needs, Nutrient.saturates), needs.saturatesG);
      expect(dailyAmount(needs, Nutrient.sugars), needs.sugarsG);
      expect(dailyAmount(needs, Nutrient.salt), needs.saltG);
    });

    test('share of the day', () {
      expect(shareOfDay(2.5, 5), 0.5);
      expect(shareOfDay(1, 0), 0);
    });

    test('above a reference: only past it, never for energy', () {
      expect(aboveReference(Nutrient.salt, 5, 5), isFalse);
      expect(aboveReference(Nutrient.salt, 5.01, 5), isTrue);
      expect(aboveReference(Nutrient.energy, 99999, 8400), isFalse);
    });

    group('status for the bars (decision H8)', () {
      test('ok under 70 %, warn from 70 % up to the amount', () {
        expect(nutrientStatus(Nutrient.fat, 69.9, 100), NutrientStatus.ok);
        expect(nutrientStatus(Nutrient.fat, 70, 100), NutrientStatus.warn);
        expect(nutrientStatus(Nutrient.fat, 100, 100), NutrientStatus.warn);
      });

      test('over above the amount for fat, saturates and salt', () {
        for (final nutrient in [
          Nutrient.fat,
          Nutrient.saturates,
          Nutrient.salt,
        ]) {
          expect(
            nutrientStatus(nutrient, 100.1, 100),
            NutrientStatus.over,
            reason: nutrient.name,
          );
        }
      });

      test('sugars, a reference intake, stay at warn above it', () {
        expect(nutrientStatus(Nutrient.sugars, 62, 90), NutrientStatus.ok);
        expect(nutrientStatus(Nutrient.sugars, 63, 90), NutrientStatus.warn);
        expect(nutrientStatus(Nutrient.sugars, 400, 90), NutrientStatus.warn);
      });

      test('nothing eaten, or no amount, is ok', () {
        expect(nutrientStatus(Nutrient.salt, 0, 5), NutrientStatus.ok);
        expect(nutrientStatus(Nutrient.salt, 3, 0), NutrientStatus.ok);
      });

      test('the warn step is 70 %', () {
        expect(warnShare, 0.7);
      });
    });
  });

  test('copyWith changes the meal, day and amount only', () {
    final entry = _product(amount: 30);
    final moved = entry.copyWith(
      meal: Meal.dinner,
      amount: 60,
      eatenAt: DateTime(2026, 11, 19, 20),
    );
    expect(
      (moved.meal, moved.amount, moved.eatenAt),
      (
        Meal.dinner,
        60.0,
        DateTime(2026, 11, 19, 20),
      ),
    );
    expect((moved.ean, moved.values), (entry.ean, entry.values));
  });
}
