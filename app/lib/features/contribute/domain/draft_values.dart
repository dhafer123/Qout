/// Reading, checking and converting the amounts of a [ContributionDraft].
///
/// The checks mirror the backend's request limits and the label parser's
/// heuristics (docs/specs/README.md): amounts per 100 g are at most 100 g,
/// saturates at most the fat, the share of fruit, vegetables and legumes at
/// most 100 %. The values printed on every label must be filled in to send.
library;

import 'package:qout/core/api/qout_api.dart' as api;
import 'package:qout/features/contribute/domain/contribution_draft.dart';
import 'package:qout/scoring/scoring.dart';

/// Why a draft can't be sent, per field.
enum ValueProblem {
  notANumber,
  over100Grams,
  over100Percent,
  saturatesOverFat,
  required,
}

final _number = RegExp(r'^\d+([.,]\d+)?$');

/// The amount typed in [text] (`12`, `0,5`, `1.25`); null when blank.
/// Throws [FormatException] for anything else, including digits too many
/// for a number.
double? parseAmount(String? text) {
  final trimmed = text?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  final amount = _number.hasMatch(trimmed)
      ? double.parse(trimmed.replaceAll(',', '.'))
      : double.nan;
  if (!amount.isFinite) throw FormatException('not an amount', trimmed);
  return amount;
}

/// What is wrong with each field of [draft]. With [requireMandatory], empty
/// mandatory fields are reported too (when sending).
Map<NutrientField, ValueProblem> problems(
  ContributionDraft draft, {
  bool requireMandatory = false,
}) {
  final found = <NutrientField, ValueProblem>{};
  final amounts = <NutrientField, double>{};
  for (final field in NutrientField.values) {
    final double? amount;
    try {
      amount = parseAmount(draft.values[field]);
    } on FormatException {
      found[field] = ValueProblem.notANumber;
      continue;
    }
    if (amount == null) {
      if (requireMandatory && field.mandatory) {
        found[field] = ValueProblem.required;
      }
      continue;
    }
    if (field.grams && amount > 100) {
      found[field] = ValueProblem.over100Grams;
    } else if (field == NutrientField.fvl && amount > 100) {
      found[field] = ValueProblem.over100Percent;
    } else {
      amounts[field] = amount;
    }
  }
  final fat = amounts[NutrientField.totalFat];
  final saturates = amounts[NutrientField.saturatedFat];
  if (fat != null && saturates != null && saturates > fat) {
    found[NutrientField.saturatedFat] = ValueProblem.saturatesOverFat;
  }
  return found;
}

/// The energy in kJ, converted from kcal when typed in kcal.
double? energyKj(ContributionDraft draft) {
  final typed = parseAmount(draft.values[NutrientField.energy]);
  if (typed == null || draft.energyUnit == EnergyUnit.kj) return typed;
  return kjFromKcal(typed).toDouble();
}

/// The engine's input. Throws [FormatException] or [ArgumentError] when a
/// value is invalid (check [problems] first).
NutritionInput nutritionInput(ContributionDraft draft) {
  double? amount(NutrientField field) => parseAmount(draft.values[field]);
  return NutritionInput(
    energyKj: energyKj(draft),
    sugarsG: amount(NutrientField.sugars),
    saturatedFatG: amount(NutrientField.saturatedFat),
    totalFatG: amount(NutrientField.totalFat),
    saltG: amount(NutrientField.salt),
    fibreG: amount(NutrientField.fibre),
    proteinG: amount(NutrientField.protein),
    fvlPercent: amount(NutrientField.fvl),
    nonNutritiveSweeteners: draft.category == Category.beverage
        ? draft.sweeteners
        : null,
  );
}

/// The grade the Dart engine gives the values as they stand: unverified (a
/// moderator checks them against the photos). Null while a value is invalid.
ScoreResult? provisionalScore(ContributionDraft draft) {
  if (problems(draft).isNotEmpty) return null;
  return score(draft.category, nutritionInput(draft));
}

/// The values as the backend takes them (`ContributionCreate.nutrition`).
api.NutritionValues nutritionValues(ContributionDraft draft) {
  final input = nutritionInput(draft);
  return api.NutritionValues(
    energyKj: input.energyKj,
    sugarsG: input.sugarsG,
    saturatedFatG: input.saturatedFatG,
    totalFatG: input.totalFatG,
    saltG: input.saltG,
    fibreG: input.fibreG,
    proteinG: input.proteinG,
    fvlPercent: input.fvlPercent,
    nonNutritiveSweeteners: input.nonNutritiveSweeteners,
  );
}

/// [draft] with the values a label parser read ([reading]): what it found
/// replaces the form's values, the fields it flagged are marked, and
/// `parserUsed` records which parser it was. Energy is shown in the unit the
/// label printed (kcal when kJ was only derived from it).
ContributionDraft fillFromReading(
  ContributionDraft draft,
  api.LabelReading reading,
) {
  final read = reading.valuesValue;
  final kjDerived = reading.derived.contains('energy_kj');
  final useKcal =
      read.energyKcal != null && (read.energyKj == null || kjDerived);
  final values = <NutrientField, String>{
    if (useKcal)
      NutrientField.energy: amountText(read.energyKcal!)
    else if (read.energyKj != null)
      NutrientField.energy: amountText(read.energyKj!),
    for (final (field, amount) in [
      (NutrientField.totalFat, read.totalFatG),
      (NutrientField.saturatedFat, read.saturatedFatG),
      (NutrientField.sugars, read.sugarsG),
      (NutrientField.fibre, read.fibreG),
      (NutrientField.protein, read.proteinG),
      (NutrientField.salt, read.saltG),
    ])
      if (amount != null) field: amountText(amount),
  };
  final flagged = {
    for (final issue in reading.issues)
      if (issue.blocking) ?_issueField(issue.field),
  };
  return draft.copyWith(
    values: {
      // Keep what the parser can't read (the fruit, vegetable, legume share).
      NutrientField.fvl: ?draft.values[NutrientField.fvl],
      ...values,
    },
    energyUnit: useKcal ? EnergyUnit.kcal : EnergyUnit.kj,
    basis: switch (reading.basis) {
      api.NutritionBasis.per100g ||
      api.NutritionBasis.per100ml => reading.basis!,
      _ => draft.basis,
    },
    flagged: flagged,
    parserUsed: reading.parserUsed == api.ParserUsed.llm
        ? api.ParserUsed.llm
        : api.ParserUsed.rules,
    edited: false,
    revision: draft.revision + 1,
  );
}

/// An amount without trailing zeros: `12`, `0.5`, `1.25`.
String amountText(double amount) => amount == amount.roundToDouble()
    ? amount.toStringAsFixed(0)
    : amount.toString();

NutrientField? _issueField(String? field) => switch (field) {
  'energy_kj' || 'energy_kcal' => NutrientField.energy,
  'total_fat_g' => NutrientField.totalFat,
  'saturated_fat_g' => NutrientField.saturatedFat,
  'sugars_g' => NutrientField.sugars,
  'fibre_g' => NutrientField.fibre,
  'protein_g' => NutrientField.protein,
  'salt_g' || 'sodium_g' => NutrientField.salt,
  _ => null,
};
