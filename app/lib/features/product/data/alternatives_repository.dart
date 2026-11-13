import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/core/api/api_providers.dart';
import 'package:qout/core/api/qout_api.dart';

/// Better alternatives to a product, from the API. Online only: they are a
/// suggestion, not part of the product, so nothing is cached.
class AlternativesRepository {
  AlternativesRepository({required QoutApi api}) : _api = api;

  /// How many the result screen shows.
  static const shown = 5;

  final QoutApi _api;

  /// Best first; throws [QoutApiException] when the API can't be reached.
  Future<List<AlternativeProduct>> get(String ean) async =>
      (await _api.getProductAlternatives(ean: ean, limit: shown)).items;
}

final alternativesRepositoryProvider = Provider<AlternativesRepository>(
  (ref) => AlternativesRepository(api: ref.watch(qoutApiProvider)),
);

/// Alternatives to one product (by the API's EAN).
final AutoDisposeFutureProviderFamily<List<AlternativeProduct>, String>
alternativesProvider = FutureProvider.autoDispose
    .family<List<AlternativeProduct>, String>(
      (ref, ean) => ref.watch(alternativesRepositoryProvider).get(ean),
    );
