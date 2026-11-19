import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/database/database.dart';

void main() {
  late AppDatabase database;
  final t0 = DateTime.utc(2026, 11, 12, 9, 30, 15, 123, 456);

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('schema version 3', () {
    expect(database.schemaVersion, 3);
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

    test('record keeps one entry per barcode, at its latest scan', () async {
      final history = database.scanHistoryDao;
      await history.record('111', scannedAt: t0);
      await history.record(
        '222',
        scannedAt: t0.add(const Duration(minutes: 1)),
      );
      await history.record(
        '111',
        scannedAt: t0.add(const Duration(minutes: 2)),
      );

      final rows = await history.watchRecent().first;
      expect(rows.map((r) => (r.ean, r.scannedAt)), [
        ('111', t0.add(const Duration(minutes: 2))),
        ('222', t0.add(const Duration(minutes: 1))),
      ]);
    });

    test('with products: joined from the cache, live', () async {
      final history = database.scanHistoryDao;
      final updates = history.watchRecentWithProducts().map(
        (rows) => [
          for (final (scan, product) in rows) (scan.ean, product?.json),
        ],
      );
      await history.record('111', scannedAt: t0);
      await history.record(
        '222',
        scannedAt: t0.add(const Duration(minutes: 1)),
      );
      expect(await updates.first, [('222', null), ('111', null)]);

      await database.productCacheDao.save({'111'}, json: '{}', fetchedAt: t0);
      expect(await updates.first, [('222', null), ('111', '{}')]);

      final limited = await history.watchRecentWithProducts(limit: 1).first;
      expect(limited.single.$1.ean, '222');
    });
  });

  group('outbox', () {
    late OutboxDao outbox;

    setUp(() => outbox = database.outboxDao);

    Future<OutboxRow> add(String clientId, {String kind = 'new_product'}) =>
        outbox
            .enqueue(
              kind: kind,
              clientId: clientId,
              payload: '{"client_id": "$clientId"}',
              createdAt: t0,
            )
            .then((_) => outbox.find(clientId).then((row) => row!));

    test('enqueue: waiting, due at once; a client id queued once', () async {
      final a = await add('a');
      expect(
        (a.kind, a.state, a.attempts, a.nextAttemptAt, a.lastError),
        ('new_product', OutboxState.waiting, 0, null, null),
      );
      expect(a.createdAt, t0);
      final again = await outbox.enqueue(
        kind: 'new_product',
        clientId: 'a',
        payload: '{"other": true}',
        createdAt: t0,
      );
      expect(again, isFalse);
      expect((await outbox.find('a'))!.payload, '{"client_id": "a"}');
      expect(await outbox.find('missing'), isNull);
    });

    test('due: waiting entries whose time has come, oldest first', () async {
      final a = await add('a');
      final b = await add('b');
      final c = await add('c');
      await add('d');
      final later = t0.add(const Duration(minutes: 5));
      await outbox.recordRetry(a.id, error: 'offline', nextAttemptAt: later);
      await outbox.recordNeedsSignIn(b.id, 'sign in');
      await outbox.recordRefused(c.id, 'refused');

      expect((await outbox.due(t0)).map((r) => r.clientId), ['d']);
      expect(
        (await outbox.due(later)).map((r) => r.clientId),
        ['a', 'd'],
      );
      // Times compared in UTC whatever the zone given.
      expect(
        (await outbox.due(later.toLocal())).map((r) => r.clientId),
        ['a', 'd'],
      );
    });

    test('failures: state, attempts, reason, retry time', () async {
      final a = await add('a');
      final next = t0.add(const Duration(seconds: 30));
      await outbox.recordRetry(a.id, error: 'offline', nextAttemptAt: next);
      var row = (await outbox.find('a'))!;
      expect(
        (row.state, row.attempts, row.lastError, row.nextAttemptAt),
        (OutboxState.waiting, 1, 'offline', next),
      );

      await outbox.recordNeedsSignIn(a.id, 'Sign in to send it.');
      row = (await outbox.find('a'))!;
      expect(
        (row.state, row.attempts, row.nextAttemptAt),
        (OutboxState.needsSignIn, 2, null),
      );

      await outbox.recordRefused(a.id, 'Not accepted: salt');
      row = (await outbox.find('a'))!;
      expect(
        (row.state, row.attempts, row.lastError),
        (OutboxState.refused, 3, 'Not accepted: salt'),
      );
    });

    test('next attempt: the earliest retry time of waiting entries', () async {
      expect(await outbox.nextAttempt(), isNull);
      final a = await add('a');
      final b = await add('b');
      final c = await add('c');
      expect(await outbox.nextAttempt(), isNull); // due at once
      await outbox.recordRetry(
        a.id,
        error: 'x',
        nextAttemptAt: t0.add(const Duration(minutes: 9)),
      );
      await outbox.recordRetry(
        b.id,
        error: 'x',
        nextAttemptAt: t0.add(const Duration(minutes: 2)),
      );
      await outbox.recordRefused(c.id, 'x');
      expect(await outbox.nextAttempt(), t0.add(const Duration(minutes: 2)));
    });

    test('try now and after signing in: due again; refused stays', () async {
      final a = await add('a');
      final b = await add('b');
      final c = await add('c');
      await outbox.recordRetry(
        a.id,
        error: 'offline',
        nextAttemptAt: t0.add(const Duration(hours: 1)),
      );
      await outbox.recordNeedsSignIn(b.id, 'sign in');
      await outbox.recordRefused(c.id, 'refused');

      await outbox.retryNow(a.id);
      await outbox.retryNow(c.id);
      await outbox.resumeAfterSignIn();

      expect((await outbox.due(t0)).map((r) => r.clientId), ['a', 'b']);
      expect((await outbox.find('c'))!.state, OutboxState.refused);
      // The failures stay counted (the backoff continues from them).
      expect((await outbox.find('a'))!.attempts, 1);
    });

    test('payload updates, removal, and the watched list', () async {
      final a = await add('a');
      await add('b');
      final watched = outbox.watchAll();
      expect(
        (await watched.first).map((r) => r.clientId),
        ['a', 'b'],
      );
      await outbox.updatePayload(a.id, '{"done": 1}');
      expect((await outbox.find('a'))!.payload, '{"done": 1}');
      await outbox.remove(a.id);
      expect((await outbox.all()).map((r) => r.clientId), ['b']);
    });
  });
}
