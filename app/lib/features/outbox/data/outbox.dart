import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/core/api/api_providers.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/database/database_provider.dart';
import 'package:qout/features/contribute/data/contribution_repository.dart';
import 'package:qout/features/outbox/data/outbox_files.dart';
import 'package:qout/features/outbox/domain/queued_contribution.dart';
import 'package:qout/features/outbox/domain/send_outcome.dart';

/// Outbox `kind` of error reports (queued since T20).
const errorReportKind = 'error_report';

/// Sends what the app queued (new products, error reports) when it can.
///
/// One thing at a time: runs and single sends wait for each other, so an
/// entry is never sent twice at once. Each entry has a client id the backend
/// uses to store a resend once, so an answer lost on the way is safe.
class Outbox {
  Outbox({
    required OutboxDao dao,
    required ContributionRepository contributions,
    required Future<void> Function(ReportCreate report) sendReport,
    required OutboxFiles files,
    DateTime Function()? clock,
    Random? random,
  }) : _dao = dao,
       _contributions = contributions,
       _sendReport = sendReport,
       _files = files,
       _clock = clock ?? DateTime.now,
       _random = random ?? Random();

  final OutboxDao _dao;
  final ContributionRepository _contributions;
  final Future<void> Function(ReportCreate report) _sendReport;
  final OutboxFiles _files;
  final DateTime Function() _clock;
  final Random _random;

  Future<void> _tail = Future.value();
  Future<void>? _queuedRun;
  final _sending = StreamController<String?>.broadcast();

  /// The client id of the entry being sent, null between entries.
  Stream<String?> get sending => _sending.stream;

  /// Queues a new product: its photos are copied out of the picker's
  /// temporary files first. False when [create]'s client id is queued already.
  Future<bool> addContribution(
    ContributionCreate create,
    Map<PhotoKind, String> photos,
  ) async {
    final kept = {
      for (final MapEntry(:key, :value) in photos.entries)
        key: await _files.keep(create.clientId, key, value),
    };
    return _dao.enqueue(
      kind: QueuedContribution.kind,
      clientId: create.clientId,
      payload: QueuedContribution.of(create, kept).toPayload(),
      createdAt: _clock(),
    );
  }

  /// Sends the entries due now, oldest first. A call during a run starts one
  /// more run after it (for entries queued meanwhile); calls before that
  /// share it.
  Future<void> run() => _queuedRun ??= _locked(() {
    _queuedRun = null;
    return _runDue();
  });

  Future<void> _runDue() async {
    for (final row in await _dao.due(_clock())) {
      await _send(row);
    }
  }

  /// Sends entry [clientId] now, whatever its retry time; what happened. An
  /// entry no longer queued was sent already.
  Future<SendOutcome> sendNow(String clientId) => _locked(() async {
    final row = await _dao.find(clientId);
    return row == null ? const Sent() : _send(row);
  });

  /// Deletes entry [clientId] and its photos, unsent.
  Future<void> delete(String clientId) => _locked(() async {
    final row = await _dao.find(clientId);
    if (row != null) await _dao.remove(row.id);
    await _files.remove(clientId);
  });

  /// When the next waiting entry is due, if one waits for a time.
  Future<DateTime?> nextAttempt() => _dao.nextAttempt();

  Future<SendOutcome> _send(OutboxRow row) async {
    _announce(row.clientId);
    SendOutcome outcome;
    try {
      await switch (row.kind) {
        QueuedContribution.kind => _sendContribution(row),
        errorReportKind => _sendReport(
          ReportCreate.fromJson(
            jsonDecode(row.payload) as Map<String, Object?>,
          ),
        ),
        final kind => throw FormatException('unknown outbox kind $kind'),
      };
      outcome = const Sent();
    } on Object catch (error) {
      outcome = outcomeOf(
        error is TypeError ? FormatException('$error') : error,
      );
    }
    switch (outcome) {
      case Sent():
        await _dao.remove(row.id);
        await _files.remove(row.clientId);
      case RetryLater(:final message, :final after):
        await _dao.recordRetry(
          row.id,
          error: message,
          nextAttemptAt: _clock().add(
            after ?? retryDelay(row.attempts + 1, _random),
          ),
        );
      case NeedsSignIn(:final message):
        await _dao.recordNeedsSignIn(row.id, message);
      case Refused(:final message):
        await _dao.recordRefused(row.id, message);
    }
    _announce(null);
    return outcome;
  }

  /// Closed with the provider, possibly while a send finishes.
  void _announce(String? clientId) {
    if (!_sending.isClosed) _sending.add(clientId);
  }

  Future<void> _sendContribution(OutboxRow row) async {
    var queued = QueuedContribution.fromPayload(row.payload);
    for (final kind in queued.toUpload) {
      final key = await _contributions.uploadPhoto(
        clientId: queued.clientId,
        kind: kind,
        path: queued.photos[kind]!.path,
      );
      queued = queued.withKey(kind, key);
      // Kept at once: a later failure doesn't upload this photo again.
      await _dao.updatePayload(row.id, queued.toPayload());
    }
    await _contributions.submit(queued.create());
  }

  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> close() => _sending.close();
}

final Provider<Outbox> outboxProvider = Provider<Outbox>((ref) {
  final api = ref.watch(qoutApiProvider);
  final outbox = Outbox(
    dao: ref.watch(appDatabaseProvider).outboxDao,
    contributions: ref.watch(contributionRepositoryProvider),
    sendReport: (report) => api.reportError(body: report),
    files: ref.watch(outboxFilesProvider),
  );
  ref.onDispose(outbox.close);
  return outbox;
});
