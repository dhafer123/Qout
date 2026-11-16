import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/core/ocr/label_ocr.dart';
import 'package:qout/core/photos/label_photo_picker.dart';
import 'package:qout/features/label_eval/data/label_eval_store.dart';
import 'package:qout/features/label_eval/domain/saved_label.dart';

/// Fakes for the label OCR screen: a picker returning [photos] in order
/// (null: cancelled), an OCR returning [texts] by photo path (or throwing
/// [ocrError]), and a store that keeps what it saves in memory.
class FakeLabelEval {
  FakeLabelEval({
    List<String?>? photos,
    Map<String, String>? texts,
    this.ocrError,
  }) : photos = photos ?? ['photo-1.jpg'],
       texts = texts ?? {'photo-1.jpg': 'Pour 100 g\nSel 1,5 g'};

  final List<String?> photos;
  final Map<String, String> texts;
  final Exception? ocrError;

  final picked = <PhotoSource>[];
  final read = <String>[];
  final store = FakeLabelEvalStore();

  /// Completes the OCR when set; otherwise it answers at once.
  Completer<void>? ocrGate;

  List<Override> get overrides => [
    labelPhotoPickerProvider.overrideWithValue((source) async {
      picked.add(source);
      return photos.removeAt(0);
    }),
    labelOcrProvider.overrideWithValue((path) async {
      read.add(path);
      await ocrGate?.future;
      if (ocrError case final error?) throw error;
      return texts[path]!;
    }),
    labelEvalStoreProvider.overrideWithValue(store),
  ];
}

class FakeLabelEvalStore extends LabelEvalStore {
  FakeLabelEvalStore() : super(() async => Directory('/fake/label-eval'));

  final saved = <(String text, String photo)>[];

  @override
  Future<SavedLabel> save({
    required String ocrText,
    required String photoPath,
  }) async {
    saved.add((ocrText, photoPath));
    return SavedLabel(
      id: 'tn-${saved.length.toString().padLeft(3, '0')}',
      ocrText: ocrText,
      directory: '/fake/label-eval',
    );
  }
}
