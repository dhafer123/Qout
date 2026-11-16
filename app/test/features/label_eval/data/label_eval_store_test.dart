import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qout/features/label_eval/data/label_eval_store.dart';
import 'package:qout/features/label_eval/domain/saved_label.dart';

void main() {
  group('nextId', () {
    test('starts at tn-001', () {
      expect(LabelEvalStore.nextId([]), 'tn-001');
    });

    test('follows the highest number, gaps and other files ignored', () {
      expect(
        LabelEvalStore.nextId([
          'tn-002.txt',
          'tn-009.json',
          'tn-004.jpg',
          'README.md',
          'tn-x.txt',
          'other-050.txt',
          'tn-07',
        ]),
        'tn-010',
      );
    });

    test('grows past three digits', () {
      expect(LabelEvalStore.nextId(['tn-999.txt']), 'tn-1000');
      expect(LabelEvalStore.nextId(['tn-1000.txt']), 'tn-1001');
    });
  });

  group('save', () {
    late Directory temp;
    late Directory folder;
    late LabelEvalStore store;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('label_eval_test');
      folder = Directory('${temp.path}/label-eval');
      store = LabelEvalStore(() async => folder);
    });

    tearDown(() => temp.deleteSync(recursive: true));

    File photo(String name, List<int> bytes) =>
        File('${temp.path}/$name')..writeAsBytesSync(bytes);

    test('creates the folder and writes text, photo and template', () async {
      const text = 'Valeurs nutritionnelles pour 100 g\nÉnergie 1958 kJ';

      final saved = await store.save(
        ocrText: text,
        photoPath: photo('scaled_123.jpg', [1, 2, 3]).path,
      );

      expect(
        saved,
        SavedLabel(id: 'tn-001', ocrText: text, directory: folder.path),
      );
      expect(File('${folder.path}/tn-001.txt').readAsStringSync(), text);
      expect(File('${folder.path}/tn-001.jpg').readAsBytesSync(), [1, 2, 3]);
      final json = File('${folder.path}/tn-001.json').readAsStringSync();
      expect(jsonDecode(json), LabelEvalStore.template);
      expect(json, endsWith('}\n'));
      expect(json, contains('\n  "reviewed": false,\n'));
      expect(await store.directoryPath(), folder.path);
    });

    test('the template is not reviewed and has every ground truth key', () {
      expect(LabelEvalStore.template['reviewed'], false);
      expect(LabelEvalStore.template.keys, [
        'reviewed',
        'product',
        'brand',
        'ean',
        'languages',
        'layout',
        'basis',
        'values',
        'approximate',
        'notes',
      ]);
    });

    test('numbers after the labels already saved', () async {
      folder.createSync();
      File('${folder.path}/tn-041.txt').writeAsStringSync('old');

      final first = await store.save(
        ocrText: 'a',
        photoPath: photo('a.jpg', [1]).path,
      );
      final second = await store.save(
        ocrText: 'b',
        photoPath: photo('b.jpg', [2]).path,
      );

      expect([first.id, second.id], ['tn-042', 'tn-043']);
      expect(File('${folder.path}/tn-041.txt').readAsStringSync(), 'old');
    });

    test('keeps PNG photos as PNG, anything else is JPEG', () async {
      await store.save(ocrText: '', photoPath: photo('a.PNG', [1]).path);
      await store.save(ocrText: '', photoPath: photo('b.jpeg', [2]).path);
      await store.save(ocrText: '', photoPath: photo('noextension', [3]).path);

      final names =
          folder
              .listSync()
              .map((e) => e.uri.pathSegments.last)
              .where((name) => !name.endsWith('.txt'))
              .where((name) => !name.endsWith('.json'))
              .toList()
            ..sort();
      expect(names, ['tn-001.png', 'tn-002.jpg', 'tn-003.jpg']);
    });

    test('an empty text is saved as is', () async {
      final saved = await store.save(
        ocrText: '',
        photoPath: photo('a.jpg', [1]).path,
      );

      expect(saved.ocrText, '');
      expect(File('${folder.path}/tn-001.txt').readAsStringSync(), '');
    });
  });
}
