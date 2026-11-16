import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/qout_api.dart' as api;
import 'package:qout/features/contribute/domain/contribution_draft.dart';
import 'package:qout/features/contribute/domain/draft_values.dart';
import 'package:qout/scoring/scoring.dart';

import '../../../helpers/fake_contribution.dart';

ContributionDraft _draft([Map<NutrientField, String> values = const {}]) =>
    ContributionDraft(ean: '6191234567897', clientId: 'id', values: values);

/// The values of `label-parse-ok.json`, as typed.
const Map<NutrientField, String> _clean = {
  NutrientField.energy: '1046',
  NutrientField.totalFat: '9,5',
  NutrientField.saturatedFat: '3.2',
  NutrientField.sugars: '12',
  NutrientField.fibre: '2,1',
  NutrientField.protein: '7.4',
  NutrientField.salt: '0,85',
};

void main() {
  group('parseAmount', () {
    test('reads a decimal point or comma; blank is null', () {
      expect(parseAmount('12'), 12);
      expect(parseAmount(' 0,5 '), 0.5);
      expect(parseAmount('1.25'), 1.25);
      expect(parseAmount(''), isNull);
      expect(parseAmount('  '), isNull);
      expect(parseAmount(null), isNull);
    });

    test('rejects anything else', () {
      for (final text in ['-1', '1.2.3', ',5', '5,', '1e3', 'abc', '1 2']) {
        expect(() => parseAmount(text), throwsFormatException, reason: text);
      }
    });

    test('rejects digits too many for a number', () {
      expect(() => parseAmount('9' * 400), throwsFormatException);
    });
  });

  group('problems', () {
    test('none for complete, plausible values', () {
      expect(problems(_draft(_clean), requireMandatory: true), isEmpty);
    });

    test('empty mandatory fields only when sending', () {
      final draft = _draft();
      expect(problems(draft), isEmpty);
      expect(problems(draft, requireMandatory: true), {
        for (final field in NutrientField.values)
          if (field.mandatory) field: ValueProblem.required,
      });
      // Fibre and the fruit, vegetable and legume share are optional.
      expect(NutrientField.fibre.mandatory, isFalse);
      expect(NutrientField.fvl.mandatory, isFalse);
    });

    test('not a number', () {
      final draft = _draft({..._clean, NutrientField.sugars: '1.2.3'});
      expect(problems(draft), {NutrientField.sugars: ValueProblem.notANumber});
    });

    test('grams at most 100; energy is not in grams', () {
      final draft = _draft({
        ..._clean,
        NutrientField.energy: '2500',
        NutrientField.protein: '100',
        NutrientField.salt: '100.5',
      });
      expect(problems(draft), {NutrientField.salt: ValueProblem.over100Grams});
    });

    test('the fruit, vegetable and legume share at most 100 %', () {
      expect(problems(_draft({NutrientField.fvl: '100'})), isEmpty);
      expect(problems(_draft({NutrientField.fvl: '101'})), {
        NutrientField.fvl: ValueProblem.over100Percent,
      });
    });

    test('saturates at most the fat', () {
      final equal = _draft({
        NutrientField.totalFat: '3',
        NutrientField.saturatedFat: '3,0',
      });
      expect(problems(equal), isEmpty);
      final more = _draft({
        NutrientField.totalFat: '3',
        NutrientField.saturatedFat: '3.1',
      });
      expect(problems(more), {
        NutrientField.saturatedFat: ValueProblem.saturatesOverFat,
      });
    });

    test('no fat comparison when either is invalid', () {
      final draft = _draft({
        NutrientField.totalFat: '101',
        NutrientField.saturatedFat: '50',
      });
      expect(problems(draft), {
        NutrientField.totalFat: ValueProblem.over100Grams,
      });
    });
  });

  group('energy', () {
    test('kJ as typed', () {
      expect(energyKj(_draft(_clean)), 1046);
      expect(energyKj(_draft()), isNull);
    });

    test('kcal converted with the calculator factor', () {
      final draft =
          _draft(
            _clean,
          ).copyWith(
            values: {NutrientField.energy: '250'},
            energyUnit: EnergyUnit.kcal,
          );
      expect(energyKj(draft), kjFromKcal(250).toDouble());
    });
  });

  group('engine input and API values', () {
    test('every field in its place', () {
      final draft = _draft({..._clean, NutrientField.fvl: '40'});
      final input = nutritionInput(draft);
      expect(
        input,
        NutritionInput(
          energyKj: 1046,
          totalFatG: 9.5,
          saturatedFatG: 3.2,
          sugarsG: 12,
          fibreG: 2.1,
          proteinG: 7.4,
          saltG: 0.85,
          fvlPercent: 40,
        ),
      );
      final values = nutritionValues(draft);
      expect(values.energyKj, 1046);
      expect(values.totalFatG, 9.5);
      expect(values.saturatedFatG, 3.2);
      expect(values.sugarsG, 12);
      expect(values.fibreG, 2.1);
      expect(values.proteinG, 7.4);
      expect(values.saltG, 0.85);
      expect(values.fvlPercent, 40);
      expect(values.nonNutritiveSweeteners, isNull);
    });

    test('sweeteners only for drinks', () {
      final food = _draft(_clean).copyWith(sweeteners: true);
      expect(nutritionInput(food).nonNutritiveSweeteners, isNull);
      final drink = food.copyWith(category: Category.beverage);
      expect(nutritionInput(drink).nonNutritiveSweeteners, isTrue);
      expect(
        nutritionInput(
          drink.copyWith(sweeteners: false),
        ).nonNutritiveSweeteners,
        isFalse,
      );
    });
  });

  group('provisionalScore', () {
    test("is the engine's result for the values", () {
      final draft = _draft({..._clean, NutrientField.fvl: '0'});
      expect(
        provisionalScore(draft),
        score(Category.general, nutritionInput(draft)),
      );
      expect(provisionalScore(draft), isA<NutriScore>());
    });

    test('follows the category', () {
      final draft = _draft(_clean).copyWith(category: Category.cheese);
      expect(provisionalScore(draft)?.category, Category.cheese);
    });

    test('insufficient data while values are missing', () {
      expect(provisionalScore(_draft()), isA<InsufficientData>());
    });

    test('none while a value is invalid', () {
      expect(provisionalScore(_draft({NutrientField.salt: '120'})), isNull);
      expect(provisionalScore(_draft({NutrientField.salt: 'x'})), isNull);
    });
  });

  group('fillFromReading', () {
    test('a complete rules reading fills the values in kJ', () {
      final reading = recordedLabelParse('label-parse-ok');
      final draft = fillFromReading(
        _draft({NutrientField.fvl: '20', NutrientField.sugars: '99'}).copyWith(
          edited: true,
          revision: 3,
        ),
        _reading(reading),
      );
      expect(draft.values, {
        NutrientField.fvl: '20', // kept: no label shows it
        NutrientField.energy: '1046',
        NutrientField.totalFat: '9.5',
        NutrientField.saturatedFat: '3.2',
        NutrientField.sugars: '12',
        NutrientField.fibre: '2.1',
        NutrientField.protein: '7.4',
        NutrientField.salt: '0.85',
      });
      expect(draft.energyUnit, EnergyUnit.kj);
      expect(draft.basis, api.NutritionBasis.per100g);
      expect(draft.parserUsed, api.ParserUsed.rules);
      expect(draft.flagged, isEmpty);
      expect(draft.edited, isFalse);
      expect(draft.revision, 4);
    });

    test('a missing value is flagged and left empty', () {
      final draft = fillFromReading(
        _draft(),
        _reading(recordedLabelParse('label-parse-salt-missing')),
      );
      expect(draft.values.containsKey(NutrientField.salt), isFalse);
      expect(draft.flagged, {NutrientField.salt});
    });

    test('an LLM reading is recorded as such', () {
      final result = recordedFallback('label-fallback-done').result!;
      expect(fillFromReading(_draft(), result).parserUsed, api.ParserUsed.llm);
    });

    test('kcal shown when kJ was only derived from it', () {
      const reading = api.LabelReading(
        parserUsed: api.ParserUsed.rules,
        ok: true,
        basis: api.NutritionBasis.per100ml,
        valuesValue: api.LabelValues(energyKj: 176, energyKcal: 42),
        derived: ['energy_kj'],
        approximate: [],
        issues: [
          api.LabelIssueRead(code: 'x', field: 'sodium_g', blocking: true),
          api.LabelIssueRead(code: 'y', field: 'sugars_g', blocking: false),
          api.LabelIssueRead(code: 'z', blocking: true),
        ],
      );
      final draft = fillFromReading(_draft(), reading);
      expect(draft.values, {NutrientField.energy: '42'});
      expect(draft.energyUnit, EnergyUnit.kcal);
      expect(draft.basis, api.NutritionBasis.per100ml);
      expect(draft.flagged, {NutrientField.salt});
    });

    test('kcal shown when only kcal was printed', () {
      const reading = api.LabelReading(
        parserUsed: api.ParserUsed.rules,
        ok: false,
        valuesValue: api.LabelValues(energyKcal: 42),
        derived: [],
        approximate: [],
        issues: [],
      );
      final draft = fillFromReading(
        _draft().copyWith(basis: api.NutritionBasis.per100ml),
        reading,
      );
      expect(draft.energyUnit, EnergyUnit.kcal);
      // No basis read: the contributor's choice stays.
      expect(draft.basis, api.NutritionBasis.per100ml);
    });

    test('every issue field maps to its form field', () {
      final fields = {
        'energy_kj': NutrientField.energy,
        'energy_kcal': NutrientField.energy,
        'total_fat_g': NutrientField.totalFat,
        'saturated_fat_g': NutrientField.saturatedFat,
        'sugars_g': NutrientField.sugars,
        'fibre_g': NutrientField.fibre,
        'protein_g': NutrientField.protein,
        'salt_g': NutrientField.salt,
        'sodium_g': NutrientField.salt,
        'carbohydrates_g': null,
      };
      for (final MapEntry(key: name, value: field) in fields.entries) {
        final reading = api.LabelReading(
          parserUsed: api.ParserUsed.rules,
          ok: false,
          valuesValue: const api.LabelValues(),
          derived: const [],
          approximate: const [],
          issues: [
            api.LabelIssueRead(code: 'missing', field: name, blocking: true),
          ],
        );
        expect(
          fillFromReading(_draft(), reading).flagged,
          {?field},
          reason: name,
        );
      }
    });
  });

  test('amountText drops trailing zeros', () {
    expect(amountText(12), '12');
    expect(amountText(0.5), '0.5');
    expect(amountText(1.25), '1.25');
    expect(amountText(0), '0');
  });

  test('newContributionId is a version 4 UUID', () {
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    for (var seed = 0; seed < 50; seed++) {
      expect(newContributionId(Random(seed)), matches(pattern));
    }
    expect(newContributionId(), isNot(newContributionId()));
  });
}

api.LabelReading _reading(api.LabelParseResult result) => api.LabelReading(
  parserUsed: result.parserUsed,
  ok: result.ok,
  basis: result.basis,
  valuesValue: result.valuesValue,
  derived: result.derived,
  approximate: result.approximate,
  issues: result.issues,
);
