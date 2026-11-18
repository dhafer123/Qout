import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:qout/features/scan/presentation/scan_success.dart';

void main() {
  test('the bundled animation reads and lasts as long as the timer', () async {
    final bytes = File(ScanSuccess.asset).readAsBytesSync();
    final composition = await LottieComposition.fromBytes(bytes);

    expect(composition.duration, ScanSuccess.duration);
    // Only the success part: the frame, two circles and the check.
    expect(
      composition.layers.map((l) => l.name),
      containsAll(['Check', 'Circle 1', 'Circle 2', 'QR Scanner frame']),
    );
    expect(composition.layers, hasLength(4));
  });

  testWidgets('calls onDone once, when it ends', (tester) async {
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(home: ScanSuccess(onDone: () => done++)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(done, 0);
    await tester.pumpAndSettle();
    expect(done, 1);
  });

  testWidgets('is announced to screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(home: ScanSuccess(onDone: () {})),
    );
    expect(find.bySemanticsLabel('Barcode read'), findsOneWidget);
    await tester.pumpAndSettle();
    semantics.dispose();
  });
}
