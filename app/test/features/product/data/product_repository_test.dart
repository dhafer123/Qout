import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/domain/product_result.dart';

ProductDetail recorded(String name) => ProductDetail.fromJson(
  jsonDecode(File('test/fixtures/api/$name.json').readAsStringSync())
      as Map<String, Object?>,
);

/// Answers `getProduct` from [responses] (a product or an exception) in order.
class FakeQoutApi implements QoutApi {
  final responses = <Object>[];
  final requested = <String>[];

  @override
  Future<ProductDetail> getProduct({required String ean}) async {
    requested.add(ean);
    final response = responses.removeAt(0);
    if (response is ProductDetail) return response;
    throw response as Exception;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase database;
  late FakeQoutApi api;
  late DateTime now;
  late ProductRepository repository;

  final fanta = recorded('product-beverage-graded'); // EAN 42094579
  final t0 = DateTime.utc(2026, 11, 12, 9);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    api = FakeQoutApi();
    now = t0;
    repository = ProductRepository(
      api: api,
      cache: database.productCacheDao,
      clock: () => now,
    );
  });

  tearDown(() => database.close());

  Future<List<ProductResult>> get(String ean) => repository.get(ean).toList();

  ProductResult found(
    ProductDetail product,
    DateTime fetchedAt,
    ProductFreshness freshness, [
    QoutApiException? error,
  ]) => ProductResult.found(
    product: product,
    fetchedAt: fetchedAt,
    freshness: freshness,
    refreshError: error,
  );

  group('not cached', () {
    test('fetched from the API and cached', () async {
      api.responses.add(fanta);

      expect(await get('42094579'), [found(fanta, t0, ProductFreshness.fresh)]);

      final row = await database.productCacheDao.find('42094579');
      expect(row!.fetchedAt, t0);
      expect(
        ProductDetail.fromJson(jsonDecode(row.json) as Map<String, Object?>),
        fanta,
      );
    });

    test('404 is not found', () async {
      api.responses.add(const ApiNotFound('no product'));
      expect(await get('6190000000019'), [
        const ProductResult.notFound(ean: '6190000000019'),
      ]);
    });

    test('422 is an invalid barcode', () async {
      api.responses.add(const ApiInvalidRequest('wrong check digit'));
      expect(await get('6190000000018'), [
        const ProductResult.invalidBarcode(
          ean: '6190000000018',
          message: 'wrong check digit',
        ),
      ]);
    });

    test('offline is unavailable, and nothing is cached', () async {
      const offline = ApiConnectionError('connection refused');
      api.responses.add(offline);

      final [result] = await get('42094579');

      expect(
        result,
        const ProductResult.unavailable(ean: '42094579', error: offline),
      );
      expect((result as ProductUnavailable).isOffline, isTrue);
      expect(result.retryAfter, isNull);
      expect(await database.productCacheDao.find('42094579'), isNull);
    });

    test('server unavailable keeps its Retry-After', () async {
      api.responses.add(
        const ApiUnavailable('OFF down', retryAfter: Duration(seconds: 30)),
      );
      final [result as ProductUnavailable] = await get('42094579');
      expect(result.isOffline, isFalse);
      expect(result.retryAfter, const Duration(seconds: 30));
    });

    test('a UPC-A lookup is cached under both codes', () async {
      final upc = ProductDetail.fromJson({
        ...fanta.toJson(),
        'ean': '0036000291452',
      });
      api.responses.add(upc);

      await get('036000291452');

      expect(await database.productCacheDao.find('036000291452'), isNotNull);
      expect(await database.productCacheDao.find('0036000291452'), isNotNull);
    });
  });

  group('cached', () {
    setUp(() async {
      api.responses.add(fanta);
      await get('42094579');
      api.requested.clear();
    });

    test('fresh: served from the cache without a request', () async {
      now = t0.add(const Duration(hours: 5, minutes: 59));

      expect(await get('42094579'), [found(fanta, t0, ProductFreshness.fresh)]);
      expect(api.requested, isEmpty);
    });

    test('stale: cached first, then the refreshed product', () async {
      now = t0.add(ProductRepository.defaultMaxAge);
      final updated = ProductDetail.fromJson({
        ...fanta.toJson(),
        'name': 'Fanta tropical (new recipe)',
      });
      api.responses.add(updated);

      expect(await get('42094579'), [
        found(fanta, t0, ProductFreshness.refreshing),
        found(updated, now, ProductFreshness.fresh),
      ]);
      final row = await database.productCacheDao.find('42094579');
      expect(row!.fetchedAt, now);
    });

    test(
      'stale and offline: the cached product, marked refreshFailed',
      () async {
        now = t0.add(const Duration(days: 3));
        const offline = ApiConnectionError('no network');
        api.responses.add(offline);

        expect(await get('42094579'), [
          found(fanta, t0, ProductFreshness.refreshing),
          found(fanta, t0, ProductFreshness.refreshFailed, offline),
        ]);
        expect(await database.productCacheDao.find('42094579'), isNotNull);
      },
    );

    test('stale and withdrawn (404): removed from the cache', () async {
      now = t0.add(const Duration(days: 1));
      api.responses.add(const ApiNotFound('no product'));

      expect(await get('42094579'), [
        found(fanta, t0, ProductFreshness.refreshing),
        const ProductResult.notFound(ean: '42094579'),
      ]);
      expect(await database.productCacheDao.find('42094579'), isNull);
    });

    test('a shorter freshness window refreshes sooner', () async {
      final eager = ProductRepository(
        api: api,
        cache: database.productCacheDao,
        clock: () => now,
        maxAge: const Duration(minutes: 1),
      );
      now = t0.add(const Duration(minutes: 2));
      api.responses.add(fanta);

      final results = await eager.get('42094579').toList();

      expect(results.length, 2);
      expect(api.requested, ['42094579']);
    });

    test('an unreadable cache entry is dropped and refetched', () async {
      await database.productCacheDao.save(
        {'42094579'},
        json: '{"ean": 42}',
        fetchedAt: t0,
      );
      api.responses.add(fanta);

      expect(await get('42094579'), [found(fanta, t0, ProductFreshness.fresh)]);
      expect(api.requested, ['42094579']);
    });
  });

  test('the default clock is the real time', () async {
    final real = ProductRepository(api: api, cache: database.productCacheDao);
    api.responses.add(fanta);
    final before = DateTime.now();

    final [result as ProductFound] = await real.get('42094579').toList();

    expect(result.fetchedAt.isBefore(before), isFalse);
  });
}
