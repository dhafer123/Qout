import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/photos/label_photo_resizer.dart';

void main() {
  test('within the limit: not resized', () {
    expect(scaledSize(1600, 900), isNull);
    expect(scaledSize(1200, 1600), isNull);
    expect(scaledSize(10, 10), isNull);
  });

  test('longest side brought to 1600, aspect kept', () {
    expect(scaledSize(3200, 2400), (width: 1600, height: 1200));
    expect(scaledSize(1000, 4000), (width: 400, height: 1600));
    expect(scaledSize(1601, 1601), (width: 1600, height: 1600));
  });

  test('a very thin photo keeps at least one pixel', () {
    expect(scaledSize(100000, 10), (width: 1600, height: 1));
  });
}
