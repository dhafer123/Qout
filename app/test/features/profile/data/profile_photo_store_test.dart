import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qout/features/profile/data/profile_photo_store.dart';

void main() {
  late Directory temp;
  late Directory folder;
  late FolderProfilePhotoStore store;
  late int micros;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('qout-photo-test');
    folder = Directory('${temp.path}/profile_photo');
    micros = 1000;
    store = FolderProfilePhotoStore(
      () async => folder,
      clock: () => DateTime.fromMicrosecondsSinceEpoch(micros++),
    );
  });

  tearDown(() => temp.deleteSync(recursive: true));

  File picked(String bytes) =>
      File('${temp.path}/picked-$bytes.jpg')..writeAsStringSync(bytes);

  test('add copies the photo into the folder, created on demand', () async {
    expect(folder.existsSync(), isFalse);
    final source = picked('one');
    final name = await store.add(source.path);

    expect(name, 'profile-1000.jpg');
    final file = (await store.find(name))!;
    expect(file.readAsStringSync(), 'one');
    expect(file.parent.path, folder.path);
    // A copy: the picker's temporary file can go.
    source.deleteSync();
    expect((await store.find(name))!.existsSync(), isTrue);
  });

  test('every photo gets a new name', () async {
    final a = await store.add(picked('a').path);
    final b = await store.add(picked('b').path);
    expect(a, isNot(b));
    expect((await store.find(a))!.readAsStringSync(), 'a');
    expect((await store.find(b))!.readAsStringSync(), 'b');
  });

  test('remove deletes the file; removing twice is fine', () async {
    final name = await store.add(picked('x').path);
    await store.remove(name);
    expect(await store.find(name), isNull);
    await store.remove(name);
  });

  test('find: null for a name never stored', () async {
    expect(await store.find('profile-1.jpg'), isNull);
  });
}
