/// Nutri-Score engine (updated algorithm, 2023), the Dart port of
/// `backend/app/modules/scoring`. Pure Dart, no Flutter imports, so it also
/// runs with `dart run` (see `tool/scoring_parity.dart`).
library;

export 'package:qout/scoring/engine.dart'
    show kjFromKcal, requiredFields, saltFromSodium, score;
export 'package:qout/scoring/models.dart';
