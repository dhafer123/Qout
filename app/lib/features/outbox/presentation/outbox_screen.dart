import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/router.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/database/database_provider.dart';
import 'package:qout/core/ui/insets.dart';
import 'package:qout/core/ui/state_message.dart';
import 'package:qout/features/outbox/data/outbox.dart';
import 'package:qout/features/outbox/domain/queued_contribution.dart';
import 'package:qout/features/outbox/presentation/outbox_scheduler.dart';

/// Everything queued, oldest first; updates as entries change.
final StreamProvider<List<OutboxRow>> outboxEntriesProvider =
    StreamProvider<List<OutboxRow>>(
      (ref) => ref.watch(appDatabaseProvider).outboxDao.watchAll(),
    );

/// The client id of the entry being sent right now, if any.
final StreamProvider<String?> outboxSendingProvider = StreamProvider<String?>(
  (ref) => ref.watch(outboxProvider).sending,
);

/// What an entry is, for a list: "New product · Sablés" / "Error report".
({String title, String subtitle}) outboxEntryLabel(OutboxRow row) {
  try {
    if (row.kind == QueuedContribution.kind) {
      final queued = QueuedContribution.fromPayload(row.payload);
      return (
        title: queued.name ?? 'New product',
        subtitle: 'New product · ${queued.ean}',
      );
    }
    final json = jsonDecode(row.payload) as Map<String, Object?>;
    return (title: 'Error report', subtitle: 'Product ${json['ean']}');
  } on Object {
    return (title: 'Unreadable entry', subtitle: row.kind);
  }
}

/// Where an entry stands, in words.
String outboxStatusText(OutboxRow row, {required bool sending}) {
  if (sending) return 'Sending…';
  return switch (row.state) {
    OutboxState.refused => row.lastError ?? 'Not accepted.',
    OutboxState.needsSignIn => 'Sign in to send it.',
    OutboxState.waiting => switch ((row.lastError, row.nextAttemptAt)) {
      (null, _) => 'Waiting to be sent.',
      (final error?, final next?) =>
        '$error Next try at ${_time(next.toLocal())}.',
      (final error?, null) => '$error Will try again.',
    },
  };
}

String _time(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

/// The queue (`/outbox`): each entry's state, "Try now" and "Delete".
class OutboxScreen extends ConsumerWidget {
  const OutboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(outboxEntriesProvider);
    final sending = ref.watch(outboxSendingProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Waiting to be sent')),
      body: switch (entries) {
        AsyncData(value: final rows) when rows.isEmpty => const StateMessage(
          icon: PhosphorIconsRegular.checkCircle,
          title: 'Nothing waiting',
          message: 'Everything has been sent.',
        ),
        AsyncData(value: final rows) => ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24,
          ).clearOfNavigationBar(context),
          children: [
            Text(
              'Sent automatically while the app is open and online.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: QoutPalette.of(context).muted,
              ),
            ),
            const SizedBox(height: 12),
            for (final row in rows)
              _EntryCard(row: row, sending: row.clientId == sending),
          ],
        ),
        AsyncError() => const StateMessage(
          icon: PhosphorIconsRegular.warningCircle,
          title: 'Could not read the queue.',
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _EntryCard extends ConsumerWidget {
  const _EntryCard({required this.row, required this.sending});

  final OutboxRow row;
  final bool sending;

  Future<void> _tryNow(WidgetRef ref) async {
    await ref.read(appDatabaseProvider).outboxDao.retryNow(row.id);
    await ref.read(outboxTriggerProvider).sync();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final label = outboxEntryLabel(row);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete it?'),
        content: Text(
          '"${label.title}" will not be sent. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(outboxProvider).delete(row.clientId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final label = outboxEntryLabel(row);
    final refused = row.state == OutboxState.refused;
    final needsSignIn = row.state == OutboxState.needsSignIn;
    final palette = QoutPalette.of(context);
    final statusColor = refused ? theme.colorScheme.error : palette.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.title, style: theme.textTheme.titleSmall),
              Text(label.subtitle, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      refused
                          ? PhosphorIconsRegular.warningCircle
                          : needsSignIn
                          ? PhosphorIconsRegular.signIn
                          : PhosphorIconsRegular.cloudArrowUp,
                      size: 18,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      outboxStatusText(row, sending: sending),
                      style: TextStyle(
                        color: refused ? theme.colorScheme.error : null,
                      ),
                    ),
                  ),
                ],
              ),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: sending
                        ? null
                        : () => unawaited(_delete(context, ref)),
                    child: const Text('Delete'),
                  ),
                  if (needsSignIn)
                    TextButton(
                      onPressed: () => context.push(AppRoutes.signIn),
                      child: const Text('Sign in'),
                    )
                  else if (!refused)
                    TextButton(
                      onPressed: sending ? null : () => unawaited(_tryNow(ref)),
                      child: const Text('Try now'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// On the home screen while something is queued; opens the queue.
class OutboxCard extends ConsumerWidget {
  const OutboxCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(outboxEntriesProvider).valueOrNull ?? const [];
    if (rows.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final palette = QoutPalette.of(context);
    final refused = rows.where((r) => r.state == OutboxState.refused).length;
    final signIn = rows.where((r) => r.state == OutboxState.needsSignIn).length;
    final waiting = rows.length - refused - signIn;
    final parts = [
      if (waiting > 0) '$waiting waiting to be sent',
      if (signIn > 0) '$signIn need you to sign in',
      if (refused > 0) '$refused not accepted',
    ];
    final hint = refused > 0
        ? 'Open to see why.'
        : signIn > 0
        ? 'Open to sign in and send them.'
        : 'Sent automatically when Qout can be reached.';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.outbox),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
            child: Row(
              children: [
                Icon(
                  refused > 0
                      ? PhosphorIconsRegular.warningCircle
                      : PhosphorIconsRegular.cloudArrowUp,
                  size: 22,
                  color: refused > 0
                      ? theme.colorScheme.error
                      : palette.accentText,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parts.join(' · '),
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(hint, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 20,
                  color: palette.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
