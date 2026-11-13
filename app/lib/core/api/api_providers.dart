import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/core/env/app_env.dart';
import 'package:qout/features/auth/data/auth_interceptor.dart';
import 'package:qout/features/auth/data/auth_repository.dart';

/// Connecting must be quick: the app falls back to its cache when offline.
const apiConnectTimeout = Duration(seconds: 5);

/// A first lookup may wait for Open Food Facts on the server (up to ~10 s).
const apiReceiveTimeout = Duration(seconds: 15);

/// HTTP client for the Qout API: base URL from [AppEnv], JSON, timeouts, and
/// the access token on calls that need a signed-in user ([AuthInterceptor]).
final Provider<Dio> dioProvider = Provider<Dio>((ref) {
  final env = ref.watch(appEnvProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: env.apiBaseUrl.toString(),
      connectTimeout: apiConnectTimeout,
      receiveTimeout: apiReceiveTimeout,
      headers: {Headers.acceptHeader: Headers.jsonContentType},
    ),
  );
  // Read lazily: the auth repository calls the API through this same Dio.
  dio.interceptors.add(
    AuthInterceptor(dio: dio, auth: () => ref.read(authRepositoryProvider)),
  );
  ref.onDispose(dio.close);
  return dio;
});

final Provider<QoutApi> qoutApiProvider = Provider<QoutApi>(
  (ref) => QoutApi(ref.watch(dioProvider)),
);
