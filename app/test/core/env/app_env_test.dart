import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/env/app_env.dart';

void main() {
  group('AppFlavor.parse', () {
    test('parses every known flavor by name', () {
      for (final flavor in AppFlavor.values) {
        expect(AppFlavor.parse(flavor.name), flavor);
      }
    });

    for (final name in [null, '', 'Dev', 'production', 'release']) {
      test('rejects "$name"', () {
        expect(
          () => AppFlavor.parse(name),
          throwsA(
            isA<UnsupportedFlavorException>()
                .having((e) => e.name, 'name', name)
                .having((e) => e.toString(), 'message', contains('--flavor')),
          ),
        );
      });
    }
  });

  group('AppEnv.resolve', () {
    final expected = {
      'dev': 'http://10.0.2.2:8000',
      'staging': 'https://api.staging.qout.invalid',
      'prod': 'https://api.qout.invalid',
    };

    for (final MapEntry(key: flavorName, value: url) in expected.entries) {
      test('$flavorName resolves to its default API URL', () {
        final env = AppEnv.resolve(flavorName: flavorName);

        expect(env.flavor.name, flavorName);
        expect(env.apiBaseUrl, Uri.parse(url));
      });
    }

    test('every flavor has a default API URL', () {
      expect(defaultApiBaseUrls.keys, unorderedEquals(AppFlavor.values));
    });

    test('an empty override keeps the default URL', () {
      final env = AppEnv.resolve(flavorName: 'prod', apiBaseUrlOverride: '');

      expect(env.apiBaseUrl, Uri.parse('https://api.qout.invalid'));
    });

    test('a non-empty override replaces the default URL', () {
      final env = AppEnv.resolve(
        flavorName: 'dev',
        apiBaseUrlOverride: 'http://192.168.1.20:8000',
      );

      expect(env.flavor, AppFlavor.dev);
      expect(env.apiBaseUrl, Uri.parse('http://192.168.1.20:8000'));
    });

    for (final bad in ['not a url', '/v1', 'ftp://example.com', 'http://']) {
      test('rejects invalid override "$bad"', () {
        expect(
          () => AppEnv.resolve(flavorName: 'dev', apiBaseUrlOverride: bad),
          throwsFormatException,
        );
      });
    }

    test('unknown flavor fails even with an override', () {
      expect(
        () => AppEnv.resolve(
          flavorName: 'qa',
          apiBaseUrlOverride: 'https://example.com',
        ),
        throwsA(isA<UnsupportedFlavorException>()),
      );
    });

    test('is a value type', () {
      expect(
        AppEnv.resolve(flavorName: 'prod'),
        AppEnv.resolve(flavorName: 'prod'),
      );
    });
  });

  test('fromBuild fails without a flavor (plain `flutter test`)', () {
    expect(AppEnv.fromBuild, throwsA(isA<UnsupportedFlavorException>()));
  });

  test('appEnvProvider must be overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(() => container.read(appEnvProvider), throwsA(anything));
  });
}
