import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/core/ocr/label_ocr.dart';
import 'package:qout/core/photos/label_photo_picker.dart';
import 'package:qout/features/contribute/data/contribution_repository.dart';
import 'package:qout/features/contribute/domain/contribution_draft.dart';
import 'package:qout/features/contribute/domain/draft_values.dart';
import 'package:qout/scoring/scoring.dart' as scoring;

part 'contribution_controller.freezed.dart';

/// The flow's pages.
enum ContributionStep { photos, review, sent }

/// Where reading the nutrition table stands.
enum LabelReadingStatus {
  /// No nutrition photo yet.
  none,

  /// ML Kit, then the server's rules parser.
  reading,

  /// The rules parser's values are in the form; the LLM fallback is reading
  /// the label again.
  askingAi,

  /// The LLM's values arrived after the contributor started editing:
  /// offered, not applied.
  aiOffered,

  /// The values in the form came from the LLM fallback.
  aiApplied,

  /// Read; nothing more to come (the values may still need typing).
  done,

  /// The text could not be read or sent: values are typed by hand.
  failed,
}

/// How often and how long the app asks for the LLM fallback's result. The
/// backend gives up after its own deadline (90 s by default).
class FallbackPolling {
  const FallbackPolling({
    this.interval = const Duration(seconds: 2),
    this.timeout = const Duration(seconds: 90),
  });

  final Duration interval;
  final Duration timeout;

  /// How many times to ask. Counted rather than timed by the clock, so it
  /// works the same under a test's fake time; slow answers may stretch the
  /// wait, but the backend's own deadline then ends it (`needs_manual_entry`).
  int get attempts => interval == Duration.zero
      ? 1
      : (timeout.inMicroseconds / interval.inMicroseconds).ceil();
}

final fallbackPollingProvider = Provider<FallbackPolling>(
  (ref) => const FallbackPolling(),
);

@freezed
abstract class ContributionState with _$ContributionState {
  const factory ContributionState({
    required ContributionDraft draft,
    @Default(ContributionStep.photos) ContributionStep step,
    @Default(LabelReadingStatus.none) LabelReadingStatus reading,

    /// Photos being read by ML Kit right now.
    @Default(<PhotoKind>{}) Set<PhotoKind> readingPhotos,

    /// The LLM's reading, when offered (not applied).
    LabelReading? aiOffer,

    /// Sending: uploading the photos, then submitting.
    @Default(false) bool sending,

    /// Why the last send failed (shown with "Try again").
    String? sendError,

    /// The contributor tried to send: missing values are shown as errors.
    @Default(false) bool showRequired,
  }) = _ContributionState;
}

extension ContributionStateX on ContributionState {
  /// The front and nutrition photos are required by the backend.
  bool get hasRequiredPhotos =>
      draft.photos.containsKey(PhotoKind.front) &&
      draft.photos.containsKey(PhotoKind.nutrition);
}

