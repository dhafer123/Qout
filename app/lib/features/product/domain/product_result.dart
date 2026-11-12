import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qout/core/api/qout_api.dart';

part 'product_result.freezed.dart';

/// How current a [ProductResult.found] product is.
enum ProductFreshness {
  /// Fetched recently, or just now: no refresh needed.
  fresh,

  /// From the local cache, older than the freshness window; a refresh is on
  /// its way (another result follows).
  refreshing,

  /// From the local cache; the refresh failed (offline, server down), so this
  /// is the best available. `fetchedAt` says how old it is.
  refreshFailed,
}

/// What looking up a barcode gave. `ProductRepository.get` emits one or two of
/// these (a cached product, then its refreshed version).
@freezed
sealed class ProductResult with _$ProductResult {
  const factory ProductResult.found({
    required ProductDetail product,
    required DateTime fetchedAt,
    required ProductFreshness freshness,

    /// Why the refresh failed ([ProductFreshness.refreshFailed] only).
    QoutApiException? refreshError,
  }) = ProductFound;

  /// Nobody knows this barcode (or the product was withdrawn): the
  /// contribution flow can offer to add it.
  const factory ProductResult.notFound({required String ean}) = ProductNotFound;

  /// The API rejected the barcode (e.g. wrong check digit).
  const factory ProductResult.invalidBarcode({
    required String ean,
    required String message,
  }) = InvalidBarcode;

  /// Not cached, and the API can't be reached ([error] says why).
  const factory ProductResult.unavailable({
    required String ean,
    required QoutApiException error,
  }) = ProductUnavailable;
}

extension ProductUnavailableReason on ProductUnavailable {
  /// No connection at all (as opposed to a server problem).
  bool get isOffline => error is ApiConnectionError;

  /// When the server asked to be retried ([ApiUnavailable] only).
  Duration? get retryAfter => switch (error) {
    ApiUnavailable(:final retryAfter) => retryAfter,
    _ => null,
  };
}
