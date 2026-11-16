import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/api/api_providers.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/auth/presentation/sign_in_screen.dart';
import 'package:qout/features/contribute/presentation/contribute_screen.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/product/data/product_repository.dart';
import 'package:qout/features/product/domain/product_result.dart';

import '../helpers/fake_auth_api.dart';
import '../helpers/fake_contribution.dart';
import '../helpers/fake_product_repository.dart';
import '../helpers/pump_app.dart';

/// The app's API: sign-in from [FakeAuthApi], the contribution calls from
/// [FakeContributionApi]; nothing else is expected.
class _Api extends FakeAuthApi {
  _Api(this.contributions);

  final FakeContributionApi contributions;

  @override
  Future<LabelParseResult> parseLabelText({required LabelParseRequest body}) =>
      contributions.parseLabelText(body: body);

  @override
  Future<LabelFallbackRead> getLabelFallback({required String fallbackId}) =>
      contributions.getLabelFallback(fallbackId: fallbackId);

  @override
  Future<UploadTicket> createUpload({required UploadRequest body}) =>
      contributions.createUpload(body: body);

  @override
  Future<ContributionRead> submitContribution({
    required ContributionCreate body,
  }) => contributions.submitContribution(body: body);
}

const _ean = '6191234567897';

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
    final api = _Api(fake.api)..loginResults.add(pair('1'));

    await tester.pumpQoutApp(
      overrides: [
        ...fake.overrides,
        qoutApiProvider.overrideWithValue(api),
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
}
