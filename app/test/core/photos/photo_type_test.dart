import 'package:flutter_test/flutter_test.dart';
import 'package:qout/core/photos/photo_type.dart';

void main() {
  test('PNG from its signature', () {
    expect(isPng([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]), isTrue);
    expect(isPng([0x89, 0x50, 0x4E, 0x47]), isTrue);
  });

  test('anything else is not PNG', () {
    expect(isPng([0xFF, 0xD8, 0xFF, 0xE0]), isFalse); // JPEG
    expect(isPng([0x89, 0x50, 0x4E]), isFalse); // too short
    expect(isPng([]), isFalse);
  });
}
