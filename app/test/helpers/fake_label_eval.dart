import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/core/ocr/label_ocr.dart';
import 'package:qout/core/photos/label_photo_picker.dart';
import 'package:qout/core/photos/label_photo_resizer.dart';
import 'package:qout/features/label_eval/data/label_eval_store.dart';
import 'package:qout/features/label_eval/domain/inbox_photo.dart';
import 'package:qout/features/label_eval/domain/saved_label.dart';

/// Fakes for the label OCR screen: a picker returning [photos] in order
/// (null: cancelled), an OCR returning [texts] by photo path (or throwing
/// [ocrError]), a resizer adding `.small` to the path, and a store that keeps
/// what it saves in memory, with an `inbox`.
class FakeLabelEval {
  FakeLabelEval({
    List<String?>? photos,
    Map<String, String>? texts,
    this.ocrError,
    List<InboxPhoto> inbox = const [],
  }) : photos = photos ?? ['photo-1.jpg'],
       texts = texts ?? {'photo-1.jpg': 'Pour 100 g\nSel 1,5 g'},
       store = FakeLabelEvalStore(inbox);

  final List<String?> photos;
  final Map<String, String> texts;
  final Exception? ocrError;
  final FakeLabelEvalStore store;

  final picked = <PhotoSource>[];
  final read = <String>[];
  final resized = <String>[];

  /// Completes the OCR when set; otherwise it answers at once.
  Completer<void>? ocrGate;

  List<Override> get overrides => [
    labelPhotoPickerProvider.overrideWithValue((source) async {
      picked.add(source);
      return photos.removeAt(0);
    }),
    labelPhotoResizerProvider.overrideWithValue((path) async {
      resized.add(path);
      return '$path.small';
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
  FakeLabelEvalStore(List<InboxPhoto> inbox)
    : waiting = [...inbox],
      super(() async => Directory('/fake/label-eval'));

  final List<InboxPhoto> waiting;
  final saved = <(String text, String? photo, Map<String, Object?> template)>[];

  @override
  Future<SavedLabel> save({
    required String ocrText,
    String? photoPath,
    Map<String, Object?> overrides = const {},
  }) async {
    saved.add((ocrText, photoPath, overrides));
    return SavedLabel(
      id: 'tn-${saved.length.toString().padLeft(3, '0')}',
      ocrText: ocrText,
      directory: '/fake/label-eval',
    );
  }

  /// Thrown by [inbox] when set.
  Exception? inboxError;

  @override
  Future<List<InboxPhoto>> inbox() async {
    if (inboxError case final error?) throw error;
    return [...waiting];
  }

  @override
  Future<void> remove(InboxPhoto photo) async => waiting.remove(photo);
}
