import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/core/api/api_providers.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/database/database_provider.dart';
import 'package:qout/features/product/domain/product_result.dart';

/// Products by barcode: local cache first, then the API (stale-while-
/// revalidate).
///
/// - Cached and younger than [maxAge]: served from the cache, no request.
/// - Cached but older: served from the cache at once, then refreshed; the
///   refreshed product follows. If the refresh fails the cached one stays,
///   marked [ProductFreshness.refreshFailed]; if the product was withdrawn
///   (404) it leaves the cache.
/// - Not cached: fetched, stored, served.
class ProductRepository {
  ProductRepository({
    required QoutApi api,
    required ProductCacheDao cache,
    DateTime Function()? clock,
    this.maxAge = defaultMaxAge,
  }) : _api = api,
       _cache = cache,
       _clock = clock ?? DateTime.now;

  /// How long a cached product is served without asking the API.
  static const defaultMaxAge = Duration(hours: 6);

  final QoutApi _api;
  final ProductCacheDao _cache;
  final DateTime Function() _clock;
  final Duration maxAge;

  /// One or two results for [ean]: a stale cached product is followed by its
  /// refreshed version (or the same product marked `refreshFailed`).
  Stream<ProductResult> get(String ean) async* {
    final cached = await _cached(ean);
    if (cached == null) {
      yield await _fetch(ean);
      return;
    }
    final (product, fetchedAt) = cached;
    if (_clock().difference(fetchedAt) < maxAge) {
      yield ProductResult.found(
        product: product,
        fetchedAt: fetchedAt,
        freshness: ProductFreshness.fresh,
      );
      return;
    }
    yield ProductResult.found(
      product: product,
      fetchedAt: fetchedAt,
      freshness: ProductFreshness.refreshing,
    );
    final refreshed = await _fetch(ean, alsoKnownAs: product.ean);
    yield switch (refreshed) {
      // Offline or server trouble: the cached product is still the best.
      ProductUnavailable(:final error) => ProductResult.found(
        product: product,
        fetchedAt: fetchedAt,
        freshness: ProductFreshness.refreshFailed,
        refreshError: error,
      ),
      _ => refreshed,
    };
  }

  Future<ProductResult> _fetch(String ean, {String? alsoKnownAs}) async {
    final keys = {ean, ?alsoKnownAs};
    try {
      final product = await _api.getProduct(ean: ean);
      await _cache.save(
        {...keys, product.ean},
        json: jsonEncode(product.toJson()),
        fetchedAt: _clock(),
      );
      return ProductResult.found(
        product: product,
        fetchedAt: _clock(),
        freshness: ProductFreshness.fresh,
      );
    } on ApiNotFound {
      await _cache.remove(keys);
      return ProductResult.notFound(ean: ean);
    } on ApiInvalidRequest catch (error) {
      return ProductResult.invalidBarcode(ean: ean, message: error.message);
    } on QoutApiException catch (error) {
      return ProductResult.unavailable(ean: ean, error: error);
    }
  }

  /// The cached product, or null (also when the stored JSON no longer reads,
  /// e.g. after an app update changed the API models: it is then dropped).
  Future<(ProductDetail, DateTime)?> _cached(String ean) async {
    final row = await _cache.find(ean);
    if (row == null) return null;
    try {
      final json = jsonDecode(row.json) as Map<String, Object?>;
      return (ProductDetail.fromJson(json), row.fetchedAt);
    } on Object {
      await _cache.remove({ean});
      return null;
    }
  }
}

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(
    api: ref.watch(qoutApiProvider),
    cache: ref.watch(appDatabaseProvider).productCacheDao,
  ),
);
