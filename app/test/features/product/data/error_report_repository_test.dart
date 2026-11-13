import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/features/product/data/error_report_repository.dart';
import 'package:qout/features/product/domain/error_report.dart';

void main() {
  late AppDatabase database;
  late ErrorReportRepository repository;

  final now = DateTime.utc(2026, 11, 13, 10, 30);
  final productUpdatedAt = DateTime.utc(2026, 11, 12, 17, 18, 43);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = ErrorReportRepository(
      outbox: database.outboxDao,
      clock: () => now,
      newId: () => 'id-1',
    );
  });

  tearDown(() => database.close());

  Future<void> submit(
    Set<ErrorReportReason> reasons, {
    String comment = '',
  }) => repository.submit(
    ean: '6191234567897',
    reasons: reasons,
    comment: comment,
    productUpdatedAt: productUpdatedAt,
  );

  test('queues the report in the outbox', () async {
    await submit({
      ErrorReportReason.grade,
      ErrorReportReason.name,
    }, comment: '  Salt is 0.3 g on the pack \n');

    final [row] = await database.outboxDao.pending();
    expect(row.kind, 'error_report');
    expect(row.createdAt, now);
    expect(row.attempts, 0);
    expect(jsonDecode(row.payload), {
      'client_id': 'id-1',
      'ean': '6191234567897',
      'reasons': ['name', 'grade'],
      'comment': 'Salt is 0.3 g on the pack',
      'product_updated_at': '2026-11-12T17:18:43.000Z',
      'created_at': '2026-11-13T10:30:00.000Z',
    });
  });

  test('an empty comment is sent as null', () async {
    await submit({ErrorReportReason.nutrition}, comment: '   ');

    final [row] = await database.outboxDao.pending();
    expect((jsonDecode(row.payload) as Map)['comment'], isNull);
  });

  test('refuses an invalid report and queues nothing', () async {
    await expectLater(submit({}), throwsArgumentError);
    await expectLater(submit({ErrorReportReason.other}), throwsArgumentError);
    expect(await database.outboxDao.pending(), isEmpty);
  });

  test('each report gets its own id by default', () async {
    repository = ErrorReportRepository(outbox: database.outboxDao);
    await submit({ErrorReportReason.name});
    await submit({ErrorReportReason.name});

    final ids = [
      for (final row in await database.outboxDao.pending())
        (jsonDecode(row.payload) as Map)['client_id'],
    ];
    expect(ids.toSet(), hasLength(2));
  });

  test('client ids are 32 hex digits', () {
    expect(newClientId(), matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(newClientId(Random(1)), newClientId(Random(1)));
    expect(newClientId(Random(1)), isNot(newClientId(Random(2))));
  });
}
