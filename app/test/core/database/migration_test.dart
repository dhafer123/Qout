import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/database/database.dart';

/// An app database at schema [version] (fixture
/// `test/fixtures/database/schema_v<version>.sql`), with rows: [sql] is run
/// after creating the tables.
QueryExecutor _atVersion(int version, String sql) => NativeDatabase.memory(
  setup: (raw) {
    raw
      ..execute(
        File(
          'test/fixtures/database/schema_v$version.sql',
        ).readAsStringSync(),
      )
      ..execute(sql)
      ..execute('PRAGMA user_version = $version');
  },
);

QueryExecutor _version1(String sql) => _atVersion(1, sql);

/// The schema version `user_version` says.
Future<int> _userVersion(AppDatabase database) => database
    .customSelect('PRAGMA user_version')
    .map((row) => row.read<int>('user_version'))
    .getSingle();

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

    // Same schema as a database created at the current version.
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    expect(await _schema(migrated), await _schema(fresh));
    expect(await _userVersion(migrated), fresh.schemaVersion);
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

  test(
    '2 -> 3: the profile table, empty: the welcome screens show once',
    () async {
      final migrated = AppDatabase(
        _atVersion(2, '''
        INSERT INTO scan_history (ean, scanned_at)
          VALUES ('619', '2026-11-12T09:31:00.000Z');
        INSERT INTO contribution_outbox (kind, client_id, payload, created_at)
          VALUES ('error_report', 'r1', '{}', '2026-11-13T10:00:00.000Z');
      '''),
      );
      addTearDown(migrated.close);

      expect(await migrated.profileDao.get(), isNull);
      // The other tables are untouched.
      expect(
        (await migrated.scanHistoryDao.watchRecent().first).single.ean,
        '619',
      );
      expect((await migrated.outboxDao.all()).single.clientId, 'r1');

      final fresh = AppDatabase(NativeDatabase.memory());
      addTearDown(fresh.close);
      expect(await _schema(migrated), await _schema(fresh));
      expect(await _userVersion(migrated), fresh.schemaVersion);
    },
  );

  test('3 -> 4: the profile gets a first name, the rest is kept', () async {
    final migrated = AppDatabase(
      _atVersion(3, '''
        INSERT INTO local_profile (id, onboarding_completed_at, sex, age,
            age_entered_at, height_cm, weight_kg, pal, allergens,
            avoided_additives)
          VALUES (1, '2026-11-18T09:00:00.000Z', 'male', 23,
            '2026-11-18T09:00:00.000Z', 178, 60, '1.6', '["milk"]',
            '["E330"]');
        INSERT INTO scan_history (ean, scanned_at)
          VALUES ('619', '2026-11-19T09:31:00.000Z');
      '''),
    );
    addTearDown(migrated.close);

    final row = (await migrated.profileDao.get())!;
    expect(row.firstName, isNull);
    expect(
      (row.sex, row.age, row.heightCm, row.weightKg, row.pal),
      (
        'male',
        23,
        178.0,
        60.0,
        '1.6',
      ),
    );
    expect((row.allergens, row.avoidedAdditives), ('["milk"]', '["E330"]'));
    expect(
      (await migrated.scanHistoryDao.watchRecent().first).single.ean,
      '619',
    );

    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    expect(await _schema(migrated), await _schema(fresh));
    expect(await _userVersion(migrated), fresh.schemaVersion);
  });

  test('4 -> 5: an empty diary, the rest kept', () async {
    final migrated = AppDatabase(
      _atVersion(4, '''
        INSERT INTO local_profile (id, onboarding_completed_at, sex, age,
            age_entered_at, height_cm, weight_kg, pal, first_name)
          VALUES (1, '2026-11-18T09:00:00.000Z', 'male', 23,
            '2026-11-18T09:00:00.000Z', 178, 60, '1.6', 'Dhafer');
        INSERT INTO scan_history (ean, scanned_at)
          VALUES ('619', '2026-11-19T09:31:00.000Z');
      '''),
    );
    addTearDown(migrated.close);

    expect(
      await migrated.diaryDao.between(DateTime(2000), DateTime(2100)),
      isEmpty,
    );
    expect((await migrated.profileDao.get())!.firstName, 'Dhafer');
    expect(
      (await migrated.scanHistoryDao.watchRecent().first).single.ean,
      '619',
    );

    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    expect(await _schema(migrated), await _schema(fresh));
    expect(await _userVersion(migrated), fresh.schemaVersion);
  });

  test('5 -> 6: no settings saved (theme follows the phone), the rest '
      'kept', () async {
    final migrated = AppDatabase(
      _atVersion(5, '''
        INSERT INTO local_profile (id, onboarding_completed_at, first_name)
          VALUES (1, '2026-11-18T09:00:00.000Z', 'Dhafer');
        INSERT INTO diary_entries (eaten_at, meal, energy_kj)
          VALUES ('2026-11-22T12:00:00.000Z', 'lunch', 2000);
      '''),
    );
    addTearDown(migrated.close);

    expect(await migrated.settingsDao.themeMode(), isNull);
    expect((await migrated.profileDao.get())!.firstName, 'Dhafer');
    expect(
      (await migrated.diaryDao.between(
        DateTime(2000),
        DateTime(2100),
      )).single.energyKj,
      2000,
    );

    // Saving works on the migrated table.
    await migrated.settingsDao.saveThemeMode('dark');
    expect(await migrated.settingsDao.themeMode(), 'dark');

    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    expect(await _schema(migrated), await _schema(fresh));
    expect(await _userVersion(migrated), fresh.schemaVersion);
  });
}
