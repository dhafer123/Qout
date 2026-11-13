import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qout/app/router.dart';
import 'package:qout/features/history/data/scan_history_repository.dart';
import 'package:qout/features/history/domain/history_entry.dart';
import 'package:qout/features/product/domain/score_explanation.dart';
import 'package:qout/features/product/presentation/grade_badge.dart';
import 'package:qout/features/product/presentation/product_labels.dart';

/// Scan button, then the products scanned so far (works offline).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final history = ref.watch(scanHistoryProvider);
    final hasHistory = history.valueOrNull?.isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Qout'),
        actions: [
          if (hasHistory)
            PopupMenuButton<void>(
              tooltip: 'More',
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: () => unawaited(_confirmClear(context, ref)),
                  child: const Text('Clear history'),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Scan a food barcode to see its nutrition score.',
                  style: textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.scan),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Center(child: Text('The history could not be read.')),
              data: (entries) => entries.isEmpty
                  ? const _EmptyHistory()
                  : _HistoryList(entries),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
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
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text('No scans yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Scanned products appear here, also offline.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends ConsumerStatefulWidget {
  const _HistoryList(this.entries);

  final List<HistoryEntry> entries;

  @override
  ConsumerState<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends ConsumerState<_HistoryList> {
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
    final entries = [
      for (final entry in widget.entries)
        if (!_dismissed.contains(entry.id)) entry,
    ];
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Dismissible(
          key: ValueKey(entry.id),
          direction: DismissDirection.endToStart,
          background: ColoredBox(
            color: Theme.of(context).colorScheme.errorContainer,
            child: const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Icon(Icons.delete_outline),
              ),
            ),
          ),
          onDismissed: (_) => _remove(entry),
          child: HistoryTile(entry: entry),
        );
      },
    );
  }
}

/// One scanned product: grade, name, brand and when it was scanned.
class HistoryTile extends StatelessWidget {
  const HistoryTile({required this.entry, super.key});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final product = entry.product;
    final scanned = formatDateTime(context, entry.scannedAt);
    final brand = product?.brand;
    return ListTile(
      leading: GradeBadge(
        grade: product == null ? null : explainScore(product).displayGrade,
        size: 44,
      ),
      title: Text(
        product?.name ?? 'Unnamed product',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        brand != null ? '$brand · $scanned' : '${entry.ean} · $scanned',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => context.push(AppRoutes.product(entry.ean)),
    );
  }
}
