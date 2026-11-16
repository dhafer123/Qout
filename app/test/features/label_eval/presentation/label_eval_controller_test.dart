import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/photos/label_photo_picker.dart';
import 'package:qout/features/label_eval/domain/inbox_photo.dart';
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
    expect(fake.store.saved.map((s) => (s.$1, s.$2)), [
      ('Pour 100 g\nSel 1,5 g', 'photo-1.jpg'),
    ]);
    expect(fake.store.saved.single.$3, isEmpty);
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
    expect(fake.store.saved.map((s) => (s.$1, s.$2)), [('', 'photo-1.jpg')]);
  });

  group('inbox', () {
    const off = InboxPhoto(
      path: '/fake/label-eval/inbox/6191509900701.jpg',
      template: {'ean': '6191509900701', 'source': 'open-food-facts'},
    );
    const own = InboxPhoto(path: '/fake/label-eval/inbox/other.png');

    test('reads each photo resized and saves text and template', () async {
      start(
        FakeLabelEval(
          inbox: [off, own],
          texts: {'${off.path}.small': 'Sel 1 g', '${own.path}.small': ''},
        ),
      );

      await controller().readInbox();

      expect(fake.resized, [off.path, own.path]);
      expect(fake.read, ['${off.path}.small', '${own.path}.small']);
      expect(fake.store.saved, [
        ('Sel 1 g', null, off.template),
        ('', null, own.template),
      ]);
      expect(fake.store.waiting, isEmpty);
      expect(state(), const LabelEvalState.inboxRead(['tn-001', 'tn-002']));
      expect(fake.picked, isEmpty);
    });

    test('an empty inbox', () async {
      start(FakeLabelEval());

      await controller().readInbox();

      expect(state(), const LabelEvalState.inboxRead([]));
    });

    test('progress while reading', () async {
      start(FakeLabelEval(inbox: [off], texts: {'${off.path}.small': 'x'}));
      fake.ocrGate = Completer<void>();
      final states = <LabelEvalState>[];
      container.listen(labelEvalControllerProvider, (_, next) {
        states.add(next);
      });

      final reading = controller().readInbox();
      await pumpEventQueue();
      expect(state(), const LabelEvalState.readingInbox(done: 0, total: 1));
      expect(state().busy, isTrue);

      await controller().capture(PhotoSource.camera); // ignored while busy
      await controller().readInbox(); // ignored too
      expect(fake.picked, isEmpty);

      fake.ocrGate!.complete();
      await reading;
      expect(states, [
        const LabelEvalState.readingInbox(done: 0, total: 1),
        const LabelEvalState.readingInbox(done: 1, total: 1),
        const LabelEvalState.inboxRead(['tn-001']),
      ]);
    });

    test('a failure keeps the photos not read yet, to resume', () async {
      start(
        FakeLabelEval(
          inbox: [off, own],
          texts: {'${off.path}.small': 'x'}, // no text for `own`: OCR throws
        ),
      );

      await controller().readInbox();

      expect(fake.store.waiting, [own]);
      expect(
        state(),
        isA<LabelEvalFailed>().having(
          (s) => s.message,
          'message',
          startsWith('Saved 1 before an error (other.png): '),
        ),
      );
    });

    test('a failure before any photo names none', () async {
      start(FakeLabelEval());
      fake.store.inboxError = const FileSystemException('denied');

      await controller().readInbox();

      expect(
        state(),
        isA<LabelEvalFailed>().having(
          (s) => s.message,
          'message',
          startsWith('Saved 0 before an error: FileSystemException: denied'),
        ),
      );
    });
  });
}
