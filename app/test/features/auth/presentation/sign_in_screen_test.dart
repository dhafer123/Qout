import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/api/api_providers.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/auth/domain/auth_session.dart';
import 'package:qout/features/auth/presentation/sign_in_art.dart';
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
      overrides: [authApiProvider.overrideWithValue(api)],
    );
    await tester.pushRoute(AppRoutes.signIn);
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  /// The Sign in / Sign up switch's choice (the button says "Sign in" too).
  Finder segment(String label) => find.descendant(
    of: find.byType(SegmentedButton<bool>),
    matching: find.text(label),
  );

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

  group('look (T46)', () {
    testWidgets('the illustration, a title per mode, the switch', (
      tester,
    ) async {
      await openSignIn(tester);
      expect(find.byType(SignInArt), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byType(SegmentedButton<bool>), findsOneWidget);
      expect(find.text('At least 10 characters.'), findsNothing);

      await tester.tap(segment('Sign up'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Create account'),
        findsOneWidget,
      );
      expect(find.text('At least 10 characters.'), findsOneWidget);
    });

    testWidgets('switching modes clears the error', (tester) async {
      api.loginResults.add(const ApiUnauthorized('wrong email or password'));
      await openSignIn(tester);
      await fill(tester);
      await submit(tester, 'Sign in');
      expect(find.text('Wrong email or password.'), findsOneWidget);

      await tester.tap(segment('Sign up'));
      await tester.pumpAndSettle();
      expect(find.text('Wrong email or password.'), findsNothing);
    });

    testWidgets('the keyboard folds the illustration away', (tester) async {
      await openSignIn(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.byType(SignInArt), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    });

    double progress(WidgetTester tester) => tester
        .widget<Lottie>(
          find.descendant(
            of: find.byType(SignInArt),
            matching: find.byType(Lottie),
          ),
        )
        .controller!
        .value;

    testWidgets('it plays a round, rests, and plays again', (tester) async {
      await openSignIn(tester);
      // Settled at the end of a round, resting.
      expect(progress(tester), 1);
      await tester.pump(SignInArt.rest - const Duration(milliseconds: 100));
      expect(progress(tester), 1);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      expect(progress(tester), inExclusiveRange(0, 1));
    });

    testWidgets('reduced motion: it stands still', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await openSignIn(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(progress(tester), 0);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  test("the illustration's phone is in the brand greens (T46)", () {
    final json =
        jsonDecode(File(SignInArt.asset).readAsStringSync())
            as Map<String, dynamic>;
    final found = <int>{};
    int rgb(List<dynamic> c, int at) =>
        ((c[at] as num) * 255).round() << 16 |
        ((c[at + 1] as num) * 255).round() << 8 |
        ((c[at + 2] as num) * 255).round();
    void walk(Object? o) {
      if (o is Map<String, dynamic>) {
        final ty = o['ty'];
        if ((ty == 'fl' || ty == 'st') && o['c'] is Map) {
          final k = (o['c'] as Map)['k'] as List<dynamic>;
          if (k.first is num) found.add(rgb(k, 0));
        }
        if (ty == 'gf' || ty == 'gs') {
          final g = o['g'] as Map<String, dynamic>;
          final k = (g['k'] as Map)['k'] as List<dynamic>;
          for (var i = 0; i < (g['p'] as int); i++) {
            found.add(rgb(k, i * 4 + 1));
          }
        }
        o.values.forEach(walk);
      } else if (o is List) {
        o.forEach(walk);
      }
    }

    const phone = {'Group 5', 'phone', 'password', 'login', 'profile'};
    for (final layer in (json['layers'] as List).cast<Map<String, dynamic>>()) {
      if (phone.contains(layer['nm'])) walk(layer);
    }
    // Regression: the supplied phone was hot pink with purple details.
    const pinkAndPurple = {
      0xFF9085, 0xFD80A0, 0xFB6FBB, 0xDE8BDF, //
      0x3B407A, 0xAA80F9, 0x8672E8, 0x6165D7,
    };
    expect(found.intersection(pinkAndPurple), isEmpty);
    expect(found, contains(0x2E7D32));
  });

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
      await tester.tap(find.text('Sign up'));
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

      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();

      expect(find.text('Create your account'), findsOneWidget); // title
      expect(find.text('a@example.tn'), findsOneWidget);
      await tester.tap(segment('Sign in'));
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
      await tester.tap(find.text('Sign up'));
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
      await tester.tap(find.text('Sign up'));
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
      await tester.tap(find.text('Sign up'));
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

    testWidgets('signed out: Sign in on the profile opens the form', (
      tester,
    ) async {
      await tester.pumpQoutApp(tokens: tokens);

      await tester.tap(find.byKey(const ValueKey('tab-profile')));
      await tester.pumpAndSettle();
      // The account card is the last one on the Profile tab (T43d).
      await tester.scrollToCentre(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('signed in: Sign out on the profile asks, then forgets the '
        'session', (tester) async {
      tokens.session = session;
      await tester.pumpQoutApp(
        tokens: tokens,
        overrides: [authApiProvider.overrideWithValue(api)],
      );

      await tester.tap(find.byKey(const ValueKey('tab-profile')));
      await tester.pumpAndSettle();
      await tester.scrollToCentre(
        find.widgetWithText(OutlinedButton, 'Sign out'),
      );
      expect(find.text('a@example.tn'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tokens.session, isNotNull);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Signed out'), findsOneWidget);
      expect(tokens.session, isNull);
      expect(api.logouts, ['refresh-0']);
      expect(find.text('Not signed in'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });
  });
}
