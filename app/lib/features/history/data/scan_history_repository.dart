import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/database/database_provider.dart';
import 'package:qout/features/history/domain/history_entry.dart';

/// Scanned products, newest first, with what the phone knows about each.
/// Works offline: products come from the local product cache.
class ScanHistoryRepository {
  ScanHistoryRepository({
    required ScanHistoryDao history,
    DateTime Function()? clock,
  }) : _history = history,
       _clock = clock ?? DateTime.now;

  /// Entries shown at most (the DAO's default limit).
  static const maxEntries = 100;

  final ScanHistoryDao _history;
  final DateTime Function() _clock;

  /// Records a scan of [ean] now; an earlier entry for it moves to the top.
  Future<void> record(String ean) => _history.record(ean, scannedAt: _clock());

  /// The history, updated as scans or saved products change.
  Stream<List<HistoryEntry>> watch() => _history.watchRecentWithProducts().map(
    (rows) => [
      for (final (scan, cached) in rows)
        HistoryEntry(
          id: scan.id,
          ean: scan.ean,
          scannedAt: scan.scannedAt,
          product: _decode(cached),
        ),
    ],
  );

  Future<void> remove(HistoryEntry entry) => _history.remove(entry.id);

  /// Puts back a removed [entry] at its original time (undo).
  Future<void> restore(HistoryEntry entry) =>
      _history.record(entry.ean, scannedAt: entry.scannedAt);

  Future<void> clear() => _history.clear();

  /// A cached product that no longer reads (e.g. after an app update) is
  /// shown without details; the product screen refetches it.
  static ProductDetail? _decode(CachedProductRow? row) {
    if (row == null) return null;
    try {
      return ProductDetail.fromJson(
        jsonDecode(row.json) as Map<String, Object?>,
      );
    } on Object {
      return null;
    }
  }
}

final scanHistoryRepositoryProvider = Provider<ScanHistoryRepository>(
  (ref) => ScanHistoryRepository(
    history: ref.watch(appDatabaseProvider).scanHistoryDao,
  ),
);

/// The history list for the home screen.
final AutoDisposeStreamProvider<List<HistoryEntry>> scanHistoryProvider =
    StreamProvider.autoDispose(
      (ref) => ref.watch(scanHistoryRepositoryProvider).watch(),
    );
