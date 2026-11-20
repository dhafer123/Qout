import 'dart:async';

import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/diary/data/diary_repository.dart';
import 'package:qout/health/diary.dart';

/// In-memory diary for widget tests (drift's live queries rely on timers
/// that fake-async widget tests never complete). Builds entries with the
/// real repository's functions.
class FakeDiaryRepository implements DiaryRepository {
  FakeDiaryRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final _entries = <DiaryEntry>[];
  final _changes = StreamController<void>.broadcast(sync: true);
  int _nextId = 1;

  List<DiaryEntry> get entries => List.unmodifiable(_entries);

  /// Adds [entry] as if logged (its id is replaced).
  DiaryEntry seed(DiaryEntry entry) {
    final saved = DiaryEntry(
      id: _nextId++,
      eatenAt: entry.eatenAt,
      meal: entry.meal,
      ean: entry.ean,
      name: entry.name,
      brand: entry.brand,
      imageUrl: entry.imageUrl,
      grade: entry.grade,
      novaGroup: entry.novaGroup,
      unit: entry.unit,
      amount: entry.amount,
      servingQuantity: entry.servingQuantity,
      values: entry.values,
    );
    _entries.add(saved);
    _changes.add(null);
    return saved;
  }

  @override
  Stream<List<DiaryEntry>> watchDay(DateTime day) {
    final start = dayOf(day);
    return watchBetween(
      start,
      DateTime(start.year, start.month, start.day + 1),
    );
  }

  @override
  Stream<List<DiaryEntry>> watchBetween(DateTime from, DateTime to) async* {
    List<DiaryEntry> current() => [
      for (final e in _entries)
        if (!e.eatenAt.isBefore(from) && e.eatenAt.isBefore(to)) e,
    ]..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
    yield current();
    yield* _changes.stream.map((_) => current());
  }

  @override
  Future<void> logProduct(
    ProductDetail product, {
    required double amount,
    required Meal meal,
    DateTime? day,
  }) async => seed(
    diaryEntryOf(
      product,
      amount: amount,
      meal: meal,
      eatenAt: eatenAtFor(day, _clock()),
    ),
  );

  @override
  Future<void> quickAdd({
    required double kcal,
    required Meal meal,
    String? name,
    DateTime? day,
  }) async => seed(
    quickAddEntry(
      kcal: kcal,
      meal: meal,
      name: name,
      eatenAt: eatenAtFor(day, _clock()),
    ),
  );

  @override
  Future<void> change(DiaryEntry entry) async {
    final i = _entries.indexWhere((e) => e.id == entry.id);
    if (i >= 0) _entries[i] = entry;
    _changes.add(null);
  }

  @override
  Future<void> remove(DiaryEntry entry) async {
    _entries.removeWhere((e) => e.id == entry.id);
    _changes.add(null);
  }

  @override
  Future<void> restore(DiaryEntry entry) async {
    _entries.add(entry);
    _changes.add(null);
  }

  @override
  Future<void> clear() async {
    _entries.clear();
    _changes.add(null);
  }
}
