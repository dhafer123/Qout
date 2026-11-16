import 'package:freezed_annotation/freezed_annotation.dart';

part 'saved_label.freezed.dart';

/// A label added to the evaluation set on the phone: `<id>.txt` (the OCR
/// text), the photo and `<id>.json` (ground truth template), in `directory`.
@freezed
abstract class SavedLabel with _$SavedLabel {
  const factory SavedLabel({
    required String id,
    required String ocrText,
    required String directory,
  }) = _SavedLabel;
}
