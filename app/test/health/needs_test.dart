import 'package:flutter_test/flutter_test.dart';
import 'package:qout/health/needs.dart';
import 'package:qout/health/profile.dart';

Profile _profile({
  Sex? sex = Sex.female,
  int age = 40,
  double heightCm = 165,
  double weightKg = 60,
  ActivityLevel activity = ActivityLevel.moderatelyActive,
}) => Profile(
  sex: sex,
  age: age,
  heightCm: heightCm,
  weightKg: weightKg,
  activity: activity,
);

void main() {
  group('reference intakes (Annex XIII Part B)', () {
    test('no profile', () {
      final needs = computeNeeds(null);
      expect(needs.basis, NeedsBasis.reference);
      expect(needs.referenceReason, ReferenceReason.noProfile);
      expect(
        (needs.energyKj, needs.fatG, needs.saturatesG, needs.sugarsG),
        (8400, 70, 20, 90),
      );
      expect(needs.saltG, 6);
      expect(needs.bmi, isNull);
    });

    test('sex not given: reference, BMI still computed', () {
      final needs = computeNeeds(_profile(sex: null));
      expect(needs.referenceReason, ReferenceReason.sexNotGiven);
      expect(needs.energyKj, 8400);
      expect(needs.bmi?.category, BmiCategory.normal);
    });

    test('79 is personal, 80 is reference', () {
      expect(computeNeeds(_profile(age: 79)).basis, NeedsBasis.personal);
      final at80 = computeNeeds(_profile(age: 80));
      expect(at80.basis, NeedsBasis.reference);
      expect(at80.referenceReason, ReferenceReason.age80OrOver);
    });
  });

  group('personal', () {
    test('salt is WHO 5 g, sugars the EU 90 g', () {
      final needs = computeNeeds(_profile());
      expect(needs.referenceReason, isNull);
      expect((needs.saltG, needs.sugarsG), (5, 90));
    });

    test('more activity never lowers the energy', () {
      final levels = ActivityLevel.values
          .map((level) => computeNeeds(_profile(activity: level)).energyKj)
          .toList();
      expect(levels, orderedEquals([...levels]..sort()));
    });

    test('more body mass never lowers the energy', () {
      for (final sex in Sex.values) {
        for (final age in [18, 29, 30, 59, 60, 79]) {
          final lighter = computeNeeds(_profile(sex: sex, age: age));
          final heavier = computeNeeds(
            _profile(sex: sex, age: age, weightKg: 61),
          );
          expect(heavier.energyKj, greaterThan(lighter.energyKj));
        }
      }
    });

    test('fat and saturates follow the rounded energy', () {
      // 0.35 × E / 37 and 0.10 × E / 37, halves rounded up.
      final needs = computeNeeds(_profile());
      expect(needs.fatG, (0.35 * needs.energyKj / 37).round());
      expect(needs.saturatesG, (0.10 * needs.energyKj / 37).round());
    });
  });

  group('BMI', () {
    test('exact boundary values are in the higher class', () {
      // 2 m tall: BMI = weight / 4.
      final cases = {
        74.0: BmiCategory.normal, // 18.5
        100.0: BmiCategory.preobese, // 25
        120.0: BmiCategory.obeseClass1, // 30
        140.0: BmiCategory.obeseClass2, // 35
        160.0: BmiCategory.obeseClass3, // 40
      };
      for (final MapEntry(key: weight, value: category) in cases.entries) {
        expect(bmiOf(heightCm: 200, weightKg: weight).category, category);
      }
    });

    test('shown rounded down, so it stays in its class', () {
      final bmi = bmiOf(heightCm: 200, weightKg: 73.9); // 18.475
      expect(bmi.category, BmiCategory.underweight);
      expect(bmi.display, '18.4');
      expect(bmiOf(heightCm: 180, weightKg: 75).display, '23.1'); // 23.148
    });
  });
}
