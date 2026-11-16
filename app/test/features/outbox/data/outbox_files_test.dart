import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/api/qout_api.dart' show PhotoKind;
import 'package:qout/features/outbox/data/outbox_files.dart';

void main() {
  late Directory root;
  late DirectoryOutboxFiles files;

  setUp(() {
    root = Directory.systemTemp.createTempSync('outbox-files-');
    files = DirectoryOutboxFiles(() async => root);
  });

  tearDown(() => root.deleteSync(recursive: true));

  File source(String name, List<int> bytes) =>
      File('${root.path}/$name')..writeAsBytesSync(bytes);

  test('keeps a copy per contribution and kind, extension kept', () async {
    final picked = source('image_picker_123.JPG', [1, 2, 3]);
    final kept = await files.keep('c1', PhotoKind.front, picked.path);

    expect(kept, '${root.path}/outbox/c1/front.jpg');
    expect(File(kept).readAsBytesSync(), [1, 2, 3]);
    picked.deleteSync(); // the picker's file may go: the copy stays
    expect(File(kept).existsSync(), isTrue);

    final noExtension = source('photo', [4]);
    expect(
      await files.keep('c1', PhotoKind.nutrition, noExtension.path),
      '${root.path}/outbox/c1/nutrition',
    );
  });

  test('remove deletes the contribution folder, if any', () async {
    await files.keep('c1', PhotoKind.front, source('a.jpg', [1]).path);
    await files.keep('c2', PhotoKind.front, source('b.jpg', [2]).path);

    await files.remove('c1');
    await files.remove('never-kept');

    expect(Directory('${root.path}/outbox/c1').existsSync(), isFalse);
    expect(Directory('${root.path}/outbox/c2').existsSync(), isTrue);
  });

  test('a missing photo cannot be kept', () async {
    await expectLater(
      files.keep('c1', PhotoKind.front, '${root.path}/gone.jpg'),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('the provider keeps them in the app support folder', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(outboxFilesProvider), isA<DirectoryOutboxFiles>());
  });
}
