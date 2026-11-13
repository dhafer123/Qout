/// User-facing wording for product data (English for now).
library;

import 'package:flutter/material.dart';
import 'package:qout/core/api/qout_api.dart';

/// Score components (breakdown keys).
String componentLabel(String name) => switch (name) {
  'energy' => 'Energy',
  'energy_from_saturates' => 'Energy from saturated fat',
  'sugars' => 'Sugars',
  'saturated_fat' => 'Saturated fat',
  'saturated_fat_ratio' => 'Saturated fat share of total fat',
  'salt' => 'Salt',
  'non_nutritive_sweeteners' => 'Sweeteners',
  'protein' => 'Protein',
  'fibre' => 'Fibre',
  'fvl' => 'Fruit, vegetables, legumes',
  _ => _humanize(name),
};

/// Scoring inputs (spec names), as used in "missing: ...".
String inputLabel(String field) => switch (field) {
  'energy_kj' => 'energy',
  'sugars_g' => 'sugars',
  'saturated_fat_g' => 'saturated fat',
  'total_fat_g' => 'total fat',
  'salt_g' => 'salt',
  'fibre_g' => 'fibre',
  'protein_g' => 'protein',
  'fvl_percent' => 'fruit, vegetable and legume content',
  'non_nutritive_sweeteners' => 'whether it contains sweeteners',
  _ => _humanize(field),
};

/// NOVA groups (docs/specs/README.md, "NOVA").
String? novaLabel(int? group) => switch (group) {
  1 => 'Unprocessed or minimally processed foods',
  2 => 'Processed culinary ingredients',
  3 => 'Processed foods',
  4 => 'Ultra-processed foods',
  _ => null,
};

/// EFSA overexposure risk. "Unknown" means the source has no flag: not
/// evaluated, which is not the same as safe.
String riskLabel(OverexposureRisk risk) => switch (risk) {
  OverexposureRisk.high =>
    'High risk of exceeding the acceptable daily intake (EFSA)',
  OverexposureRisk.moderate =>
    'Moderate risk of exceeding the acceptable daily intake (EFSA)',
  OverexposureRisk.none =>
    'No risk of exceeding the acceptable daily intake found (EFSA)',
  OverexposureRisk.unknown || OverexposureRisk.unrecognized => 'Not evaluated',
};

String sourceLabel(DataSource source) => switch (source) {
  DataSource.openFoodFacts => 'Open Food Facts',
  DataSource.contribution => 'Qout contributors',
  DataSource.manual => 'Qout',
  DataSource.unrecognized => 'Other',
};

String statusLabel(ProductStatus status) => switch (status) {
  ProductStatus.verified => 'Verified',
  _ => 'Not verified yet',
};

/// [value] with at most [decimals] decimals, trailing zeros removed.
String formatAmount(double value, {int decimals = 2}) {
  final fixed = value.toStringAsFixed(decimals);
  if (!fixed.contains('.')) return fixed;
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// kJ per kcal for showing energy (docs/specs/README.md, "Display only");
/// never used for scoring.
const kjPerKcalForDisplay = 4.184;

/// Energy as declared in kJ, with kcal next to it: `2056 kJ / 491 kcal`.
String formatEnergy(double kj) =>
    '${formatAmount(kj, decimals: 0)} kJ / '
    '${formatAmount(kj / kjPerKcalForDisplay, decimals: 0)} kcal';

/// A date and time in the phone's locale and time zone.
String formatDateTime(BuildContext context, DateTime time) {
  final local = time.toLocal();
  final l10n = MaterialLocalizations.of(context);
  return '${l10n.formatShortDate(local)}, '
      '${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

/// A date in the phone's locale and time zone.
String formatDate(BuildContext context, DateTime time) =>
    MaterialLocalizations.of(context).formatShortDate(time.toLocal());

String _humanize(String name) {
  final words = name.replaceAll('_', ' ').trim();
  if (words.isEmpty) return name;
  return words[0].toUpperCase() + words.substring(1);
}
