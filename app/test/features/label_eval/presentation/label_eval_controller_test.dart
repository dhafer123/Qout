import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/photos/label_photo_picker.dart';
import 'package:qout/features/label_eval/domain/saved_label.dart';
import 'package:qout/features/label_eval/presentation/label_eval_controller.dart';

import '../../../helpers/fake_label_eval.dart';

void main() {
  late FakeLabelEval fake;
  late ProviderContainer container;

  void start(FakeLabelEval value) {
    fake = value;
    container = ProviderContainer(overrides: fake.overrides);
    addTearDown(container.dispose);
    // Keep the auto-disposed controller alive between reads.
    container.listen(labelEvalControllerProvider, (_, _) {});
  }

  LabelEvalController controller() =>
      container.read(labelEvalControllerProvider.notifier);

  LabelEvalState state() => container.read(labelEvalControllerProvider);

  test('starts idle', () {
    start(FakeLabelEval());

    expect(state(), const LabelEvalState.idle());
  });

  test('photo → OCR → saved', () async {
    start(FakeLabelEval());

    await controller().capture(PhotoSource.camera);

    expect(fake.picked, [PhotoSource.camera]);
    expect(fake.read, ['photo-1.jpg']);
    expect(fake.store.saved, [('Pour 100 g\nSel 1,5 g', 'photo-1.jpg')]);
    expect(
      state(),
      const LabelEvalState.saved(
        SavedLabel(
          id: 'tn-001',
          ocrText: 'Pour 100 g\nSel 1,5 g',
          directory: '/fake/label-eval',
        ),
      ),
    );
  });

  test('working while reading; another capture is ignored', () async {
    start(FakeLabelEval(photos: ['photo-1.jpg', 'photo-2.jpg']));
    fake.ocrGate = Completer<void>();

    final capture = controller().capture(PhotoSource.gallery);
    await pumpEventQueue();
    expect(state(), const LabelEvalState.working());

    await controller().capture(PhotoSource.camera);
    expect(fake.picked, [PhotoSource.gallery]);

    fake.ocrGate!.complete();
    await capture;
    expect(state(), isA<LabelEvalSaved>());
    expect(fake.store.saved, hasLength(1));
  });

  test('a cancelled photo keeps what was shown', () async {
    start(FakeLabelEval(photos: ['photo-1.jpg', null]));
    await controller().capture(PhotoSource.camera);
    final shown = state();

    await controller().capture(PhotoSource.camera);

    expect(state(), shown);
    expect(fake.read, ['photo-1.jpg']);
    expect(fake.store.saved, hasLength(1));
  });

  test('an OCR failure is shown and nothing is saved', () async {
    start(FakeLabelEval(ocrError: Exception('ML Kit failed')));

    await controller().capture(PhotoSource.camera);

    expect(state(), const LabelEvalState.failed('Exception: ML Kit failed'));
    expect(fake.store.saved, isEmpty);
  });

  test('an empty text is saved too (e.g. Arabic only)', () async {
    start(
      FakeLabelEval(
        photos: ['photo-1.jpg'],
        texts: {'photo-1.jpg': ''},
      ),
    );

    await controller().capture(PhotoSource.camera);

    expect(state(), isA<LabelEvalSaved>());
    expect(fake.store.saved, [('', 'photo-1.jpg')]);
  });
}
