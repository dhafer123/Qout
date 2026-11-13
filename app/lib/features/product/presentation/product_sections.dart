import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/product/data/alternatives_repository.dart';
import 'package:qout/features/product/domain/score_explanation.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';
import 'package:qout/features/product/presentation/product_labels.dart';

/// A titled card on the result screen.
class ProductSection extends StatelessWidget {
  const ProductSection({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Badge, name, brand and barcode.
class ProductHeader extends StatelessWidget {
  const ProductHeader({
    required this.product,
    required this.explanation,
    super.key,
  });

  final ProductDetail product;
  final ScoreExplanation explanation;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          GradeBadge(grade: explanation.displayGrade),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name ?? 'Unnamed product',
                  style: textTheme.titleLarge,
                ),
                if (product.brand case final brand?)
                  Text(brand, style: textTheme.bodyLarge),
                Text('Barcode ${product.ean}', style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Why this score".
class ScoreSection extends StatelessWidget {
  const ScoreSection({required this.explanation, super.key});

  final ScoreExplanation explanation;

  @override
  Widget build(BuildContext context) {
    return ProductSection(
      title: 'Why this score',
      child: switch (explanation) {
        final GradedExplanation graded => _GradedBreakdown(graded),
        WaterExplanation() => const Text('Plain water is always graded A.'),
        GradeOnlyExplanation() => const Text(
          'The details of this score are not available in this version of '
          'the app.',
        ),
        InsufficientDataExplanation(:final missing) => Text(
          'Not enough data to grade this product. Missing: '
          '${missing.map(inputLabel).join(', ')}.',
        ),
        NotScoredExplanation() => const Text(
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
  const _GradedBreakdown(this.e);

  final GradedExplanation e;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Negative points: ${e.negativeTotal}',
          style: textTheme.labelLarge,
        ),
        for (final c in e.negative) _ComponentRow(c),
        const SizedBox(height: 12),
        Text(
          'Positive points: ${e.positiveTotal}',
          style: textTheme.labelLarge,
        ),
        for (final c in e.positive)
          _ComponentRow(
            c,
            notCounted: c.name == 'protein' && !e.proteinCounted,
          ),
        const SizedBox(height: 12),
        Text(
          'Score: ${e.negativeTotal} − ${e.subtracted} = ${e.score}, '
          'grade ${e.grade.value}',
          style: textTheme.titleSmall,
        ),
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(note, style: textTheme.bodySmall),
          ),
      ],
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow(this.component, {this.notCounted = false});

  final ScoreComponent component;
  final bool notCounted;

  @override
  Widget build(BuildContext context) {
    final max = component.maxPoints;
    final points = max == null
        ? '${component.points}'
        : '${component.points} / $max';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  notCounted
                      ? '${componentLabel(component.name)} (not counted)'
                      : componentLabel(component.name),
                ),
              ),
              Text(points),
            ],
          ),
          if (max != null && max > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(
                value: (component.points / max).clamp(0, 1),
                semanticsLabel: componentLabel(component.name),
              ),
            ),
        ],
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
    if (n == null) {
      return const ProductSection(
        title: 'Nutrition',
        child: Text('No nutrition values for this product yet.'),
      );
    }
    final unit = n.basis == NutritionBasis.per100ml ? '100 mL' : '100 g';
    String grams(double? v) => v == null ? '–' : '${formatAmount(v)} g';
    return ProductSection(
      title: 'Nutrition per $unit',
      child: Column(
        children: [
          _NutrientRow(
            'Energy',
            n.energyKj == null ? '–' : formatEnergy(n.energyKj!),
          ),
          _NutrientRow('Fat', grams(n.totalFatG)),
          _NutrientRow('of which saturated', grams(n.saturatedFatG)),
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
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('– not declared'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutrientRow extends StatelessWidget {
  const _NutrientRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value),
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
      child: Text(label == null ? 'Unknown' : 'Group $novaGroup: $label'),
    );
  }
}

/// Additives with their EFSA overexposure risk.
class AdditivesSection extends StatelessWidget {
  const AdditivesSection({required this.additives, super.key});

  final List<AdditiveDetail> additives;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (additives.isEmpty) {
      return const ProductSection(
        title: 'Additives',
        child: Text('No additives listed.'),
      );
    }
    return ProductSection(
      title: 'Additives (${additives.length})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final additive in additives)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                switch (additive.overexposureRisk) {
                  OverexposureRisk.high ||
                  OverexposureRisk.moderate => Icons.warning_amber_rounded,
                  OverexposureRisk.none => Icons.check_circle_outline,
                  _ => Icons.help_outline,
                },
                color: switch (additive.overexposureRisk) {
                  OverexposureRisk.high => colors.error,
                  _ => colors.onSurfaceVariant,
                },
              ),
              title: Text(
                additive.name == null
                    ? additive.code
                    : '${additive.code} · ${additive.name}',
              ),
              subtitle: Text(riskLabel(additive.overexposureRisk)),
            ),
          Text(
            '"Not evaluated" means no risk level is recorded for this '
            'additive: it is neither a warning nor a sign that it is safe.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
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
    return ProductSection(
      title: 'Source',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${sourceLabel(product.source)} · ${statusLabel(product.status)}',
          ),
          Text('Updated ${formatDate(context, product.updatedAt)}'),
          if (quality != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(quality),
            ),
        ],
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
      child: SizedBox(
        height: 132,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) => _AlternativeCard(items[index]),
        ),
      ),
    );
  }
}

class _AlternativeCard extends StatelessWidget {
  const _AlternativeCard(this.item);

  final AlternativeProduct item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: 150,
      child: Card.outlined(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push(AppRoutes.product(item.ean)),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GradeBadge(grade: item.grade, size: 36),
                const SizedBox(height: 8),
                Text(
                  item.name ?? 'Unnamed product',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium,
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
        ),
      ),
    );
  }
}
