import 'package:flutter_test/flutter_test.dart';
import 'package:qout/health/advice.dart';
import 'package:qout/health/needs.dart';
import 'package:qout/health/profile.dart';

/// The recorded biscuit (product-serving-allergens): 21.7 g serving.
const _biscuit = ProductFacts(
  basis: PortionUnit.gram,
  per100: {
    Nutrient.energy: 1980,
    Nutrient.fat: 23,
    Nutrient.saturates: 10.9,
    Nutrient.sugars: 23,
    Nutrient.salt: 0.30775,
  },
  servingQuantity: 21.7,
  servingUnit: PortionUnit.gram,
  allergens: {Allergen.gluten, Allergen.soybeans, Allergen.milk},
  traces: {Allergen.nuts},
  additives: [
    AdditiveFact(code: 'E330', name: 'Citric acid', risk: AdditiveRisk.unknown),
    AdditiveFact(code: 'E450', name: 'Diphosphates', risk: AdditiveRisk.high),
    AdditiveFact(code: 'E338', risk: AdditiveRisk.moderate),
    AdditiveFact(code: 'E300', name: 'Ascorbic acid', risk: AdditiveRisk.none),
  ],
);

/// scoring-spec/needs/cases/personal--female-22-active.json: 10029 kJ, fat
/// 95 g, saturates 27 g, sugars 90 g, salt 5 g.
Profile _profile({Set<Allergen> allergens = const {}}) => Profile(
  sex: Sex.female,
  age: 22,
  heightCm: 165,
  weightKg: 58,
  activity: ActivityLevel.active,
  allergens: allergens,
);

ForYou _advice(
  ProductFacts product, {
  Profile? profile,
  Set<String> avoided = const {},
}) => adviceFor(
  product,
  profile: profile,
  needs: computeNeeds(profile),
  avoided: avoided,
);

Map<Nutrient, String> _percents(ForYou advice) => {
  for (final share in advice.shares)
    share.nutrient: share.lessThanOne ? '<1' : '${share.percent}',
};

ProductFacts _with({
  double? servingQuantity = 21.7,
  PortionUnit? servingUnit = PortionUnit.gram,
  PortionUnit? basis = PortionUnit.gram,
  Map<Nutrient, double>? per100,
  Set<Allergen>? allergens = const {},
  Set<Allergen>? traces = const {},
}) => ProductFacts(
  basis: basis,
  per100: per100 ?? _biscuit.per100,
  servingQuantity: servingQuantity,
  servingUnit: servingUnit,
  allergens: allergens,
  traces: traces,
  additives: const [],
);

void main() {
  group('portion', () {
    test('the serving when its unit matches the basis', () {
      expect(
        portionOf(_biscuit),
        const Portion(amount: 21.7, unit: PortionUnit.gram, isServing: true),
      );
    });

    test('otherwise 100 g or 100 mL', () {
      const per100g = Portion(
        amount: 100,
        unit: PortionUnit.gram,
        isServing: false,
      );
      expect(portionOf(_with(servingQuantity: null)), per100g);
      expect(portionOf(_with(servingUnit: PortionUnit.millilitre)), per100g);
      expect(portionOf(_with(servingQuantity: 0)), per100g);
      expect(portionOf(_with(servingQuantity: 1000.5)), per100g);
      expect(
        portionOf(
          _with(basis: PortionUnit.millilitre, servingQuantity: null),
        ),
        const Portion(
          amount: 100,
          unit: PortionUnit.millilitre,
          isServing: false,
        ),
      );
    });

    test('none without nutrition values', () {
      final advice = _advice(_with(basis: null));
      expect(advice.portion, isNull);
      expect(advice.shares, isEmpty);
    });
  });

  group('shares', () {
    test('per serving, against the personal needs', () {
      final advice = _advice(_biscuit, profile: _profile());
      expect(advice.basis, NeedsBasis.personal);
      // 1980 × 21.7 / 10029 = 4.28; 23 × 21.7 / 95 = 5.25; 10.9 × 21.7 / 27
      // = 8.76; 23 × 21.7 / 90 = 5.55; 0.30775 × 21.7 / 5 = 1.34.
      expect(_percents(advice), {
        Nutrient.energy: '4',
        Nutrient.fat: '5',
        Nutrient.saturates: '9',
        Nutrient.sugars: '6',
        Nutrient.salt: '1',
      });
    });

    test('without a profile, against the EU reference intakes', () {
      final advice = _advice(_biscuit);
      expect((advice.basis, advice.hasProfile), (NeedsBasis.reference, false));
      // 1980 × 21.7 / 8400 = 5.12; 0.30775 × 21.7 / 6 = 1.11.
      expect(_percents(advice)[Nutrient.energy], '5');
      expect(_percents(advice)[Nutrient.salt], '1');
    });

    test('rounded half up; above 0 but rounding to 0 is "< 1 %"', () {
      final advice = _advice(
        _with(
          servingQuantity: null,
          per100: {
            Nutrient.salt: 0.03, // 0.03 × 100 / 6 = 0.5: rounds up to 1
            Nutrient.sugars: 0.4, // 0.4 × 100 / 90 = 0.44: "< 1"
            Nutrient.fat: 0, // 0: 0 %
          },
        ),
      );
      expect(_percents(advice), {
        Nutrient.fat: '0',
        Nutrient.sugars: '<1',
        Nutrient.salt: '1',
      });
    });

    test('a nutrient not declared is left out', () {
      final advice = _advice(_with(per100: {Nutrient.energy: 400}));
      expect(advice.shares.map((s) => s.nutrient), [Nutrient.energy]);
    });
  });

  group('allergens', () {
    test('contains, then may contain, in Annex II order', () {
      final advice = _advice(
        _biscuit,
        profile: _profile(
          allergens: {Allergen.nuts, Allergen.milk, Allergen.fish},
        ),
      );
      expect(advice.notes.whereType<AllergenContains>(), [
        const AllergenContains(Allergen.milk),
      ]);
      expect(advice.notes.whereType<AllergenMayContain>(), [
        const AllergenMayContain(Allergen.nuts),
      ]);
    });

    test('contains wins over may contain', () {
      final advice = _advice(
        _with(allergens: {Allergen.milk}, traces: {Allergen.milk}),
        profile: _profile(allergens: {Allergen.milk}),
      );
      expect(advice.notes, [const AllergenContains(Allergen.milk)]);
    });

    test('none listed: said only to someone with allergies', () {
      expect(
        _advice(_with(), profile: _profile(allergens: {Allergen.eggs})).notes,
        [const AllergensNoneListed()],
      );
      expect(_advice(_with(), profile: _profile()).notes, isEmpty);
    });

    test('not known yet: nothing said', () {
      expect(
        _advice(
          _with(allergens: null, traces: null),
          profile: _profile(allergens: {Allergen.eggs}),
        ).notes,
        isEmpty,
      );
    });
  });

  group('additives', () {
    test('avoided first, then EFSA high and moderate flags', () {
      final advice = _advice(_biscuit, avoided: {'E330', 'E999'});
      expect(advice.notes, [
        const AdditiveAvoided('E330', 'Citric acid'),
        const AdditiveRiskNote('E450', 'Diphosphates', high: true),
        const AdditiveRiskNote('E338', null, high: false),
      ]);
    });

    test('allergen notes come before additive notes', () {
      final advice = _advice(
        _biscuit,
        profile: _profile(allergens: {Allergen.milk}),
        avoided: {'E330'},
      );
      expect(advice.notes.first, const AllergenContains(Allergen.milk));
    });
  });
}
