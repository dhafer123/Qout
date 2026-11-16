import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reads the text of the label photo at `imagePath` on the device; empty when
/// none was found.
///
/// The text is what the backend's label parser receives
/// (`POST /v1/labels/parse`), so the label evaluation set (`eval/labels/`)
/// and the contribution flow must both use [labelOcrProvider].
typedef LabelOcr = Future<String> Function(String imagePath);

/// ML Kit's on-device recognizer, Latin script (the model bundled with the
/// app). It doesn't read Arabic: Arabic text comes out empty or garbled.
///
/// The result is `RecognizedText.text`: ML Kit's text blocks in its reading
/// order, one line per text line. Tables often come out column by column.
final labelOcrProvider = Provider<LabelOcr>((ref) {
  final recognizer = TextRecognizer();
  ref.onDispose(() => unawaited(recognizer.close()));
  return (imagePath) async {
    final recognized = await recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    return recognized.text;
  };
});
