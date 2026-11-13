import 'package:flutter_test/flutter_test.dart';
import 'package:qout/features/scan/domain/barcode.dart';

void main() {
  group('gtinCheckDigit', () {
    test('matches known codes', () {
      expect(gtinCheckDigit('400638133393'), 1); // EAN-13
      expect(gtinCheckDigit('5449000'), 0); // EAN-8
      expect(gtinCheckDigit('03600029145'), 2); // UPC-A
      expect(gtinCheckDigit('619123456789'), 7); // Tunisian prefix
    });
  });

  group('hasValidCheckDigit', () {
    test('accepts correct check digits', () {
      expect(hasValidCheckDigit('4006381333931'), isTrue);
      expect(hasValidCheckDigit('54490000'), isTrue);
      expect(hasValidCheckDigit('036000291452'), isTrue);
    });

    test('rejects a wrong check digit', () {
      expect(hasValidCheckDigit('4006381333932'), isFalse);
      expect(hasValidCheckDigit('54490001'), isFalse);
    });

    test('rejects a single changed digit', () {
      // Any single-digit error changes the check digit.
      for (var i = 0; i < 12; i++) {
        final digits = '4006381333931'.split('');
        digits[i] = digits[i] == '9' ? '0' : '${int.parse(digits[i]) + 1}';
        expect(hasValidCheckDigit(digits.join()), isFalse, reason: 'pos $i');
      }
    });

    test('rejects non-digits and too-short codes', () {
      expect(hasValidCheckDigit(''), isFalse);
      expect(hasValidCheckDigit('0'), isFalse);
      expect(hasValidCheckDigit('400638133393a'), isFalse);
      expect(hasValidCheckDigit('400638 333931'), isFalse);
      expect(hasValidCheckDigit('٤٠٠٦٣٨١٣٣٣٩٣١'), isFalse); // Arabic digits
    });
  });

  group('expandUpcE', () {
    test('the GS1 reference example', () {
      expect(expandUpcE('04252614'), '042100005264');
    });

    test('last data digit 0, 1, 2: manufacturer ends with it + 00', () {
      expect(expandUpcE('01234505'), '012000003455');
      expect(expandUpcE('11234511'), '112100003451');
      expect(expandUpcE('01234523'), '012200003453');
    });

    test('last data digit 3: three manufacturer digits', () {
      expect(expandUpcE('01234531'), '012300000451');
    });

    test('last data digit 4: four manufacturer digits', () {
      expect(expandUpcE('01234543'), '012340000053');
    });

    test('last data digit 5 to 9: five manufacturer digits', () {
      expect(expandUpcE('01234558'), '012345000058');
      expect(expandUpcE('11234593'), '112345000093');
    });

    test('rejects a wrong check digit', () {
      expect(expandUpcE('04252615'), isNull);
    });

    test('rejects number systems other than 0 and 1', () {
      for (final ns in ['2', '5', '9']) {
        expect(expandUpcE('${ns}4252614'), isNull, reason: ns);
      }
    });

    test('rejects other lengths and non-digits', () {
      expect(expandUpcE('425261'), isNull);
      expect(expandUpcE('0425261'), isNull);
      expect(expandUpcE('042526140'), isNull);
      expect(expandUpcE('0425261x'), isNull);
    });
  });

  group('normalizeScannedBarcode', () {
    test('EAN-13 and EAN-8 are kept as read', () {
      expect(
        normalizeScannedBarcode('6191234567897', RetailBarcodeFormat.ean13),
        '6191234567897',
      );
      expect(
        normalizeScannedBarcode('54490000', RetailBarcodeFormat.ean8),
        '54490000',
      );
    });

    test('UPC-A becomes EAN-13 with a leading zero', () {
      expect(
        normalizeScannedBarcode('036000291452', RetailBarcodeFormat.upcA),
        '0036000291452',
      );
    });

    test('UPC-A already reported in 13 digits is kept', () {
      expect(
        normalizeScannedBarcode('0036000291452', RetailBarcodeFormat.upcA),
        '0036000291452',
      );
      expect(
        normalizeScannedBarcode('1036000291452', RetailBarcodeFormat.upcA),
        isNull,
      );
    });

    test('UPC-E is expanded to EAN-13', () {
      expect(
        normalizeScannedBarcode('04252614', RetailBarcodeFormat.upcE),
        '0042100005264',
      );
    });

    test('surrounding whitespace is ignored', () {
      expect(
        normalizeScannedBarcode(' 54490000\n', RetailBarcodeFormat.ean8),
        '54490000',
      );
    });

    test('rejects a wrong check digit in every format', () {
      expect(
        normalizeScannedBarcode('6191234567890', RetailBarcodeFormat.ean13),
        isNull,
      );
      expect(
        normalizeScannedBarcode('54490001', RetailBarcodeFormat.ean8),
        isNull,
      );
      expect(
        normalizeScannedBarcode('036000291453', RetailBarcodeFormat.upcA),
        isNull,
      );
      expect(
        normalizeScannedBarcode('04252615', RetailBarcodeFormat.upcE),
        isNull,
      );
    });

    test('rejects a length that does not match the format', () {
      expect(
        normalizeScannedBarcode('54490000', RetailBarcodeFormat.ean13),
        isNull,
      );
      expect(
        normalizeScannedBarcode('6191234567897', RetailBarcodeFormat.ean8),
        isNull,
      );
      expect(
        normalizeScannedBarcode('54490000', RetailBarcodeFormat.upcA),
        isNull,
      );
      expect(
        normalizeScannedBarcode('036000291452', RetailBarcodeFormat.upcE),
        isNull,
      );
    });

    test('an EAN-8 read as UPC-E is checked as UPC-E', () {
      // Valid EAN-8, but number system 5 doesn't exist in UPC-E.
      expect(
        normalizeScannedBarcode('54490000', RetailBarcodeFormat.upcE),
        isNull,
      );
    });

    test('rejects empty and non-digit values', () {
      for (final format in RetailBarcodeFormat.values) {
        expect(normalizeScannedBarcode('', format), isNull);
        expect(normalizeScannedBarcode('ABC-1234', format), isNull);
        expect(normalizeScannedBarcode('https://qout.tn', format), isNull);
      }
    });
  });
}
