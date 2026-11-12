import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/database/database.dart';

void main() {
  late AppDatabase database;
  final t0 = DateTime.utc(2026, 11, 12, 9, 30, 15, 123, 456);

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('schema version 1', () {
    expect(database.schemaVersion, 1);
  });

  group('product cache', () {
    test('save, find, replace and remove', () async {
      final cache = database.productCacheDao;
      await cache.save(['a', 'b', 'a'], json: '{"v": 1}', fetchedAt: t0);

      final a = await cache.find('a');
      expect((a!.json, a.fetchedAt), ('{"v": 1}', t0)); // microseconds kept
      expect(await cache.find('b'), isNotNull);
      expect(await cache.find('c'), isNull);

      final later = t0.add(const Duration(hours: 1));
      await cache.save({'a'}, json: '{"v": 2}', fetchedAt: later);
      expect((await cache.find('a'))!.json, '{"v": 2}');

      await cache.remove({'a', 'missing'});
      expect(await cache.find('a'), isNull);
      expect(await cache.find('b'), isNotNull);
    });

    test('times keep their UTC offset', () async {
      final local = DateTime(2026, 11, 12, 10);
      await database.productCacheDao.save({'a'}, json: '{}', fetchedAt: local);
      final stored = (await database.productCacheDao.find('a'))!.fetchedAt;
      expect(stored.isAtSameMomentAs(local), isTrue);
    });
  });

  group('scan history', () {
    test('newest first, live updates, delete one or all', () async {
      final history = database.scanHistoryDao;
      final updates = history.watchRecent().map(
        (rows) => rows.map((r) => r.ean).toList(),
      );
      expect(await updates.first, isEmpty);

      final first = await history.add('111', scannedAt: t0);
      await history.add('222', scannedAt: t0.add(const Duration(minutes: 1)));
      await history.add('333', scannedAt: t0.add(const Duration(minutes: 1)));
      expect(await updates.first, ['333', '222', '111']); // same time: by id

      await history.remove(first);
      expect(await updates.first, ['333', '222']);
      await history.clear();
      expect(await updates.first, isEmpty);
    });

    test('times are stored in UTC, so offsets never mix', () async {
      final summer = DateTime.parse('2026-06-01T12:00:00+02:00');
      final winter = DateTime.parse('2026-06-01T11:30:00+00:00');
      await database.scanHistoryDao.add('summer', scannedAt: summer);
      await database.scanHistoryDao.add('winter', scannedAt: winter);
      final [newest, oldest] = await database.scanHistoryDao
          .watchRecent()
          .first;
      expect((newest.ean, oldest.ean), ('winter', 'summer'));
      expect(newest.scannedAt.isUtc, isTrue);
    });

    test('limit', () async {
      for (var i = 0; i < 5; i++) {
        await database.scanHistoryDao.add(
          '$i',
          scannedAt: t0.add(Duration(minutes: i)),
        );
      }
      final rows = await database.scanHistoryDao.watchRecent(limit: 2).first;
      expect(rows.map((r) => r.ean), ['4', '3']);
    });
  });

  group('contribution outbox', () {
    test('enqueue, pending in order, failures counted, remove', () async {
      final outbox = database.outboxDao;
      final first = await outbox.enqueue(
        kind: 'new_product',
        payload: '{"ean": "1"}',
        createdAt: t0,
      );
      await outbox.enqueue(
        kind: 'new_product',
        payload: '{"ean": "2"}',
        createdAt: t0,
      );

      await outbox.recordFailure(first, 'offline');
      await outbox.recordFailure(first, 'HTTP 503');

      final [a, b] = await outbox.pending();
      expect((a.id, a.attempts, a.lastError), (first, 2, 'HTTP 503'));
      expect((b.attempts, b.lastError, b.kind), (0, null, 'new_product'));

      await outbox.remove(first);
      expect((await outbox.pending()).map((r) => r.payload), ['{"ean": "2"}']);
    });
  });
}
