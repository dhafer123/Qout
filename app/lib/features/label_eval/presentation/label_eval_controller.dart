import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qout/core/ocr/label_ocr.dart';
import 'package:qout/core/photos/label_photo_picker.dart';
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

  const factory LabelEvalState.failed(String message) = LabelEvalFailed;
}

/// Photo → ML Kit text → saved in the evaluation set (dev builds only).
class LabelEvalController extends AutoDisposeNotifier<LabelEvalState> {
  @override
  LabelEvalState build() => const LabelEvalState.idle();

  Future<void> capture(PhotoSource source) async {
    if (state is LabelEvalWorking) return;
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
}

final labelEvalControllerProvider =
    AutoDisposeNotifierProvider<LabelEvalController, LabelEvalState>(
      LabelEvalController.new,
    );
