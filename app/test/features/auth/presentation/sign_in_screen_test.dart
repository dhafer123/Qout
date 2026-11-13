import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/api/api_providers.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/auth/domain/auth_session.dart';
import 'package:qout/features/auth/presentation/sign_in_screen.dart';
import 'package:qout/features/home/presentation/home_screen.dart';

import '../../../helpers/fake_auth_api.dart';
import '../../../helpers/in_memory_token_store.dart';
import '../../../helpers/pump_app.dart';

void main() {
  late FakeAuthApi api;
  late InMemoryTokenStore tokens;

  setUp(() {
    api = FakeAuthApi();
    tokens = InMemoryTokenStore();
  });

  Future<void> openSignIn(WidgetTester tester) async {
    await tester.pumpQoutApp(
      tokens: tokens,
      overrides: [qoutApiProvider.overrideWithValue(api)],
    );
    await tester.pushRoute(AppRoutes.signIn);
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> fill(
    WidgetTester tester, {
    String email = 'a@example.tn',
    String password = 'a long password',
  }) async {
    await tester.enterText(field('Email'), email);
    await tester.enterText(field('Password'), password);
  }

  Future<void> submit(WidgetTester tester, String button) async {
    await tester.tap(find.widgetWithText(FilledButton, button));
    await tester.pumpAndSettle();
  }

  group('form validation', () {
    testWidgets('empty fields', (tester) async {
      await openSignIn(tester);

      await submit(tester, 'Sign in');

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(api.logins, isEmpty);
    });

    testWidgets('an invalid email', (tester) async {
      await openSignIn(tester);
      await fill(tester, email: 'not-an-email');

      await submit(tester, 'Sign in');

      expect(find.text('This is not a valid email address.'), findsOneWidget);
      expect(api.logins, isEmpty);
    });

    testWidgets('a new account needs a 10-character password', (tester) async {
      await openSignIn(tester);
      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      expect(find.text('At least 10 characters.'), findsOneWidget);
      await fill(tester, password: 'short');

      await submit(tester, 'Create account');

      expect(find.text('Use at least 10 characters.'), findsOneWidget);
      expect(api.registrations, isEmpty);
    });

    testWidgets('a short password is fine for signing in', (tester) async {
      api.loginResults.add(const ApiUnauthorized('wrong email or password'));
      await openSignIn(tester);
      await fill(tester, password: 'short');

      await submit(tester, 'Sign in');

      expect(api.logins, hasLength(1));
    });

    testWidgets('switching modes keeps what was typed', (tester) async {
      await openSignIn(tester);
      await fill(tester);

      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();

      expect(find.text('Create an account'), findsOneWidget); // title
      expect(find.text('a@example.tn'), findsOneWidget);
      await tester.tap(find.text('Already have an account? Sign in'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    });

    testWidgets('the password can be shown', (tester) async {
      await openSignIn(tester);
      await fill(tester);
      EditableText password() => tester.widget<EditableText>(
        find.descendant(
          of: field('Password'),
          matching: find.byType(EditableText),
        ),
      );
      expect(password().obscureText, isTrue);

      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();

      expect(password().obscureText, isFalse);
    });
  });

  group('server answers', () {
    testWidgets('signing in returns to where it was asked', (tester) async {
      api.loginResults.add(pair('1'));
      await openSignIn(tester);
      await fill(tester, email: ' A@Example.TN ');

      await submit(tester, 'Sign in');

      expect(find.byType(SignInScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(api.logins.single.email, 'a@example.tn');
      expect(tokens.session?.email, 'a@example.tn');
    });

    testWidgets('creating an account signs in', (tester) async {
      api.registerResults.add(pair('1'));
      await openSignIn(tester);
      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      await fill(tester);

      await submit(tester, 'Create account');

      expect(api.registrations, hasLength(1));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tokens.session, isNotNull);
    });

    for (final (error, message) in [
      (
        const ApiUnauthorized('wrong email or password') as QoutApiException,
        'Wrong email or password.',
      ),
      (
        const ApiTooManyRequests(
          'slow down',
          retryAfter: Duration(minutes: 14),
        ),
        'Too many attempts. Try again in 14 minutes.',
      ),
      (
        const ApiConnectionError('offline'),
        'You are offline. Connect to the internet and try again.',
      ),
      (
        const ApiBadResponse(500, 'boom'),
        'Qout could not be reached. Try again in a moment.',
      ),
    ]) {
      testWidgets('sign in refused: $message', (tester) async {
        api.loginResults.add(error);
        await openSignIn(tester);
        await fill(tester);

        await submit(tester, 'Sign in');

        expect(find.text(message), findsOneWidget);
        expect(find.byType(SignInScreen), findsOneWidget);
        expect(tokens.session, isNull);
      });
    }

    testWidgets('an email already registered', (tester) async {
      api.registerResults.add(const ApiConflict('exists'));
      await openSignIn(tester);
      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      await fill(tester);

      await submit(tester, 'Create account');

      expect(
        find.text(
          'An account with this email already exists. Sign in instead.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the server refuses the entries', (tester) async {
      api.registerResults.add(
        const ApiInvalidRequest('not a valid email address'),
      );
      await openSignIn(tester);
      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      await fill(tester);

      await submit(tester, 'Create account');

      expect(find.text('Not a valid email address.'), findsOneWidget);
    });
  });

  group('home menu', () {
    final session = AuthSession(
      email: 'a@example.tn',
      accessToken: 'access',
      accessExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
      refreshToken: 'refresh-0',
      refreshExpiresAt: DateTime.now().add(const Duration(days: 30)),
    );

    testWidgets('signed out: Sign in opens the form', (tester) async {
      await tester.pumpQoutApp(tokens: tokens);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('signed in: Sign out forgets the session', (tester) async {
      tokens.session = session;
      await tester.pumpQoutApp(
        tokens: tokens,
        overrides: [qoutApiProvider.overrideWithValue(api)],
      );

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out (a@example.tn)'));
      await tester.pumpAndSettle();

      expect(find.text('Signed out'), findsOneWidget);
      expect(tokens.session, isNull);
      expect(api.logouts, ['refresh-0']);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
    });
  });
}
