import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/qout_api.dart';

/// Responses recorded from the backend's `GET /v1/products/{ean}`.
Map<String, Object?> fixture(String name) =>
    jsonDecode(File('test/fixtures/api/$name.json').readAsStringSync())
        as Map<String, Object?>;

/// Answers every request with [respond]; records the requests.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(
  Object? body, {
  int status = 200,
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...headers,
  },
);

(QoutApi, FakeAdapter) apiAnswering(
  ResponseBody Function(RequestOptions options) respond,
) {
  final adapter = FakeAdapter(respond);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = adapter;
  return (QoutApi(dio), adapter);
}

void main() {
  group('recorded product responses', () {
    test('a graded general food', () {
      final product = ProductDetail.fromJson(fixture('product-general-graded'));

      expect(product.ean, '9557062321136');
      expect(product.category, Category.general);
      expect(product.source, DataSource.openFoodFacts);
      expect(product.qualityFlag, QualityFlag.complete);
      expect(product.novaGroup, 4);
      expect(product.additives.map((a) => a.code), ['E320', 'E330']);
      expect(
        product.additives.first.overexposureRisk,
        OverexposureRisk.unknown,
      );
      expect(product.nutrition!.basis, NutritionBasis.per100g);
      expect(product.nutrition!.energyKj, 2055.5);
      expect(product.nutrition!.fibreG, isNull);
      expect(product.score!.grade, Grade.e);
      expect(product.score!.total, 22);
      expect(product.score!.breakdown['assumed_zero'], ['fibre_g']);
      expect(
        product.updatedAt,
        DateTime.utc(2026, 11, 12, 17, 18, 43, 332, 419),
      );
    });

    test('water is graded A without points', () {
      final product = ProductDetail.fromJson(fixture('product-water'));
      expect(product.category, Category.water);
      expect((product.score!.grade, product.score!.total), (Grade.a, null));
    });

    test('insufficient data has a score without a grade', () {
      final product = ProductDetail.fromJson(
        fixture('product-insufficient-data'),
      );
      expect(product.name, isNull);
      expect(product.score!.grade, isNull);
      expect(product.score!.breakdown, contains('insufficient_data'));
    });

    test('an unknown category has no score', () {
      final product = ProductDetail.fromJson(
        fixture('product-unknown-category'),
      );
      expect((product.category, product.score), (null, null));
    });

    for (final name in [
      'product-general-graded',
      'product-beverage-graded',
      'product-water',
      'product-insufficient-data',
      'product-unknown-category',
    ]) {
      test('$name: toJson gives back the recorded JSON', () {
        final json = fixture(name);
        final product = ProductDetail.fromJson(json);
        expect(product.toJson(), json);
        expect(ProductDetail.fromJson(product.toJson()), product);
      });
    }
  });

  group('models', () {
    test('equality and hash code are by value, nested included', () {
      final a = ProductDetail.fromJson(fixture('product-general-graded'));
      final b = ProductDetail.fromJson(fixture('product-general-graded'));
      final other = ProductDetail.fromJson(fixture('product-water'));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(other));
      expect(a.toString(), startsWith('ProductDetail({ean: 9557062321136'));
    });

    test('values a newer backend may add become unrecognized', () {
      final json = fixture('product-general-graded')
        ..['category'] = 'insects'
        ..['status'] = 'archived';
      final product = ProductDetail.fromJson(json);
      expect(product.category, Category.unrecognized);
      expect(product.status, ProductStatus.unrecognized);
      expect(product.toJson()['category'], '');
    });

    test('a non-string enum value is a format error', () {
      expect(() => Grade.fromJson(3), throwsFormatException);
    });

    test('collections are read-only', () {
      final product = ProductDetail.fromJson(fixture('product-general-graded'));
      expect(product.additives.clear, throwsUnsupportedError);
      expect(product.score!.breakdown.clear, throwsUnsupportedError);
    });
  });

  group('QoutApi.getProduct', () {
    test('requests the product and decodes it', () async {
      final (api, adapter) = apiAnswering(
        (_) => jsonBody(fixture('product-beverage-graded')),
      );

      final product = await api.getProduct(ean: '42094579');

      expect(product.name, 'Fanta tropical');
      expect(adapter.requests.single.method, 'GET');
      expect(
        adapter.requests.single.uri.toString(),
        'http://api.test/v1/products/42094579',
      );
    });

    test('the barcode is URL-encoded', () async {
      final (api, adapter) = apiAnswering((_) => jsonBody({}, status: 422));
      await expectLater(
        api.getProduct(ean: '12/34'),
        throwsA(isA<ApiInvalidRequest>()),
      );
      expect(adapter.requests.single.uri.path, '/v1/products/12%2F34');
    });

    test('404 is ApiNotFound with the server message', () async {
      final (api, _) = apiAnswering(
        (_) => jsonBody({
          'detail': 'no product with barcode 6190000000019',
        }, status: 404),
      );
      await expectLater(
        api.getProduct(ean: '6190000000019'),
        throwsA(
          isA<ApiNotFound>().having(
            (e) => e.message,
            'message',
            'no product with barcode 6190000000019',
          ),
        ),
      );
    });

    test('422 (recorded) is ApiInvalidRequest', () async {
      final (api, _) = apiAnswering(
        (_) => jsonBody(fixture('error-invalid-barcode'), status: 422),
      );
      await expectLater(
        api.getProduct(ean: '123'),
        throwsA(
          isA<ApiInvalidRequest>().having(
            (e) => e.toString(),
            'toString',
            "ApiInvalidRequest: invalid barcode '123': must have 8, 12, 13 or "
                '14 digits',
          ),
        ),
      );
    });

    test('503 is ApiUnavailable with Retry-After', () async {
      final (api, _) = apiAnswering(
        (_) => jsonBody(
          {'detail': 'Open Food Facts is unavailable'},
          status: 503,
          headers: {
            'retry-after': ['30'],
          },
        ),
      );
      await expectLater(
        api.getProduct(ean: '6194039501011'),
        throwsA(
          isA<ApiUnavailable>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 30),
          ),
        ),
      );
    });

    test('503 with an unusable Retry-After', () async {
      for (final header in ['soon', '-1']) {
        final (api, _) = apiAnswering(
          (_) => jsonBody(
            {},
            status: 503,
            headers: {
              'retry-after': [header],
            },
          ),
        );
        await expectLater(
          api.getProduct(ean: '6194039501011'),
          throwsA(
            isA<ApiUnavailable>()
                .having((e) => e.retryAfter, 'retryAfter', isNull)
                .having((e) => e.message, 'message', 'HTTP 503'),
          ),
        );
      }
    });

    test('other statuses are ApiBadResponse', () async {
      final (api, _) = apiAnswering((_) => jsonBody('oops', status: 500));
      await expectLater(
        api.getProduct(ean: '6194039501011'),
        throwsA(
          isA<ApiBadResponse>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', 'HTTP 500'),
        ),
      );
    });

    test('a body that does not match the spec is ApiBadResponse', () async {
      final (api, _) = apiAnswering(
        (_) => jsonBody({'ean': 42}), // wrong type, fields missing
      );
      await expectLater(
        api.getProduct(ean: '6194039501011'),
        throwsA(
          isA<ApiBadResponse>()
              .having((e) => e.statusCode, 'statusCode', isNull)
              .having(
                (e) => e.message,
                'message',
                startsWith('unexpected response body'),
              ),
        ),
      );
    });

    test('no response is ApiConnectionError', () async {
      final (api, _) = apiAnswering(
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'connection refused',
        ),
      );
      await expectLater(
        api.getProduct(ean: '6194039501011'),
        throwsA(
          isA<ApiConnectionError>().having(
            (e) => e.message,
            'message',
            contains('connection refused'),
          ),
        ),
      );
    });

    test('a timeout without a message is ApiConnectionError', () async {
      final (api, _) = apiAnswering(
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await expectLater(
        api.getProduct(ean: '6194039501011'),
        throwsA(isA<ApiConnectionError>()),
      );
    });

    test('every exception names its kind', () {
      expect(const ApiNotFound('x').toString(), 'ApiNotFound: x');
      expect(const ApiUnavailable('x').toString(), 'ApiUnavailable: x');
      expect(const ApiConnectionError('x').toString(), 'ApiConnectionError: x');
      expect(const ApiBadResponse(500, 'x').toString(), 'ApiBadResponse: x');
    });
  });
}
