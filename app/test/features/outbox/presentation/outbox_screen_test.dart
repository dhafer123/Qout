import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/api/api_providers.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/features/auth/presentation/sign_in_screen.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/outbox/domain/queued_contribution.dart';
import 'package:qout/features/outbox/presentation/outbox_screen.dart';

import '../../../helpers/fake_auth_api.dart';
import '../../../helpers/fake_outbox.dart';
import '../../../helpers/pump_app.dart';

final _created = DateTime.utc(2026, 11, 16, 15);
final _nextTry = DateTime.utc(2026, 11, 16, 15, 7);

String _contribution(String clientId, String? name) => QueuedContribution.of(
  ContributionCreate(
    clientId: clientId,
    ean: '6191234567897',
    name: name,
    category: Category.general,
    basis: NutritionBasis.per100g,
    nutrition: const NutritionValues(),
    photos: const ContributionPhotos(front: '', nutrition: ''),
    parserUsed: ParserUsed.manual,
  ),
  {PhotoKind.front: 'f.jpg', PhotoKind.nutrition: 'n.jpg'},
).toPayload();

String _report(String clientId) =>
    jsonEncode({'client_id': clientId, 'ean': '6194039501011'});

void main() {
  late AppDatabase database;
  late FakeOutboxFiles files;
  late FakeOutboxTrigger trigger;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    files = FakeOutboxFiles();
    trigger = FakeOutboxTrigger();
  });

  tearDown(() => database.close());

  OutboxDao dao() => database.outboxDao;

  Future<int> queue(String clientId, String kind, String payload) async {
    await dao().enqueue(
      kind: kind,
      clientId: clientId,
      payload: payload,
      createdAt: _created,
    );
    return (await dao().find(clientId))!.id;
  }

  /// Waiting (failed once), needing sign-in, and refused.
  Future<void> threeStates() async {
    final waiting = await queue(
      'w',
      'new_product',
      _contribution('w', 'Sablés'),
    );
    final signIn = await queue('s', 'error_report', _report('s'));
    final refused = await queue('r', 'new_product', _contribution('r', null));
    await dao().recordRetry(
      waiting,
      error: 'No connection to Qout.',
      nextAttemptAt: _nextTry,
    );
    await dao().recordNeedsSignIn(signIn, 'Sign in to send it.');
    await dao().recordRefused(refused, 'Not accepted: salt_g too high');
  }

  Future<void> open(WidgetTester tester, {String? route}) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpQoutApp(
      database: database,
      outboxFiles: files,
      outboxTrigger: trigger,
      outboxEntries: dao().watchAll(),
    );
    if (route != null) await tester.pushRoute(route);
    await tester.pumpAndSettle();
  }

  Finder card(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(Card));

  group('home card', () {
    testWidgets('hidden while nothing is queued', (tester) async {
      await open(tester);
      expect(find.byType(OutboxCard), findsOneWidget);
      expect(find.textContaining('waiting to be sent'), findsNothing);
      await tester.unmountQoutApp();
    });

    testWidgets('counts by state; opens the queue', (tester) async {
      await threeStates();
      await queue('w2', 'error_report', _report('w2'));
      await open(tester);

      expect(
        find.text(
          '2 waiting to be sent · 1 need you to sign in · 1 not accepted',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await tester.tap(find.byType(OutboxCard));
      await tester.pumpAndSettle();
      expect(find.byType(OutboxScreen), findsOneWidget);
      await tester.unmountQoutApp();
    });

    testWidgets('follows the queue as it changes', (tester) async {
      await open(tester);
      await queue('a', 'error_report', _report('a'));
      await tester.pumpAndSettle();
      expect(find.text('1 waiting to be sent'), findsOneWidget);
      expect(find.byIcon(Icons.outbox_outlined), findsOneWidget);

      await dao().remove((await dao().find('a'))!.id);
      await tester.pumpAndSettle();
      expect(find.textContaining('waiting to be sent'), findsNothing);
      await tester.unmountQoutApp();
    });
  });

  group('queue screen', () {
    testWidgets('each entry with its state', (tester) async {
      await threeStates();
      await open(tester, route: AppRoutes.outbox);

      expect(find.text('Waiting to be sent'), findsOneWidget); // title
      final local = _nextTry.toLocal();
      final time =
          '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
      expect(find.text('Sablés'), findsOneWidget);
      expect(find.text('New product · 6191234567897'), findsNWidgets(2));
      expect(
        find.text('No connection to Qout. Next try at $time.'),
        findsOneWidget,
      );
      expect(find.text('Error report'), findsOneWidget);
      expect(find.text('Product 6194039501011'), findsOneWidget);
      expect(find.text('Sign in to send it.'), findsOneWidget);
      expect(find.text('New product'), findsOneWidget); // no name given
      expect(find.text('Not accepted: salt_g too high'), findsOneWidget);

      // Actions per state.
      expect(
        find.descendant(of: card('Sablés'), matching: find.text('Try now')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card('Error report'),
          matching: find.text('Sign in'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card('New product'),
          matching: find.text('Try now'),
        ),
        findsNothing,
      );
      await tester.unmountQoutApp();
    });

    testWidgets('try now: due at once, and a sync', (tester) async {
      await threeStates();
      await open(tester, route: AppRoutes.outbox);
      final syncs = trigger.syncs;

      await tester.tap(
        find.descendant(of: card('Sablés'), matching: find.text('Try now')),
      );
      await tester.pumpAndSettle();

      final row = await dao().find('w');
      expect(row!.nextAttemptAt, isNull);
      expect(trigger.syncs, syncs + 1);
      await tester.unmountQoutApp();
    });

    testWidgets('delete asks first, then removes it and its photos', (
      tester,
    ) async {
      await threeStates();
      await open(tester, route: AppRoutes.outbox);

      Future<void> tapDelete() async {
        await tester.tap(
          find.descendant(
            of: card('New product'),
            matching: find.text('Delete'),
          ),
        );
        await tester.pumpAndSettle();
      }

      await tapDelete();
      expect(find.text('Delete it?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Not accepted: salt_g too high'), findsOneWidget);

      await tapDelete();
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('Not accepted: salt_g too high'), findsNothing);
      expect(await dao().find('r'), isNull);
      expect(files.removed, ['r']);
      await tester.unmountQoutApp();
    });

    testWidgets('sign in opens the form', (tester) async {
      await threeStates();
      await open(tester, route: AppRoutes.outbox);
      await tester.tap(
        find.descendant(
          of: card('Error report'),
          matching: find.text('Sign in'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      await tester.unmountQoutApp();
    });

    testWidgets('nothing waiting', (tester) async {
      await open(tester, route: AppRoutes.outbox);
      expect(
        find.text('Nothing waiting. Everything has been sent.'),
        findsOneWidget,
      );
      await tester.unmountQoutApp();
    });
  });

  group('status text', () {
    OutboxRow row({
      OutboxState state = OutboxState.waiting,
      String? error,
      DateTime? next,
      String kind = 'new_product',
      String payload = '{}',
    }) => OutboxRow(
      id: 1,
      kind: kind,
      clientId: 'c',
      payload: payload,
      createdAt: _created,
      state: state,
      nextAttemptAt: next,
      attempts: 0,
      lastError: error,
    );

    test('by state', () {
      expect(outboxStatusText(row(), sending: false), 'Waiting to be sent.');
      expect(outboxStatusText(row(), sending: true), 'Sending…');
      expect(
        outboxStatusText(row(error: 'Qout is busy.'), sending: false),
        'Qout is busy. Will try again.',
      );
      expect(
        outboxStatusText(row(state: OutboxState.refused), sending: false),
        'Not accepted.',
      );
      expect(
        outboxStatusText(row(state: OutboxState.needsSignIn), sending: false),
        'Sign in to send it.',
      );
    });

    test('an unreadable entry still has a label', () {
      expect(outboxEntryLabel(row(payload: 'x')), (
        title: 'Unreadable entry',
        subtitle: 'new_product',
      ));
    });
  });

  group('syncs', () {
    testWidgets('when the app starts and comes back', (tester) async {
      await open(tester);
      expect(trigger.syncs, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(trigger.syncs, 2);
      await tester.unmountQoutApp();
    });

    testWidgets('when the user signs in, not at start', (tester) async {
      final authApi = FakeAuthApi()..loginResults.add(pair('1'));
      await tester.pumpQoutApp(
        database: database,
        outboxTrigger: trigger,
        overrides: [authApiProvider.overrideWithValue(authApi)],
      );
      expect(trigger.signIns, 0); // starting signed out isn't signing in

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'a@example.tn',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'a long password',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(trigger.signIns, 1);
    });
  });
}
