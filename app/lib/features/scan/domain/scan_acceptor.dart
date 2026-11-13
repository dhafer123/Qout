import 'package:qout/features/scan/domain/barcode.dart';

/// One barcode read from a camera frame.
typedef BarcodeRead = ({String raw, RetailBarcodeFormat format});

/// Decides when a scanned barcode is trustworthy: it must be valid and seen in
/// [requiredReads] consecutive frames. One frame can misread a digit; the
/// check digit catches most of that, repeated reads catch the rest.
///
/// - A frame with no valid barcode (nothing in view, or only misreads) is
///   ignored: it neither counts nor breaks the streak.
/// - A frame that contains the current candidate extends the streak.
/// - A frame with valid barcodes but not the candidate starts a new streak
///   with its first valid one.
/// - Once a code is accepted, frames are ignored until [reset].
class ScanAcceptor {
  ScanAcceptor({this.requiredReads = defaultRequiredReads}) {
    if (requiredReads < 1) {
      throw ArgumentError.value(requiredReads, 'requiredReads', 'must be >= 1');
    }
  }

  /// Consecutive identical reads before a code is accepted.
  static const defaultRequiredReads = 3;

  final int requiredReads;

  String? _candidate;
  int _streak = 0;
  String? _accepted;

  /// The accepted code (normalised, see [normalizeScannedBarcode]), if any.
  String? get accepted => _accepted;

  /// Feeds the barcodes of one frame. Returns the code when this frame makes
  /// it accepted, otherwise null (also for every frame after acceptance).
  String? addFrame(Iterable<BarcodeRead> reads) {
    if (_accepted != null) return null;
    final codes = [
      for (final read in reads) ?normalizeScannedBarcode(read.raw, read.format),
    ];
    if (codes.isEmpty) return null;
    if (_candidate != null && codes.contains(_candidate)) {
      _streak++;
    } else {
      _candidate = codes.first;
      _streak = 1;
    }
    if (_streak < requiredReads) return null;
    return _accepted = _candidate;
  }

  /// Forgets the streak and any accepted code, to scan again.
  void reset() {
    _candidate = null;
    _streak = 0;
    _accepted = null;
  }
}
