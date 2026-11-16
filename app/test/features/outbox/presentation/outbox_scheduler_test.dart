import 'dart:async';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/database/database_provider.dart';
import 'package:qout/core/env/app_env.dart';
import 'package:qout/features/outbox/data/outbox.dart';
import 'package:qout/features/outbox/presentation/outbox_scheduler.dart';
import 'package:qout/features/product/data/error_report_repository.dart';
import 'package:qout/features/product/domain/error_report.dart';

import '../../../helpers/fake_contribution.dart';
import '../../../helpers/fake_outbox.dart';

/// A timer the test fires by hand.
class _Timer implements Timer {
  _Timer(this.wait, this.callback);

  final Duration wait;
  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

class _MidRandom implements Random {
  @override
  double nextDouble() => 0.5;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase database;
  late List<QoutApiException> reportAnswers;
  late List<ReportCreate> sent;
  late DateTime now;
  late List<_Timer> timers;
  late Outbox outbox;
  late OutboxScheduler scheduler;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    reportAnswers = [];
    sent = [];
    now = DateTime.utc(2026, 11, 16, 15);
    timers = [];
    outbox = Outbox(
      dao: database.outboxDao,
      contributions: FakeContribution().repository,
      sendReport: (report) async {
        if (reportAnswers.isNotEmpty) throw reportAnswers.removeAt(0);
        sent.add(report);
      },
      files: FakeOutboxFiles(),
      clock: () => now,
      random: _MidRandom(),
    );
    scheduler = OutboxScheduler(
      outbox: outbox,
      dao: database.outboxDao,
      clock: () => now,
      timer: (wait, callback) {
        final timer = _Timer(wait, callback);
        timers.add(timer);
        return timer;
      },
    );
  });

  tearDown(() async {
    scheduler.dispose();
    await outbox.close();
    await database.close();
  });

  Future<void> report(String id) =>
      ErrorReportRepository(
        outbox: database.outboxDao,
        clock: () => now,
        newId: () => id,
      ).submit(
        ean: '6194039501011',
        reasons: {ErrorReportReason.grade},
        comment: '',
        productUpdatedAt: DateTime.utc(2026, 11, 12),
      );

  test('sends what is due; no timer when nothing waits', () async {
    await report('a' * 32);
    await scheduler.sync();
    expect(sent, hasLength(1));
    expect(timers, isEmpty);
  });

  test('a failure sets a timer for the retry, which sends it', () async {
    await report('a' * 32);
    reportAnswers.add(const ApiConnectionError('offline'));

    await scheduler.sync();
    expect(sent, isEmpty);
    expect(timers.single.wait, const Duration(seconds: 30));

    now = now.add(const Duration(seconds: 30));
    timers.single.callback();
    await pumpEventQueue();
    expect(sent, hasLength(1));
    expect(timers, hasLength(1)); // nothing left: no new timer
  });

  test('a new sync replaces the timer; an overdue retry waits 0', () async {
    await report('a' * 32);
    reportAnswers.addAll([
      const ApiConnectionError('offline'),
      const ApiConnectionError('offline'),
    ]);
    await scheduler.sync();
    now = now.add(const Duration(minutes: 5)); // the app was paused
    await database.outboxDao.recordRetry(
      (await database.outboxDao.all()).single.id,
      error: 'offline',
      nextAttemptAt: now.subtract(const Duration(seconds: 1)),
    );
    await scheduler.sync(); // sends (fails again): next in 2 min
    expect(timers.first.cancelled, isTrue);
    expect(timers.last.wait, const Duration(minutes: 2));
  });

  test('after signing in, the entries that needed it are sent', () async {
    await report('a' * 32);
    reportAnswers.add(const ApiUnauthorized('x'));
    await scheduler.sync();
    expect(
      (await database.outboxDao.all()).single.state,
      OutboxState.needsSignIn,
    );

    await scheduler.signedIn();
    expect(sent, hasLength(1));
  });

  test('disposed: no new timer', () async {
    await report('a' * 32);
    reportAnswers.add(const ApiConnectionError('offline'));
    final running = scheduler.sync();
    scheduler.dispose();
    await running;
    expect(timers, isEmpty);
  });

  test('the provider wires the outbox to the database', () {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        appEnvProvider.overrideWithValue(AppEnv.resolve(flavorName: 'dev')),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(outboxTriggerProvider), isA<OutboxScheduler>());
    expect(container.read(outboxProvider), isA<Outbox>());
  });
}
