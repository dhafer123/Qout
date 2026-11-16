import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qout/core/ocr/label_ocr.dart';
import 'package:qout/core/photos/label_photo_picker.dart';
import 'package:qout/core/photos/label_photo_resizer.dart';
import 'package:qout/features/label_eval/data/label_eval_store.dart';
import 'package:qout/features/label_eval/domain/saved_label.dart';

part 'label_eval_controller.freezed.dart';

@freezed
sealed class LabelEvalState with _$LabelEvalState {
  /// Nothing captured yet on this screen.
  const factory LabelEvalState.idle() = LabelEvalIdle;

  /// A photo was taken: reading and saving it.
  const factory LabelEvalState.working() = LabelEvalWorking;

  const factory LabelEvalState.saved(SavedLabel label) = LabelEvalSaved;

  /// Reading the inbox: [done] of [total] photos saved so far.
  const factory LabelEvalState.readingInbox({
    required int done,
    required int total,
  }) = LabelEvalReadingInbox;

  /// The inbox was read: the ids saved (none: it was empty).
  const factory LabelEvalState.inboxRead(List<String> ids) = LabelEvalInboxRead;

  const factory LabelEvalState.failed(String message) = LabelEvalFailed;
}

extension LabelEvalBusy on LabelEvalState {
  bool get busy => this is LabelEvalWorking || this is LabelEvalReadingInbox;
}

/// Photo → ML Kit text → saved in the evaluation set (dev builds only).
class LabelEvalController extends AutoDisposeNotifier<LabelEvalState> {
  @override
  LabelEvalState build() => const LabelEvalState.idle();

  Future<void> capture(PhotoSource source) async {
    if (state.busy) return;
    try {
      final photo = await ref.read(labelPhotoPickerProvider)(source);
      if (photo == null) return; // cancelled: keep what was shown
      state = const LabelEvalState.working();
      final text = await ref.read(labelOcrProvider)(photo);
      state = LabelEvalState.saved(
        await ref
            .read(labelEvalStoreProvider)
            .save(ocrText: text, photoPath: photo),
      );
    } on Object catch (error) {
      state = LabelEvalState.failed('$error');
    }
  }

  /// Reads every inbox photo at the app's photo size and saves its text and
  /// template; each photo leaves the inbox once saved, so a failure can be
  /// resumed by reading the inbox again.
  Future<void> readInbox() async {
    if (state.busy) return;
    final store = ref.read(labelEvalStoreProvider);
    final ids = <String>[];
    var current = '';
    try {
      final photos = await store.inbox();
      state = LabelEvalState.readingInbox(done: 0, total: photos.length);
      for (final photo in photos) {
        current = photo.path.split('/').last;
        final resized = await ref.read(labelPhotoResizerProvider)(photo.path);
        final text = await ref.read(labelOcrProvider)(resized);
        final saved = await store.save(
          ocrText: text,
          overrides: photo.template,
        );
        await store.remove(photo);
        ids.add(saved.id);
        state = LabelEvalState.readingInbox(
          done: ids.length,
          total: photos.length,
        );
      }
      state = LabelEvalState.inboxRead(ids);
    } on Object catch (error) {
      final where = current.isEmpty ? '' : ' ($current)';
      state = LabelEvalState.failed(
        'Saved ${ids.length} before an error$where: $error',
      );
    }
  }
}

final labelEvalControllerProvider =
    AutoDisposeNotifierProvider<LabelEvalController, LabelEvalState>(
      LabelEvalController.new,
    );
