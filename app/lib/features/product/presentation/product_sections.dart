import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/core/ui/fading_rule.dart';
import 'package:qout/core/ui/section_label.dart';
import 'package:qout/features/product/data/alternatives_repository.dart';
import 'package:qout/features/product/domain/score_explanation.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';
import 'package:qout/features/product/presentation/product_labels.dart';
import 'package:qout/features/profile/data/profile_repository.dart';

const _tabular = [FontFeature.tabularFigures()];

/// A titled section of the result screen: a fading rule above (unless
/// [first]), the title, then the content.
class ProductSection extends StatelessWidget {
  const ProductSection({
    required this.title,
    required this.child,
    this.first = false,
    super.key,
  });

  final String title;
  final Widget child;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!first)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: FadingRule(),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, first ? 26 : 22, 16, 8),
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        child,
      ],
    );
  }
}

/// Name, brand, barcode and whether the product is verified.
class ProductHeader extends StatelessWidget {
  const ProductHeader({required this.product, super.key});

  final ProductDetail product;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    final verified = product.status == ProductStatus.verified;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              product.name ?? 'Unnamed product',
              style: textTheme.titleLarge,
            ),
          ),
          if (product.brand case final brand?) ...[
            const SizedBox(height: 4),
            Text(
              brand,
              style: textTheme.bodyMedium?.copyWith(color: palette.muted),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Barcode ${product.ean}',
                style: textTheme.bodySmall?.copyWith(fontFeatures: _tabular),
              ),
              _StatusTag(verified: verified),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final palette = QoutPalette.of(context);
    final foreground = verified ? palette.onTag : palette.muted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: verified ? palette.tag : Colors.transparent,
        border: verified ? null : Border.all(color: palette.edge),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 3, 10, 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              verified
                  ? PhosphorIconsRegular.sealCheck
                  : PhosphorIconsRegular.hourglass,
              size: 15,
              color: foreground,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                verified ? 'Verified' : 'Not verified yet',
                style: TextStyle(fontSize: 12, height: 1.3, color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The grade, what the scale means, and where the grade sits on A to E.
class GradeCard extends StatelessWidget {
  const GradeCard({required this.explanation, super.key});

  final ScoreExplanation explanation;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final grade = explanation.displayGrade;
    final known = isKnownGrade(grade);
    final subtitle = switch (explanation) {
      InsufficientDataExplanation() => 'Not enough data to grade it.',
      NotScoredExplanation() => 'Its food category is not known yet.',
      _ when !known => 'This grade is not known to this version of the app.',
      _ => 'On a scale from A (best) to E (worst)',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GradeBadge(grade: grade),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          known ? 'Grade ${grade!.value}' : 'No grade',
                          style: textTheme.titleMedium?.copyWith(fontSize: 20),
                        ),
                        Text(subtitle, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              if (known) ...[
                const SizedBox(height: 14),
                GradeTrack(grade: grade),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Why this score".
class ScoreSection extends StatelessWidget {
  const ScoreSection({
    required this.explanation,
    required this.nutrition,
    super.key,
  });

  final ScoreExplanation explanation;

  /// For the amount under each component ("2056 kJ").
  final NutritionDetail? nutrition;

  @override
  Widget build(BuildContext context) {
    Widget text(String value) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(value),
    );
    return ProductSection(
      title: 'Why this score',
      child: switch (explanation) {
        final GradedExplanation graded => _GradedBreakdown(graded, nutrition),
        WaterExplanation() => text('Plain water is always graded A.'),
        GradeOnlyExplanation() => text(
          'The details of this score are not available in this version of '
          'the app.',
        ),
        InsufficientDataExplanation(:final missing) => text(
          'Not enough data to grade this product. Missing: '
          '${missing.map(inputLabel).join(', ')}.',
        ),
        NotScoredExplanation() => text(
          'This product cannot be graded yet: its food category is unknown.',
        ),
      },
    );
  }
}

/// Decision 8 (docs/specs/README.md): undeclared fibre counts as 0 points.
const _fibreAssumedZeroNote =
    'Fibre is not declared, so it counts as 0 points. The real grade can only '
    'be the same or better.';

class _GradedBreakdown extends StatelessWidget {
  const _GradedBreakdown(this.e, this.nutrition);

  final GradedExplanation e;
  final NutritionDetail? nutrition;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    final notes = [
      if (!e.proteinCounted)
        switch (e.proteinNLimit) {
          final limit? =>
            'Protein does not count here: with $limit or more negative '
                'points, only fibre and fruit, vegetables and legumes are '
                'subtracted.',
          null => 'Protein does not count for this product.',
        },
      if (e.assumedZero.contains('fibre_g')) _fibreAssumedZeroNote,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'Counts against it',
          trailing: '${e.negativeTotal} pts',
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        ),
        for (final c in e.negative)
          ComponentRow(
            component: c,
            amount: componentAmount(c.name, nutrition),
            color: palette.against,
          ),
        SectionLabel(
          'Counts in its favour',
          trailing: '${e.subtracted} pts',
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        ),
        for (final c in e.positive)
          ComponentRow(
            component: c,
            amount: componentAmount(c.name, nutrition),
            color: palette.inFavour,
            notCounted: c.name == 'protein' && !e.proteinCounted,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Semantics(
            label:
                'Total: ${e.negativeTotal} against minus ${e.subtracted} in '
                'favour makes ${e.score} points, grade ${e.grade.value}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${e.negativeTotal} against − ${e.subtracted} in favour',
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: palette.muted,
                        fontFeatures: _tabular,
                      ),
                    ),
                  ),
                  Text(
                    '${e.score} pts · ${e.grade.value}',
                    style: textTheme.titleSmall?.copyWith(
                      fontSize: 14,
                      fontFeatures: _tabular,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(note, style: textTheme.bodySmall),
          ),
      ],
    );
  }
}

/// The declared amount behind a score component, as shown under its name:
/// "2056 kJ", "24 g", "0 %", "Yes". Null when not declared or not a single
/// amount (e.g. the saturated fat share).
String? componentAmount(String name, NutritionDetail? n) {
  if (n == null) return null;
  String? grams(double? v) => v == null ? null : '${formatAmount(v)} g';
  return switch (name) {
    'energy' =>
      n.energyKj == null
          ? null
          : '${formatAmount(n.energyKj!, decimals: 0)} kJ',
    'sugars' => grams(n.sugarsG),
    'saturated_fat' => grams(n.saturatedFatG),
    'salt' => grams(n.saltG),
    'protein' => grams(n.proteinG),
    'fibre' => grams(n.fibreG),
    'fvl' =>
      n.fvlPercent == null
          ? null
          : '${formatAmount(n.fvlPercent!, decimals: 1)} %',
    'non_nutritive_sweeteners' => switch (n.nonNutritiveSweeteners) {
      true => 'Contains sweeteners',
      false => 'No sweeteners',
      null => null,
    },
    _ => null,
  };
}

/// One score component: name and amount, a bar of its points out of the
/// most it can take, and the points.
class ComponentRow extends StatelessWidget {
  const ComponentRow({
    required this.component,
    required this.color,
    this.amount,
    this.notCounted = false,
    super.key,
  });

  final ScoreComponent component;
  final String? amount;
  final Color color;
  final bool notCounted;

  /// Share of the bar filled: points out of the component's maximum.
  static double fill(ScoreComponent c) {
    final max = c.maxPoints;
    if (max == null || max <= 0) return 0;
    return (c.points / max).clamp(0, 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    final label = notCounted
        ? '${componentLabel(component.name)} (not counted)'
        : componentLabel(component.name);
    final max = component.maxPoints;
    final points = max == null
        ? '${component.points}'
        : '${component.points} / $max';
    final spokenPoints = max == null
        ? '${component.points} points'
        : '${component.points} of $max points';
    final spoken = [label, ?amount, spokenPoints].join(', ');
    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Padding(
        key: ValueKey('component-${component.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: notCounted
                        ? textTheme.bodyMedium?.copyWith(color: palette.muted)
                        : textTheme.bodyMedium,
                  ),
                  if (amount case final text?)
                    Text(
                      text,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        fontFeatures: _tabular,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 92,
              child: _Bar(
                fill: fill(component),
                color: notCounted ? palette.muted : color,
                track: palette.track,
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44),
              child: Text(
                points,
                textAlign: TextAlign.end,
                style: textTheme.titleSmall?.copyWith(fontFeatures: _tabular),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fill, required this.color, required this.track});

  final double fill;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: track),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: fill,
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Declared values per 100 g or 100 mL.
class NutritionSection extends StatelessWidget {
  const NutritionSection({required this.nutrition, super.key});

  final NutritionDetail? nutrition;

  @override
  Widget build(BuildContext context) {
    final n = nutrition;
    final textTheme = Theme.of(context).textTheme;
    if (n == null) {
      return ProductSection(
        title: 'Nutrition',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'No nutrition values for this product yet.',
            style: textTheme.bodyMedium,
          ),
        ),
      );
    }
    final unit = n.basis == NutritionBasis.per100ml ? '100 mL' : '100 g';
    String grams(double? v) => v == null ? '–' : '${formatAmount(v)} g';
    return ProductSection(
      title: 'Nutrition per $unit',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NutrientRow(
            'Energy',
            n.energyKj == null ? '–' : formatEnergy(n.energyKj!),
          ),
          _NutrientRow('Fat', grams(n.totalFatG)),
          _NutrientRow(
            'of which saturates',
            grams(n.saturatedFatG),
            indented: true,
          ),
          _NutrientRow('Sugars', grams(n.sugarsG)),
          _NutrientRow('Fibre', grams(n.fibreG)),
          _NutrientRow('Protein', grams(n.proteinG)),
          _NutrientRow('Salt', grams(n.saltG)),
          _NutrientRow(
            'Fruit, vegetables, legumes',
            n.fvlPercent == null
                ? '–'
                : '${formatAmount(n.fvlPercent!, decimals: 1)} %',
          ),
          if (n.nonNutritiveSweeteners case final sweeteners?)
            _NutrientRow('Sweeteners', sweeteners ? 'Yes' : 'No'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('– not declared', style: textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _NutrientRow extends StatelessWidget {
  const _NutrientRow(this.label, this.value, {this.indented = false});

  final String label;
  final String value;
  final bool indented;

  @override
  Widget build(BuildContext context) {
    final muted = QoutPalette.of(context).muted;
    final style = indented ? TextStyle(color: muted) : null;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(indented ? 32 : 16, 9, 16, 9),
      // Side by side when they fit; with large text the value moves under
      // the label instead of overflowing.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        children: [
          Text(label, style: style),
          Text(
            value,
            style: (style ?? const TextStyle()).copyWith(
              fontFeatures: _tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// NOVA processing group.
class ProcessingSection extends StatelessWidget {
  const ProcessingSection({required this.novaGroup, super.key});

  final int? novaGroup;

  @override
  Widget build(BuildContext context) {
    final label = novaLabel(novaGroup);
    return ProductSection(
      title: 'Processing (NOVA)',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(label == null ? 'Unknown' : 'Group $novaGroup: $label'),
      ),
    );
  }
}

/// Additives with their EFSA overexposure risk; each can be marked to avoid
/// (T40: "For you" then points it out on every product that has it).
class AdditivesSection extends ConsumerWidget {
  const AdditivesSection({required this.additives, super.key});

  final List<AdditiveDetail> additives;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = QoutPalette.of(context);
    final avoided = ref.watch(avoidedAdditivesProvider).valueOrNull ?? const {};
    if (additives.isEmpty) {
      return const ProductSection(
        title: 'Additives',
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('No additives listed.'),
        ),
      );
    }
    return ProductSection(
      title: 'Additives (${additives.length})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final additive in additives)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      switch (additive.overexposureRisk) {
                        OverexposureRisk.high || OverexposureRisk.moderate =>
                          PhosphorIconsRegular.warning,
                        OverexposureRisk.none =>
                          PhosphorIconsRegular.checkCircle,
                        _ => PhosphorIconsRegular.question,
                      },
                      size: 20,
                      color: additive.overexposureRisk == OverexposureRisk.high
                          ? theme.colorScheme.error
                          : palette.muted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          additive.name == null
                              ? additive.code
                              : '${additive.code} · ${additive.name}',
                        ),
                        Text(
                          riskLabel(additive.overexposureRisk),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _AvoidButton(
                    code: additive.code,
                    avoided: avoided.contains(additive.code),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              '"Not evaluated" means no risk level is recorded for this '
              'additive: it is neither a warning nor a sign that it is safe.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Marks an additive to avoid, or stops avoiding it.
class _AvoidButton extends ConsumerWidget {
  const _AvoidButton({required this.code, required this.avoided});

  final String code;
  final bool avoided;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: avoided ? 'Stop avoiding $code' : 'Avoid $code',
      isSelected: avoided,
      icon: const Icon(PhosphorIconsRegular.prohibit),
      selectedIcon: Icon(PhosphorIconsFill.prohibit, color: scheme.error),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        await ref
            .read(profileRepositoryProvider)
            .setAvoided(code, avoid: !avoided);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                avoided
                    ? 'You no longer avoid $code.'
                    : 'You avoid $code: products with it are pointed out.',
              ),
            ),
          );
      },
    );
  }
}

/// Where the data comes from and how current it is.
class SourceSection extends StatelessWidget {
  const SourceSection({required this.product, super.key});

  final ProductDetail product;

  @override
  Widget build(BuildContext context) {
    final quality = switch (product.qualityFlag) {
      QualityFlag.incomplete => 'Some values are missing from the source.',
      QualityFlag.suspect =>
        'Some values look inconsistent. Check them against the label.',
      _ => null,
    };
    final muted = QoutPalette.of(context).muted;
    return ProductSection(
      title: 'Source',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${sourceLabel(product.source)} · '
              '${statusLabel(product.status)}',
            ),
            Text(
              'Updated ${formatDate(context, product.updatedAt)}',
              style: TextStyle(color: muted),
            ),
            if (quality != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(quality),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Better choices": products of the same kind with a better grade. Shown only
/// when there are some; while loading, offline or on error it takes no space
/// (a suggestion must never get in the way of the result).
class AlternativesSection extends ConsumerWidget {
  const AlternativesSection({
    required this.ean,
    required this.grade,
    super.key,
  });

  /// The product's EAN as the API knows it.
  final String ean;

  /// The product's grade: nothing beats A, and without a grade there is
  /// nothing to compare, so no request is made then.
  final Grade? grade;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (grade == null || grade == Grade.a || grade == Grade.unrecognized) {
      return const SizedBox.shrink();
    }
    final items = ref.watch(alternativesProvider(ean)).valueOrNull;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return ProductSection(
      title: 'Better choices',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0) const FadingRule(),
            _AlternativeRow(item),
          ],
        ],
      ),
    );
  }
}

class _AlternativeRow extends StatelessWidget {
  const _AlternativeRow(this.item);

  final AlternativeProduct item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    return InkWell(
      onTap: () => context.push(AppRoutes.product(item.ean)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
          child: Row(
            children: [
              GradeBadge(grade: item.grade, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name ?? 'Unnamed product',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall,
                    ),
                    if (item.brand case final brand?)
                      Text(
                        brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              Icon(
                PhosphorIconsRegular.caretRight,
                size: 18,
                color: palette.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
