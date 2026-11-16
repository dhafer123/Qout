import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/contribute/data/contribution_repository.dart';
import 'package:qout/features/outbox/domain/queued_contribution.dart';
import 'package:qout/features/outbox/domain/send_outcome.dart';

class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('outcomeOf', () {
    test('try again later: connection, storage, busy, limited, 5xx', () {
      expect(
        outcomeOf(const ApiConnectionError('x')),
        isA<RetryLater>().having((o) => o.after, 'after', isNull),
      );
      expect(outcomeOf(const PhotoUploadError('x')), isA<RetryLater>());
      expect(
        outcomeOf(
          const ApiUnavailable('x', retryAfter: Duration(seconds: 120)),
        ),
        isA<RetryLater>().having(
          (o) => o.after,
          'after',
          const Duration(seconds: 120),
        ),
      );
      expect(
        outcomeOf(
          const ApiTooManyRequests('x', retryAfter: Duration(hours: 1)),
        ),
        isA<RetryLater>().having(
          (o) => o.after,
          'after',
          const Duration(hours: 1),
        ),
      );
      expect(outcomeOf(const ApiBadResponse(500, 'x')), isA<RetryLater>());
      expect(outcomeOf(const ApiBadResponse(null, 'x')), isA<RetryLater>());
      expect(outcomeOf(StateError('x')), isA<RetryLater>());
    });

    test('needs sign-in: 401', () {
      expect(outcomeOf(const ApiUnauthorized('x')), isA<NeedsSignIn>());
      expect(const NeedsSignIn().message, 'Sign in to send it.');
    });

    test('refused for good: invalid, unknown, conflict, other 4xx', () {
      String refused(Object error) => (outcomeOf(error) as Refused).message;
      expect(
        refused(const ApiInvalidRequest('salt_g too high')),
        'Not accepted: salt_g too high',
      );
      expect(
        refused(const ApiNotFound('x')),
        'Not accepted: this product is unknown.',
      );
      expect(refused(const ApiConflict('taken')), 'Not accepted: taken');
      expect(
        refused(const ApiBadResponse(413, 'x')),
        'Not accepted (HTTP 413).',
      );
      expect(
        refused(const FileSystemException('gone')),
        startsWith('A photo is missing on this phone.'),
      );
      expect(
        refused(const FormatException('x')),
        'This entry is damaged. Delete it.',
      );
    });
  });

  group('retryDelay', () {
    test('30 s doubling up to 1 h', () {
      final exact = _FixedRandom(0.5);
      expect(
        [for (var n = 1; n <= 9; n++) retryDelay(n, exact).inSeconds],
        [30, 60, 120, 240, 480, 960, 1920, 3600, 3600],
      );
      expect(retryDelay(1000, exact), outboxMaxRetry);
      expect(retryDelay(0, exact), outboxFirstRetry);
    });

    test('jitter of ±20 %', () {
      expect(retryDelay(1, _FixedRandom(0)).inSeconds, 24);
      expect(retryDelay(1, _FixedRandom(0.999999)).inMilliseconds, 36000);
      expect(retryDelay(20, _FixedRandom(0)).inSeconds, 2880);
    });
  });

  group('QueuedContribution', () {
    const create = ContributionCreate(
      clientId: 'c1',
      ean: '6191234567897',
      name: 'Sablés',
      category: Category.general,
      basis: NutritionBasis.per100g,
      nutrition: NutritionValues(saltG: 0.85),
      photos: ContributionPhotos(front: '', nutrition: ''),
      parserUsed: ParserUsed.manual,
    );

    test('round trip; photo keys filled in when uploaded', () {
      final queued = QueuedContribution.of(create, {
        PhotoKind.front: '/a/front.jpg',
        PhotoKind.nutrition: '/a/nutrition.jpg',
      });
      expect(
        (queued.clientId, queued.ean, queued.name),
        (
          'c1',
          '6191234567897',
          'Sablés',
        ),
      );
      expect(queued.create, throwsStateError);

      final read = QueuedContribution.fromPayload(
        queued
            .withKey(PhotoKind.front, 'k-front')
            .withKey(PhotoKind.nutrition, 'k-nutrition')
            .toPayload(),
      );
      expect(read.toUpload, isEmpty);
      expect(read.photos[PhotoKind.front]!.path, '/a/front.jpg');
      final sent = read.create();
      expect(sent.photos.front, 'k-front');
      expect(sent.photos.nutrition, 'k-nutrition');
      expect(sent.photos.ingredients, isNull);
      expect(sent.nutrition.saltG, 0.85);
      expect(sent.parserUsed, ParserUsed.manual);
    });

    test('not a queued contribution', () {
      for (final payload in ['', '[]', '{}', '{"request": {}, "photos": 1}']) {
        expect(
          () => QueuedContribution.fromPayload(payload),
          throwsFormatException,
          reason: payload,
        );
      }
    });
  });
}
