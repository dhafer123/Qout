/// The "For you" advice on a product (T40): which of the fixed sentences in
/// `docs/specs/README.md` ("Advice texts") apply, and the shares of the daily
/// amounts. Pure Dart, no Flutter imports: the product screen maps the API's
/// product into [ProductFacts].
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qout/health/needs.dart';
import 'package:qout/health/profile.dart';
import 'package:qout/scoring/exact_decimal.dart';

part 'advice.freezed.dart';

/// Unit of the nutrition basis and of a serving.
enum PortionUnit { gram, millilitre }

/// EFSA overexposure risk flag of an additive (T10).
enum AdditiveRisk { high, moderate, none, unknown }

/// The nutrients compared with the daily amounts, in display order.
enum Nutrient { energy, fat, saturates, sugars, salt }

@immutable
class AdditiveFact {
  const AdditiveFact({required this.code, required this.risk, this.name});

  final String code;
  final String? name;
  final AdditiveRisk risk;
}

/// What the advice needs from a product.
@immutable
class ProductFacts {
  const ProductFacts({
    required this.additives,
    this.basis,
    this.per100 = const {},
    this.servingQuantity,
    this.servingUnit,
    this.allergens,
    this.traces,
  });

  /// Unit of [per100] (per 100 g or 100 mL); null: no nutrition values.
  final PortionUnit? basis;

  /// Declared amounts per 100 g or 100 mL (energy in kJ, the rest in g);
  /// a nutrient not declared is absent.
  final Map<Nutrient, double> per100;

  final double? servingQuantity;
  final PortionUnit? servingUnit;

  /// Annex II allergens it contains / may contain; null: not known.
  final Set<Allergen>? allergens;
  final Set<Allergen>? traces;

  final List<AdditiveFact> additives;
}

/// The amount the shares are for: one serving, or 100 g / 100 mL.
@freezed
abstract class Portion with _$Portion {
  const factory Portion({
    required double amount,
    required PortionUnit unit,
    required bool isServing,
  }) = _Portion;
}

/// One share of a daily amount, as a whole percent (`lessThanOne`: above 0
/// but rounding to 0, shown "< 1 %").
@freezed
abstract class Share with _$Share {
  const factory Share({
    required Nutrient nutrient,
    required int percent,
    required bool lessThanOne,
  }) = _Share;
}

/// One sentence of the advice table (`docs/specs/README.md`).
@freezed
sealed class AdviceNote with _$AdviceNote {
  /// `allergen_contains`
  const factory AdviceNote.allergenContains(Allergen allergen) =
      AllergenContains;

  /// `allergen_may_contain`
  const factory AdviceNote.allergenMayContain(Allergen allergen) =
      AllergenMayContain;

  /// `allergens_none_listed`
  const factory AdviceNote.allergensNoneListed() = AllergensNoneListed;

  /// `additive_avoided`
  const factory AdviceNote.additiveAvoided(String code, String? name) =
      AdditiveAvoided;

  /// `additive_high_risk` / `additive_moderate_risk`
  const factory AdviceNote.additiveRisk(
    String code,
    String? name, {
    required bool high,
  }) = AdditiveRiskNote;
}

@freezed
abstract class ForYou with _$ForYou {
  const factory ForYou({
    /// Allergen notes first, then additive notes.
    required List<AdviceNote> notes,

    /// Null without nutrition values (`no_nutrition`).
    required Portion? portion,
    required List<Share> shares,

    /// `shares_personal` or `shares_reference`.
    required NeedsBasis basis,

    /// False: `set_up_profile` is shown.
    required bool hasProfile,
  }) = _ForYou;
}

/// Largest serving used (g or mL): the backend's data check (decision in
/// `docs/specs/README.md`, "Serving").
const maxServing = 1000;

/// The advice for [product], given the user's [profile] (null: none), the
/// [needs] computed from it and the additive codes they [avoided].
ForYou adviceFor(
  ProductFacts product, {
  required Profile? profile,
  required DailyNeeds needs,
  Set<String> avoided = const {},
}) {
  final portion = portionOf(product);
  return ForYou(
    notes: [
      ..._allergenNotes(product, profile?.allergens ?? const {}),
      ..._additiveNotes(product.additives, avoided),
    ],
    portion: portion,
    shares: portion == null ? const [] : _shares(product, portion, needs),
    basis: needs.basis,
    hasProfile: profile != null,
  );
}

/// The serving when it can be trusted for shares (its unit matches the
/// basis and its amount is above 0 and at most [maxServing]), else 100 g or
/// 100 mL; null without nutrition values.
Portion? portionOf(ProductFacts product) {
  final basis = product.basis;
  if (basis == null) return null;
  final quantity = product.servingQuantity;
  if (quantity != null &&
      product.servingUnit == basis &&
      quantity > 0 &&
      quantity <= maxServing) {
    return Portion(amount: quantity, unit: basis, isServing: true);
  }
  return Portion(amount: 100, unit: basis, isServing: false);
}

List<AdviceNote> _allergenNotes(ProductFacts product, Set<Allergen> mine) {
  if (mine.isEmpty) return const [];
  final contains = product.allergens;
  if (contains == null) return const []; // not known yet: nothing to say
  final traces = product.traces ?? const {};
  return [
    for (final allergen in Allergen.values)
      if (mine.contains(allergen) && contains.contains(allergen))
        AdviceNote.allergenContains(allergen)
      else if (mine.contains(allergen) && traces.contains(allergen))
        AdviceNote.allergenMayContain(allergen),
    if (contains.isEmpty) const AdviceNote.allergensNoneListed(),
  ];
}

List<AdviceNote> _additiveNotes(
  List<AdditiveFact> additives,
  Set<String> avoided,
) => [
  for (final additive in additives)
    if (avoided.contains(additive.code))
      AdviceNote.additiveAvoided(additive.code, additive.name),
  for (final additive in additives)
    if (additive.risk case AdditiveRisk.high || AdditiveRisk.moderate)
      AdviceNote.additiveRisk(
        additive.code,
        additive.name,
        high: additive.risk == AdditiveRisk.high,
      ),
];

List<Share> _shares(ProductFacts product, Portion portion, DailyNeeds needs) {
  final daily = {
    Nutrient.energy: needs.energyKj,
    Nutrient.fat: needs.fatG,
    Nutrient.saturates: needs.saturatesG,
    Nutrient.sugars: needs.sugarsG,
    Nutrient.salt: needs.saltG,
  };
  final amount = ExactDecimal.fromDouble(portion.amount);
  return [
    for (final nutrient in Nutrient.values)
      if (product.per100[nutrient] case final per100?)
        _share(
          nutrient,
          ExactDecimal.fromDouble(per100) * amount,
          daily[nutrient]!,
        ),
  ];
}

/// per100 × portion / 100 as a percent of [daily]: per100 × portion / daily,
/// rounded half up to a whole percent.
Share _share(Nutrient nutrient, ExactDecimal per100TimesPortion, int daily) {
  final percent = per100TimesPortion.divideRoundHalfAwayFromZero(
    ExactDecimal.fromInt(daily),
  );
  return Share(
    nutrient: nutrient,
    percent: percent,
    lessThanOne: percent == 0 && !per100TimesPortion.isZero,
  );
}
