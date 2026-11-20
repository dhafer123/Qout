import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/api/qout_api.dart' show ProductDetail;
import 'package:qout/features/product/domain/product_facts.dart';
import 'package:qout/features/product/presentation/product_labels.dart'
    show formatAmount;
import 'package:qout/features/product/presentation/product_sections.dart';
import 'package:qout/features/profile/data/profile_repository.dart';
import 'package:qout/health/advice.dart';
import 'package:qout/health/needs.dart';
import 'package:qout/health/profile.dart';

/// "For you" (T40): the user's allergens and avoided additives in this
/// product, EFSA's additive flags, and what a portion gives against the
/// daily amounts. Every sentence comes from the table in
/// `docs/specs/README.md` ("Advice texts").
class ForYouSection extends ConsumerWidget {
  const ForYouSection({required this.product, super.key});

  final ProductDetail product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // While the phone's profile loads (a moment), nothing; if it can't be
    // read, advice as without a profile.
    final profile = ref.watch(profileProvider);
    if (profile.isLoading) return const SizedBox.shrink();
    final mine = profile.valueOrNull;
    final avoided = ref.watch(avoidedAdditivesProvider).valueOrNull ?? const {};
    final advice = adviceFor(
      productFacts(product),
      profile: mine,
      needs: computeNeeds(mine),
      avoided: avoided,
    );
    final textTheme = Theme.of(context).textTheme;
    return ProductSection(
      title: 'For you',
      icon: PhosphorIconsRegular.heartbeat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final note in advice.notes) _NoteRow(note),
          if (advice.portion case final portion?)
            _Shares(
              portion: portion,
              shares: advice.shares,
              personal: advice.basis == NeedsBasis.personal,
              servingWords: portion.isServing ? product.serving?.size : null,
            )
          else
            const _Line("No nutrition values yet, so shares can't be shown."),
          if (!advice.hasProfile)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set up your profile to compare with your own needs.',
                  ),
                  TextButton.icon(
                    onPressed: () => context.push(AppRoutes.profileEdit),
                    icon: const Icon(PhosphorIconsRegular.userPlus, size: 20),
                    label: const Text('Set up my profile'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'General information, not medical advice.',
              style: textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// An allergen in a sentence: lower case, as the label lists it.
String allergenInSentence(Allergen allergen) => switch (allergen) {
  Allergen.gluten => 'gluten',
  Allergen.crustaceans => 'crustaceans',
  Allergen.eggs => 'eggs',
  Allergen.fish => 'fish',
  Allergen.peanuts => 'peanuts',
  Allergen.soybeans => 'soy',
  Allergen.milk => 'milk',
  Allergen.nuts => 'nuts',
  Allergen.celery => 'celery',
  Allergen.mustard => 'mustard',
  Allergen.sesame => 'sesame',
  Allergen.sulphites => 'sulphites',
  Allergen.lupin => 'lupin',
  Allergen.molluscs => 'molluscs',
};

/// The sentence for [note] (`docs/specs/README.md`, "Advice texts").
String adviceText(AdviceNote note) {
  String additive(String code, String? name) =>
      name == null ? code : '$code $name';
  return switch (note) {
    AllergenContains(:final allergen) =>
      'Contains ${allergenInSentence(allergen)}, which you listed as an '
          'allergy.',
    AllergenMayContain(:final allergen) =>
      'May contain traces of ${allergenInSentence(allergen)}, which you '
          'listed as an allergy.',
    AllergensNoneListed() =>
      'Open Food Facts lists no allergens for this product. Check the label.',
    AdditiveAvoided(:final code, :final name) =>
      'Contains ${additive(code, name)}, which you chose to avoid.',
    AdditiveRiskNote(:final code, :final name, :final high) =>
      '${additive(code, name)}: EFSA found a ${high ? 'high' : 'moderate'} '
          'risk that some people take in more than the acceptable daily '
          'intake.',
  };
}

class _NoteRow extends StatelessWidget {
  const _NoteRow(this.note);

  final AdviceNote note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = QoutPalette.of(context);
    final (icon, color) = switch (note) {
      AllergenContains() => (PhosphorIconsFill.warningOctagon, scheme.error),
      AllergenMayContain() => (PhosphorIconsRegular.warning, palette.doubt),
      AllergensNoneListed() => (PhosphorIconsRegular.info, palette.muted),
      AdditiveAvoided() => (PhosphorIconsRegular.prohibit, scheme.error),
      AdditiveRiskNote(:final high) => (
        PhosphorIconsRegular.warning,
        high ? scheme.error : palette.doubt,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 20, color: color)),
          const SizedBox(width: 12),
          Expanded(child: Text(adviceText(note))),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
    child: Text(text),
  );
}

String _nutrientLabel(Nutrient nutrient) => switch (nutrient) {
  Nutrient.energy => 'Energy',
  Nutrient.fat => 'Fat',
  Nutrient.saturates => 'Saturated fat',
  Nutrient.sugars => 'Sugars',
  Nutrient.salt => 'Salt',
};

/// "1 serving (21.7 g)", or "100 g" / "100 mL".
String portionLabel(Portion portion) {
  final unit = portion.unit == PortionUnit.gram ? 'g' : 'mL';
  return portion.isServing
      ? '1 serving (${formatAmount(portion.amount)} $unit)'
      : '100 $unit';
}

String shareText(Share share) =>
    share.lessThanOne ? '< 1 %' : '${share.percent} %';

class _Shares extends StatelessWidget {
  const _Shares({
    required this.portion,
    required this.shares,
    required this.personal,
    required this.servingWords,
  });

  final Portion portion;
  final List<Share> shares;
  final bool personal;

  /// The label's own words for the serving, when the serving is used.
  final String? servingWords;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    final portionText = portionLabel(portion);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Text(
            personal
                ? '$portionText gives this share of your daily needs:'
                : '$portionText gives this share of the reference intake '
                      'for an average adult:',
            style: textTheme.titleSmall,
          ),
        ),
        if (servingWords case final words?)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('On the label: $words', style: textTheme.bodySmall),
          ),
        for (final share in shares)
          MergeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(_nutrientLabel(share.nutrient)),
                  ),
                  Expanded(
                    flex: 4,
                    child: ExcludeSemantics(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (share.percent / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                          color: palette.accent,
                          backgroundColor: palette.track,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 48),
                    child: Text(
                      shareText(share),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
