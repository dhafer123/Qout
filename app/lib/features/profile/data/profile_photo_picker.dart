import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qout/core/photos/label_photo_picker.dart' show PhotoSource;

/// Profile photos are reduced to this many pixels on their longest side
/// (shown at 56 dp at most)...
const profilePhotoMaxSide = 512.0;

/// ...and re-encoded as JPEG at this quality.
const profilePhotoJpegQuality = 85;

/// Takes or picks a profile photo; its (temporary) file path, or null when
/// the user cancelled.
typedef ProfilePhotoPicker = Future<String?> Function(PhotoSource source);

/// The system camera (front first) or gallery through image_picker.
final profilePhotoPickerProvider = Provider<ProfilePhotoPicker>((ref) {
  final picker = ImagePicker();
  return (source) async {
    final file = await picker.pickImage(
      source: switch (source) {
        PhotoSource.camera => ImageSource.camera,
        PhotoSource.gallery => ImageSource.gallery,
      },
      preferredCameraDevice: CameraDevice.front,
      maxWidth: profilePhotoMaxSide,
      maxHeight: profilePhotoMaxSide,
      imageQuality: profilePhotoJpegQuality,
      requestFullMetadata: false,
    );
    return file?.path;
  };
});
