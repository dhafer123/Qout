import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/core/ocr/label_ocr.dart';
import 'package:qout/core/photos/label_photo_picker.dart';
import 'package:qout/features/contribute/data/contribution_repository.dart';
import 'package:qout/features/contribute/presentation/contribution_controller.dart';

import 'fixtures.dart';

/// The OCR text behind `test/fixtures/api/label-parse-ok.json`: a clean
/// French nutrition table the rules parser reads completely.
const cleanLabelText = '''
Valeurs nutritionnelles pour 100 g
Énergie 1046 kJ / 250 kcal
Matières grasses 9,5 g
dont acides gras saturés 3,2 g
Glucides 33 g
dont sucres 12 g
Fibres alimentaires 2,1 g
Protéines 7,4 g
Sel 0,85 g''';

/// The same table with the salt line misread (`label-parse-salt-missing`):
/// the rules reading is not ok and the LLM fallback is asked.
final String saltMissingLabelText = cleanLabelText.replaceFirst(
  'Sel 0,85 g',
  'Se| 0,85',
);

LabelParseResult recordedLabelParse(String name) =>
    LabelParseResult.fromJson(recordedProductJson(name));

LabelFallbackRead recordedFallback(String name) =>
    LabelFallbackRead.fromJson(recordedProductJson(name));

/// The contribution endpoints, answering from queues; every call recorded.
class FakeContributionApi implements QoutApi {
  final parsed = <String>[];
  final fallbackIds = <String>[];
  final uploads = <UploadRequest>[];
  final submitted = <ContributionCreate>[];

  /// Answers to `parseLabelText` in order: a [LabelParseResult] or a
  /// [QoutApiException] to throw.
  final parseResults = <Object>[];

  /// Answers to `getLabelFallback` in order; the last one repeats.
  final fallbackResults = <Object>[];

  /// Thrown by the next `createUpload` / `submitContribution` calls, in
  /// order; then they succeed.
  final uploadErrors = <QoutApiException>[];
  final submitErrors = <QoutApiException>[];

  /// When set, `parseLabelText` / `submitContribution` wait for them.
  Completer<void>? parseGate;
  Completer<void>? submitGate;

  @override
  Future<LabelParseResult> parseLabelText({
    required LabelParseRequest body,
  }) async {
    parsed.add(body.ocrText);
    await parseGate?.future;
    final answer = parseResults.removeAt(0);
    return answer is LabelParseResult
        ? answer
        : throw answer as QoutApiException;
  }

  @override
  Future<LabelFallbackRead> getLabelFallback({
    required String fallbackId,
  }) async {
    fallbackIds.add(fallbackId);
    final answer = fallbackResults.length > 1
        ? fallbackResults.removeAt(0)
        : fallbackResults.single;
    return answer is LabelFallbackRead
        ? answer
        : throw answer as QoutApiException;
  }

  @override
  Future<UploadTicket> createUpload({required UploadRequest body}) async {
    uploads.add(body);
    if (uploadErrors.isNotEmpty) throw uploadErrors.removeAt(0);
    final key = 'contributions/${body.contributionId}/${body.kind.value}.jpg';
    return UploadTicket(
      key: key,
      url: 'https://storage.test/$key?signature=x',
      expiresAt: DateTime.utc(2026, 11, 16, 16),
    );
  }

  @override
  Future<ContributionRead> submitContribution({
    required ContributionCreate body,
  }) async {
    submitted.add(body);
    await submitGate?.future;
    if (submitErrors.isNotEmpty) throw submitErrors.removeAt(0);
    return ContributionRead(
      id: '0b8f6c62-1d1f-4c55-9a0e-3c2f1e7d9a10',
      clientId: body.clientId,
      ean: body.ean,
      name: body.name,
      brand: body.brand,
      category: body.category,
      status: ContributionStatus.pending,
      createdAt: DateTime.utc(2026, 11, 16, 15),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Everything the contribution flow touches outside Dart: the photo picker
/// ([photos] in order, null: cancelled), ML Kit ([texts] by path; missing:
/// no text; or [ocrError]), the API ([api]) and storage ([puts], failing
/// with [putErrors] first). Photo files read as [photoBytes].
class FakeContribution {
  FakeContribution({
    List<String?>? photos,
    Map<String, String>? texts,
    FakeContributionApi? api,
  }) : photos = photos ?? [],
       texts = texts ?? {},
       api = api ?? FakeContributionApi();

  final List<String?> photos;
  final Map<String, String> texts;
  final FakeContributionApi api;
  Exception? ocrError;

  /// When set, ML Kit waits for it.
  Completer<void>? ocrGate;

  final picked = <PhotoSource>[];
  final read = <String>[];
  final puts = <(Uri url, int length, String contentType)>[];
  final putErrors = <PhotoUploadError>[];

  /// A JPEG start; `png-` paths read as PNG data.
  Uint8List photoBytes(String path) => Uint8List.fromList(
    path.startsWith('png-')
        ? [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        : [0xFF, 0xD8, 0xFF, 0xE0, 0x00],
  );

  ContributionRepository get repository => ContributionRepository(
    api: api,
    put: (url, bytes, contentType) async {
      if (putErrors.isNotEmpty) throw putErrors.removeAt(0);
      puts.add((url, bytes.length, contentType));
    },
    readPhoto: (path) async => photoBytes(path),
  );

  List<Override> get overrides => [
    labelPhotoPickerProvider.overrideWithValue((source) async {
      picked.add(source);
      return photos.removeAt(0);
    }),
    labelOcrProvider.overrideWithValue((path) async {
      read.add(path);
      await ocrGate?.future;
      if (ocrError case final error?) throw error;
      return texts[path] ?? '';
    }),
    contributionRepositoryProvider.overrideWithValue(repository),
    // Quick polling: 5 answers before giving up.
    fallbackPollingProvider.overrideWithValue(
      const FallbackPolling(
        interval: Duration(milliseconds: 10),
        timeout: Duration(milliseconds: 50),
      ),
    ),
  ];
}
