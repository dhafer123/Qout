import 'dart:async';

import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/product/data/alternatives_repository.dart';

/// Alternatives for widget tests: [items] (none by default), or [error].
class FakeAlternativesRepository implements AlternativesRepository {
  FakeAlternativesRepository({this.items = const [], this.error});

  List<AlternativeProduct> items;
  QoutApiException? error;
  final requested = <String>[];

  @override
  Future<List<AlternativeProduct>> get(String ean) async {
    requested.add(ean);
    if (error case final error?) throw error;
    return items;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
