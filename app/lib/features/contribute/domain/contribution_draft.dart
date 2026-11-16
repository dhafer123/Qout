import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qout/core/api/qout_api.dart'
    show NutritionBasis, ParserUsed, PhotoKind;
import 'package:qout/scoring/scoring.dart' show Category;

part 'contribution_draft.freezed.dart';

/// The values the contributor reviews, in the order of a label. Carbohydrate
/// is not asked: the score doesn't use it and the backend doesn't store it.
enum NutrientField {
  energy('energy_kj'),
  totalFat('total_fat_g'),
  saturatedFat('saturated_fat_g'),
  sugars('sugars_g'),
  fibre('fibre_g'),
  protein('protein_g'),
  salt('salt_g'),
  fvl('fvl_percent')
  ;

  const NutrientField(this.key);

  /// The field's name in the API (`NutritionValues`) and the engine.
  final String key;

  /// Printed on every label (Regulation (EU) 1169/2011, Article 30), so it
  /// must be filled in before sending. Fibre and the fruit, vegetable and
  /// legume share are often missing from labels.
  bool get mandatory => switch (this) {
    fibre || fvl => false,
    _ => true,
  };

  /// Amounts in grams (per 100 g or 100 mL), at most 100.
  bool get grams => this != energy && this != fvl;
}

/// How the contributor types the energy; kcal is converted to kJ (the
/// calculator's factor, `kjFromKcal`) for the score and the backend.
enum EnergyUnit { kj, kcal }

/// A product being added, as the contributor builds it. Amounts are kept as
/// typed (text) until sent; see `draft_values.dart`.
@freezed
abstract class ContributionDraft with _$ContributionDraft {
  const factory ContributionDraft({
    required String ean,

    /// The contribution's id, also in its photo keys: a resend is the same
    /// contribution.
    required String clientId,

    /// Photo kind -> file path on the phone.
    @Default(<PhotoKind, String>{}) Map<PhotoKind, String> photos,

    /// Photo kind -> text ML Kit read from it.
    @Default(<PhotoKind, String>{}) Map<PhotoKind, String> ocrText,
    @Default(Category.general) Category category,
    @Default(NutritionBasis.per100g) NutritionBasis basis,
    @Default('') String name,
    @Default('') String brand,

    /// Field -> amount as typed (decimal comma or point); missing or blank:
    /// not declared.
    @Default(<NutrientField, String>{}) Map<NutrientField, String> values,
    @Default(EnergyUnit.kj) EnergyUnit energyUnit,

    /// Beverages only: contains a non-nutritive sweetener.
    @Default(false) bool sweeteners,

    /// What filled in the values before the contributor reviewed them.
    @Default(ParserUsed.manual) ParserUsed parserUsed,

    /// Values the label parser flagged (missing, impossible, inconsistent):
    /// worth checking against the photo.
    @Default(<NutrientField>{}) Set<NutrientField> flagged,

    /// The contributor changed a value by hand.
    @Default(false) bool edited,

    /// Bumped when values are filled in by the app (a parser), so the form
    /// shows them instead of what it holds.
    @Default(0) int revision,
  }) = _ContributionDraft;
}

/// A random (version 4) UUID, the contribution's `client_id`.
String newContributionId([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = [for (var i = 0; i < 16; i++) source.nextInt(256)];
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')];
  return [
    hex.sublist(0, 4).join(),
    hex.sublist(4, 6).join(),
    hex.sublist(6, 8).join(),
    hex.sublist(8, 10).join(),
    hex.sublist(10).join(),
  ].join('-');
}
