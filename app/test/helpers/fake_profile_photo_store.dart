import 'dart:io';

import 'package:qout/features/profile/data/profile_photo_store.dart';

/// Profile photos kept by name in memory, no file IO; [files] maps each
/// stored name to the path it was added from.
class FakeProfilePhotoStore implements ProfilePhotoStore {
  final Map<String, String> files = {};
  var _next = 0;

  @override
  Future<String> add(String sourcePath) async {
    final name = 'photo-${++_next}.jpg';
    files[name] = sourcePath;
    return name;
  }

  @override
  Future<File?> find(String name) async =>
      files.containsKey(name) ? File('memory/$name') : null;

  @override
  Future<void> remove(String name) async => files.remove(name);
}
