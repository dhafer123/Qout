import 'package:flutter_test/flutter_test.dart';
import 'package:qout/scoring/exact_decimal.dart';

ExactDecimal d(String text) => ExactDecimal.parse(text);

void main() {
  group('parse', () {
    final cases = {
      '0': '0',
      '-0': '0',
      '0.000': '0',
      '4.1': '4.1',
      '4.10': '4.1',
      '+12': '12',
      '-3.25': '-3.25',
      '1e-7': '0.0000001',
      '2.5E+3': '2500',
      '1.5e2': '150',
      '120e-2': '1.2',
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      test('"$input" -> $expected', () {
        expect(d(input).toString(), expected);
      });
    }

    for (final bad in ['', '.5', '5.', '1,5', 'abc', '1e', '--1', 'NaN']) {
      test('rejects "$bad"', () {
        expect(() => d(bad), throwsFormatException);
      });
    }
  });

  group('fromDouble', () {
    test('keeps the written value, like Python repr', () {
      expect(ExactDecimal.fromDouble(4.1), d('4.1'));
      expect(ExactDecimal.fromDouble(0.58), d('0.58'));
      expect(ExactDecimal.fromDouble(1e-7), d('0.0000001'));
      expect(ExactDecimal.fromDouble(1e21), d('1e21'));
      expect(ExactDecimal.fromDouble(3), d('3'));
    });

    for (final bad in [double.nan, double.infinity, double.negativeInfinity]) {
      test('rejects $bad', () {
        expect(() => ExactDecimal.fromDouble(bad), throwsArgumentError);
      });
    }
  });

  test('fromInt', () {
    expect(ExactDecimal.fromInt(-37), d('-37'));
  });

  group('arithmetic is exact', () {
    test('0.58 * 100 is exactly 58 (57.99999999999999 as doubles)', () {
      expect(0.58 * 100, lessThan(58));
      expect(d('0.58') * ExactDecimal.fromInt(100), d('58'));
    });

    test('0.56 * 2.5 is exactly 1.4', () {
      expect(0.56 * 2.5, greaterThan(1.4));
      expect(d('0.56') * d('2.5'), d('1.4'));
    });

    test('add and subtract align scales', () {
      expect(d('0.1') + d('0.2'), d('0.3'));
      expect(d('1') - d('0.001'), d('0.999'));
      expect(d('0.5') - d('0.75'), d('-0.25'));
    });
  });

  group('comparison', () {
    test('operators', () {
      expect(d('3.4') < d('3.41'), isTrue);
      expect(d('3.4') <= d('3.40'), isTrue);
      expect(d('3.4') > d('3.399'), isTrue);
      expect(d('3.4') >= d('3.4'), isTrue);
      expect(d('-1') < d('0'), isTrue);
      expect(d('2').compareTo(d('10')), lessThan(0));
    });

    test('equal values are equal regardless of how they were written', () {
      expect(d('1.50'), d('1.5'));
      expect(d('1.50').hashCode, d('1.5').hashCode);
      expect(d('0.0'), ExactDecimal.fromInt(0));
      expect(d('1.5'), isNot(d('1.05')));
      expect(d('1.5') == Object(), isFalse);
    });

    test('isZero and isNegative', () {
      expect(d('0.000').isZero, isTrue);
      expect(d('0.001').isZero, isFalse);
      expect(d('-0.001').isNegative, isTrue);
      expect(d('0').isNegative, isFalse);
    });
  });

  group('roundHalfAwayFromZero (Excel ROUND)', () {
    final cases = {
      '10.5': 11,
      '10.49': 10,
      '31.5': 32,
      '52.5': 53,
      '336.42': 336,
      '-2.5': -3,
      '-2.4': -2,
      '7': 7,
      '0.5': 1,
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      test('$input -> $expected', () {
        expect(d(input).roundHalfAwayFromZero(), expected);
      });
    }
  });

  test('toDouble and toString', () {
    expect(d('0.3').toDouble(), 0.3);
    expect(d('-0.05').toString(), '-0.05');
    expect(d('0.0000001').toDouble(), 1e-7);
  });
}
