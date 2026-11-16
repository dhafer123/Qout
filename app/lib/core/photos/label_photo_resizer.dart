import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/core/photos/label_photo_picker.dart';

/// The path of the photo at `path` reduced to [labelPhotoMaxSide] pixels on
/// its longest side (a temporary PNG), or `path` itself when it is not
/// larger. Photos that don't come from the picker (the evaluation inbox) go
/// through this, so ML Kit reads them at the size the app sends.
typedef LabelPhotoResizer = Future<String> Function(String path);

final labelPhotoResizerProvider = Provider<LabelPhotoResizer>(
  (ref) => resizeLabelPhoto,
);

Future<String> resizeLabelPhoto(String path) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    await File(path).readAsBytes(),
  );
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  try {
    final size = scaledSize(descriptor.width, descriptor.height);
    if (size == null) return path;
    final codec = await descriptor.instantiateCodec(
      targetWidth: size.width,
      targetHeight: size.height,
    );
    final frame = await codec.getNextFrame();
    final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    final out = File(
      '${Directory.systemTemp.path}/label-'
      '${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await out.writeAsBytes(png!.buffer.asUint8List(), flush: true);
    return out.path;
  } finally {
    descriptor.dispose();
    buffer.dispose();
  }
}

/// The reduced size, or null when the longest side is within the limit.
({int width, int height})? scaledSize(int width, int height) {
  final longest = max(width, height);
  if (longest <= labelPhotoMaxSide) return null;
  final scale = labelPhotoMaxSide / longest;
  return (
    width: max(1, (width * scale).round()),
    height: max(1, (height * scale).round()),
  );
}
