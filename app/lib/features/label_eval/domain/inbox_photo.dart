import 'package:freezed_annotation/freezed_annotation.dart';

part 'inbox_photo.freezed.dart';

/// A photo waiting in the evaluation set's inbox (pushed from the PC, e.g.
/// Open Food Facts photos from `scripts/fetch_off_labels.py`).
@freezed
abstract class InboxPhoto with _$InboxPhoto {
  const factory InboxPhoto({
    required String path,

    /// From `<name>.json` next to the photo: ground truth template values
    /// (product, brand, ean, source, photo_url). Empty when there is none.
    @Default(<String, Object?>{}) Map<String, Object?> template,
  }) = _InboxPhoto;
}
