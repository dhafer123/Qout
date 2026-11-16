import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/core/api/api_providers.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/core/photos/photo_type.dart';

/// Reads a photo file (the picker's reduced JPEG or PNG).
typedef PhotoBytes = Future<Uint8List> Function(String path);

/// Uploads [bytes] with one `PUT` to a presigned storage URL, with exactly
/// the signed `Content-Type` (and the length the URL was asked for).
typedef PhotoPut =
    Future<void> Function(Uri url, Uint8List bytes, String contentType);

/// A photo upload storage refused or that could not be sent.
class PhotoUploadError implements Exception {
  const PhotoUploadError(this.message);

  final String message;

  @override
  String toString() => 'PhotoUploadError: $message';
}

/// The contribution flow's calls: reading a label's text on the server (the
/// rules parser, then possibly the LLM fallback), uploading the photos and
/// submitting the product. Errors are the API client's (`QoutApiException`)
/// and [PhotoUploadError].
class ContributionRepository {
  ContributionRepository({
    required QoutApi api,
    required PhotoPut put,
    PhotoBytes? readPhoto,
  }) : _api = api,
       _put = put,
       _readPhoto = readPhoto ?? ((path) => File(path).readAsBytes());

  final QoutApi _api;
  final PhotoPut _put;
  final PhotoBytes _readPhoto;

  Future<LabelParseResult> parseLabel(String ocrText) =>
      _api.parseLabelText(body: LabelParseRequest(ocrText: ocrText));

  Future<LabelFallbackRead> fallback(String id) =>
      _api.getLabelFallback(fallbackId: id);

  /// Uploads the photo at [path] as [kind] of contribution [clientId]; its key
  /// in storage, for [submit].
  Future<String> uploadPhoto({
    required String clientId,
    required PhotoKind kind,
    required String path,
  }) async {
    final bytes = await _readPhoto(path);
    final type = isPng(bytes)
        ? PhotoContentType.imagePng
        : PhotoContentType.imageJpeg;
    final ticket = await _api.createUpload(
      body: UploadRequest(
        contributionId: clientId,
        kind: kind,
        contentType: type,
        sizeBytes: bytes.length,
      ),
    );
    await _put(Uri.parse(ticket.url), bytes, type.value);
    return ticket.key;
  }

  Future<ContributionRead> submit(ContributionCreate body) =>
      _api.submitContribution(body: body);
}

/// Uploads go straight to storage, not the API: a plain client without the
/// API's base URL or access token.
final Provider<PhotoPut> photoPutProvider = Provider<PhotoPut>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  ref.onDispose(dio.close);
  return dioPhotoPut(dio);
});

/// [PhotoPut] with [dio]; failures become [PhotoUploadError].
PhotoPut dioPhotoPut(Dio dio) => (url, bytes, contentType) async {
  try {
    await dio.putUri<void>(
      url,
      data: Stream<List<int>>.value(bytes),
      options: Options(
        headers: {
          Headers.contentTypeHeader: contentType,
          Headers.contentLengthHeader: bytes.length,
        },
      ),
    );
  } on DioException catch (error) {
    final status = error.response?.statusCode;
    throw PhotoUploadError(
      status == null ? 'no connection to storage' : 'storage answered $status',
    );
  }
};

final Provider<ContributionRepository> contributionRepositoryProvider =
    Provider<ContributionRepository>(
      (ref) => ContributionRepository(
        api: ref.watch(qoutApiProvider),
        put: ref.watch(photoPutProvider),
      ),
    );
