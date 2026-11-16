import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qout/core/api/qout_api.dart' show PhotoKind;

/// Photos of queued contributions, kept by the app until they are sent: the
/// picker's files are temporary and Android may delete them.
abstract interface class OutboxFiles {
  /// Copies the photo at [path] for contribution [clientId]; the copy's path.
  Future<String> keep(String clientId, PhotoKind kind, String path);

  /// Deletes the photos kept for [clientId] (sent or deleted).
  Future<void> remove(String clientId);
}

/// `outbox/<client id>/<kind>.<ext>` under [root].
class DirectoryOutboxFiles implements OutboxFiles {
  DirectoryOutboxFiles(this.root);

  final Future<Directory> Function() root;

  Future<Directory> _folder(String clientId) async =>
      Directory('${(await root()).path}/outbox/$clientId');

  @override
  Future<String> keep(String clientId, PhotoKind kind, String path) async {
    final folder = await _folder(clientId);
    await folder.create(recursive: true);
    final dot = path.lastIndexOf('.');
    final extension = dot > path.lastIndexOf('/') && dot >= 0
        ? path.substring(dot).toLowerCase()
        : '';
    final copy = await File(
      path,
    ).copy('${folder.path}/${kind.value}$extension');
    return copy.path;
  }

  @override
  Future<void> remove(String clientId) async {
    final folder = await _folder(clientId);
    if (folder.existsSync()) await folder.delete(recursive: true);
  }
}

/// In the app's private support folder (not backed up, not user-visible).
final Provider<OutboxFiles> outboxFilesProvider = Provider<OutboxFiles>(
  (ref) => DirectoryOutboxFiles(getApplicationSupportDirectory),
);
