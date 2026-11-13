import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/auth/data/auth_interceptor.dart';
import 'package:qout/features/auth/data/auth_repository.dart';

/// Answers requests with queued statuses; records the Authorization header.
class ScriptedAdapter implements HttpClientAdapter {
  final statuses = <int>[];
  final authorizations = <String?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    authorizations.add(options.headers['Authorization'] as String?);
    final status = statuses.isEmpty ? 200 : statuses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode({'status': status}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Hands out tokens: `t1`, then `t2` after each forced refresh.
class FakeAuth implements AuthRepository {
  FakeAuth({this.signedIn = true, this.refreshWorks = true});

  bool signedIn;
  bool refreshWorks;
  int refreshes = 0;
  int _version = 1;

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async {
    if (!signedIn) return null;
    if (forceRefresh) {
      refreshes++;
      if (!refreshWorks) return null;
      _version++;
    }
    return 't$_version';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ScriptedAdapter adapter;
  late FakeAuth auth;
  late Dio dio;

  setUp(() {
    adapter = ScriptedAdapter();
    auth = FakeAuth();
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor(dio: dio, auth: () => auth));
  });

  Future<Response<Object?>> call({required bool authenticated}) =>
      dio.get<Object?>(
        '/v1/thing',
        options: Options(extra: {authenticatedRequestKey: authenticated}),
      );

  test('marked calls carry the access token', () async {
    await call(authenticated: true);
    expect(adapter.authorizations, ['Bearer t1']);
  });

  test(
    'other calls never do, even when signed in (scanning is anonymous)',
    () async {
      await call(authenticated: false);
      await dio.get<Object?>('/v1/products/123');
      expect(adapter.authorizations, [null, null]);
    },
  );

  test('signed out: sent without a token (the server answers 401)', () async {
    auth.signedIn = false;
    adapter.statuses.add(401);

    await expectLater(
      call(authenticated: true),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    expect(adapter.authorizations, [null]);
  });

  test('a 401 gets one refresh and one retry', () async {
    adapter.statuses.addAll([401, 200]);

    final response = await call(authenticated: true);

    expect(response.statusCode, 200);
    expect(adapter.authorizations, ['Bearer t1', 'Bearer t2']);
    expect(auth.refreshes, 1);
  });

  test('a second 401 reaches the caller', () async {
    adapter.statuses.addAll([401, 401, 200]);

    await expectLater(
      call(authenticated: true),
      throwsA(isA<DioException>()),
    );
    expect(adapter.authorizations, hasLength(2));
    expect(auth.refreshes, 1);
  });

  test('no retry when the refresh fails', () async {
    auth.refreshWorks = false;
    adapter.statuses.add(401);

    await expectLater(
      call(authenticated: true),
      throwsA(isA<DioException>()),
    );
    expect(adapter.authorizations, ['Bearer t1']);
  });

  test('other errors and unmarked 401s pass through untouched', () async {
    adapter.statuses.addAll([500, 401]);

    await expectLater(call(authenticated: true), throwsA(isA<DioException>()));
    await expectLater(
      call(authenticated: false),
      throwsA(isA<DioException>()),
    );
    expect(auth.refreshes, 0);
  });
}
