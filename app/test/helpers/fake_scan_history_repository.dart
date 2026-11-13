import 'dart:async';

import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/history/data/scan_history_repository.dart';
import 'package:qout/features/history/domain/history_entry.dart';

/// In-memory scan history for widget tests (drift's live queries rely on
/// timers that fake-async widget tests never complete). Same behaviour as the
/// real repository: newest first, one entry per barcode.
class FakeScanHistoryRepository implements ScanHistoryRepository {
  FakeScanHistoryRepository({DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.utc(2026, 11, 13, 12));

  final DateTime Function() _clock;

  /// Saved products by barcode, as the product cache would hold them.
  final products = <String, ProductDetail>{};

  final _entries = <HistoryEntry>[];
  final _changes = StreamController<void>.broadcast(sync: true);
  int _nextId = 1;

  List<HistoryEntry> get entries => List.unmodifiable(_current());

  /// Adds [ean] as scanned at [at] (default: the clock).
  void seed(String ean, {DateTime? at, ProductDetail? product}) {
    if (product != null) products[ean] = product;
    _add(ean, at ?? _clock());
  }

  @override
  Future<void> record(String ean) async => _add(ean, _clock());

  @override
  Stream<List<HistoryEntry>> watch() async* {
    yield _current();
    yield* _changes.stream.map((_) => _current());
  }

  @override
  Future<void> remove(HistoryEntry entry) async {
    _entries.removeWhere((e) => e.id == entry.id);
    _changes.add(null);
  }

  @override
  Future<void> restore(HistoryEntry entry) async =>
      _add(entry.ean, entry.scannedAt);

  @override
  Future<void> clear() async {
    _entries.clear();
    _changes.add(null);
  }

  void _add(String ean, DateTime at) {
    _entries
      ..removeWhere((e) => e.ean == ean)
      ..add(HistoryEntry(id: _nextId++, ean: ean, scannedAt: at));
    _changes.add(null);
  }

  List<HistoryEntry> _current() {
    final sorted = [..._entries]
      ..sort((a, b) {
        final byTime = b.scannedAt.compareTo(a.scannedAt);
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });
    return [
      for (final e in sorted.take(ScanHistoryRepository.maxEntries))
        e.copyWith(product: products[e.ean]),
    ];
  }
}