/// One product being added, by barcode. Photos are read on the phone (ML
/// Kit); the nutrition table's text goes to the server's label parser and
/// fills the form; the contributor reviews; sending uploads the photos and
/// submits the product (moderated before it is published).
class ContributionController
    extends AutoDisposeFamilyNotifier<ContributionState, String> {
  /// Bumped when a new nutrition photo replaces the one being read, so a late
  /// answer for the old one is ignored.
  int _readingGeneration = 0;
  bool _disposed = false;

  ContributionRepository get _repository =>
      ref.read(contributionRepositoryProvider);

  @override
  ContributionState build(String ean) {
    ref.onDispose(() => _disposed = true);
    return ContributionState(
      draft: ContributionDraft(ean: ean, clientId: newContributionId()),
    );
  }

  // ---------------------------------------------------------------- photos

  /// Takes or picks the [kind] photo and reads its text. The nutrition
  /// table's text then fills the form.
  Future<void> capture(PhotoKind kind, PhotoSource source) async {
    final path = await ref.read(labelPhotoPickerProvider)(source);
    if (path == null || _disposed) return; // cancelled
    final draft = state.draft;
    state = state.copyWith(
      draft: draft.copyWith(
        photos: {...draft.photos, kind: path},
        ocrText: {...draft.ocrText}..remove(kind),
      ),
      readingPhotos: {...state.readingPhotos, kind},
      reading: kind == PhotoKind.nutrition
          ? LabelReadingStatus.reading
          : state.reading,
      aiOffer: kind == PhotoKind.nutrition ? null : state.aiOffer,
    );
    final generation = kind == PhotoKind.nutrition
        ? ++_readingGeneration
        : _readingGeneration;

    String? text;
    try {
      text = await ref.read(labelOcrProvider)(path);
    } on Object {
      text = null; // the photo is kept; its text is optional
    }
    if (_disposed || state.draft.photos[kind] != path) return;
    state = state.copyWith(
      draft: state.draft.copyWith(
        ocrText: {
          ...state.draft.ocrText,
          if (text != null && text.trim().isNotEmpty) kind: text,
        },
      ),
      readingPhotos: {...state.readingPhotos}..remove(kind),
    );
    if (kind != PhotoKind.nutrition) return;
    if (text == null || text.trim().isEmpty) {
      state = state.copyWith(reading: LabelReadingStatus.failed);
      return;
    }
    await _parse(text, generation);
  }

  Future<void> _parse(String text, int generation) async {
    final LabelParseResult result;
    try {
      result = await _repository.parseLabel(text);
    } on Object {
      if (_current(generation)) {
        state = state.copyWith(reading: LabelReadingStatus.failed);
      }
      return;
    }
    if (!_current(generation)) return;
    final read = _hasValues(result.valuesValue);
    if (read) state = state.copyWith(draft: _fill(result));
    final fallback = result.fallback;
    if (fallback != null && fallback.status == FallbackStatus.pending) {
      state = state.copyWith(reading: LabelReadingStatus.askingAi);
      await _pollFallback(fallback.id, generation);
    } else if (fallback?.status == FallbackStatus.done &&
        fallback?.result != null) {
      _offerOrApply(fallback!.result!);
    } else {
      state = state.copyWith(
        reading: read ? LabelReadingStatus.done : LabelReadingStatus.failed,
      );
    }
  }

  Future<void> _pollFallback(String id, int generation) async {
    final polling = ref.read(fallbackPollingProvider);
    for (var asked = 0; asked < polling.attempts; asked++) {
      await Future<void>.delayed(polling.interval);
      if (!_current(generation)) return;
      final LabelFallbackRead fallback;
      try {
        fallback = await _repository.fallback(id);
      } on Object {
        continue; // a lost answer: ask again until the deadline
      }
      if (!_current(generation)) return;
      switch (fallback.status) {
        case FallbackStatus.pending:
          continue;
        case FallbackStatus.done when fallback.result != null:
          _offerOrApply(fallback.result!);
          return;
        case _:
          _aiGaveUp();
          return;
      }
    }
    if (_current(generation)) _aiGaveUp();
  }

  void _offerOrApply(LabelReading reading) {
    if (state.draft.edited) {
      state = state.copyWith(
        reading: LabelReadingStatus.aiOffered,
        aiOffer: reading,
      );
    } else {
      state = state.copyWith(
        draft: fillFromReading(state.draft, reading),
        reading: LabelReadingStatus.aiApplied,
        aiOffer: null,
      );
    }
  }

  /// The LLM gave no values: the rules parser's stay (if it read any).
  void _aiGaveUp() => state = state.copyWith(
    reading: state.draft.parserUsed == ParserUsed.manual
        ? LabelReadingStatus.failed
        : LabelReadingStatus.done,
  );

  bool _current(int generation) =>
      !_disposed && generation == _readingGeneration;

  ContributionDraft _fill(LabelParseResult result) => fillFromReading(
    state.draft,
    LabelReading(
      parserUsed: result.parserUsed,
      ok: result.ok,
      basis: result.basis,
      valuesValue: result.valuesValue,
      derived: result.derived,
      approximate: result.approximate,
      issues: result.issues,
    ),
  );

  static bool _hasValues(LabelValues? values) =>
      values != null &&
      [
        values.energyKj,
        values.energyKcal,
        values.totalFatG,
        values.saturatedFatG,
        values.sugarsG,
        values.fibreG,
        values.proteinG,
        values.saltG,
      ].any((value) => value != null);

  /// Puts the offered LLM values in the form, replacing the edits.
  void useAiOffer() {
    final offer = state.aiOffer;
    if (offer == null) return;
    state = state.copyWith(
      draft: fillFromReading(state.draft, offer),
      reading: LabelReadingStatus.aiApplied,
      aiOffer: null,
    );
  }

  /// Keeps the form as it is.
  void dismissAiOffer() => state = state.copyWith(
    reading: LabelReadingStatus.done,
    aiOffer: null,
  );

  // ---------------------------------------------------------------- review

  void toReview() {
    if (state.hasRequiredPhotos) {
      state = state.copyWith(step: ContributionStep.review);
    }
  }

  void toPhotos() => state = state.copyWith(step: ContributionStep.photos);

  void setValue(NutrientField field, String text) {
    final draft = state.draft;
    state = state.copyWith(
      draft: draft.copyWith(
        values: {...draft.values, field: text},
        flagged: {...draft.flagged}..remove(field),
        edited: true,
      ),
    );
  }

  /// "None (0 %)": no fruit, vegetables or legumes.
  void noFruitOrVegetables() {
    final draft = state.draft;
    state = state.copyWith(
      draft: draft.copyWith(
        values: {...draft.values, NutrientField.fvl: '0'},
        edited: true,
        revision: draft.revision + 1,
      ),
    );
  }

  void setEnergyUnit(EnergyUnit unit) => _update(
    (d) => d.copyWith(energyUnit: unit, edited: true),
  );

  void setCategory(scoring.Category category) =>
      _update((d) => d.copyWith(category: category));

  void setBasis(NutritionBasis basis) =>
      _update((d) => d.copyWith(basis: basis));

  void setSweeteners({required bool value}) =>
      _update((d) => d.copyWith(sweeteners: value));

  void setName(String name) => _update((d) => d.copyWith(name: name));

  void setBrand(String brand) => _update((d) => d.copyWith(brand: brand));

  void _update(ContributionDraft Function(ContributionDraft) change) =>
      state = state.copyWith(draft: change(state.draft));

  // ---------------------------------------------------------------- sending

  /// Uploads the photos and submits. False when values are missing or wrong
  /// (shown in the form) or sending failed ([ContributionState.sendError]).
  Future<bool> send() async {
    if (state.sending) return false;
    final draft = state.draft;
    if (!state.hasRequiredPhotos ||
        problems(draft, requireMandatory: true).isNotEmpty) {
      state = state.copyWith(showRequired: true);
      return false;
    }
    state = state.copyWith(sending: true, sendError: null, showRequired: true);
    try {
      final keys = <PhotoKind, String>{};
      for (final MapEntry(key: kind, value: path) in draft.photos.entries) {
        keys[kind] = await _repository.uploadPhoto(
          clientId: draft.clientId,
          kind: kind,
          path: path,
        );
      }
      await _repository.submit(_body(draft, keys));
    } on Object catch (error) {
      if (!_disposed) {
        state = state.copyWith(sending: false, sendError: sendErrorText(error));
      }
      return false;
    }
    if (!_disposed) {
      state = state.copyWith(sending: false, step: ContributionStep.sent);
    }
    return true;
  }

  ContributionCreate _body(
    ContributionDraft draft,
    Map<PhotoKind, String> keys,
  ) {
    String? text(String value) => value.trim().isEmpty ? null : value.trim();
    return ContributionCreate(
      clientId: draft.clientId,
      ean: draft.ean,
      name: text(draft.name),
      brand: text(draft.brand),
      category: Category.values.firstWhere(
        (c) => c.value == draft.category.value,
      ),
      basis: draft.basis,
      nutrition: nutritionValues(draft),
      photos: ContributionPhotos(
        front: keys[PhotoKind.front]!,
        nutrition: keys[PhotoKind.nutrition]!,
        ingredients: keys[PhotoKind.ingredients],
      ),
      ocrText: ContributionOcr(
        front: draft.ocrText[PhotoKind.front],
        nutrition: draft.ocrText[PhotoKind.nutrition],
        ingredients: draft.ocrText[PhotoKind.ingredients],
      ),
      parserUsed: draft.parserUsed,
    );
  }
}

/// What to tell the contributor when sending failed.
String sendErrorText(Object error) => switch (error) {
  ApiConnectionError() || PhotoUploadError() =>
    'Could not reach the server. Check your connection and try again.',
  ApiUnauthorized() => 'Your session has ended. Sign in again, then retry.',
  ApiInvalidRequest(:final message) =>
    'The server refused this product: $message',
  ApiTooManyRequests() => 'Too many photos sent in the last hour. Try later.',
  ApiUnavailable() => 'The server is busy. Try again in a moment.',
  _ => 'Something went wrong. Try again.',
};

/// The product being added, by barcode; dropped when the flow closes.
final AutoDisposeNotifierProviderFamily<
  ContributionController,
  ContributionState,
  String
>
contributionControllerProvider = NotifierProvider.autoDispose
    .family<ContributionController, ContributionState, String>(
      ContributionController.new,
    );
