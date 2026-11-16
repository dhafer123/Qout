import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qout/features/label_eval/data/label_eval_store.dart';
import 'package:qout/features/label_eval/domain/saved_label.dart';

const jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 1, 2];
const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1];

void main() {
  group('extensionOf', () {
    test('PNG signature → png, anything else → jpg', () {
      expect(LabelEvalStore.extensionOf(png), 'png');
      expect(LabelEvalStore.extensionOf(jpeg), 'jpg');
      expect(LabelEvalStore.extensionOf([0x89, 0x50]), 'jpg');
      expect(LabelEvalStore.extensionOf([]), 'jpg');
    });
  });

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
        'source',
        'photo_url',
        'languages',
        'layout',
        'basis',
        'values',
        'approximate',
        'notes',
      ]);
      expect(LabelEvalStore.template['source'], 'own');
    });

    test('no photo: text and template only, overrides applied', () async {
      final saved = await store.save(
        ocrText: 'Sel 1 g',
        overrides: {
          'ean': '6191509900701',
          'source': 'open-food-facts',
          'photo_url': 'https://images.openfoodfacts.org/x.jpg',
          'reviewed': true, // not an inbox key: ignored
          'values': {'salt_g': '9'},
        },
      );

      expect(saved.id, 'tn-001');
      expect(
        folder.listSync().map((e) => e.uri.pathSegments.last).toList()..sort(),
        ['tn-001.json', 'tn-001.txt'],
      );
      final json =
          jsonDecode(File('${folder.path}/tn-001.json').readAsStringSync())
              as Map<String, Object?>;
      expect(json, {
        ...LabelEvalStore.template,
        'ean': '6191509900701',
        'source': 'open-food-facts',
        'photo_url': 'https://images.openfoodfacts.org/x.jpg',
      });
    });

    group('inbox', () {
      late Directory inbox;

      setUp(() => inbox = Directory('${folder.path}/inbox'));

      test('no inbox folder: empty', () async {
        expect(await store.inbox(), isEmpty);
      });

      test('photos by name with their template, other files ignored', () async {
        inbox.createSync(recursive: true);
        File('${inbox.path}/b.PNG').writeAsBytesSync(png);
        File('${inbox.path}/a.jpg').writeAsBytesSync(jpeg);
        File('${inbox.path}/a.json').writeAsStringSync('{"ean": "123"}');
        File('${inbox.path}/c.jpeg').writeAsBytesSync(jpeg);
        File('${inbox.path}/notes.txt').writeAsStringSync('x');
        File('${inbox.path}/orphan.json').writeAsStringSync('{}');
        Directory('${inbox.path}/sub.jpg').createSync();

        final photos = await store.inbox();

        expect(photos.map((p) => p.path.split(RegExp(r'[/\\]')).last), [
          'a.jpg',
          'b.PNG',
          'c.jpeg',
        ]);
        expect(photos.first.template, {'ean': '123'});
        expect(photos[1].template, isEmpty);
      });

      test('a template that is not an object is an error', () async {
        inbox.createSync(recursive: true);
        File('${inbox.path}/a.jpg').writeAsBytesSync(jpeg);
        File('${inbox.path}/a.json').writeAsStringSync('[1]');

        await expectLater(store.inbox(), throwsFormatException);
      });

      test('remove deletes the photo and its template', () async {
        inbox.createSync(recursive: true);
        File('${inbox.path}/a.jpg').writeAsBytesSync(jpeg);
        File('${inbox.path}/a.json').writeAsStringSync('{}');
        File('${inbox.path}/b.jpg').writeAsBytesSync(jpeg);
        final photos = await store.inbox();

        await store.remove(photos.first);
        await store.remove(photos.last); // no template

        expect(inbox.listSync(), isEmpty);
      });
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

    test('the photo type comes from its content, not its name', () async {
      // image_picker re-encodes a picked PNG to JPEG, keeping `.png`.
      await store.save(ocrText: '', photoPath: photo('a.png', jpeg).path);
      await store.save(ocrText: '', photoPath: photo('b.jpg', png).path);
      await store.save(ocrText: '', photoPath: photo('noextension', [3]).path);

      final names =
          folder
              .listSync()
              .map((e) => e.uri.pathSegments.last)
              .where((name) => !name.endsWith('.txt'))
              .where((name) => !name.endsWith('.json'))
              .toList()
            ..sort();
      expect(names, ['tn-001.jpg', 'tn-002.png', 'tn-003.jpg']);
      expect(File('${folder.path}/tn-002.png').readAsBytesSync(), png);
    });

    test(
      'a private picker file is saved readable (adb pull)',
      () async {
        final source = photo('private.jpg', jpeg);
        await Process.run('chmod', ['600', source.path]);

        await store.save(ocrText: '', photoPath: source.path);

        final mode = File('${folder.path}/tn-001.jpg').statSync().mode;
        expect(mode & 0x24, isNot(0), reason: 'group/other read bits');
      },
      skip: Platform.isWindows ? 'no POSIX file modes' : null,
    );

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
