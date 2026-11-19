import 'package:flutter_test/flutter_test.dart';
import 'package:qout/features/profile/domain/profile_form.dart';
import 'package:qout/health/profile.dart';

ProfileFormValues _values({
  SexChoice? sex = SexChoice.female,
  String age = '30',
  String height = '165',
  String weight = '60',
  ActivityLevel? activity = ActivityLevel.active,
  Set<Allergen> allergens = const {},
}) => ProfileFormValues(
  sex: sex,
  age: age,
  height: height,
  weight: weight,
  activity: activity,
  allergens: allergens,
);

void main() {
  test('a complete form gives the profile', () {
    final (:profile, :problems) = readProfileForm(
      _values(
        sex: SexChoice.notGiven,
        weight: ' 61,5 ',
        allergens: {Allergen.lupin},
      ),
    );
    expect(problems, isEmpty);
    expect(
      profile,
      Profile(
        sex: null,
        age: 30,
        heightCm: 165,
        weightKg: 61.5,
        activity: ActivityLevel.active,
        allergens: const {Allergen.lupin},
      ),
    );
  });

  test('the empty form: every required field', () {
    final (:profile, :problems) = readProfileForm(ProfileFormValues.empty);
    expect(profile, isNull);
    expect(problems, {
      'sex': FormProblem.missing,
      'activity': FormProblem.missing,
      'age': FormProblem.missing,
      'height': FormProblem.missing,
      'weight': FormProblem.missing,
    });
  });

  test('each field is checked on its own', () {
    expect(readProfileForm(_values(age: '17', height: '')).problems, {
      'age': FormProblem.underage,
      'height': FormProblem.missing,
    });
    expect(readProfileForm(_values(age: '1234')).problems, {
      'age': FormProblem.notANumber,
    });
    expect(readProfileForm(_values(age: '121')).problems, {
      'age': FormProblem.outOfRange,
    });
    expect(readProfileForm(_values(height: '1.2.3')).problems, {
      'height': FormProblem.notANumber,
    });
    expect(readProfileForm(_values(weight: '301')).problems, {
      'weight': FormProblem.outOfRange,
    });
  });

  test('pre-filled from a profile, and back', () {
    final profile = Profile(
      sex: Sex.male,
      age: 45,
      heightCm: 178,
      weightKg: 81.5,
      activity: ActivityLevel.lowActive,
      allergens: const {Allergen.eggs},
    );
    final values = ProfileFormValues.of(profile);
    expect(
      (values.sex, values.age, values.height, values.weight),
      (
        SexChoice.male,
        '45',
        '178',
        '81.5',
      ),
    );
    expect(readProfileForm(values).profile, profile);
  });

  test('sex choices map both ways', () {
    for (final choice in SexChoice.values) {
      expect(SexChoiceX.of(choice.sex), choice);
    }
  });
}
