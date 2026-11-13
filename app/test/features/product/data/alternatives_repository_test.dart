import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/product/data/alternatives_repository.dart';

const _items = [
  AlternativeProduct(
    ean: '6191234567897',
    name: 'Oat biscuits',
    grade: Grade.b,
  ),
];

/// Answers `getProductAlternatives` with `_items`, or throws [error].
class _FakeApi implements QoutApi {
  _FakeApi({this.error});

  final QoutApiException? error;
  final calls = <(String, int?)>[];

  @override
  Future<ProductAlternatives> getProductAlternatives({
    required String ean,
    int? limit,
  }) async {
    calls.add((ean, limit));
    if (error case final error?) throw error;
    return ProductAlternatives(ean: ean, items: _items);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('asks for the five best and returns them', () async {
    final api = _FakeApi();

    final items = await AlternativesRepository(api: api).get('9557062321136');

    expect(items, _items);
    expect(api.calls, [('9557062321136', 5)]);
  });

  test('API errors reach the caller', () async {
    final api = _FakeApi(error: const ApiConnectionError('offline'));

    await expectLater(
      AlternativesRepository(api: api).get('9557062321136'),
      throwsA(isA<ApiConnectionError>()),
    );
  });
}
