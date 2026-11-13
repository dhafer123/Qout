import 'package:qout/features/auth/data/token_store.dart';
import 'package:qout/features/auth/domain/auth_session.dart';

/// [TokenStore] without the platform's secure storage (tests).
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this.session]);

  AuthSession? session;
  int writes = 0;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession value) async {
    session = value;
    writes++;
  }

  @override
  Future<void> clear() async => session = null;
}
