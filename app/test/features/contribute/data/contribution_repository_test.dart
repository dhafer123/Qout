import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/api_providers.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/contribute/data/contribution_repository.dart';

import '../../../helpers/fake_contribution.dart';

/// Storage answering [status] (or no connection when null).
class _StorageAdapter implements HttpClientAdapter {
  _StorageAdapter({this.status = 200});

  final int? status;
  final requests = <RequestOptions>[];
  final bodies = <List<int>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    bodies.add([
      for (final chunk in await requestStream?.toList() ?? <Uint8List>[])
        ...chunk,
    ]);
    final status = this.status;
    if (status == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'refused',
      );
    }
    return ResponseBody.fromString('', status);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeContribution fake;

  setUp(() => fake = FakeContribution());

  group('label text', () {
    test('parse sends the OCR text', () async {
      fake.api.parseResults.add(recordedLabelParse('label-parse-ok'));
      final result = await fake.repository.parseLabel(cleanLabelText);
      expect(result.ok, isTrue);
      expect(fake.api.parsed, [cleanLabelText]);
    });

    test('fallback asks by id', () async {
      fake.api.fallbackResults.add(recordedFallback('label-fallback-done'));
      final fallback = await fake.repository.fallback('abc');
      expect(fallback.status, FallbackStatus.done);
      expect(fake.api.fallbackIds, ['abc']);
    });
  });

  group('uploadPhoto', () {
    test('asks for a ticket, then puts the JPEG there', () async {
      final key = await fake.repository.uploadPhoto(
        clientId: 'c1',
        kind: PhotoKind.nutrition,
        path: 'nutrition.jpg',
      );
      expect(key, 'contributions/c1/nutrition.jpg');
      final request = fake.api.uploads.single;
      expect(request.contributionId, 'c1');
      expect(request.kind, PhotoKind.nutrition);
      expect(request.contentType, PhotoContentType.imageJpeg);
      expect(request.sizeBytes, 5);
      expect(fake.puts.single, (
        Uri.parse(
          'https://storage.test/contributions/c1/nutrition.jpg?signature=x',
        ),
        5,
        'image/jpeg',
      ));
    });

    test('PNG data is sent as PNG, whatever its name', () async {
      await fake.repository.uploadPhoto(
        clientId: 'c1',
        kind: PhotoKind.front,
        path: 'png-front.jpg',
      );
      expect(fake.api.uploads.single.contentType, PhotoContentType.imagePng);
      expect(fake.puts.single.$3, 'image/png');
    });

    test('a refused ticket stops before storage', () async {
      fake.api.uploadErrors.add(const ApiTooManyRequests('slow down'));
      await expectLater(
        fake.repository.uploadPhoto(
          clientId: 'c1',
          kind: PhotoKind.front,
          path: 'front.jpg',
        ),
        throwsA(isA<ApiTooManyRequests>()),
      );
      expect(fake.puts, isEmpty);
    });

    test('a storage failure is passed on', () async {
      fake.putErrors.add(const PhotoUploadError('storage answered 403'));
      await expectLater(
        fake.repository.uploadPhoto(
          clientId: 'c1',
          kind: PhotoKind.front,
          path: 'front.jpg',
        ),
        throwsA(isA<PhotoUploadError>()),
      );
    });
  });

  test('submit sends the contribution', () async {
    const body = ContributionCreate(
      clientId: 'c1',
      ean: '6191234567897',
      category: Category.general,
      basis: NutritionBasis.per100g,
      nutrition: NutritionValues(),
      photos: ContributionPhotos(front: 'f', nutrition: 'n'),
      parserUsed: ParserUsed.manual,
    );
    final read = await fake.repository.submit(body);
    expect(read.status, ContributionStatus.pending);
    expect(fake.api.submitted.single, same(body));
  });

  group('dioPhotoPut', () {
    final url = Uri.parse('https://storage.test/k?signature=x');
    final bytes = Uint8List.fromList([1, 2, 3]);

    test('one PUT with the signed type and the length', () async {
      final adapter = _StorageAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      await dioPhotoPut(dio)(url, bytes, 'image/jpeg');
      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.uri, url);
      expect(request.headers[Headers.contentTypeHeader], 'image/jpeg');
      expect(request.headers[Headers.contentLengthHeader], 3);
      expect(adapter.bodies.single, [1, 2, 3]);
    });

    test('a refusal names the status', () async {
      final dio = Dio()..httpClientAdapter = _StorageAdapter(status: 403);
      await expectLater(
        dioPhotoPut(dio)(url, bytes, 'image/jpeg'),
        throwsA(
          isA<PhotoUploadError>().having(
            (e) => e.toString(),
            'text',
            'PhotoUploadError: storage answered 403',
          ),
        ),
      );
    });

    test('no connection', () async {
      final dio = Dio()..httpClientAdapter = _StorageAdapter(status: null);
      await expectLater(
        dioPhotoPut(dio)(url, bytes, 'image/jpeg'),
        throwsA(
          isA<PhotoUploadError>().having(
            (e) => e.message,
            'message',
            'no connection to storage',
          ),
        ),
      );
    });
  });

  test('providers build without touching the network', () {
    final container = ProviderContainer(
      overrides: [qoutApiProvider.overrideWithValue(FakeContributionApi())],
    );
    addTearDown(container.dispose);
    expect(container.read(photoPutProvider), isA<PhotoPut>());
    expect(
      container.read(contributionRepositoryProvider),
      isA<ContributionRepository>(),
    );
  });
}
