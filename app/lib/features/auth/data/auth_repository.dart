import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/core/api/api_providers.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/auth/data/token_store.dart';
import 'package:qout/features/auth/domain/auth_session.dart';
import 'package:qout/features/auth/domain/credentials.dart';

/// The contributor account on this phone: sign in, create an account, sign
/// out, and a valid access token for calls that need one.
///
/// - Tokens live in [TokenStore] (secure storage), so a session survives
///   app restarts.
/// - [accessToken] refreshes an expiring token first; concurrent callers share
///   one refresh (each refresh token works only once on the server).
/// - A rejected refresh (expired, revoked, reused) signs out; no connection
///   keeps the session for later.
class AuthRepository {
  AuthRepository({
    required QoutApi api,
    required TokenStore store,
    DateTime Function()? clock,
  }) : _api = api,
       _store = store,
       _clock = clock ?? DateTime.now;

  final QoutApi _api;
  final TokenStore _store;
  final DateTime Function() _clock;

  final _changes = StreamController<AuthState>.broadcast();
  AuthSession? _session;
  bool _loaded = false;
  Future<String?>? _refreshing;

  /// The current state, then every change.
  Stream<AuthState> watch() async* {
    await _load();
    yield _state;
    yield* _changes.stream;
  }

  Future<AuthState> current() async {
    await _load();
    return _state;
  }

  /// Throws [QoutApiException]: [ApiUnauthorized] for a wrong email or
  /// password, [ApiTooManyRequests] after too many attempts.
  Future<void> signIn({required String email, required String password}) async {
    final normalized = normalizeEmail(email);
    final pair = await _api.login(
      body: Credentials(email: normalized, password: password),
    );
    await _save(_sessionFrom(normalized, pair));
  }

  /// Creates the account and signs in. Throws [QoutApiException]:
  /// [ApiConflict] when the email already has an account,
  /// [ApiInvalidRequest] when the server refuses the email or password.
  Future<void> register({
    required String email,
    required String password,
  }) async {
    final normalized = normalizeEmail(email);
    final pair = await _api.register(
      body: Credentials(email: normalized, password: password),
    );
    await _save(_sessionFrom(normalized, pair));
  }

  /// Signs out on this phone at once; tells the server when it can be
  /// reached (otherwise the server-side session just expires).
  Future<void> signOut() async {
    await _load();
    final session = _session;
    await _save(null);
    if (session == null) return;
    try {
      await _api.logout(
        body: RefreshRequest(refreshToken: session.refreshToken),
      );
    } on QoutApiException {
      // Offline or server trouble: the phone is signed out regardless.
    }
  }

  /// A usable access token, refreshed if needed; null when signed out or the
  /// refresh can't happen now. With [forceRefresh] (the server rejected the
  /// current one), a new token is fetched even if it looks valid.
  Future<String?> accessToken({bool forceRefresh = false}) async {
    await _load();
    final session = _session;
    if (session == null) return null;
    if (!forceRefresh && session.accessUsableAt(_clock())) {
      return session.accessToken;
    }
    return _refreshing ??= _refresh(session).whenComplete(
      () => _refreshing = null,
    );
  }

  Future<String?> _refresh(AuthSession session) async {
    if (!session.refreshUsableAt(_clock())) {
      await _save(null);
      return null;
    }
    try {
      final pair = await _api.refreshTokens(
        body: RefreshRequest(refreshToken: session.refreshToken),
      );
      final renewed = _sessionFrom(session.email, pair);
      await _save(renewed);
      return renewed.accessToken;
    } on ApiUnauthorized {
      await _save(null); // expired, revoked or reused: sign in again
      return null;
    } on QoutApiException {
      return null; // offline or server trouble: keep the session for later
    }
  }

  AuthSession _sessionFrom(String email, TokenPair pair) {
    final now = _clock();
    return AuthSession(
      email: email,
      accessToken: pair.accessToken,
      accessExpiresAt: now.add(Duration(seconds: pair.expiresIn)),
      refreshToken: pair.refreshToken,
      refreshExpiresAt: now.add(Duration(seconds: pair.refreshExpiresIn)),
    );
  }

  AuthState get _state => switch (_session) {
    final session? => AuthState.signedIn(email: session.email),
    null => const AuthState.signedOut(),
  };

  Future<void> _load() async {
    if (_loaded) return;
    _session = await _store.read();
    _loaded = true;
  }

  Future<void> _save(AuthSession? session) async {
    final before = _state;
    _session = session;
    _loaded = true;
    if (session == null) {
      await _store.clear();
    } else {
      await _store.write(session);
    }
    if (_state != before) _changes.add(_state);
  }
}

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (ref) => AuthRepository(
        api: ref.watch(qoutApiProvider),
        store: ref.watch(tokenStoreProvider),
      ),
    );

/// Signed in or out, for the UI.
final StreamProvider<AuthState> authStateProvider = StreamProvider(
  (ref) => ref.watch(authRepositoryProvider).watch(),
);
