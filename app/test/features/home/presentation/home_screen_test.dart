import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/product/presentation/product_screen.dart';
import 'package:qout/features/scan/presentation/scan_screen.dart';

import '../../../helpers/fake_scanner_platform.dart';
import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('shows a Scan button', (tester) async {
    await tester.pumpQoutApp();

    expect(
      find.ancestor(
        of: find.text('Scan'),
        matching: find.bySubtype<FilledButton>(),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
  });

  testWidgets('Scan opens the scanner', (tester) async {
    installFakeScanner();
    await tester.pumpQoutApp();

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.byType(ScanScreen), findsOneWidget);
    expect(find.byKey(FakeScannerPlatform.cameraKey), findsOneWidget);
  });

  testWidgets('a scanned code opens its product; back returns home', (
    tester,
  ) async {
    final scanner = installFakeScanner();
    await tester.pumpQoutApp();
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      scanner.emitCode('6191234567897');
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(ProductScreen), findsOneWidget);
    expect(find.text('6191234567897'), findsOneWidget);
    expect(find.byType(ScanScreen), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
