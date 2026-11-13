import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/features/history/data/scan_history_repository.dart';
import 'package:qout/features/history/domain/history_entry.dart';

import '../../../helpers/fixtures.dart';

void main() {
  late AppDatabase database;
  late DateTime now;
  late ScanHistoryRepository repository;

  final t0 = DateTime.utc(2026, 11, 13, 9);
  final milk = recordedProduct('product-water');

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    now = t0;
    repository = ScanHistoryRepository(
      history: database.scanHistoryDao,
      clock: () => now,
    );
  });

  tearDown(() => database.close());

  Future<List<HistoryEntry>> entries() => repository.watch().first;

  Future<void> scanAt(String ean, int minutes) {
    now = t0.add(Duration(minutes: minutes));
    return repository.record(ean);
  }

  Future<void> cache(String ean, String json) =>
      database.productCacheDao.save({ean}, json: json, fetchedAt: t0);

  test('empty at first', () async {
    expect(await entries(), isEmpty);
  });

  test('newest first, with the scan time', () async {
    await scanAt('111', 0);
    await scanAt('222', 5);

    final [newest, oldest] = await entries();
    expect(
      (newest.ean, newest.scannedAt),
      ('222', t0.add(const Duration(minutes: 5))),
    );
    expect((oldest.ean, oldest.scannedAt), ('111', t0));
  });

  test('scanning a product again moves it to the top, once', () async {
    await scanAt('111', 0);
    await scanAt('222', 1);
    await scanAt('111', 2);

    expect((await entries()).map((e) => e.ean), ['111', '222']);
  });

  test('includes the saved product, or null', () async {
    await cache(milk.ean, jsonEncode(milk.toJson()));
    await scanAt(milk.ean, 0);
    await scanAt('6191234567897', 1);

    final [unknown, known] = await entries();
    expect(known.product, milk);
    expect(unknown.product, isNull);
  });

  test('a saved product that no longer reads is left out', () async {
    await cache('111', '{"not": "a product"}');
    await cache('222', 'not json');
    await scanAt('111', 0);
    await scanAt('222', 1);

    expect((await entries()).map((e) => e.product), [null, null]);
  });

  test('updates when a product is saved later (scanned offline)', () async {
    final updates = repository.watch().map(
      (list) => list.map((e) => e.product?.name).toList(),
    );
    await scanAt(milk.ean, 0);
    expect(await updates.first, [null]);

    await cache(milk.ean, jsonEncode(milk.toJson()));
    expect(await updates.first, [milk.name]);
  });

  test('remove, then restore at its original time', () async {
    await scanAt('111', 0);
    await scanAt('222', 1);
    await scanAt('333', 2);
    final removed = (await entries())[1];

    await repository.remove(removed);
    expect((await entries()).map((e) => e.ean), ['333', '111']);

    await repository.restore(removed);
    final restored = await entries();
    expect(restored.map((e) => e.ean), ['333', '222', '111']);
    expect(restored[1].scannedAt, removed.scannedAt);
  });

  test('clear', () async {
    await scanAt('111', 0);
    await scanAt('222', 1);

    await repository.clear();
    expect(await entries(), isEmpty);
  });

  test('shows at most the 100 most recent', () async {
    for (var i = 0; i < ScanHistoryRepository.maxEntries + 5; i++) {
      await scanAt('$i', i);
    }

    final list = await entries();
    expect(list, hasLength(100));
    expect(list.first.ean, '104');
  });
}
