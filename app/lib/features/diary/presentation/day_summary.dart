import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/ui/animated_value.dart';
import 'package:qout/features/diary/presentation/diary_format.dart';
import 'package:qout/health/advice.dart' show Nutrient;
import 'package:qout/health/diary.dart';
import 'package:qout/health/needs.dart';

const _tabular = [FontFeature.tabularFigures()];

const List<Nutrient> _bars = [
  Nutrient.fat,
  Nutrient.saturates,
  Nutrient.sugars,
  Nutrient.salt,
];

/// What the day's entries gave against the daily needs: an energy ring and
/// a bar for fat, saturated fat, sugars and salt, coloured by how much of
/// its daily amount is used (T43f). How each amount reads, and that this is
/// not medical advice, sits behind the ⓘ.
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
        for (final (index, nutrient) in _bars.indexed)
          NutrientBar(
            index: index,
            nutrient: nutrient,
            total: totals.of(nutrient),
            daily: dailyAmount(needs, nutrient),
          ),
      ],
    );
    final missing = totals.missing[Nutrient.energy] ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: LayoutBuilder(
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
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      if (missing > 0)
                        missing == 1
                            ? '1 item has no energy value.'
                            : '$missing items have no energy value.',
                      if (personal)
                        'Compared with your daily needs.'
                      else
                        'Compared with the EU reference intakes.',
                    ].join(' '),
                    style: textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: 'About these numbers',
                  onPressed: () => unawaited(
                    showModalBottomSheet<void>(
                      context: context,
                      useRootNavigator: true,
                      showDragHandle: true,
                      isScrollControlled: true,
                      builder: (context) => _AboutSheet(needs: needs),
                    ),
                  ),
                  icon: const Icon(PhosphorIconsRegular.info, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// How each daily amount reads, the colours, and that it is general
/// information.
class _AboutSheet extends StatelessWidget {
  const _AboutSheet({required this.needs});

  final DailyNeeds needs;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final personal = needs.basis == NeedsBasis.personal;
    String line(Nutrient nutrient) {
      final amount = dailyAmount(needs, nutrient);
      final name = nutrientName(nutrient);
      return switch (nutrient) {
        Nutrient.sugars =>
          '$name: $amount g, a reference intake for all sugars, not a limit.',
        Nutrient.salt when personal => '$name: under $amount g a day.',
        Nutrient.salt => '$name: $amount g, the EU reference intake.',
        _ => '$name: up to $amount g a day.',
      };
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('About these numbers', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            if (!personal) ...[
              const Text('Based on EU reference intakes.'),
              const SizedBox(height: 12),
            ],
            for (final nutrient in _bars)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line(nutrient)),
              ),
            const SizedBox(height: 8),
            Text(
              'General information, not medical advice.',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// [value] with a comma every three digits: "1,799".
String groupThousands(int value) {
  final digits = value.abs().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return value < 0 ? '-$grouped' : grouped;
}

/// The day's energy as a ring: what is left of the daily need (or how far
/// past it), with what was eaten and the need under it.
class EnergyRing extends StatelessWidget {
  const EnergyRing({required this.eatenKj, required this.needKj, super.key});

  final double eatenKj;
  final int needKj;

  static const double size = 128;

  /// The ring sweeps and the numbers run after the card has faded in
  /// (T43g).
  static const Duration duration = Duration(milliseconds: 900);
  static const Duration delay = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final eaten = kcalOf(eatenKj);
    final need = kcalOf(needKj.toDouble());
    final left = need - eaten;
    // Read out once, with the final values.
    return Semantics(
      container: true,
      label:
          'Energy: ${groupThousands(left.abs())} kilocalories '
          '${left < 0 ? 'over' : 'left'}. '
          '${groupThousands(eaten)} eaten of a daily need of '
          '${groupThousands(need)}.',
      excludeSemantics: true,
      child: AnimatedValue(
        id: 'ring',
        value: eatenKj,
        duration: duration,
        delay: delay,
        builder: _ring,
      ),
    );
  }

  /// The ring as it stands with [kj] eaten.
  Widget _ring(BuildContext context, double kj) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    final eaten = kcalOf(kj);
    final need = kcalOf(needKj.toDouble());
    final left = need - eaten;
    final word = left < 0 ? 'over' : 'left';
    // One line beside the bars; under large text it may wrap.
    final large = MediaQuery.textScalerOf(context).scale(10) > 13;
    final detail = Text(
      '${groupThousands(eaten)} eaten · ${groupThousands(need)} need',
      key: const ValueKey('ring-detail'),
      maxLines: large ? null : 1,
      textAlign: TextAlign.center,
      style: textTheme.bodySmall?.copyWith(fontFeatures: _tabular),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(
              share: shareOfDay(kj, needKj),
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
                        groupThousands(left.abs()),
                        key: const ValueKey('ring-left'),
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFeatures: _tabular,
                        ),
                      ),
                      Text('kcal $word', style: textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (large)
          detail
        else
          SizedBox(
            width: size + 24,
            child: FittedBox(fit: BoxFit.scaleDown, child: detail),
          ),
      ],
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

/// The colour of a bar in [status].
Color statusColor(StatusColors colors, NutrientStatus status) =>
    switch (status) {
      NutrientStatus.ok => colors.ok,
      NutrientStatus.warn => colors.warn,
      NutrientStatus.over => colors.over,
    };

/// One nutrient on one line, "Fat   9.1 / 33 g", and a bar of the day's
/// share coloured by [nutrientStatus].
class NutrientBar extends StatelessWidget {
  const NutrientBar({
    required this.nutrient,
    required this.total,
    required this.daily,
    this.index = 0,
    super.key,
  });

  final Nutrient nutrient;
  final double total;
  final int daily;

  /// Its place in the card: bars fill one after another (T43g).
  final int index;

  /// One after another: each starts this long after the one above.
  static const Duration stagger = Duration(milliseconds: 80);

  static String _amount(double total) =>
      total < 10 ? total.toStringAsFixed(1) : '${total.round()}';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    final above = aboveReference(nutrient, total, daily);
    final name = nutrientName(nutrient);
    final large = MediaQuery.textScalerOf(context).scale(10) > 13;
    // Read out once, with the final values.
    return Semantics(
      container: true,
      label:
          '$name: ${_amount(total)} of $daily grams'
          '${above ? ', above your daily reference' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: AnimatedValue(
          id: 'bar-${nutrient.name}',
          value: total,
          delay: EnergyRing.delay + stagger * index,
          builder: (context, shown) {
            final value = Text(
              '${_amount(shown)} / $daily g',
              key: ValueKey('bar-value-${nutrient.name}'),
              style: textTheme.bodyMedium?.copyWith(
                color: palette.muted,
                fontFeatures: _tabular,
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // One line: the name on the left, the value on the right.
                // Under large text the value may move under the name.
                if (large)
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    children: [
                      Text(name, style: textTheme.bodyMedium),
                      value,
                    ],
                  )
                else
                  LayoutBuilder(
                    // The value against the right edge; if it doesn't fit,
                    // it shrinks a little rather than overflow.
                    builder: (context, constraints) => Row(
                      children: [
                        Expanded(
                          child: Text(name, style: textTheme.bodyMedium),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.6,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: value,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    key: ValueKey('bar-${nutrient.name}'),
                    value: shareOfDay(shown, daily).clamp(0, 1).toDouble(),
                    minHeight: 7,
                    // The colour follows the fill: green, then amber, then
                    // red as the bar passes each step.
                    color: statusColor(
                      StatusColors.of(context),
                      nutrientStatus(nutrient, shown, daily),
                    ),
                    backgroundColor: palette.track,
                  ),
                ),
                // From the final value, so the card's height never jumps.
                if (above)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Above your daily reference',
                      style: textTheme.bodySmall?.copyWith(
                        color: palette.doubt,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
