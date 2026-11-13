import 'package:flutter_test/flutter_test.dart';
import 'package:qout/features/auth/domain/auth_session.dart';
import 'package:qout/features/auth/domain/credentials.dart';

final t0 = DateTime.utc(2026, 11, 13, 10);

AuthSession session() => AuthSession(
  email: 'a@example.tn',
  accessToken: 'access',
  accessExpiresAt: t0.add(const Duration(minutes: 15)),
  refreshToken: 'refresh',
  refreshExpiresAt: t0.add(const Duration(days: 30)),
);

void main() {
  group('email', () {
    test('trimmed and lower-cased, as the backend compares', () {
      expect(normalizeEmail('  Dhafer@Example.TN '), 'dhafer@example.tn');
    });

    test('valid addresses', () {
      for (final email in ['a@b.tn', ' A+tag@sub.example.com ']) {
        expect(emailProblem(email), isNull, reason: email);
      }
    });

    test('empty and invalid addresses', () {
      expect(emailProblem('  '), 'Enter your email address.');
      for (final email in ['plain', 'a@b', 'a b@c.tn', '@c.tn', 'a@@c.tn']) {
        expect(
          emailProblem(email),
          'This is not a valid email address.',
          reason: email,
        );
      }
      final tooLong = '${'a' * 64}@${'b' * 186}.com'; // 255 characters
      expect(emailProblem(tooLong), 'This is not a valid email address.');
    });
  });

  group('password', () {
    test('a new account needs 10 to 128 characters', () {
      expect(passwordProblem('x' * 10, newAccount: true), isNull);
      expect(passwordProblem('x' * 128, newAccount: true), isNull);
      expect(
        passwordProblem('x' * 9, newAccount: true),
        'Use at least 10 characters.',
      );
      expect(
        passwordProblem('x' * 129, newAccount: true),
        'Use at most 128 characters.',
      );
    });

    test('signing in only needs one', () {
      expect(passwordProblem('short', newAccount: false), isNull);
      expect(
        passwordProblem('', newAccount: false),
        'Enter your password.',
      );
      expect(
        passwordProblem('x' * 129, newAccount: false),
        'Use at most 128 characters.',
      );
    });
  });

  group('session', () {
    test('JSON round trip', () {
      final original = session();
      expect(authSessionFromJson(original.toJson()), original);
    });

    test('the access token is used until 30 s before it expires', () {
      final s = session();
      expect(s.accessUsableAt(t0), isTrue);
      expect(s.accessUsableAt(t0.add(const Duration(minutes: 14))), isTrue);
      expect(
        s.accessUsableAt(t0.add(const Duration(minutes: 14, seconds: 31))),
        isFalse,
      );
    });

    test('the refresh token works until it expires', () {
      final s = session();
      expect(s.refreshUsableAt(t0.add(const Duration(days: 29))), isTrue);
      expect(s.refreshUsableAt(t0.add(const Duration(days: 30))), isFalse);
    });
  });
}
