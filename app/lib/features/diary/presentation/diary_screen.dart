import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/api/qout_api.dart' show Grade;
import 'package:qout/core/ui/entrance.dart';
import 'package:qout/core/ui/section_label.dart';
import 'package:qout/features/diary/data/diary_repository.dart';
import 'package:qout/features/diary/presentation/diary_format.dart';
import 'package:qout/features/diary/presentation/diary_sheets.dart';
import 'package:qout/features/history/data/scan_history_repository.dart';
import 'package:qout/features/history/presentation/scan_history_list.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';
import 'package:qout/features/product/presentation/product_photo.dart';
import 'package:qout/health/advice.dart' show Nutrient;
import 'package:qout/health/diary.dart';

/// The day the Diary tab shows (local midnight); today at first.
final selectedDiaryDayProvider = StateProvider<DateTime>(
  (ref) => dayOf(DateTime.now()),
);

/// The grade a diary entry kept, as the badge's grade.
Grade? gradeOfEntry(DiaryEntry entry) {
  final letter = entry.grade;
  if (letter == null) return null;
  for (final grade in Grade.values) {
    if (grade.value == letter) return grade;
  }
  return null;
}

/// The Diary tab: what was eaten, day by day (on the phone only), then the
/// products scanned lately.
class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedDiaryDayProvider);
    final entries = ref.watch(diaryDayProvider(day));
    final history = ref.watch(scanHistoryProvider);
    final hasHistory = history.valueOrNull?.isNotEmpty ?? false;
    final textTheme = Theme.of(context).textTheme;
    final list = entries.valueOrNull ?? const <DiaryEntry>[];
    final dayKcal = kcalOf(totalsOf(list).of(Nutrient.energy));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary'),
        actions: [
          IconButton(
            tooltip: 'Quick add',
            icon: const Icon(PhosphorIconsRegular.plusCircle),
            onPressed: () => showQuickAddSheet(context, day: day),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: EntranceScope(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: WeekStrip(
                selected: day,
                onSelected: (d) =>
                    ref.read(selectedDiaryDayProvider.notifier).state = d,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          dayLabel(context, day),
                          style: textTheme.titleMedium,
                        ),
                      ),
                    ),
                    if (list.isNotEmpty)
                      Text(
                        '$dayKcal kcal',
                        style: textTheme.titleSmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (entries.isLoading && !entries.hasValue)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (entries.hasError)
              const SliverToBoxAdapter(
                child: ListMessage(
                  icon: PhosphorIconsRegular.warningCircle,
                  title: 'The diary could not be read.',
                ),
              )
            else if (list.isEmpty)
              const SliverToBoxAdapter(
                child: ListMessage(
                  icon: PhosphorIconsRegular.forkKnife,
                  title: 'Nothing logged on this day',
                  message:
                      'Open a product and tap "I ate this", or use quick '
                      'add for food without a barcode.',
                ),
              )
            else
              _DayEntries(list),
            SliverToBoxAdapter(
              child: SectionLabel(
                'Recently scanned',
                padding: const EdgeInsets.fromLTRB(16, 20, 4, 0),
                action: hasHistory
                    ? TextButton(
                        onPressed: () =>
                            unawaited(confirmClearHistory(context, ref)),
                        child: const Text(
                          'Clear',
                          semanticsLabel: 'Clear history',
                        ),
                      )
                    : null,
              ),
            ),
            ...history.when(
              loading: () => const [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
              error: (_, _) => const [
                SliverToBoxAdapter(
                  child: ListMessage(
                    icon: PhosphorIconsRegular.warningCircle,
                    title: 'The history could not be read.',
                  ),
                ),
              ],
              data: (scans) => [
                if (scans.isEmpty)
                  const SliverToBoxAdapter(
                    child: ListMessage(
                      icon: PhosphorIconsRegular.clockCounterClockwise,
                      title: 'No scans yet',
                      message: 'Scanned products appear here, also offline.',
                    ),
                  )
                else
                  ScanHistorySliver(scans, firstIndex: 4),
              ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }
}

/// The day's entries under a heading per meal.
class _DayEntries extends ConsumerStatefulWidget {
  const _DayEntries(this.entries);

  final List<DiaryEntry> entries;

  @override
  ConsumerState<_DayEntries> createState() => _DayEntriesState();
}

class _DayEntriesState extends ConsumerState<_DayEntries> {
  /// Swiped away but maybe not yet gone from the stream.
  final _dismissed = <int>{};

  void _remove(DiaryEntry entry) {
    setState(() => _dismissed.add(entry.id));
    final repository = ref.read(diaryRepositoryProvider);
    unawaited(repository.remove(entry));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Removed from your diary'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              unawaited(repository.restore(entry));
              if (mounted) setState(() => _dismissed.remove(entry.id));
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final items = <Object>[];
    for (final meal in Meal.values) {
      final ofMeal = [
        for (final e in widget.entries)
          if (e.meal == meal && !_dismissed.contains(e.id)) e,
      ];
      if (ofMeal.isEmpty) continue;
      items
        ..add((meal, kcalOf(totalsOf(ofMeal).of(Nutrient.energy))))
        ..addAll(ofMeal);
    }
    return SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is (Meal, int)) {
          final (meal, kcal) = item;
          return Entrance(
            index: 2 + index,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(meal.label, style: textTheme.titleSmall),
                    ),
                  ),
                  Text('$kcal kcal', style: textTheme.bodySmall),
                ],
              ),
            ),
          );
        }
        final entry = item as DiaryEntry;
        return Entrance(
          key: ValueKey('diary-${entry.id}'),
          index: 2 + index,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Dismissible(
                key: ValueKey('diary-${entry.id}'),
                direction: DismissDirection.endToStart,
                background: ColoredBox(
                  color: scheme.errorContainer,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Icon(
                        PhosphorIconsRegular.trash,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
                onDismissed: (_) => _remove(entry),
                child: DiaryEntryTile(entry: entry),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One thing eaten: photo (or grade, or a fork for a quick add), name,
/// portion and kcal. Tap to change it.
class DiaryEntryTile extends StatelessWidget {
  const DiaryEntryTile({required this.entry, super.key});

  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    final photo = entry.imageUrl;
    final energy = entry.eaten[Nutrient.energy];
    final grade = gradeOfEntry(entry);
    final Widget leading;
    if (photo != null && photo.isNotEmpty) {
      leading = ProductThumbnail(url: photo, size: 48);
    } else if (entry.isQuickAdd) {
      leading = SizedBox.square(
        dimension: 48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.tag,
            borderRadius: BorderRadius.circular(QoutRadius.md),
          ),
          child: Icon(PhosphorIconsRegular.forkKnife, color: palette.onTag),
        ),
      );
    } else {
      leading = GradeBadge(grade: grade, size: 48);
    }
    return InkWell(
      onTap: () => showEditEntrySheet(context, entry),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 14, 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name ??
                        (entry.isQuickAdd ? 'Quick add' : 'Unnamed product'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                  ),
                  // The kcal moves under the portion when space is short.
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    children: [
                      Text(portionText(entry), style: textTheme.bodySmall),
                      Text(
                        energy == null ? '– kcal' : '${kcalOf(energy)} kcal',
                        style: textTheme.titleSmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (grade != null && photo != null && photo.isNotEmpty) ...[
              const SizedBox(width: 10),
              GradeBadge(grade: grade, size: 28),
            ],
          ],
        ),
      ),
    );
  }
}

