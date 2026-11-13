import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qout/core/api/qout_api.dart';

part 'history_entry.freezed.dart';

/// One scanned product in the history.
@freezed
abstract class HistoryEntry with _$HistoryEntry {
  const factory HistoryEntry({
    required int id,
    required String ean,
    required DateTime scannedAt,

    /// The product as saved on the phone; null when it was never fetched
    /// (scanned offline, unknown product) or can't be read any more.
    ProductDetail? product,
  }) = _HistoryEntry;
}
