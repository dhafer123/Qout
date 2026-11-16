/// What a photo file holds, read from its first bytes: image_picker may keep a
/// `.png` name on data it re-encoded as JPEG, so the name can't be trusted.
library;

const _pngSignature = [0x89, 0x50, 0x4E, 0x47];

/// True for PNG data; anything else is treated as JPEG (what the picker and
/// the camera produce).
bool isPng(List<int> photo) =>
    photo.length >= _pngSignature.length &&
    Iterable<int>.generate(
      _pngSignature.length,
    ).every((i) => photo[i] == _pngSignature[i]);