/// Monday to Sunday of the selected day's week, with arrows to the weeks
/// before and after (not past this week).
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    required this.selected,
    required this.onSelected,
    this.today,
    super.key,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  /// Defaults to now; set in tests.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final now = dayOf(today ?? DateTime.now());
    final monday = DateTime(
      selected.year,
      selected.month,
      selected.day - (selected.weekday - DateTime.monday),
    );
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ];
    final thisWeek = !days.last.isBefore(now);
    final l10n = MaterialLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous week',
            icon: const Icon(PhosphorIconsRegular.caretLeft),
            onPressed: () => onSelected(
              DateTime(selected.year, selected.month, selected.day - 7),
            ),
          ),
          for (final day in days)
            Expanded(
              child: _DayPill(
                day: day,
                selected: day == selected,
                isToday: day == now,
                enabled: !day.isAfter(now),
                weekday: l10n.narrowWeekdays[day.weekday % 7],
                onTap: () => onSelected(day),
              ),
            ),
          IconButton(
            tooltip: 'Next week',
            icon: const Icon(PhosphorIconsRegular.caretRight),
            onPressed: thisWeek
                ? null
                : () {
                    final next = DateTime(
                      selected.year,
                      selected.month,
                      selected.day + 7,
                    );
                    onSelected(next.isAfter(now) ? now : next);
                  },
          ),
        ],
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.enabled,
    required this.weekday,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final bool enabled;
  final String weekday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = QoutPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final foreground = selected
        ? scheme.onPrimary
        : enabled
        ? scheme.onSurface
        : palette.muted;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: MaterialLocalizations.of(context).formatFullDate(day),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: selected ? scheme.primary : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: isToday && !selected
                ? BorderSide(color: palette.accent)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        weekday,
                        style: textTheme.labelSmall?.copyWith(
                          color: foreground,
                        ),
                      ),
                      Text(
                        '${day.day}',
                        style: textTheme.titleSmall?.copyWith(
                          color: foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
