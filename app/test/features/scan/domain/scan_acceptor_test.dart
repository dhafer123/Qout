import 'package:flutter_test/flutter_test.dart';
import 'package:qout/features/scan/domain/barcode.dart';
import 'package:qout/features/scan/domain/scan_acceptor.dart';

const _ean13 = '6191234567897';
const _other = '4006381333931';
const _misread = '6191234567890'; // wrong check digit

List<BarcodeRead> _frame(
  String raw, [
  RetailBarcodeFormat format = RetailBarcodeFormat.ean13,
]) => [(raw: raw, format: format)];

void main() {
  test('accepts a code after the required number of identical reads', () {
    final acceptor = ScanAcceptor();

    expect(acceptor.addFrame(_frame(_ean13)), isNull);
    expect(acceptor.addFrame(_frame(_ean13)), isNull);
    expect(acceptor.addFrame(_frame(_ean13)), _ean13);
    expect(acceptor.accepted, _ean13);
  });

  test('the default is three reads', () {
    expect(ScanAcceptor().requiredReads, 3);
  });

  test('one read short is not accepted', () {
    final acceptor = ScanAcceptor(requiredReads: 4);

    for (var i = 0; i < 3; i++) {
      expect(acceptor.addFrame(_frame(_ean13)), isNull);
    }
    expect(acceptor.accepted, isNull);
  });

  test('a single read is enough when required reads is 1', () {
    expect(ScanAcceptor(requiredReads: 1).addFrame(_frame(_ean13)), _ean13);
  });

  test('rejects required reads below 1', () {
    expect(() => ScanAcceptor(requiredReads: 0), throwsArgumentError);
  });

  test('a different valid code restarts the streak', () {
    final acceptor = ScanAcceptor()
      ..addFrame(_frame(_ean13))
      ..addFrame(_frame(_ean13));

    expect(acceptor.addFrame(_frame(_other)), isNull);
    expect(acceptor.addFrame(_frame(_other)), isNull);
    expect(acceptor.addFrame(_frame(_other)), _other);
  });

  test('alternating codes are never accepted', () {
    final acceptor = ScanAcceptor();
    for (var i = 0; i < 10; i++) {
      expect(acceptor.addFrame(_frame(i.isEven ? _ean13 : _other)), isNull);
    }
  });

  test('misreads and empty frames neither count nor break the streak', () {
    final acceptor = ScanAcceptor();

    expect(acceptor.addFrame(_frame(_ean13)), isNull);
    expect(acceptor.addFrame(_frame(_misread)), isNull);
    expect(acceptor.addFrame(const []), isNull);
    expect(acceptor.addFrame(_frame(_ean13)), isNull);
    expect(acceptor.addFrame(_frame(_misread)), isNull);
    expect(acceptor.addFrame(_frame(_ean13)), _ean13);
  });

  test('misreads alone are never accepted', () {
    final acceptor = ScanAcceptor();
    for (var i = 0; i < 10; i++) {
      expect(acceptor.addFrame(_frame(_misread)), isNull);
    }
  });

  test('the same product in UPC-A and EAN-13 form counts as one code', () {
    final acceptor = ScanAcceptor()
      ..addFrame(_frame('036000291452', RetailBarcodeFormat.upcA))
      ..addFrame(_frame('0036000291452'));

    expect(
      acceptor.addFrame(_frame('036000291452', RetailBarcodeFormat.upcA)),
      '0036000291452',
    );
  });

  test('a frame containing the candidate extends the streak', () {
    final acceptor = ScanAcceptor()..addFrame(_frame(_ean13));

    final both = [..._frame(_other), ..._frame(_ean13)];
    expect(acceptor.addFrame(both), isNull);
    expect(acceptor.addFrame(both), _ean13);
  });

  test('a new streak starts with the first valid code of the frame', () {
    final acceptor = ScanAcceptor(requiredReads: 2);

    final frame = [..._frame(_misread), ..._frame(_other), ..._frame(_ean13)];
    expect(acceptor.addFrame(frame), isNull);
    expect(acceptor.addFrame(_frame(_other)), _other);
  });

  test('frames after acceptance are ignored until reset', () {
    final acceptor = ScanAcceptor(requiredReads: 1)..addFrame(_frame(_ean13));

    expect(acceptor.addFrame(_frame(_other)), isNull);
    expect(acceptor.accepted, _ean13);

    acceptor.reset();
    expect(acceptor.accepted, isNull);
    expect(acceptor.addFrame(_frame(_other)), _other);
  });

  test('reset clears a streak in progress', () {
    final acceptor = ScanAcceptor()
      ..addFrame(_frame(_ean13))
      ..addFrame(_frame(_ean13))
      ..reset();

    expect(acceptor.addFrame(_frame(_ean13)), isNull);
  });
}
