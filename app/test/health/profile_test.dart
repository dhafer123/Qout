import 'package:flutter_test/flutter_test.dart';
import 'package:qout/health/profile.dart';
import 'package:qout/scoring/exact_decimal.dart';

void main() {
  group('profileProblems (decision H7)', () {
    Map<String, ProfileProblem> check({
      int age = 30,
      double heightCm = 170,
      double weightKg = 70,
    }) => profileProblems(age: age, heightCm: heightCm, weightKg: weightKg);

    test('a valid profile has none', () {
      expect(check(), isEmpty);
      expect(check(age: 18, heightCm: 100, weightKg: 30), isEmpty);
      expect(check(age: 120, heightCm: 250, weightKg: 300), isEmpty);
    });

    test('under 18: for adults only', () {
      expect(check(age: 17), {'age': ProfileProblem.underage});
    });

    test('out of range', () {
      expect(check(age: 121), {'age': ProfileProblem.outOfRange});
      expect(check(heightCm: 99.9), {'height': ProfileProblem.outOfRange});
      expect(check(heightCm: 250.1), {'height': ProfileProblem.outOfRange});
      expect(check(weightKg: 29.9), {'weight': ProfileProblem.outOfRange});
      expect(check(weightKg: 300.5), {'weight': ProfileProblem.outOfRange});
      expect(
        check(heightCm: double.nan),
        {'height': ProfileProblem.outOfRange},
      );
    });

    test('the constructor refuses an invalid profile', () {
      expect(
        () => Profile(
          sex: Sex.male,
          age: 17,
          heightCm: 170,
          weightKg: 70,
          activity: ActivityLevel.active,
        ),
        throwsArgumentError,
      );
    });
  });

  test('activity levels are EFSA PAL values', () {
    expect(ActivityLevel.values.map((level) => level.value), [
      '1.4',
      '1.6',
      '1.8',
      '2.0',
    ]);
    expect(ActivityLevel.parse('2'), ActivityLevel.veryActive);
    expect(ActivityLevel.parse('1.6').pal, ExactDecimal.parse('1.6'));
    expect(() => ActivityLevel.parse('2.2'), throwsFormatException);
  });

  test('sex parses the spec names, null is not given', () {
    expect(Sex.parse('female'), Sex.female);
    expect(Sex.parse(null), isNull);
    expect(() => Sex.parse('other'), throwsFormatException);
  });

  test('allergens: the 14 of Annex II, unknown keys dropped', () {
    expect(Allergen.values, hasLength(14));
    expect(Allergen.fromKey('sesame'), Allergen.sesame);
    expect(Allergen.fromKey('kiwi'), isNull);
  });

  test('profiles with the same values are equal', () {
    Profile make(Set<Allergen> allergens) => Profile(
      sex: null,
      age: 30,
      heightCm: 170,
      weightKg: 70,
      activity: ActivityLevel.lowActive,
      allergens: allergens,
    );
    expect(
      make({Allergen.milk, Allergen.eggs}),
      make({Allergen.eggs, Allergen.milk}),
    );
    expect(make({Allergen.milk}), isNot(make({})));
    expect(make({}).hashCode, make({}).hashCode);
  });

  group('ageNow', () {
    final entered = DateTime(2026, 11, 19);

    int at(DateTime now) =>
        ageNow(ageWhenEntered: 30, enteredAt: entered, now: now);

    test('one more year on each anniversary', () {
      expect(at(DateTime(2026, 11, 19)), 30);
      expect(at(DateTime(2027, 11, 18)), 30);
      expect(at(DateTime(2027, 11, 19)), 31);
      expect(at(DateTime(2036, 12)), 40);
    });

    test('a clock set before the entry date never lowers it', () {
      expect(at(DateTime(2025)), 30);
    });
  });
}
