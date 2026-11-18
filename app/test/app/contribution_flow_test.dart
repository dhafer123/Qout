import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/api/api_providers.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/core/database/database.dart';
import 'package:qout/features/auth/domain/auth_session.dart';
import 'package:qout/features/auth/presentation/sign_in_screen.dart';
import 'package:qout/features/contribute/presentation/contribute_screen.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/outbox/data/outbox.dart';
import 'package:qout/features/outbox/presentation/outbox_scheduler.dart';
import 'package:qout/features/outbox/presentation/outbox_screen.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/domain/product_result.dart';

import '../helpers/fake_auth_api.dart';
import '../helpers/fake_contribution.dart';
import '../helpers/fake_product_repository.dart';
import '../helpers/in_memory_token_store.dart';
import '../helpers/pump_app.dart';

const _ean = '6191234567897';

/// Syncs with the app's own outbox (the real sending, no timers).
class _RunTrigger implements OutboxTrigger {
  ProviderContainer? container;

  @override
  Future<void> sync() async => container?.read(outboxProvider).run();

  @override
  Future<void> signedIn() => sync();
}

/// Takes the photo for each tile [titles] with the camera.
Future<void> _takePhotos(WidgetTester tester, List<String> titles) async {
  for (final title in titles) {
    await tester.tap(
      find.descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(Card)),
        matching: find.text('Camera'),
      ),
    );
    await tester.pump();
    await tester.pump();
  }
}

/// End to end with a fake API: an unknown product is added from three
/// photos, the label read by the rules parser and the LLM fallback.
void main() {
  testWidgets('unknown product: sign in, photos, check, send', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fake = FakeContribution(
      photos: ['front.jpg', 'salt.jpg', 'ingredients.jpg'],
      texts: {
        'front.jpg': 'Sablés\nMarque',
        'salt.jpg': saltMissingLabelText,
        'ingredients.jpg': 'Ingrédients : farine de blé, sucre, beurre',
      },
    );
    fake.api.parseResults.add(recordedLabelParse('label-parse-salt-missing'));
    fake.api.fallbackResults.add(recordedFallback('label-fallback-done'));
    final authApi = FakeAuthApi()..loginResults.add(pair('1'));

    await tester.pumpQoutApp(
      overrides: [
        ...fake.overrides,
        authApiProvider.overrideWithValue(authApi),
        productRepositoryProvider.overrideWithValue(
          FakeProductRepository(
            results: [const ProductResult.notFound(ean: _ean)],
          ),
        ),
      ],
    );
    await tester.pushRoute(AppRoutes.product(_ean));
    await tester.pumpAndSettle();

    // Unknown: adding it asks to sign in first.
    await tester.tap(find.text('Add this product'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
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
    expect(find.byType(ContributeScreen), findsOneWidget);

    // Three photos.
    for (final title in [
      'Front of the package',
      'Nutrition table',
      'Ingredients (optional)',
    ]) {
      await tester.tap(
        find.descendant(
          of: find.ancestor(of: find.text(title), matching: find.byType(Card)),
          matching: find.text('Camera'),
        ),
      );
      await tester.pump();
      await tester.pump();
    }
    expect(find.text('Text read.'), findsNWidgets(3));
    await tester.tap(find.text('Continue'));
    await tester.pump();

    // The rules parser missed the salt; the fallback reads it.
    expect(find.text('Check the values'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(find.textContaining('Read by AI'), findsOneWidget);
    String value(String label) => tester
        .widget<TextField>(find.widgetWithText(TextField, label))
        .controller!
        .text;
    expect(value('Salt'), '0.85');

    // The contributor completes and checks.
    await tester.tap(find.text('None (0 %)'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Product name (optional)'),
      'Sablés au beurre',
    );
    await tester.pump();
    expect(find.text('Unverified'), findsOneWidget);
    expect(find.textContaining('Provisional grade'), findsOneWidget);

    await tester.tap(find.text('Send for review'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Thank you!'), findsOneWidget);

    final body = fake.api.submitted.single;
    expect(body.ean, _ean);
    expect(body.name, 'Sablés au beurre');
    expect(body.parserUsed, ParserUsed.llm);
    expect(body.nutrition.saltG, 0.85);
    expect(body.nutrition.fvlPercent, 0);
    expect(body.ocrText?.nutrition, saltMissingLabelText);
    expect(fake.puts.map((put) => put.$3), everyElement('image/jpeg'));
    expect(fake.api.uploads.map((upload) => upload.kind), [
      PhotoKind.front,
      PhotoKind.nutrition,
      PhotoKind.ingredients,
    ]);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('offline: saved, shown on the home screen, sent later', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 3200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final trigger = _RunTrigger();

    final fake = FakeContribution(
      photos: ['front.jpg', 'nutrition.jpg'],
      texts: {'front.jpg': 'Sablés', 'nutrition.jpg': cleanLabelText},
    );
    fake.api.parseResults.add(recordedLabelParse('label-parse-ok'));
    // The connection drops before sending.
    fake.api.uploadErrors.add(const ApiConnectionError('offline'));

    await tester.pumpQoutApp(
      database: database,
      tokens: InMemoryTokenStore(
        AuthSession(
          email: 'a@example.tn',
          accessToken: 'access',
          accessExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
          refreshToken: 'refresh',
          refreshExpiresAt: DateTime.now().add(const Duration(days: 30)),
        ),
      ),
      outboxTrigger: trigger,
      outboxEntries: database.outboxDao.watchAll(),
      overrides: [
        ...fake.overrides,
        productRepositoryProvider.overrideWithValue(
          FakeProductRepository(
            results: [const ProductResult.notFound(ean: _ean)],
          ),
        ),
      ],
    );
    trigger.container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    await tester.pushRoute(AppRoutes.product(_ean));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add this product'));
    await tester.pumpAndSettle();
    await _takePhotos(tester, ['Front of the package', 'Nutrition table']);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('None (0 %)'));
    await tester.pump();
    await tester.tap(find.text('Send for review'));
    await tester.pumpAndSettle();

    // Kept on the phone.
    expect(find.text('Saved'), findsOneWidget);
    expect(find.textContaining('No connection to Qout.'), findsOneWidget);
    expect(fake.api.submitted, isEmpty);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Shown on the home screen.
    expect(find.text('1 waiting to be sent'), findsOneWidget);
    await tester.tap(find.byType(OutboxCard));
    await tester.pumpAndSettle();
    expect(find.textContaining('Next try at'), findsOneWidget);

    // Back online: sent at once on request.
    await tester.tap(find.text('Try now'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing waiting'), findsOneWidget);
    expect(find.text('Everything has been sent.'), findsOneWidget);
    final body = fake.api.submitted.single;
    expect(body.ean, _ean);
    expect(body.nutrition.saltG, 0.85);
    expect(fake.api.uploads.map((u) => u.kind), [
      PhotoKind.front, // the failed attempt
      PhotoKind.front,
      PhotoKind.nutrition,
    ]);
    expect(await database.outboxDao.all(), isEmpty);
    await tester.unmountQoutApp();
  });
}
