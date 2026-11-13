import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/database/database_provider.dart';
import 'package:qout/features/product/domain/error_report.dart';

/// Saves "report an error" submissions in the outbox, which sends them to the
/// backend (T30). Works offline.
class ErrorReportRepository {
  ErrorReportRepository({
    required OutboxDao outbox,
    DateTime Function()? clock,
    String Function()? newId,
  }) : _outbox = outbox,
       _clock = clock ?? DateTime.now,
       _newId = newId ?? newClientId;

  /// Outbox `kind` of these entries.
  static const outboxKind = 'error_report';

  final OutboxDao _outbox;
  final DateTime Function() _clock;
  final String Function() _newId;

  /// Queues a report on product [ean] as the user saw it ([productUpdatedAt]
  /// identifies that version). Throws [ArgumentError] if
  /// [validateErrorReport] finds a problem.
  Future<void> submit({
    required String ean,
    required Set<ErrorReportReason> reasons,
    required String comment,
    required DateTime productUpdatedAt,
  }) async {
    final problem = validateErrorReport(reasons: reasons, comment: comment);
    if (problem != null) {
      throw ArgumentError.value(problem, 'report', 'cannot be sent');
    }
    final text = comment.trim();
    final now = _clock().toUtc();
    final payload = {
      // Lets the backend ignore a report sent twice (retries, T30).
      'client_id': _newId(),
      'ean': ean,
      'reasons': [
        for (final reason in ErrorReportReason.values)
          if (reasons.contains(reason)) reason.value,
      ],
      'comment': text.isEmpty ? null : text,
      'product_updated_at': productUpdatedAt.toUtc().toIso8601String(),
      'created_at': now.toIso8601String(),
    };
    await _outbox.enqueue(
      kind: outboxKind,
      payload: jsonEncode(payload),
      createdAt: now,
    );
  }
}

/// A random 128-bit id as 32 hex digits.
String newClientId([Random? random]) {
  final source = random ?? Random.secure();
  return [
    for (var i = 0; i < 16; i++)
      source.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

final errorReportRepositoryProvider = Provider<ErrorReportRepository>(
  (ref) => ErrorReportRepository(
    outbox: ref.watch(appDatabaseProvider).outboxDao,
  ),
);
