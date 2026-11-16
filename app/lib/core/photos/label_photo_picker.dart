import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Where a label photo comes from.
enum PhotoSource { camera, gallery }

/// Label photos are reduced to this many pixels on their longest side...
const labelPhotoMaxSide = 1600.0;

/// ...and re-encoded as JPEG at this quality.
const labelPhotoJpegQuality = 85;

/// Takes or picks a label photo; its file path, or null when the user
/// cancelled.
///
/// OCR runs on this reduced photo, and the same file is kept (evaluation set)
/// or uploaded (contributions), so both see exactly the same image.
typedef LabelPhotoPicker = Future<String?> Function(PhotoSource source);

/// The system camera or gallery through image_picker.
final labelPhotoPickerProvider = Provider<LabelPhotoPicker>((ref) {
  final picker = ImagePicker();
  return (source) async {
    final file = await picker.pickImage(
      source: switch (source) {
        PhotoSource.camera => ImageSource.camera,
        PhotoSource.gallery => ImageSource.gallery,
      },
      maxWidth: labelPhotoMaxSide,
      maxHeight: labelPhotoMaxSide,
      imageQuality: labelPhotoJpegQuality,
      requestFullMetadata: false,
    );
    return file?.path;
  };
});
