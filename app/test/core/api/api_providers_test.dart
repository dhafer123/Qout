import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/api_providers.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/core/database/database_provider.dart';
import 'package:qout/core/env/app_env.dart';
import 'package:qout/features/product/data/product_repository.dart';

void main() {
  ProviderContainer container({String? url}) {
    final c = ProviderContainer(
      overrides: [
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
}
