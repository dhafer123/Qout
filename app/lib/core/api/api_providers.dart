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

/// Base URL from [AppEnv], JSON, timeouts.
BaseOptions _apiOptions(AppEnv env) => BaseOptions(
  baseUrl: env.apiBaseUrl.toString(),
  connectTimeout: apiConnectTimeout,
  receiveTimeout: apiReceiveTimeout,
  headers: {Headers.acceptHeader: Headers.jsonContentType},
);

/// HTTP client for the Qout API, with the access token on calls that need a
/// signed-in user ([AuthInterceptor]).
final Provider<Dio> dioProvider = Provider<Dio>((ref) {
  final dio = Dio(_apiOptions(ref.watch(appEnvProvider)));
  // Read lazily, on the first signed-in call. The auth repository must not
  // be built on this client ([authApiProvider]): it would depend on the
  // provider reading it, which Riverpod rejects (CircularDependencyError).
  dio.interceptors.add(
    AuthInterceptor(dio: dio, auth: () => ref.read(authRepositoryProvider)),
  );
  ref.onDispose(dio.close);
  return dio;
});

final Provider<QoutApi> qoutApiProvider = Provider<QoutApi>(
  (ref) => QoutApi(ref.watch(dioProvider)),
);

/// The API for the auth repository: signing in, signing up, refreshing and
/// signing out need no access token, so their client has no interceptor.
final Provider<QoutApi> authApiProvider = Provider<QoutApi>((ref) {
  final dio = Dio(_apiOptions(ref.watch(appEnvProvider)));
  ref.onDispose(dio.close);
  return QoutApi(dio);
});
