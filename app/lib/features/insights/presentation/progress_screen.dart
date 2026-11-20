import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/api/qout_api.dart' show Grade;
import 'package:qout/core/ui/entrance.dart';
import 'package:qout/core/ui/section_card.dart';
import 'package:qout/core/ui/state_message.dart';
import 'package:qout/features/diary/data/diary_repository.dart';
import 'package:qout/features/diary/presentation/diary_format.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';
import 'package:qout/features/profile/data/profile_repository.dart';
import 'package:qout/health/diary.dart';
import 'package:qout/health/insights.dart';
import 'package:qout/health/needs.dart';

/// The Monday of the week the Progress tab shows; this week at first.
final selectedWeekProvider = StateProvider<DateTime>(
  (ref) => mondayOf(DateTime.now()),
);

/// The diary entries of the week starting on a Monday, live.
final AutoDisposeStreamProviderFamily<List<DiaryEntry>, DateTime>
diaryWeekProvider = StreamProvider.autoDispose
    .family<List<DiaryEntry>, DateTime>((ref, monday) {
      final end = DateTime(monday.year, monday.month, monday.day + 7);
      return ref.watch(diaryRepositoryProvider).watchBetween(monday, end);
    });

/// The Progress tab (T43): the week from the diary, in neutral words.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monday = ref.watch(selectedWeekProvider);
    final entries = ref.watch(diaryWeekProvider(monday));
    final needs = ref.watch(dailyNeedsProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: Column(
        children: [
          _WeekSelector(
            monday: monday,
            onChanged: (m) => ref.read(selectedWeekProvider.notifier).state = m,
          ),
          Expanded(
            child: switch ((entries, needs)) {
              (AsyncError(), _) => const StateMessage(
                icon: PhosphorIconsRegular.warningCircle,
                title: 'The diary could not be read',
                message: 'Try again later.',
              ),
              (AsyncData(value: final list), final DailyNeeds needs) => _Week(
                weekInsights(list, monday, needs),
                needs,
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({required this.monday, required this.onChanged});

  final DateTime monday;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    final thisWeek = mondayOf(DateTime.now());
    final label = monday == thisWeek
        ? 'This week'
        : '${l10n.formatShortMonthDay(monday)} – '
              '${l10n.formatShortMonthDay(sunday)}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous week',
            icon: const Icon(PhosphorIconsRegular.caretLeft),
            onPressed: () => onChanged(
              DateTime(monday.year, monday.month, monday.day - 7),
            ),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next week',
            icon: const Icon(PhosphorIconsRegular.caretRight),
            onPressed: monday == thisWeek
                ? null
                : () => onChanged(
                    DateTime(monday.year, monday.month, monday.day + 7),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Week extends StatelessWidget {
  const _Week(this.week, this.needs);

  final WeekInsights week;
  final DailyNeeds needs;

  @override
  Widget build(BuildContext context) {
    if (week.isEmpty) {
      return const StateMessage(
        icon: PhosphorIconsRegular.chartLineUp,
        title: 'Nothing logged this week',
        message:
            'Log what you eat with "I ate this" on a product or a quick add; '
            'your week appears here: energy, grades, processing, salt and '
            'sugars.',
      );
    }
    final textTheme = Theme.of(context).textTheme;
    final sections = <Widget>[
      _EnergyCard(week: week, needs: needs),
      _GradesCard(week: week),
      _ProcessingCard(week: week),
      _ReferencesCard(week: week),
      if (week.topSugars.isNotEmpty || week.topSalt.isNotEmpty)
        _TopSourcesCard(week: week),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Text(
          'From what you logged. Shares are of your energy (kcal). General '
          'information, not medical advice.',
          style: textTheme.bodySmall,
        ),
      ),
    ];
    return EntranceScope(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final (i, section) in sections.indexed)
            Entrance(index: i, child: section),
        ],
      ),
    );
  }
}

/// Energy per day as bars, with the daily need as a line.
class _EnergyCard extends StatelessWidget {
  const _EnergyCard({required this.week, required this.needs});

  final WeekInsights week;
  final DailyNeeds needs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = QoutPalette.of(context);
    final l10n = MaterialLocalizations.of(context);
    final kcal = [for (final kj in week.energyKjPerDay) kcalOf(kj)];
    final need = kcalOf(needs.energyKj.toDouble());
    final top = [...kcal, need].reduce((a, b) => a > b ? a : b) * 1.15;
    final average = kcalOf(week.averageKjOnLoggedDays);
    final m = week.monday;
    final spoken = [
      for (var i = 0; i < 7; i++)
        _spokenDay(l10n, DateTime(m.year, m.month, m.day + i), kcal[i]),
    ].join('; ');
    return SectionCard(
      title: 'Energy per day',
      icon: PhosphorIconsRegular.lightning,
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: '$spoken. Your daily need: $need kilocalories.',
            excludeSemantics: true,
            child: SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: top <= 0 ? 1 : top,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barTouchData: const BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                            l10n.narrowWeekdays[(value.toInt() + 1) % 7],
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ),
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: need.toDouble(),
                        color: palette.muted,
                        strokeWidth: 1.5,
                        dashArray: const [6, 4],
                      ),
                    ],
                  ),
                  barGroups: [
                    for (var i = 0; i < 7; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: kcal[i].toDouble(),
                            width: 18,
                            color: palette.accent,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: top <= 0 ? 1 : top,
                              color: palette.track.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 0, 0),
            child: Text(
              'On the ${week.daysLogged} '
              '${week.daysLogged == 1 ? 'day' : 'days'} you logged: '
              '$average kcal on average. Dashed line: your daily need, '
              '$need kcal.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// The week's energy by grade, as one stacked bar.
class _GradesCard extends StatelessWidget {
  const _GradesCard({required this.week});

  final WeekInsights week;

  static Color _color(BuildContext context, GradeGroup group) =>
      switch (group) {
        GradeGroup.ab => gradeColors[Grade.b]!,
        GradeGroup.c => gradeColors[Grade.c]!,
        GradeGroup.de => gradeColors[Grade.e]!,
        GradeGroup.notGraded => QoutPalette.of(context).track,
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shares = week.energyShareByGrade;
    return SectionCard(
      title: 'Your week by grade',
      icon: PhosphorIconsRegular.chartPieSlice,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: shares.isEmpty
          ? Text(
              'Nothing logged had an energy value.',
              style: textTheme.bodySmall,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 14,
                      child: Row(
                        children: [
                          for (final group in GradeGroup.values)
                            if (shares[group] case final share?)
                              Expanded(
                                flex: (share * 1000).round().clamp(1, 1000),
                                child: ColoredBox(
                                  color: _color(context, group),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                for (final group in GradeGroup.values)
                  if (shares[group] case final share?)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          ExcludeSemantics(
                            child: SizedBox.square(
                              dimension: 12,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _color(context, group),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(group.label)),
                          Text(
                            _percent(share),
                            style: textTheme.titleSmall?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
    );
  }
}

/// How much of the week's energy came from ultra-processed food.
class _ProcessingCard extends StatelessWidget {
  const _ProcessingCard({required this.week});

  final WeekInsights week;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    final nova4 = week.nova4Share;
    final unknown = week.novaUnknownShare;
    return SectionCard(
      title: 'Processing',
      icon: PhosphorIconsRegular.factory,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: nova4 == null
          ? Text(
              'Nothing logged had an energy value.',
              style: textTheme.bodySmall,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${_percent(nova4)} of your energy came from '
                  'ultra-processed food (NOVA group 4).',
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: nova4.clamp(0, 1).toDouble(),
                    minHeight: 8,
                    color: palette.accent,
                    backgroundColor: palette.track,
                    semanticsLabel: 'Share from ultra-processed food',
                    semanticsValue: _percent(nova4),
                  ),
                ),
                if (unknown != null && unknown > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'The processing of ${_percent(unknown)} is not known '
                    '(quick adds, products without a NOVA group).',
                    style: textTheme.bodySmall,
                  ),
                ],
              ],
            ),
    );
  }
}

/// Days above the salt and the sugars reference.
class _ReferencesCard extends StatelessWidget {
  const _ReferencesCard({required this.week});

  final WeekInsights week;

  @override
  Widget build(BuildContext context) {
    final logged = week.daysLogged;
    String days(int n) =>
        '$n of $logged logged ${logged == 1 ? 'day' : 'days'}';
    return SectionCard(
      title: 'Salt and sugars',
      icon: PhosphorIconsRegular.drop,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CountRow(
            label: 'Days above the salt reference',
            value: days(week.daysAboveSalt),
          ),
          _CountRow(
            label: 'Days above the sugars reference',
            value: days(week.daysAboveSugars),
          ),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        children: [
          Text(label),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    ),
  );
}

/// The products that gave the most sugars and salt this week.
class _TopSourcesCard extends StatelessWidget {
  const _TopSourcesCard({required this.week});

  final WeekInsights week;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget list(String title, List<TopSource> sources) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Text(title, style: textTheme.titleSmall),
        ),
        for (final source in sources)
          _CountRow(label: source.name, value: _grams(source.grams)),
      ],
    );
    return SectionCard(
      title: 'Top sources',
      icon: PhosphorIconsRegular.listNumbers,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (week.topSugars.isNotEmpty) list('Sugars', week.topSugars),
          if (week.topSalt.isNotEmpty) list('Salt', week.topSalt),
        ],
      ),
    );
  }
}

String _spokenDay(MaterialLocalizations l10n, DateTime day, int kcal) =>
    '${l10n.formatMediumDate(day)}: $kcal kilocalories';

/// A share as a whole percent; "< 1 %" for a small one above 0.
String _percent(double share) {
  final percent = (share * 100).round();
  return percent == 0 && share > 0 ? '< 1 %' : '$percent %';
}

String _grams(double grams) =>
    grams < 10 ? '${grams.toStringAsFixed(1)} g' : '${grams.round()} g';
