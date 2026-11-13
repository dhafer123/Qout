import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/domain/product_result.dart';

/// The lookup of one barcode: a cached product may be followed by its
/// refreshed version. Invalidate it to look up again (retry).
final AutoDisposeStreamProviderFamily<ProductResult, String>
productResultProvider = StreamProvider.autoDispose
    .family<ProductResult, String>(
      (ref, ean) => ref.watch(productRepositoryProvider).get(ean),
    );
