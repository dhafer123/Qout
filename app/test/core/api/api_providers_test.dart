import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/api_providers.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/database/database_provider.dart';
import 'package:qout/core/env/app_env.dart';
import 'package:qout/features/auth/data/token_store.dart';
import 'package:qout/features/auth/domain/auth_session.dart';
import 'package:qout/features/product/data/product_repository.dart';

import '../../helpers/in_memory_token_store.dart';

/// Answers every request with [body], recording what was sent.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);

  final Object body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  ProviderContainer container({String? url, TokenStore? tokens}) {
    final c = ProviderContainer(
      overrides: [
        if (tokens != null) tokenStoreProvider.overrideWithValue(tokens),
        appEnvProvider.overrideWithValue(
          AppEnv.resolve(flavorName: 'dev', apiBaseUrlOverride: url),
        ),
        appDatabaseProvider.overrideWith((ref) {
          final database = AppDatabase(NativeDatabase.memory());
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('dio uses the environment base URL and the timeouts', () {
    final options = container().read(dioProvider).options;
    expect(options.baseUrl, 'http://10.0.2.2:8000');
    expect(options.connectTimeout, apiConnectTimeout);
    expect(options.receiveTimeout, apiReceiveTimeout);
    expect(options.headers['accept'], 'application/json');
  });

  test('an overridden base URL (physical phone) is used', () {
    final dio = container(url: 'http://192.168.1.20:8000').read(dioProvider);
    expect(dio.options.baseUrl, 'http://192.168.1.20:8000');
  });

  test('the repository is wired to the API and the database', () {
    final c = container();
    expect(c.read(productRepositoryProvider), isA<ProductRepository>());
    expect(
      c.read(productRepositoryProvider).maxAge,
      ProductRepository.defaultMaxAge,
    );
  });

  // Regression: the interceptor read the auth repository, which was built on
  // the same client: Riverpod's debug check threw CircularDependencyError and
  // every signed-in call failed on the phone before being sent.
  test('a signed-in call goes out with the token, real providers', () async {
    final c = container(
      tokens: InMemoryTokenStore(
        AuthSession(
          email: 'a@example.tn',
          accessToken: 'access-1',
          accessExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
          refreshToken: 'refresh-1',
          refreshExpiresAt: DateTime.now().add(const Duration(days: 30)),
        ),
      ),
    );
    final adapter = _Adapter({
      'id': '5f2bd33b-72da-4efd-beaa-32db3fcccee3',
      'email': 'a@example.tn',
      'role': 'contributor',
      'created_at': '2026-11-16T20:05:04Z',
    });
    c.read(dioProvider).httpClientAdapter = adapter;

    final me = await c.read(qoutApiProvider).getMe();

    expect(me.email, 'a@example.tn');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer access-1');
  });

  test('the auth calls use their own client, without the interceptor', () {
    final c = container();
    expect(c.read(authApiProvider), isNot(same(c.read(qoutApiProvider))));
  });
}
