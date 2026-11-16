import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qout/features/label_eval/domain/inbox_photo.dart';
import 'package:qout/features/label_eval/domain/saved_label.dart';

/// Saves labels for the parser evaluation set (`eval/labels/README.md`):
/// `tn-001.txt` (OCR text, unchanged), `tn-001.jpg` (the photo, when it was
/// taken with the app) and `tn-001.json` (a ground truth template,
/// `"reviewed": false`), numbered after the highest id already in the folder.
///
/// Photos pushed to `inbox/` (with an optional `<name>.json` of template
/// values) are read in one go; their photo is not copied, it is already on
/// the PC.
class LabelEvalStore {
  LabelEvalStore(this._directory);

  /// The folder to save into; created when missing.
  final Future<Directory> Function() _directory;

  static final _id = RegExp(r'^tn-(\d+)\.');
  static final _photo = RegExp(r'\.(jpe?g|png)$', caseSensitive: false);

  /// The ground truth template: filled in by hand from the photo.
  static const template = <String, Object?>{
    'reviewed': false,
    'product': null,
    'brand': null,
    'ean': null,
    'source': 'own',
    'photo_url': null,
    'languages': <String>[],
    'layout': <String>[],
    'basis': 'per_100g',
    'values': <String, String>{},
    'approximate': <String>[],
    'notes': null,
  };

  /// Template keys an inbox photo's `<name>.json` may set.
  static const inboxKeys = {'product', 'brand', 'ean', 'source', 'photo_url'};

  Future<String> directoryPath() async => (await _directory()).path;

  /// Writes [ocrText] and the template ([overrides] applied) under the next
  /// free id, with a copy of the photo at [photoPath] when given.
  Future<SavedLabel> save({
    required String ocrText,
    String? photoPath,
    Map<String, Object?> overrides = const {},
  }) async {
    final directory = await _directory();
    await directory.create(recursive: true);
    final names = await directory.list().map((e) => _name(e.path)).toList();
    final id = nextId(names);
    final base = '${directory.path}/$id';
    if (photoPath != null) {
      // Written as a new file, not copied: a copy keeps the picker's private
      // file mode, which `adb pull` can't read.
      final photo = await File(photoPath).readAsBytes();
      await File(
        '$base.${extensionOf(photo)}',
      ).writeAsBytes(photo, flush: true);
    }
    await File('$base.txt').writeAsString(ocrText, flush: true);
    final json = {
      ...template,
      for (final MapEntry(:key, :value) in overrides.entries)
        if (inboxKeys.contains(key)) key: value,
    };
    await File('$base.json').writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(json)}\n',
      flush: true,
    );
    return SavedLabel(id: id, ocrText: ocrText, directory: directory.path);
  }

  /// Photos waiting in `inbox/`, by name.
  Future<List<InboxPhoto>> inbox() async {
    final folder = await _inbox();
    if (!folder.existsSync()) return const [];
    final paths = await folder
        .list()
        .where((e) => e is File && _photo.hasMatch(e.path))
        .map((e) => e.path)
        .toList();
    paths.sort();
    return [
      for (final path in paths)
        InboxPhoto(path: path, template: await _sidecar(path)),
    ];
  }

  /// Removes an inbox photo and its `<name>.json` once it is read.
  Future<void> remove(InboxPhoto photo) async {
    for (final file in [File(photo.path), File(_sidecarPath(photo.path))]) {
      if (file.existsSync()) await file.delete();
    }
  }

  Future<Directory> _inbox() async =>
      Directory('${(await _directory()).path}/inbox');

  static String _sidecarPath(String photoPath) =>
      '${photoPath.substring(0, photoPath.lastIndexOf('.'))}.json';

  static Future<Map<String, Object?>> _sidecar(String photoPath) async {
    final file = File(_sidecarPath(photoPath));
    if (!file.existsSync()) return const {};
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw FormatException('expected a JSON object', file.path);
    }
    return decoded;
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

  /// `png` for PNG data, otherwise `jpg`. Read from the content: image_picker
  /// re-encodes a picked PNG to JPEG but keeps the `.png` file name.
  static String extensionOf(List<int> photo) {
    const pngSignature = [0x89, 0x50, 0x4E, 0x47];
    final isPng =
        photo.length >= pngSignature.length &&
        Iterable<int>.generate(
          pngSignature.length,
        ).every((i) => photo[i] == pngSignature[i]);
    return isPng ? 'png' : 'jpg';
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
