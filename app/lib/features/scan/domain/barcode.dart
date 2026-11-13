/// Retail barcodes the scanner accepts, independent of the camera plugin.
library;

/// The barcode symbologies used on food packaging.
enum RetailBarcodeFormat { ean13, ean8, upcA, upcE }

/// GTIN check digit for [body] (every digit but the last): weights 3, 1, 3...
/// from the right. Same rule as the backend (`products/ean.py`).
int gtinCheckDigit(String body) {
  var total = 0;
  for (var i = 0; i < body.length; i++) {
    final digit = body.codeUnitAt(body.length - 1 - i) - _zero;
    total += digit * (i.isEven ? 3 : 1);
  }
  return (10 - total % 10) % 10;
}

/// True for an all-digit code whose last digit is its GTIN check digit.
bool hasValidCheckDigit(String code) =>
    code.length >= 2 &&
    _isDigits(code) &&
    gtinCheckDigit(code.substring(0, code.length - 1)) ==
        code.codeUnitAt(code.length - 1) - _zero;

/// Expands an 8-digit UPC-E code (number system 0 or 1, six data digits,
/// check digit) to its 12-digit UPC-A form, following the GS1 zero-suppression
/// rules. Null if [code] isn't a valid UPC-E code.
String? expandUpcE(String code) {
  if (code.length != 8 || !_isDigits(code)) return null;
  final numberSystem = code[0];
  if (numberSystem != '0' && numberSystem != '1') return null;
  final d = code.substring(1, 7);
  final body = switch (d[5]) {
    '0' || '1' || '2' => '${d.substring(0, 2)}${d[5]}0000${d.substring(2, 5)}',
    '3' => '${d.substring(0, 3)}00000${d.substring(3, 5)}',
    '4' => '${d.substring(0, 4)}00000${d[4]}',
    _ => '${d.substring(0, 5)}0000${d[5]}',
  };
  final upcA = '$numberSystem$body${code[7]}';
  return hasValidCheckDigit(upcA) ? upcA : null;
}

/// The code to look up for a scanned barcode: EAN-13 and EAN-8 as read, UPC-A
/// as EAN-13 (leading 0, as the backend stores it), UPC-E expanded to UPC-A
/// and then EAN-13. Null when the value doesn't fit its format or the check
/// digit is wrong (a misread).
String? normalizeScannedBarcode(String raw, RetailBarcodeFormat format) {
  final code = raw.trim();
  if (!_isDigits(code)) return null;
  final ean = switch (format) {
    RetailBarcodeFormat.ean13 => code.length == 13 ? code : null,
    RetailBarcodeFormat.ean8 => code.length == 8 ? code : null,
    // Some readers already report UPC-A in its 13-digit EAN form.
    RetailBarcodeFormat.upcA => switch (code.length) {
      12 => '0$code',
      13 when code.startsWith('0') => code,
      _ => null,
    },
    RetailBarcodeFormat.upcE => switch (expandUpcE(code)) {
      final upcA? => '0$upcA',
      null => null,
    },
  };
  return ean != null && hasValidCheckDigit(ean) ? ean : null;
}

const _zero = 0x30;

bool _isDigits(String s) =>
    s.isNotEmpty && s.codeUnits.every((c) => c >= _zero && c <= _zero + 9);
