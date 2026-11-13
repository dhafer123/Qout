import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/features/auth/data/token_store.dart';
import 'package:qout/features/auth/domain/auth_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = AuthSession(
    email: 'a@example.tn',
    accessToken: 'access',
    accessExpiresAt: DateTime.utc(2026, 11, 13, 10, 15),
    refreshToken: 'refresh',
    refreshExpiresAt: DateTime.utc(2026, 12, 13, 10),
  );

  test('empty at first; write, read, clear', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = SecureTokenStore();

    expect(await store.read(), isNull);
    await store.write(session);
    expect(await SecureTokenStore().read(), session); // a new instance too
    await store.clear();
    expect(await store.read(), isNull);
  });

  test('unreadable data is dropped: sign in again', () async {
    FlutterSecureStorage.setMockInitialValues({'qout.auth.session': '{"x":1'});
    final store = SecureTokenStore();

    expect(await store.read(), isNull);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
  });
}
