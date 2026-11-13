import 'dart:async';

import 'package:qout/core/api/qout_api.dart';

TokenPair pair(String n) => TokenPair(
  accessToken: 'access-$n',
  expiresIn: 900,
  refreshToken: 'refresh-$n',
  refreshExpiresIn: 30 * 86400,
);

/// Auth endpoints answering from queues; each call is recorded.
class FakeAuthApi implements QoutApi {
  final logins = <Credentials>[];
  final registrations = <Credentials>[];
  final refreshes = <String>[];
  final logouts = <String>[];

  /// Results in order: a [TokenPair] or a [QoutApiException] to throw.
  final loginResults = <Object>[];
  final registerResults = <Object>[];
  final refreshResults = <Object>[];
  Object? logoutResult;

  /// When set, refreshes wait for it (to test concurrent callers).
  Completer<void>? refreshGate;

  @override
  Future<TokenPair> login({required Credentials body}) async {
    logins.add(body);
    return _answer(loginResults.removeAt(0));
  }

  @override
  Future<TokenPair> register({required Credentials body}) async {
    registrations.add(body);
    return _answer(registerResults.removeAt(0));
  }

  @override
  Future<TokenPair> refreshTokens({required RefreshRequest body}) async {
    refreshes.add(body.refreshToken);
    await refreshGate?.future;
    return _answer(refreshResults.removeAt(0));
  }

  @override
  Future<void> logout({required RefreshRequest body}) async {
    logouts.add(body.refreshToken);
    if (logoutResult case final QoutApiException error) throw error;
  }

  TokenPair _answer(Object result) =>
      result is TokenPair ? result : throw result as QoutApiException;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
