import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/features/diary/presentation/diary_format.dart';
import 'package:qout/health/advice.dart' show Nutrient;
import 'package:qout/health/diary.dart';
import 'package:qout/health/needs.dart';

const _tabular = [FontFeature.tabularFigures()];

/// What the day's entries gave against the daily needs: an energy ring and
/// a bar for fat, saturated fat, sugars and salt. Above a reference the
/// bar turns amber with neutral words; energy is a need, not a limit.
class DaySummaryCard extends StatelessWidget {
  const DaySummaryCard({required this.totals, required this.needs, super.key});

  final Totals totals;
  final DailyNeeds needs;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final personal = needs.basis == NeedsBasis.personal;
    final ring = EnergyRing(
      eatenKj: totals.of(Nutrient.energy),
      needKj: needs.energyKj,
    );
    final bars = Column(
      children: [
        for (final nutrient in const [
          Nutrient.fat,
          Nutrient.saturates,
          Nutrient.sugars,
          Nutrient.salt,
        ])
          NutrientBar(
            nutrient: nutrient,
            total: totals.of(nutrient),
            daily: dailyAmount(needs, nutrient),
            qualifier: switch (nutrient) {
              Nutrient.sugars => 'reference',
              Nutrient.salt when personal => 'under',
              Nutrient.salt => 'reference',
              _ => 'up to',
            },
          ),
      ],
    );
    final missing = totals.missing[Nutrient.energy] ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final large = MediaQuery.textScalerOf(context).scale(10) > 13;
                if (large || constraints.maxWidth < 300) {
                  return Column(
                    children: [ring, const SizedBox(height: 16), bars],
                  );
                }
                return Row(
                  children: [
                    ring,
                    const SizedBox(width: 18),
                    Expanded(child: bars),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Text(
              [
                if (missing > 0)
                  missing == 1
                      ? '1 item has no energy value.'
                      : '$missing items have no energy value.',
                if (personal)
                  'Compared with your daily needs.'
                else
                  'Compared with the EU reference intakes.',
                'General information, not medical advice.',
              ].join(' '),
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// The day's energy as a ring: eaten out of the daily need.
class EnergyRing extends StatelessWidget {
  const EnergyRing({required this.eatenKj, required this.needKj, super.key});

  final double eatenKj;
  final int needKj;

  static const double size = 128;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    final eaten = kcalOf(eatenKj);
    final need = kcalOf(needKj.toDouble());
    final share = shareOfDay(eatenKj, needKj);
    return Semantics(
      label:
          'Energy: $eaten of $need kilocalories, '
          '${(share * 100).round()} percent of your daily need',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(
            share: share,
            color: palette.accent,
            track: palette.track,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$eaten',
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: _tabular,
                      ),
                    ),
                    Text(
                      'of $need kcal',
                      style: textTheme.bodySmall?.copyWith(
                        fontFeatures: _tabular,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.share,
    required this.color,
    required this.track,
  });

  final double share;
  final Color color;
  final Color track;

  static const double _stroke = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, base..color = track);
    final sweep = 2 * math.pi * share.clamp(0, 1);
    if (sweep > 0) {
      canvas.drawArc(rect, -math.pi / 2, sweep, false, base..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.share != share || old.color != color || old.track != track;
}

/// One nutrient: name, "34 / up to 97 g", and a bar of the day's share.
class NutrientBar extends StatelessWidget {
  const NutrientBar({
    required this.nutrient,
    required this.total,
    required this.daily,
    required this.qualifier,
    super.key,
  });

  final Nutrient nutrient;
  final double total;
  final int daily;

  /// "up to", "under" or "reference": how the daily amount reads.
  final String qualifier;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    final above = aboveReference(nutrient, total, daily);
    final eaten = total < 10 ? total.toStringAsFixed(1) : '${total.round()}';
    final name = nutrientName(nutrient);
    final spoken =
        '$name: $eaten grams, $qualifier $daily grams'
        '${above ? ', above your daily reference' : ''}';
    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              children: [
                Text(name, style: textTheme.bodyMedium),
                Text(
                  '$eaten / $qualifier $daily g',
                  style: textTheme.bodySmall?.copyWith(
                    color: above ? palette.doubt : null,
                    fontFeatures: _tabular,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: shareOfDay(total, daily).clamp(0, 1).toDouble(),
                minHeight: 7,
                color: above ? palette.doubt : palette.accent,
                backgroundColor: palette.track,
              ),
            ),
            if (above)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Above your daily reference',
                  style: textTheme.bodySmall?.copyWith(color: palette.doubt),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
