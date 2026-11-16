import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qout/features/label_eval/domain/saved_label.dart';

/// Saves labels for the parser evaluation set (`eval/labels/README.md`):
/// `tn-001.txt` (OCR text, unchanged), `tn-001.jpg` (the photo) and
/// `tn-001.json` (a ground truth template, `"reviewed": false`), numbered
/// after the highest id already in the folder.
class LabelEvalStore {
  LabelEvalStore(this._directory);

  /// The folder to save into; created when missing.
  final Future<Directory> Function() _directory;

  static final _id = RegExp(r'^tn-(\d+)\.');

  /// The ground truth template: filled in by hand from the photo.
  static const template = <String, Object?>{
    'reviewed': false,
    'product': null,
    'brand': null,
    'ean': null,
    'languages': <String>[],
    'layout': <String>[],
    'basis': 'per_100g',
    'values': <String, String>{},
    'approximate': <String>[],
    'notes': null,
  };

  Future<String> directoryPath() async => (await _directory()).path;

  /// Copies the photo at [photoPath] and writes [ocrText] and the template
  /// under the next free id.
  Future<SavedLabel> save({
    required String ocrText,
    required String photoPath,
  }) async {
    final directory = await _directory();
    await directory.create(recursive: true);
    final names = await directory.list().map((e) => _name(e.path)).toList();
    final id = nextId(names);
    final base = '${directory.path}/$id';
    await File(photoPath).copy('$base.${_extension(photoPath)}');
    await File('$base.txt').writeAsString(ocrText, flush: true);
    await File('$base.json').writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(template)}\n',
      flush: true,
    );
    return SavedLabel(id: id, ocrText: ocrText, directory: directory.path);
  }

  /// `tn-NNN` after the highest number among [fileNames] (`tn-001` first).
  static String nextId(Iterable<String> fileNames) {
    var highest = 0;
    for (final name in fileNames) {
      final match = _id.firstMatch(name);
      if (match == null) continue;
      final number = int.parse(match.group(1)!);
      if (number > highest) highest = number;
    }
    return 'tn-${(highest + 1).toString().padLeft(3, '0')}';
  }

  static String _name(String path) => path.split(_separator).last;

  static final _separator = RegExp(r'[/\\]');

  static String _extension(String path) {
    final name = _name(path);
    final dot = name.lastIndexOf('.');
    final extension = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return switch (extension) {
      'png' => 'png',
      _ => 'jpg', // image_picker re-encodes to JPEG
    };
  }
}

/// `Android/data/<app id>/files/label-eval` on the phone, which `adb pull`
/// can read (no storage permission needed).
final labelEvalStoreProvider = Provider<LabelEvalStore>(
  (ref) => LabelEvalStore(() async {
    final base =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    return Directory('${base.path}/label-eval');
  }),
);
