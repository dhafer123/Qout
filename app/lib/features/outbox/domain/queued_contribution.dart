import 'dart:convert';

import 'package:qout/core/api/qout_api.dart';

/// A new product waiting in the outbox (`new_product`): the request without
/// its photo keys, and each photo's kept file with its storage key once
/// uploaded (so a retry doesn't upload it again).
class QueuedContribution {
  const QueuedContribution({required this.request, required this.photos});

  /// Reads an outbox payload. Throws [FormatException] when it isn't one.
  factory QueuedContribution.fromPayload(String payload) {
    try {
      final json = jsonDecode(payload) as Map<String, Object?>;
      final photos = json['photos']! as Map<String, Object?>;
      return QueuedContribution(
        request: Map.unmodifiable(json['request']! as Map<String, Object?>),
        photos: {
          for (final MapEntry(:key, :value) in photos.entries)
            PhotoKind.fromJson(key): QueuedPhoto.fromJson(
              value! as Map<String, Object?>,
            ),
        },
      );
    } on Object catch (error) {
      throw FormatException('not a queued contribution: $error');
    }
  }

  /// [create] as queued: its photo keys are left out (filled in when sent);
  /// [paths] are the kept photo files.
  factory QueuedContribution.of(
    ContributionCreate create,
    Map<PhotoKind, String> paths,
  ) => QueuedContribution(
    request: Map.unmodifiable(create.toJson()..remove('photos')),
    photos: {
      for (final MapEntry(:key, :value) in paths.entries)
        key: QueuedPhoto(path: value),
    },
  );

  /// `ContributionCreate` JSON without `photos`.
  final Map<String, Object?> request;
  final Map<PhotoKind, QueuedPhoto> photos;

  /// Outbox `kind` of these entries.
  static const kind = 'new_product';

  String get clientId => request['client_id']! as String;
  String get ean => request['ean']! as String;
  String? get name => request['name'] as String?;

  /// The photos not uploaded yet.
  Iterable<PhotoKind> get toUpload => [
    for (final MapEntry(:key, :value) in photos.entries)
      if (value.key == null) key,
  ];

  QueuedContribution withKey(PhotoKind kind, String key) => QueuedContribution(
    request: request,
    photos: {
      ...photos,
      kind: QueuedPhoto(path: photos[kind]!.path, key: key),
    },
  );

  /// The request to submit, once every photo is uploaded.
  ContributionCreate create() => ContributionCreate.fromJson({
    ...request,
    'photos': {
      for (final MapEntry(:key, :value) in photos.entries)
        key.value: value.key ?? (throw StateError('$key not uploaded')),
    },
  });

  String toPayload() => jsonEncode({
    'request': request,
    'photos': {
      for (final MapEntry(:key, :value) in photos.entries)
        key.value: value.toJson(),
    },
  });
}

/// A kept photo file, and its key in storage once uploaded.
class QueuedPhoto {
  const QueuedPhoto({required this.path, this.key});

  factory QueuedPhoto.fromJson(Map<String, Object?> json) => QueuedPhoto(
    path: json['path']! as String,
    key: json['key'] as String?,
  );

  final String path;
  final String? key;

  Map<String, Object?> toJson() => {'path': path, 'key': key};
}
