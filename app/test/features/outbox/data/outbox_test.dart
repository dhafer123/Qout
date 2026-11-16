import 'dart:async';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/features/contribute/data/contribution_repository.dart';
import 'package:qout/features/outbox/data/outbox.dart';
import 'package:qout/features/outbox/domain/queued_contribution.dart';
import 'package:qout/features/outbox/domain/send_outcome.dart';
import 'package:qout/features/product/data/error_report_repository.dart';
import 'package:qout/features/product/domain/error_report.dart';

import '../../../helpers/fake_contribution.dart';
import '../../../helpers/fake_outbox.dart';

/// Jitter factor 1: delays are exactly the backoff schedule.
class _MidRandom implements Random {
  @override
  double nextDouble() => 0.5;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _id = '1b4e28ba-2fa1-4d3b-a3f5-ef19b6a7c001';

ContributionCreate _create([String clientId = _id]) => ContributionCreate(
  clientId: clientId,
  ean: '6191234567897',
  name: 'Sablés',
  category: Category.general,
  basis: NutritionBasis.per100g,
  nutrition: const NutritionValues(energyKj: 1046, saltG: 0.85),
  photos: const ContributionPhotos(front: '', nutrition: ''),
  ocrText: const ContributionOcr(nutrition: 'Sel 0,85 g'),
  parserUsed: ParserUsed.rules,
);

const Map<PhotoKind, String> _photos = {
  PhotoKind.front: 'front.jpg',
  PhotoKind.nutrition: 'nutrition.jpg',
  PhotoKind.ingredients: 'png-ingredients.png',
};

void main() {
  late AppDatabase database;
  late FakeContribution fake;
  late FakeOutboxFiles files;
  late List<ReportCreate> reports;
  late List<QoutApiException> reportErrors;
  late DateTime now;
  late Outbox outbox;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    fake = FakeContribution();
    files = FakeOutboxFiles();
    reports = [];
    reportErrors = [];
    now = DateTime.utc(2026, 11, 16, 15);
    outbox = Outbox(
      dao: database.outboxDao,
      contributions: fake.repository,
      sendReport: (report) async {
        if (reportErrors.isNotEmpty) throw reportErrors.removeAt(0);
        reports.add(report);
      },
      files: files,
      clock: () => now,
      random: _MidRandom(),
    );
  });

  tearDown(() async {
    await outbox.close();
    await database.close();
  });

  Future<OutboxRow?> row([String clientId = _id]) =>
      database.outboxDao.find(clientId);

  Future<void> queueReport(String clientId) =>
      ErrorReportRepository(
        outbox: database.outboxDao,
        clock: () => now,
        newId: () => clientId,
      ).submit(
        ean: '6194039501011',
        reasons: {ErrorReportReason.nutrition},
        comment: 'Salt is 0.3 g',
        productUpdatedAt: DateTime.utc(2026, 11, 12),
      );

  group('queueing a contribution', () {
    test('photos kept, request without keys, once per client id', () async {
      expect(await outbox.addContribution(_create(), _photos), isTrue);

      expect(files.kept.map((k) => (k.$2, k.$3)), [
        (PhotoKind.front, 'front.jpg'),
        (PhotoKind.nutrition, 'nutrition.jpg'),
        (PhotoKind.ingredients, 'png-ingredients.png'),
      ]);
      final queued = QueuedContribution.fromPayload((await row())!.payload);
      expect(queued.clientId, _id);
      expect(queued.request.containsKey('photos'), isFalse);
      expect(queued.photos[PhotoKind.front]!.path, 'outbox/$_id/front.jpg');
      expect(queued.toUpload, hasLength(3));
      expect((await row())!.kind, 'new_product');

      expect(await outbox.addContribution(_create(), _photos), isFalse);
      expect(await database.outboxDao.all(), hasLength(1));
    });

    test('a photo that cannot be kept: nothing queued', () async {
      files.keepError = Exception('disk full');
      await expectLater(
        outbox.addContribution(_create(), _photos),
        throwsException,
      );
      expect(await database.outboxDao.all(), isEmpty);
    });
  });

  group('run', () {
    test('a contribution: photos uploaded, then submitted; gone', () async {
      await outbox.addContribution(_create(), _photos);
      await outbox.run();

      expect(fake.api.uploads.map((u) => (u.contributionId, u.kind)), [
        (_id, PhotoKind.front),
        (_id, PhotoKind.nutrition),
        (_id, PhotoKind.ingredients),
      ]);
      expect(fake.puts.map((p) => p.$3), [
        'image/jpeg',
        'image/jpeg',
        'image/png',
      ]);
      final body = fake.api.submitted.single;
      expect(body.clientId, _id);
      expect(body.name, 'Sablés');
      expect(body.nutrition.saltG, 0.85);
      expect(body.ocrText?.nutrition, 'Sel 0,85 g');
      expect(body.photos.front, 'contributions/$_id/front.jpg');
      expect(body.photos.ingredients, 'contributions/$_id/ingredients.jpg');
      expect(await row(), isNull);
      expect(files.removed, [_id]);
    });

    test('an error report goes to POST /v1/reports', () async {
      await queueReport('0123456789abcdef0123456789abcdef');
      await outbox.run();

      final report = reports.single;
      expect(report.clientId, '0123456789abcdef0123456789abcdef');
      expect(report.ean, '6194039501011');
      expect(report.reasons, [ReportReason.nutrition]);
      expect(report.comment, 'Salt is 0.3 g');
      expect(report.createdAt, now);
      expect(await database.outboxDao.all(), isEmpty);
    });

    test('oldest first; a failing entry does not stop the next', () async {
      await queueReport('0123456789abcdef0123456789abcde1');
      await outbox.addContribution(_create(), _photos);
      await queueReport('0123456789abcdef0123456789abcde2');
      reportErrors.add(const ApiConnectionError('offline'));

      await outbox.run();

      expect(reports.map((r) => r.clientId), [
        '0123456789abcdef0123456789abcde2',
      ]);
      expect(fake.api.submitted, hasLength(1));
      final [left] = await database.outboxDao.all();
      expect(left.clientId, '0123456789abcdef0123456789abcde1');
    });

    test('nothing queued: nothing sent', () async {
      await outbox.run();
      expect(fake.api.uploads, isEmpty);
      expect(reports, isEmpty);
    });
  });

  group('retry with backoff', () {
    test('offline: waits 30 s, then 60 s, ...', () async {
      await outbox.addContribution(_create(), _photos);
      fake.api.uploadErrors.addAll([
        const ApiConnectionError('offline'),
        const ApiConnectionError('offline'),
      ]);

      await outbox.run();
      var queued = (await row())!;
      expect(queued.state, OutboxState.waiting);
      expect(queued.attempts, 1);
      expect(queued.lastError, 'No connection to Qout.');
      expect(queued.nextAttemptAt, now.add(const Duration(seconds: 30)));

      // Not due yet: a run sends nothing.
      await outbox.run();
      expect(fake.api.uploads, hasLength(1));

      now = now.add(const Duration(seconds: 30));
      await outbox.run();
      queued = (await row())!;
      expect(queued.attempts, 2);
      expect(queued.nextAttemptAt, now.add(const Duration(minutes: 1)));

      now = now.add(const Duration(minutes: 1));
      await outbox.run();
      expect(await row(), isNull);
      expect(fake.api.submitted, hasLength(1));
    });

    test("the server's Retry-After wins over the backoff", () async {
      await outbox.addContribution(_create(), _photos);
      fake.api.submitErrors.add(
        const ApiUnavailable('busy', retryAfter: Duration(minutes: 7)),
      );
      await outbox.run();
      final queued = (await row())!;
      expect(queued.lastError, 'Qout is busy.');
      expect(queued.nextAttemptAt, now.add(const Duration(minutes: 7)));
    });

    test('photos uploaded once across retries', () async {
      await outbox.addContribution(_create(), _photos);
      fake.putErrors.add(const PhotoUploadError('no connection to storage'));
      fake.puts.clear();

      await outbox.run(); // front: ticket, then the PUT fails
      expect(fake.puts, isEmpty);
      now = now.add(const Duration(seconds: 30));
      fake.api.submitErrors.add(const ApiConnectionError('lost'));
      await outbox.run(); // all three uploaded; submit lost
      expect(fake.puts, hasLength(3));
      final queued = QueuedContribution.fromPayload((await row())!.payload);
      expect(queued.toUpload, isEmpty);

      now = now.add(const Duration(minutes: 1));
      await outbox.run(); // only the submit again
      expect(fake.puts, hasLength(3));
      expect(fake.api.submitted, hasLength(2));
      expect(await row(), isNull);
    });

    test('a lost answer: the resend has the same client id', () async {
      await outbox.addContribution(_create(), _photos);
      fake.api.submitErrors.add(const ApiConnectionError('timeout'));
      await outbox.run();
      now = now.add(const Duration(seconds: 30));
      await outbox.run();
      // The backend stores a client id once (200 for the resend).
      expect(fake.api.submitted.map((b) => b.clientId), [_id, _id]);
      expect(await row(), isNull);
    });
  });

  group('not retried by itself', () {
    test('401: needs sign-in, then due again after signing in', () async {
      await outbox.addContribution(_create(), _photos);
      fake.api.uploadErrors.add(const ApiUnauthorized('expired'));
      await outbox.run();
      expect((await row())!.state, OutboxState.needsSignIn);
      expect((await row())!.lastError, 'Sign in to send it.');

      now = now.add(const Duration(days: 1));
      await outbox.run();
      expect(fake.api.uploads, hasLength(1));

      await database.outboxDao.resumeAfterSignIn();
      await outbox.run();
      expect(await row(), isNull);
    });

    test('422: refused with the reason; photos kept until deleted', () async {
      await outbox.addContribution(_create(), _photos);
      fake.api.submitErrors.add(
        const ApiInvalidRequest('photo key not uploaded by this user'),
      );
      await outbox.run();
      final queued = (await row())!;
      expect(queued.state, OutboxState.refused);
      expect(
        queued.lastError,
        'Not accepted: photo key not uploaded by this user',
      );
      expect(files.removed, isEmpty);

      now = now.add(const Duration(days: 1));
      await outbox.run();
      expect(fake.api.submitted, hasLength(1));

      await outbox.delete(_id);
      expect(await row(), isNull);
      expect(files.removed, [_id]);
    });

    test('404 on a report: refused', () async {
      await queueReport('0123456789abcdef0123456789abcdef');
      reportErrors.add(const ApiNotFound('unknown product'));
      await outbox.run();
      final [queued] = await database.outboxDao.all();
      expect(queued.state, OutboxState.refused);
      expect(queued.lastError, 'Not accepted: this product is unknown.');
    });

    test('a photo deleted from the phone: refused', () async {
      await outbox.addContribution(_create(), {
        PhotoKind.front: 'missing-front.jpg',
        PhotoKind.nutrition: 'nutrition.jpg',
      });
      await outbox.run();
      expect((await row())!.state, OutboxState.refused);
      expect((await row())!.lastError, startsWith('A photo is missing'));
    });

    test('a damaged entry or an unknown kind: refused', () async {
      await database.outboxDao.enqueue(
        kind: 'new_product',
        clientId: 'bad',
        payload: '{"request": 1}',
        createdAt: now,
      );
      await database.outboxDao.enqueue(
        kind: 'future_kind',
        clientId: 'later',
        payload: '{}',
        createdAt: now,
      );
      await database.outboxDao.enqueue(
        kind: 'error_report',
        clientId: 'typed',
        payload: '{"client_id": 3}',
        createdAt: now,
      );
      await outbox.run();
      for (final queued in await database.outboxDao.all()) {
        expect(queued.state, OutboxState.refused, reason: queued.clientId);
        expect(queued.lastError, 'This entry is damaged. Delete it.');
      }
    });
  });

  group('one thing at a time', () {
    test('runs asked during a run: one more after it, shared', () async {
      await outbox.addContribution(_create(), _photos);
      fake.api.submitGate = Completer<void>();

      final first = outbox.run();
      await pumpEventQueue();
      expect(fake.api.submitted, hasLength(1)); // waiting at the gate

      // Queued meanwhile; two more runs asked: they share one.
      await queueReport('0123456789abcdef0123456789abcdef');
      final second = outbox.run();
      final third = outbox.run();
      expect(identical(second, third), isTrue);

      fake.api.submitGate!.complete();
      await Future.wait([first, second]);
      expect(fake.api.submitted, hasLength(1)); // never twice
      expect(reports, hasLength(1));
      expect(await database.outboxDao.all(), isEmpty);
    });

    test('sendNow waits for a run and finds it sent', () async {
      await outbox.addContribution(_create(), _photos);
      fake.api.submitGate = Completer<void>();
      final running = outbox.run();
      await pumpEventQueue();
      final now = outbox.sendNow(_id);
      fake.api.submitGate!.complete();
      await running;
      expect(await now, isA<Sent>());
      expect(fake.api.submitted, hasLength(1));
    });

    test('the entry being sent is announced', () async {
      final announced = <String?>[];
      final subscription = outbox.sending.listen(announced.add);
      addTearDown(subscription.cancel);
      await outbox.addContribution(_create(), _photos);
      await outbox.run();
      await pumpEventQueue();
      expect(announced, [_id, null]);
    });
  });

  group('sendNow', () {
    test('sends whatever its retry time; says what happened', () async {
      await outbox.addContribution(_create(), _photos);
      fake.api.uploadErrors.add(const ApiConnectionError('offline'));
      expect(await outbox.sendNow(_id), isA<RetryLater>());
      expect(await outbox.sendNow(_id), isA<Sent>()); // not waiting 30 s
      expect(await row(), isNull);
    });

    test('refused and sign-in outcomes', () async {
      await outbox.addContribution(_create(), _photos);
      fake.api.submitErrors.add(const ApiInvalidRequest('salt_g too high'));
      expect(
        await outbox.sendNow(_id),
        isA<Refused>().having(
          (r) => r.message,
          'message',
          'Not accepted: salt_g too high',
        ),
      );
      await outbox.delete(_id);

      await outbox.addContribution(_create(), _photos);
      fake.api.uploadErrors.add(const ApiUnauthorized('expired'));
      expect(await outbox.sendNow(_id), isA<NeedsSignIn>());
    });

    test('an entry no longer queued counts as sent', () async {
      expect(await outbox.sendNow('gone'), isA<Sent>());
    });
  });

  test('next attempt comes from the queue', () async {
    expect(await outbox.nextAttempt(), isNull);
    await outbox.addContribution(_create(), _photos);
    fake.api.uploadErrors.add(const ApiConnectionError('offline'));
    await outbox.run();
    expect(await outbox.nextAttempt(), now.add(const Duration(seconds: 30)));
  });
}
