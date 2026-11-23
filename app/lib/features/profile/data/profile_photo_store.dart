import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Where the profile photo (T43c) is kept: on the phone only, never sent.
abstract interface class ProfilePhotoStore {
  /// Copies the photo at [sourcePath] in under a new name, and returns it.
  /// A new name each time, so a replaced photo is never shown from a cache.
  Future<String> add(String sourcePath);

  /// The file stored as [name]; null when it is gone.
  Future<File?> find(String name);

  /// Deletes [name]; nothing happens when it is already gone.
  Future<void> remove(String name);
}

/// The photo as files in a folder (created when first needed).
class FolderProfilePhotoStore implements ProfilePhotoStore {
  FolderProfilePhotoStore(this._folder, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// `profile_photo` in the app's documents folder.
  FolderProfilePhotoStore.documents()
    : this(
        () async => Directory(
          '${(await getApplicationDocumentsDirectory()).path}/profile_photo',
        ),
      );

  final Future<Directory> Function() _folder;
  final DateTime Function() _clock;

  @override
  Future<String> add(String sourcePath) async {
    final folder = await _folder();
    await folder.create(recursive: true);
    final name = 'profile-${_clock().microsecondsSinceEpoch}.jpg';
    await File(sourcePath).copy('${folder.path}/$name');
    return name;
  }

  @override
  Future<File?> find(String name) async {
    final file = File('${(await _folder()).path}/$name');
    return file.existsSync() ? file : null;
  }

  @override
  Future<void> remove(String name) async {
    final file = File('${(await _folder()).path}/$name');
    if (file.existsSync()) await file.delete();
  }
}

final profilePhotoStoreProvider = Provider<ProfilePhotoStore>(
  (ref) => FolderProfilePhotoStore.documents(),
);
