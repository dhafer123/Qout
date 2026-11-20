import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/core/ui/entrance.dart';
import 'package:qout/core/ui/section_label.dart';
import 'package:qout/features/history/data/scan_history_repository.dart';
import 'package:qout/features/history/presentation/scan_history_list.dart';

/// The Diary tab: what was scanned, day by day (works offline).
class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(scanHistoryProvider);
    final hasHistory = history.valueOrNull?.isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Diary')),
      body: EntranceScope(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SectionLabel(
                'Recently scanned',
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
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
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
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
              data: (entries) => [
                if (entries.isEmpty)
                  const SliverToBoxAdapter(
                    child: ListMessage(
                      icon: PhosphorIconsRegular.clockCounterClockwise,
                      title: 'No scans yet',
                      message: 'Scanned products appear here, also offline.',
                    ),
                  )
                else
                  ScanHistorySliver(entries, firstIndex: 1),
              ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }
}
