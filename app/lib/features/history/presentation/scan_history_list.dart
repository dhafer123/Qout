import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/ui/entrance.dart';
import 'package:qout/features/history/data/scan_history_repository.dart';
import 'package:qout/features/history/domain/history_entry.dart';
import 'package:qout/features/product/domain/score_explanation.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';
import 'package:qout/features/product/presentation/product_photo.dart';

/// "Today", "Yesterday", or the date, for the day of [time] (local).
String dayLabel(BuildContext context, DateTime time, {DateTime? now}) {
  final local = time.toLocal();
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(local);
  final ago = today.difference(day).inDays;
  if (ago == 0) return 'Today';
  if (ago == 1) return 'Yesterday';
  return MaterialLocalizations.of(context).formatMediumDate(local);
}

/// Asks, then clears the scan history.
Future<void> confirmClearHistory(BuildContext context, WidgetRef ref) async {
  final clear = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Clear history?'),
      content: const Text(
        'This removes every scan from this list. Products already seen stay '
        'available offline.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Clear'),
        ),
      ],
    ),
  );
  if (clear ?? false) await ref.read(scanHistoryRepositoryProvider).clear();
}

/// The scans as cards under a heading per day; swipe a card away to remove
/// it (with undo).
class ScanHistorySliver extends ConsumerStatefulWidget {
  const ScanHistorySliver(this.entries, {this.firstIndex = 0, super.key});

  final List<HistoryEntry> entries;

  /// Where the rows start in the screen's entrance order.
  final int firstIndex;

  @override
  ConsumerState<ScanHistorySliver> createState() => _ScanHistorySliverState();
}

class _ScanHistorySliverState extends ConsumerState<ScanHistorySliver> {
  /// Swiped away but maybe not yet gone from the database stream: a dismissed
  /// row must leave the list at once.
  final _dismissed = <int>{};

  void _remove(HistoryEntry entry) {
    setState(() => _dismissed.add(entry.id));
    final repository = ref.read(scanHistoryRepositoryProvider);
    unawaited(repository.remove(entry));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Removed from history'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => unawaited(repository.restore(entry)),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // Newest first, a heading before each day.
    final items = <Object>[];
    String? day;
    for (final entry in widget.entries) {
      if (_dismissed.contains(entry.id)) continue;
      final label = dayLabel(context, entry.scannedAt);
      if (label != day) items.add(day = label);
      items.add(entry);
    }
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is String) {
          return Entrance(
            index: widget.firstIndex + index,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
              child: Semantics(
                header: true,
                child: Text(item, style: textTheme.titleSmall),
              ),
            ),
          );
        }
        final entry = item as HistoryEntry;
        return Entrance(
          key: ValueKey(entry.id),
          index: widget.firstIndex + index,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Dismissible(
                key: ValueKey(entry.id),
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
                child: HistoryTile(entry: entry),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One scanned product: its photo (or grade), name, brand (or barcode), when
/// it was scanned, and its grade.
class HistoryTile extends StatelessWidget {
  const HistoryTile({required this.entry, super.key});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = QoutPalette.of(context);
    final product = entry.product;
    final scanned = TimeOfDay.fromDateTime(
      entry.scannedAt.toLocal(),
    ).format(context);
    final brand = product?.brand;
    final name = product?.name;
    final photo = product?.imageUrl;
    final grade = product == null ? null : explainScore(product).displayGrade;
    return InkWell(
      onTap: () => context.push(AppRoutes.product(entry.ean)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 76),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
          child: Row(
            children: [
              if (photo != null && photo.isNotEmpty)
                ProductThumbnail(url: photo, size: 56)
              else
                GradeBadge(grade: grade, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? 'Unnamed product',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: name == null
                          ? textTheme.titleSmall?.copyWith(
                              color: palette.muted,
                              fontStyle: FontStyle.italic,
                            )
                          : textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${brand ?? entry.ean} · $scanned',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (photo != null && photo.isNotEmpty)
                GradeBadge(grade: grade, size: 36),
            ],
          ),
        ),
      ),
    );
  }
}

/// An empty or failed list: an icon and a line or two, flush left.
class ListMessage extends StatelessWidget {
  const ListMessage({
    required this.icon,
    required this.title,
    this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 40, color: QoutPalette.of(context).muted),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleSmall),
          if (message case final text?) ...[
            const SizedBox(height: 4),
            Text(text, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
