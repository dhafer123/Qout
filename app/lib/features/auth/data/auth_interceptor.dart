import 'package:dio/dio.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/auth/data/auth_repository.dart';

/// Adds the signed-in user's access token to the calls that need one (marked
/// by the generated client, [authenticatedRequestKey]) and only to those:
/// scanning stays anonymous. A 401 on such a call gets one refresh and one
/// retry; a second 401 reaches the caller.
class AuthInterceptor extends Interceptor {
  /// [auth] is read on each request: the repository itself calls the API
  /// through the same [Dio].
  AuthInterceptor({required Dio dio, required AuthRepository Function() auth})
    : _dio = dio,
      _auth = auth;

  final Dio _dio;
  final AuthRepository Function() _auth;

  static const _retriedKey = 'qout.auth.retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_needsToken(options)) {
      final token = await _auth().accessToken();
      if (token != null) _authorize(options, token);
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        !_needsToken(options) ||
        options.extra[_retriedKey] == true) {
      handler.next(err);
      return;
    }
    final token = await _auth().accessToken(forceRefresh: true);
    if (token == null) {
      handler.next(err);
      return;
    }
    _authorize(options, token);
    options.extra[_retriedKey] = true;
    try {
      handler.resolve(await _dio.fetch<Object?>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  static bool _needsToken(RequestOptions options) =>
      options.extra[authenticatedRequestKey] == true;

  static void _authorize(RequestOptions options, String token) =>
      options.headers['Authorization'] = 'Bearer $token';
}
