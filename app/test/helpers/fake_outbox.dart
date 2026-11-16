import 'dart:io';

import 'package:qout/core/api/qout_api.dart' show PhotoKind;
import 'package:qout/features/outbox/data/outbox_files.dart';
import 'package:qout/features/outbox/presentation/outbox_scheduler.dart';

/// Kept photos without files: `outbox/<client id>/<original path>`.
class FakeOutboxFiles implements OutboxFiles {
  final kept = <(String clientId, PhotoKind kind, String path)>[];
  final removed = <String>[];

  /// Thrown by [keep] when set (a full disk).
  Exception? keepError;

  @override
  Future<String> keep(String clientId, PhotoKind kind, String path) async {
    if (keepError case final error?) throw error;
    kept.add((clientId, kind, path));
    return 'outbox/$clientId/$path';
  }

  @override
  Future<void> remove(String clientId) async => removed.add(clientId);

  /// A kept photo that can't be read: its path for FakeContribution's
  /// reader to fail on.
  static bool missing(String path) => path.contains('missing');

  static FileSystemException missingError(String path) =>
      FileSystemException('Cannot open file', path);
}

/// Counts the syncs asked for; sends nothing.
class FakeOutboxTrigger implements OutboxTrigger {
  int syncs = 0;
  int signIns = 0;

  @override
  Future<void> sync() async => syncs++;

  @override
  Future<void> signedIn() async => signIns++;
}
