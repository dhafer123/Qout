import 'dart:async';

import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/domain/product_result.dart';

/// Answers `get` with a stream the test controls: [results] (emitted then
/// closed) or, with [controller], whatever the test adds.
class FakeProductRepository implements ProductRepository {
  FakeProductRepository({List<ProductResult>? results, this.controller})
    : results = results ?? [];

  /// Emitted in order on each `get`, then the stream closes.
  List<ProductResult> results;

  /// When set, `get` returns its stream instead of [results].
  StreamController<ProductResult>? controller;

  final requested = <String>[];

  @override
  Stream<ProductResult> get(String ean) {
    requested.add(ean);
    return controller?.stream ?? Stream.fromIterable(results);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
