import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/core/photos/label_photo_picker.dart';
import 'package:qout/features/contribute/data/contribution_repository.dart';
import 'package:qout/features/contribute/domain/contribution_draft.dart';
import 'package:qout/features/contribute/presentation/contribution_controller.dart';
import 'package:qout/scoring/scoring.dart' as scoring;

import '../../../helpers/fake_contribution.dart';

const _ean = '6191234567897';

void main() {
  late FakeContribution fake;
  late ProviderContainer container;
  final provider = contributionControllerProvider(_ean);

  ContributionController controller() => container.read(provider.notifier);
  ContributionState state() => container.read(provider);

  setUp(() {
    fake = FakeContribution(
      texts: {
        'front.jpg': 'Biscuits Sablés\nMarque',
        'nutrition.jpg': cleanLabelText,
        'salt.jpg': saltMissingLabelText,
        'ingredients.jpg': 'Ingrédients : farine de blé, sucre',
      },
    );
    // Listened to: keeps the auto-dispose provider alive.
    container = ProviderContainer(overrides: fake.overrides)
      ..listen(provider, (_, _) {});
  });

  tearDown(() => container.dispose());

  /// Takes the photo at [path] as [kind] (camera).
  Future<void> capture(PhotoKind kind, String? path) {
    fake.photos.add(path);
    return controller().capture(kind, PhotoSource.camera);
  }

  /// All three photos, the nutrition table read completely.
  Future<void> threePhotos() async {
    fake.api.parseResults.add(recordedLabelParse('label-parse-ok'));
    await capture(PhotoKind.front, 'front.jpg');
    await capture(PhotoKind.nutrition, 'nutrition.jpg');
    await capture(PhotoKind.ingredients, 'ingredients.jpg');
  }

  /// The nutrition photo whose salt the rules parser missed, then the LLM
  /// fallback answering [answers] (polled until one isn't pending).
  Future<void> saltMissing(List<Object> answers) async {
    fake.api.parseResults.add(recordedLabelParse('label-parse-salt-missing'));
    fake.api.fallbackResults.addAll(answers);
    await capture(PhotoKind.nutrition, 'salt.jpg');
  }

  test('starts on the photos with a fresh contribution id', () {
    expect(state().step, ContributionStep.photos);
    expect(state().draft.ean, _ean);
    expect(state().draft.clientId, hasLength(36));
    expect(state().reading, LabelReadingStatus.none);
    expect(state().hasRequiredPhotos, isFalse);
  });

  group('photos', () {
    test('front and ingredients: kept with their text, not parsed', () async {
      await capture(PhotoKind.front, 'front.jpg');
      fake.photos.add('ingredients.jpg');
      await controller().capture(PhotoKind.ingredients, PhotoSource.gallery);

      expect(fake.picked, [PhotoSource.camera, PhotoSource.gallery]);
      expect(state().draft.photos, {
        PhotoKind.front: 'front.jpg',
        PhotoKind.ingredients: 'ingredients.jpg',
      });
      expect(state().draft.ocrText[PhotoKind.front], 'Biscuits Sablés\nMarque');
      expect(state().readingPhotos, isEmpty);
      expect(state().reading, LabelReadingStatus.none);
      expect(fake.api.parsed, isEmpty);
    });

    test('cancelled: nothing changes', () async {
      await capture(PhotoKind.front, null);
      expect(state().draft.photos, isEmpty);
      expect(fake.read, isEmpty);
    });

    test('shown as being read while ML Kit works', () async {
      fake.ocrGate = Completer<void>();
      fake.photos.add('front.jpg');
      final done = controller().capture(PhotoKind.front, PhotoSource.camera);
      await pumpEventQueue();
      expect(state().readingPhotos, {PhotoKind.front});
      expect(state().draft.photos[PhotoKind.front], 'front.jpg');

      fake.ocrGate!.complete();
      await done;
      expect(state().readingPhotos, isEmpty);
    });

    test('nutrition table read completely fills the form', () async {
      await threePhotos();
      expect(fake.api.parsed, [cleanLabelText]);
      expect(state().reading, LabelReadingStatus.done);
      expect(state().hasRequiredPhotos, isTrue);
      final draft = state().draft;
      expect(draft.parserUsed, ParserUsed.rules);
      expect(draft.values[NutrientField.salt], '0.85');
      expect(draft.values[NutrientField.energy], '1046');
      expect(draft.revision, 1);
    });

    test('no text on the nutrition photo: typed by hand', () async {
      await capture(PhotoKind.nutrition, 'blank.jpg');
      expect(state().reading, LabelReadingStatus.failed);
      expect(state().draft.photos[PhotoKind.nutrition], 'blank.jpg');
      expect(state().draft.ocrText.containsKey(PhotoKind.nutrition), isFalse);
      expect(fake.api.parsed, isEmpty);
    });

    test('ML Kit failing keeps the photo', () async {
      fake.ocrError = Exception('no model');
      await capture(PhotoKind.nutrition, 'nutrition.jpg');
      expect(state().reading, LabelReadingStatus.failed);
      expect(state().draft.photos[PhotoKind.nutrition], 'nutrition.jpg');
    });

    test('the server not answering: typed by hand', () async {
      fake.api.parseResults.add(const ApiConnectionError('offline'));
      await capture(PhotoKind.nutrition, 'nutrition.jpg');
      expect(state().reading, LabelReadingStatus.failed);
      expect(state().draft.values, isEmpty);
      expect(state().draft.parserUsed, ParserUsed.manual);
    });

    test('nothing read and no fallback: typed by hand', () async {
      fake.api.parseResults.add(
        const LabelParseResult(
          parserUsed: ParserUsed.rules,
          ok: false,
          valuesValue: LabelValues(),
          derived: [],
          approximate: [],
          issues: [LabelIssueRead(code: 'no_nutrition_table', blocking: true)],
        ),
      );
      await capture(PhotoKind.nutrition, 'nutrition.jpg');
      expect(state().reading, LabelReadingStatus.failed);
      expect(state().draft.parserUsed, ParserUsed.manual);
    });

    test('a retaken photo replaces the one being read', () async {
      fake.ocrGate = Completer<void>();
      fake.photos.addAll(['salt.jpg', 'nutrition.jpg']);
      fake.api.parseResults.add(recordedLabelParse('label-parse-ok'));
      final first = controller().capture(
        PhotoKind.nutrition,
        PhotoSource.camera,
      );
      final second = controller().capture(
        PhotoKind.nutrition,
        PhotoSource.camera,
      );
      fake.ocrGate!.complete();
      await Future.wait([first, second]);

      expect(fake.api.parsed, [cleanLabelText]); // the old text isn't sent
      expect(state().draft.ocrText[PhotoKind.nutrition], cleanLabelText);
      expect(state().reading, LabelReadingStatus.done);
    });

    test("a late reading of a replaced photo isn't used", () async {
      fake.api
        ..parseGate = Completer<void>()
        ..parseResults.addAll([
          recordedLabelParse('label-parse-salt-missing'),
          recordedLabelParse('label-parse-ok'),
        ]);
      fake.photos.addAll(['salt.jpg', 'nutrition.jpg']);
      final first = controller().capture(
        PhotoKind.nutrition,
        PhotoSource.camera,
      );
      await pumpEventQueue();
      final second = controller().capture(
        PhotoKind.nutrition,
        PhotoSource.camera,
      );
      await pumpEventQueue();
      fake.api.parseGate!.complete();
      await Future.wait([first, second]);

      expect(fake.api.parsed, [saltMissingLabelText, cleanLabelText]);
      expect(fake.api.fallbackIds, isEmpty); // the old fallback isn't polled
      expect(state().draft.values[NutrientField.salt], '0.85');
      expect(state().draft.revision, 1);
    });

    test('closing the flow while reading is safe', () async {
      fake.ocrGate = Completer<void>();
      fake.photos.add('nutrition.jpg');
      final done = controller().capture(
        PhotoKind.nutrition,
        PhotoSource.camera,
      );
      await pumpEventQueue();
      container.dispose();
      fake.ocrGate!.complete();
      await done;
      expect(fake.api.parsed, isEmpty);
      container = ProviderContainer(); // for tearDown
    });
  });

  group('LLM fallback', () {
    test('its values replace the rules reading while untouched', () async {
      await saltMissing([
        _pending(recordedFallback('label-fallback-done')),
        recordedFallback('label-fallback-done'),
      ]);
      expect(fake.api.fallbackIds, [
        '5f0c2a1e-8d3b-4c6a-9e1f-2b7d4a6c8e01',
        '5f0c2a1e-8d3b-4c6a-9e1f-2b7d4a6c8e01',
      ]);
      expect(state().reading, LabelReadingStatus.aiApplied);
      expect(state().draft.values[NutrientField.salt], '0.85');
      expect(state().draft.parserUsed, ParserUsed.llm);
      expect(state().draft.flagged, isEmpty);
      expect(state().draft.revision, 2);
    });

    test('the rules values are shown while it reads', () async {
      fake.api.parseResults.add(recordedLabelParse('label-parse-salt-missing'));
      fake.api.fallbackResults.add(recordedFallback('label-fallback-done'));
      fake.photos.add('salt.jpg');
      final done = controller().capture(
        PhotoKind.nutrition,
        PhotoSource.camera,
      );
      await pumpEventQueue();
      expect(state().reading, LabelReadingStatus.askingAi);
      expect(state().draft.values[NutrientField.energy], '1046');
      expect(state().draft.flagged, {NutrientField.salt});
      expect(state().draft.parserUsed, ParserUsed.rules);
      await done;
    });

    test('after an edit its values are offered, not applied', () async {
      fake.api.parseResults.add(recordedLabelParse('label-parse-salt-missing'));
      fake.api.fallbackResults.add(recordedFallback('label-fallback-done'));
      fake.photos.add('salt.jpg');
      final done = controller().capture(
        PhotoKind.nutrition,
        PhotoSource.camera,
      );
      await pumpEventQueue();
      controller().setValue(NutrientField.salt, '0,8');
      await done;

      expect(state().reading, LabelReadingStatus.aiOffered);
      expect(state().aiOffer?.parserUsed, ParserUsed.llm);
      expect(state().draft.values[NutrientField.salt], '0,8');
      expect(state().draft.parserUsed, ParserUsed.rules);

      controller().useAiOffer();
      expect(state().reading, LabelReadingStatus.aiApplied);
      expect(state().aiOffer, isNull);
      expect(state().draft.values[NutrientField.salt], '0.85');
      expect(state().draft.parserUsed, ParserUsed.llm);
      expect(state().draft.edited, isFalse);

      controller().useAiOffer(); // nothing offered any more
      expect(state().reading, LabelReadingStatus.aiApplied);
    });

    test('an offer can be declined', () async {
      fake.api.parseResults.add(recordedLabelParse('label-parse-salt-missing'));
      fake.api.fallbackResults.add(recordedFallback('label-fallback-done'));
      fake.photos.add('salt.jpg');
      final done = controller().capture(
        PhotoKind.nutrition,
        PhotoSource.camera,
      );
      await pumpEventQueue();
      controller().setValue(NutrientField.salt, '0,8');
      await done;

      controller().dismissAiOffer();
      expect(state().reading, LabelReadingStatus.done);
      expect(state().aiOffer, isNull);
      expect(state().draft.values[NutrientField.salt], '0,8');
      expect(state().draft.parserUsed, ParserUsed.rules);
    });

    test('no values from it: the rules reading stays', () async {
      await saltMissing([recordedFallback('label-fallback-manual-entry')]);
      expect(state().reading, LabelReadingStatus.done);
      expect(state().draft.parserUsed, ParserUsed.rules);
      expect(state().draft.flagged, {NutrientField.salt});
    });

    test('no values from either: typed by hand', () async {
      fake.api.parseResults.add(
        LabelParseResult(
          parserUsed: ParserUsed.rules,
          ok: false,
          valuesValue: const LabelValues(),
          derived: const [],
          approximate: const [],
          issues: const [],
          fallback: _pending(recordedFallback('label-fallback-manual-entry')),
        ),
      );
      fake.api.fallbackResults.add(
        recordedFallback('label-fallback-manual-entry'),
      );
      await capture(PhotoKind.nutrition, 'nutrition.jpg');
      expect(state().reading, LabelReadingStatus.failed);
    });

    test('a lost answer is asked again', () async {
      await saltMissing([
        const ApiConnectionError('lost'),
        recordedFallback('label-fallback-done'),
      ]);
      expect(fake.api.fallbackIds, hasLength(2));
      expect(state().reading, LabelReadingStatus.aiApplied);
    });

    test('still pending at the deadline: given up', () async {
      await saltMissing([_pending(recordedFallback('label-fallback-done'))]);
      expect(fake.api.fallbackIds, hasLength(5)); // 50 ms / 10 ms
      expect(state().reading, LabelReadingStatus.done);
      expect(state().draft.parserUsed, ParserUsed.rules);
    });

    test('already done in the parse answer: applied at once', () async {
      final parse = recordedLabelParse('label-parse-salt-missing');
      fake.api.parseResults.add(
        LabelParseResult(
          parserUsed: parse.parserUsed,
          ok: parse.ok,
          basis: parse.basis,
          valuesValue: parse.valuesValue,
          derived: parse.derived,
          approximate: parse.approximate,
          issues: parse.issues,
          fallback: recordedFallback('label-fallback-done'),
        ),
      );
      await capture(PhotoKind.nutrition, 'salt.jpg');
      expect(fake.api.fallbackIds, isEmpty);
      expect(state().reading, LabelReadingStatus.aiApplied);
    });

    test('polling is every 2 s for at most 90 s by default', () {
      const polling = FallbackPolling();
      expect(polling.interval, const Duration(seconds: 2));
      expect(polling.attempts, 45);
      expect(const FallbackPolling(interval: Duration.zero).attempts, 1);
    });
  });

  group('review', () {
    test('needs the front and nutrition photos', () async {
      controller().toReview();
      expect(state().step, ContributionStep.photos);
      await capture(PhotoKind.front, 'front.jpg');
      controller().toReview();
      expect(state().step, ContributionStep.photos);
      await capture(PhotoKind.nutrition, 'blank.jpg');
      controller().toReview();
      expect(state().step, ContributionStep.review);
      controller().toPhotos();
      expect(state().step, ContributionStep.photos);
    });

    test('editing a value clears its flag', () async {
      await saltMissing([recordedFallback('label-fallback-manual-entry')]);
      controller().setValue(NutrientField.salt, '0,85');
      expect(state().draft.values[NutrientField.salt], '0,85');
      expect(state().draft.flagged, isEmpty);
      expect(state().draft.edited, isTrue);
      expect(state().draft.revision, 1); // the field already shows it
    });

    test('"None (0 %)" fills the share and shows it', () {
      controller().noFruitOrVegetables();
      expect(state().draft.values[NutrientField.fvl], '0');
      expect(state().draft.revision, 1);
      expect(state().draft.edited, isTrue);
    });

    test('the other fields', () {
      controller()
        ..setEnergyUnit(EnergyUnit.kcal)
        ..setCategory(scoring.Category.beverage)
        ..setBasis(NutritionBasis.per100ml)
        ..setSweeteners(value: true)
        ..setName('Jus')
        ..setBrand('Marque');
      final draft = state().draft;
      expect(draft.energyUnit, EnergyUnit.kcal);
      expect(draft.edited, isTrue);
      expect(draft.category, scoring.Category.beverage);
      expect(draft.basis, NutritionBasis.per100ml);
      expect(draft.sweeteners, isTrue);
      expect(draft.name, 'Jus');
      expect(draft.brand, 'Marque');
    });
  });

  group('send', () {
    test('uploads the photos, then submits everything', () async {
      await threePhotos();
      controller()
        ..toReview()
        ..setName('  Biscuits sablés ')
        ..setBrand('   ')
        ..setCategory(scoring.Category.general)
        ..noFruitOrVegetables();

      expect(await controller().send(), isTrue);

      final id = state().draft.clientId;
      expect(state().step, ContributionStep.sent);
      expect(state().sending, isFalse);
      expect(fake.api.uploads.map((u) => (u.contributionId, u.kind)), [
        (id, PhotoKind.front),
        (id, PhotoKind.nutrition),
        (id, PhotoKind.ingredients),
      ]);
      expect(fake.puts, hasLength(3));
      final body = fake.api.submitted.single;
      expect(body.clientId, id);
      expect(body.ean, _ean);
      expect(body.name, 'Biscuits sablés');
      expect(body.brand, isNull);
      expect(body.category, Category.general);
      expect(body.basis, NutritionBasis.per100g);
      expect(body.parserUsed, ParserUsed.rules);
      expect(body.nutrition.energyKj, 1046);
      expect(body.nutrition.saltG, 0.85);
      expect(body.nutrition.fvlPercent, 0);
      expect(body.photos.front, 'contributions/$id/front.jpg');
      expect(body.photos.nutrition, 'contributions/$id/nutrition.jpg');
      expect(body.photos.ingredients, 'contributions/$id/ingredients.jpg');
      expect(body.ocrText?.nutrition, cleanLabelText);
      expect(body.ocrText?.front, 'Biscuits Sablés\nMarque');
      expect(body.ocrText?.ingredients, 'Ingrédients : farine de blé, sucre');
    });

    test('without the ingredients photo', () async {
      fake.api.parseResults.add(recordedLabelParse('label-parse-ok'));
      await capture(PhotoKind.front, 'front.jpg');
      await capture(PhotoKind.nutrition, 'nutrition.jpg');
      expect(await controller().send(), isTrue);
      final body = fake.api.submitted.single;
      expect(body.photos.ingredients, isNull);
      expect(body.ocrText?.ingredients, isNull);
    });

    test('the LLM values are sent as read by it', () async {
      await capture(PhotoKind.front, 'front.jpg');
      await saltMissing([recordedFallback('label-fallback-done')]);
      expect(await controller().send(), isTrue);
      expect(fake.api.submitted.single.parserUsed, ParserUsed.llm);
    });

    test('values typed by hand are sent as manual', () async {
      await capture(PhotoKind.front, 'front.jpg');
      await capture(PhotoKind.nutrition, 'blank.jpg');
      for (final (field, text) in [
        (NutrientField.energy, '250'),
        (NutrientField.totalFat, '9,5'),
        (NutrientField.saturatedFat, '3,2'),
        (NutrientField.sugars, '12'),
        (NutrientField.protein, '7,4'),
        (NutrientField.salt, '0,85'),
      ]) {
        controller().setValue(field, text);
      }
      controller().setEnergyUnit(EnergyUnit.kcal);
      expect(await controller().send(), isTrue);
      final body = fake.api.submitted.single;
      expect(body.parserUsed, ParserUsed.manual);
      expect(body.nutrition.energyKj, scoring.kjFromKcal(250).toDouble());
      expect(body.nutrition.fibreG, isNull);
      expect(body.ocrText?.nutrition, isNull);
    });

    test('missing values: shown, nothing sent', () async {
      await capture(PhotoKind.front, 'front.jpg');
      await capture(PhotoKind.nutrition, 'blank.jpg');
      expect(await controller().send(), isFalse);
      expect(state().showRequired, isTrue);
      expect(state().step, ContributionStep.photos);
      expect(fake.api.uploads, isEmpty);
    });

    test('missing photos: nothing sent', () async {
      fake.api.parseResults.add(recordedLabelParse('label-parse-ok'));
      await capture(PhotoKind.nutrition, 'nutrition.jpg');
      expect(await controller().send(), isFalse);
      expect(fake.api.uploads, isEmpty);
    });

    test('a failure is shown; trying again resends the same one', () async {
      await threePhotos();
      fake.putErrors.add(const PhotoUploadError('no connection to storage'));

      expect(await controller().send(), isFalse);
      expect(state().sending, isFalse);
      expect(state().step, ContributionStep.photos);
      expect(
        state().sendError,
        'Could not reach the server. Check your connection and try again.',
      );
      expect(fake.api.submitted, isEmpty);

      expect(await controller().send(), isTrue);
      expect(state().sendError, isNull);
      expect(
        fake.api.uploads.map((u) => u.contributionId).toSet(),
        {state().draft.clientId},
      );
      expect(fake.api.submitted, hasLength(1));
    });

    test('a second tap while sending is ignored', () async {
      await threePhotos();
      fake.api.submitGate = Completer<void>();
      final first = controller().send();
      await pumpEventQueue();
      expect(state().sending, isTrue);
      expect(await controller().send(), isFalse);
      fake.api.submitGate!.complete();
      expect(await first, isTrue);
      expect(fake.api.submitted, hasLength(1));
    });

    test('closing the flow while sending is safe', () async {
      await threePhotos();
      fake.api
        ..submitGate = Completer<void>()
        ..submitErrors.add(const ApiUnavailable('busy'));
      final sending = controller().send();
      await pumpEventQueue();
      container.dispose();
      fake.api.submitGate!.complete();
      expect(await sending, isFalse);
      container = ProviderContainer(); // for tearDown
    });
  });

  test('send errors in plain words', () {
    expect(
      sendErrorText(const ApiConnectionError('x')),
      'Could not reach the server. Check your connection and try again.',
    );
    expect(
      sendErrorText(const ApiUnauthorized('x')),
      'Your session has ended. Sign in again, then retry.',
    );
    expect(
      sendErrorText(const ApiInvalidRequest('salt_g: too high')),
      'The server refused this product: salt_g: too high',
    );
    expect(
      sendErrorText(const ApiTooManyRequests('x')),
      'Too many photos sent in the last hour. Try later.',
    );
    expect(
      sendErrorText(const ApiUnavailable('x')),
      'The server is busy. Try again in a moment.',
    );
    expect(sendErrorText(StateError('x')), 'Something went wrong. Try again.');
  });
}

/// The same fallback, still pending.
LabelFallbackRead _pending(LabelFallbackRead done) => LabelFallbackRead(
  id: done.id,
  status: FallbackStatus.pending,
  createdAt: done.createdAt,
);
