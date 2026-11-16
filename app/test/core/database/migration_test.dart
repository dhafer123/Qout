import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/database/database.dart';

/// An app database at schema version 1 (T18), with rows: [sql] is run after
/// creating the tables.
QueryExecutor _version1(String sql) => NativeDatabase.memory(
  setup: (raw) {
    raw
      ..execute(
        File('test/fixtures/database/schema_v1.sql').readAsStringSync(),
      )
      ..execute(sql)
      ..execute('PRAGMA user_version = 1');
  },
);

/// Every table and index as SQLite stores it.
Future<List<String>> _schema(AppDatabase database) async {
  final rows = await database
      .customSelect(
        'SELECT type, name, tbl_name, sql FROM sqlite_master '
        "WHERE name NOT LIKE 'sqlite_sequence' ORDER BY type, name",
      )
      .get();
  return [
    for (final row in rows)
      [
        row.read<String>('type'),
        row.read<String>('name'),
        row.read<String>('tbl_name'),
        row.readNullable<String>('sql'),
      ].join(' | '),
  ];
}

void main() {
  test('1 -> 2: the outbox gets client id, state and retry time', () async {
    final migrated = AppDatabase(
      _version1('''
        INSERT INTO cached_products VALUES ('619', '{"ean": "619"}',
          '2026-11-12T09:30:00.000Z');
        INSERT INTO scan_history (ean, scanned_at)
          VALUES ('619', '2026-11-12T09:31:00.000Z');
        INSERT INTO contribution_outbox (kind, payload, created_at, attempts,
            last_error)
          VALUES ('error_report',
            '{"client_id": "0123456789abcdef0123456789abcdef", "ean": "619"}',
            '2026-11-13T10:00:00.000Z', 2, 'offline');
        INSERT INTO contribution_outbox (kind, payload, created_at)
          VALUES ('error_report', '{"ean": "619"}',
            '2026-11-13T10:05:00.000Z');
      '''),
    );
    addTearDown(migrated.close);

    final [report, withoutId] = await migrated.outboxDao.all();
    expect(report.clientId, '0123456789abcdef0123456789abcdef');
    expect(
      (
        report.kind,
        report.state,
        report.nextAttemptAt,
        report.attempts,
        report.lastError,
      ),
      ('error_report', OutboxState.waiting, null, 2, 'offline'),
    );
    expect(report.createdAt, DateTime.utc(2026, 11, 13, 10));
    // Not written by the app, but a migration must not fail on it.
    expect(withoutId.clientId, 'outbox-${withoutId.id}');

    // The other tables are untouched.
    expect(await migrated.productCacheDao.find('619'), isNotNull);
    expect(
      (await migrated.scanHistoryDao.watchRecent().first).single.ean,
      '619',
    );

    // Due at once: sent at the first sync after the update.
    expect(
      (await migrated.outboxDao.due(DateTime.utc(2026, 11, 16))).length,
      2,
    );

    // Same schema as a database created at version 2.
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    expect(await _schema(migrated), await _schema(fresh));
    expect(
      await migrated
          .customSelect('PRAGMA user_version')
          .map((row) => row.read<int>('user_version'))
          .getSingle(),
      2,
    );
  });

  test('1 -> 2: client ids stay unique', () async {
    final migrated = AppDatabase(_version1(''));
    addTearDown(migrated.close);
    final created = DateTime.utc(2026, 11, 16);
    expect(
      await migrated.outboxDao.enqueue(
        kind: 'error_report',
        clientId: 'x',
        payload: '{}',
        createdAt: created,
      ),
      isTrue,
    );
    expect(
      await migrated.outboxDao.enqueue(
        kind: 'error_report',
        clientId: 'x',
        payload: '{}',
        createdAt: created,
      ),
      isFalse,
    );
  });
}
