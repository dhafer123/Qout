import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/auth/data/auth_repository.dart';
import 'package:qout/features/auth/domain/auth_session.dart';

import '../../../helpers/fake_auth_api.dart';
import '../../../helpers/in_memory_token_store.dart';

void main() {
  late FakeAuthApi api;
  late InMemoryTokenStore store;
  late DateTime now;
  late AuthRepository repository;

  final t0 = DateTime.utc(2026, 11, 13, 10);

  AuthSession stored({
    String n = '0',
    Duration accessLeft = const Duration(minutes: 15),
    Duration refreshLeft = const Duration(days: 30),
  }) => AuthSession(
    email: 'a@example.tn',
    accessToken: 'access-$n',
    accessExpiresAt: t0.add(accessLeft),
    refreshToken: 'refresh-$n',
    refreshExpiresAt: t0.add(refreshLeft),
  );

  void build([AuthSession? session]) {
    store = InMemoryTokenStore(session);
    repository = AuthRepository(api: api, store: store, clock: () => now);
  }

  setUp(() {
    api = FakeAuthApi();
    now = t0;
    build();
  });

  group('sign in and create an account', () {
    test('signed out without a stored session', () async {
      expect(await repository.current(), const AuthState.signedOut());
      expect(await repository.accessToken(), isNull);
    });

    test('a stored session survives a restart', () async {
      build(stored());
      expect(
        await repository.current(),
        const AuthState.signedIn(email: 'a@example.tn'),
      );
      expect(await repository.accessToken(), 'access-0');
      expect(api.refreshes, isEmpty);
    });

    test('sign in stores the tokens, email normalised', () async {
      api.loginResults.add(pair('1'));

      await repository.signIn(email: ' A@Example.TN', password: 'secret pass');

      expect(api.logins.single.email, 'a@example.tn');
      expect(api.logins.single.password, 'secret pass');
      final session = store.session!;
      expect(session.email, 'a@example.tn');
      expect(session.accessToken, 'access-1');
      expect(session.accessExpiresAt, t0.add(const Duration(seconds: 900)));
      expect(session.refreshExpiresAt, t0.add(const Duration(days: 30)));
      expect(
        await repository.current(),
        const AuthState.signedIn(email: 'a@example.tn'),
      );
    });

    test('a failed sign in stores nothing', () async {
      api.loginResults.add(const ApiUnauthorized('wrong email or password'));

      await expectLater(
        repository.signIn(email: 'a@example.tn', password: 'wrong'),
        throwsA(isA<ApiUnauthorized>()),
      );
      expect(store.session, isNull);
    });

    test('creating an account signs in', () async {
      api.registerResults.add(pair('1'));

      await repository.register(email: 'New@Example.tn', password: 'x' * 10);

      expect(api.registrations.single.email, 'new@example.tn');
      expect(store.session!.email, 'new@example.tn');
    });

    test('an email already taken is reported', () async {
      api.registerResults.add(const ApiConflict('exists'));

      await expectLater(
        repository.register(email: 'a@example.tn', password: 'x' * 10),
        throwsA(isA<ApiConflict>()),
      );
      expect(store.session, isNull);
    });

    test('state changes are announced', () async {
      final states = <AuthState>[];
      final subscription = repository.watch().listen(states.add);
      api.loginResults.add(pair('1'));

      await pumpEventQueue();
      await repository.signIn(email: 'a@example.tn', password: 'p');
      await repository.signOut();
      await pumpEventQueue();
      await subscription.cancel();

      expect(states, [
        const AuthState.signedOut(),
        const AuthState.signedIn(email: 'a@example.tn'),
        const AuthState.signedOut(),
      ]);
    });
  });

  group('sign out', () {
    test('forgets the session and tells the server', () async {
      build(stored());

      await repository.signOut();

      expect(store.session, isNull);
      expect(api.logouts, ['refresh-0']);
      expect(await repository.current(), const AuthState.signedOut());
    });

    test('works offline', () async {
      build(stored());
      api.logoutResult = const ApiConnectionError('offline');

      await repository.signOut();

      expect(store.session, isNull);
    });

    test('signed out already: nothing to tell', () async {
      await repository.signOut();
      expect(api.logouts, isEmpty);
    });
  });

  group('access token', () {
    test('refreshed shortly before it expires', () async {
      build(stored(accessLeft: const Duration(seconds: 20)));
      api.refreshResults.add(pair('1'));

      expect(await repository.accessToken(), 'access-1');
      expect(api.refreshes, ['refresh-0']);
      expect(store.session!.refreshToken, 'refresh-1');
      expect(await repository.accessToken(), 'access-1'); // no second refresh
      expect(api.refreshes, hasLength(1));
    });

    test('a forced refresh even when it looks valid', () async {
      build(stored());
      api.refreshResults.add(pair('1'));

      expect(await repository.accessToken(forceRefresh: true), 'access-1');
    });

    test('concurrent callers share one refresh', () async {
      build(stored(accessLeft: Duration.zero));
      api
        ..refreshGate = Completer<void>()
        ..refreshResults.add(pair('1'));

      final tokens = [
        for (var i = 0; i < 3; i++) repository.accessToken(),
      ];
      await pumpEventQueue();
      api.refreshGate!.complete();

      expect(await Future.wait(tokens), ['access-1', 'access-1', 'access-1']);
      expect(api.refreshes, ['refresh-0']);
    });

    test('a rejected refresh signs out', () async {
      build(stored(accessLeft: Duration.zero));
      api.refreshResults.add(const ApiUnauthorized('reused'));

      expect(await repository.accessToken(), isNull);
      expect(store.session, isNull);
      expect(await repository.current(), const AuthState.signedOut());
    });

    test('offline: no token now, the session is kept', () async {
      build(stored(accessLeft: Duration.zero));
      api.refreshResults
        ..add(const ApiConnectionError('offline'))
        ..add(pair('1'));

      expect(await repository.accessToken(), isNull);
      expect(store.session!.refreshToken, 'refresh-0');
      expect(await repository.accessToken(), 'access-1'); // back online
    });

    test('an expired refresh token signs out without asking', () async {
      build(stored(accessLeft: Duration.zero, refreshLeft: Duration.zero));

      expect(await repository.accessToken(), isNull);
      expect(api.refreshes, isEmpty);
      expect(store.session, isNull);
    });
  });
}
