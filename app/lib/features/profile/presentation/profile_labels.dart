import 'package:qout/features/profile/domain/profile_form.dart';
import 'package:qout/health/needs.dart';
import 'package:qout/health/profile.dart';

// Words for the profile feature, in one place.

String sexChoiceLabel(SexChoice choice) => switch (choice) {
  SexChoice.male => 'Male',
  SexChoice.female => 'Female',
};

/// A saved profile's sex; "Not given" for one saved before T44c without it.
String sexText(Sex? sex) => switch (SexChoiceX.of(sex)) {
  final choice? => sexChoiceLabel(choice),
  null => 'Not given',
};

/// EFSA's names for the activity levels (EFSA 2013, §5.3.1.2).
String activityTitle(ActivityLevel level) => switch (level) {
  ActivityLevel.lowActive => 'Low active',
  ActivityLevel.moderatelyActive => 'Moderately active',
  ActivityLevel.active => 'Active',
  ActivityLevel.veryActive => 'Very active',
};

/// Rough examples, after EFSA 2013 Table 5 (which notes the link between
/// lifestyle and activity level is weak).
String activityExample(ActivityLevel level) => switch (level) {
  ActivityLevel.lowActive =>
    'Mostly sitting or resting, little walking and no exercise.',
  ActivityLevel.moderatelyActive =>
    'Office work with some walking, light chores or a little exercise.',
  ActivityLevel.active =>
    'On your feet much of the day (standing work), or daily exercise.',
  ActivityLevel.veryActive => 'Physical work, or hard exercise most days.',
};

/// Regulation (EU) 1169/2011, Annex II, in short.
String allergenLabel(Allergen allergen) => switch (allergen) {
  Allergen.gluten => 'Gluten (cereals)',
  Allergen.crustaceans => 'Crustaceans',
  Allergen.eggs => 'Eggs',
  Allergen.fish => 'Fish',
  Allergen.peanuts => 'Peanuts',
  Allergen.soybeans => 'Soy',
  Allergen.milk => 'Milk',
  Allergen.nuts => 'Nuts',
  Allergen.celery => 'Celery',
  Allergen.mustard => 'Mustard',
  Allergen.sesame => 'Sesame',
  Allergen.sulphites => 'Sulphites',
  Allergen.lupin => 'Lupin',
  Allergen.molluscs => 'Molluscs',
};

String? formProblemText(String field, FormProblem? problem) => switch ((
  field,
  problem,
)) {
  (_, null) => null,
  ('sex', _) => 'Choose one.',
  ('activity', _) => 'Choose the level closest to your usual day.',
  (_, FormProblem.missing) => 'Required.',
  (_, FormProblem.notANumber) => 'Enter a number.',
  (_, FormProblem.underage) => "Qout's advice is for adults (18 and over).",
  ('age', FormProblem.outOfRange) => 'Enter an age between 18 and 120.',
  ('height', FormProblem.outOfRange) =>
    'Enter a height between 100 and 250 cm.',
  ('weight', FormProblem.outOfRange) => 'Enter a weight between 30 and 300 kg.',
  (_, FormProblem.outOfRange) => 'Out of range.',
};

/// Neutral wording for the BMI (decision H6): where it lies against the WHO
/// normal range, nothing more.
String bmiText(Bmi bmi) => switch (bmi.category) {
  BmiCategory.underweight => 'below the WHO normal range (18.5–24.9)',
  BmiCategory.normal => 'within the WHO normal range (18.5–24.9)',
  _ => 'above the WHO normal range (18.5–24.9)',
};

/// Why the EU reference intakes are shown instead of personal values.
String referenceReasonText(ReferenceReason reason) => switch (reason) {
  ReferenceReason.noProfile =>
    'Without a profile, Qout uses the EU reference intakes for an average '
        'adult.',
  ReferenceReason.sexNotGiven =>
    'The energy equations differ for women and men, so without your sex '
        'Qout uses the EU reference intakes for an average adult.',
  ReferenceReason.age80OrOver =>
    'EFSA gives no values from 80 years, so Qout uses the EU reference '
        'intakes for an average adult.',
};
