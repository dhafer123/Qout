import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('Scan explains that scanning is not available yet', (
    tester,
  ) async {
    await tester.pumpQoutApp();

    await tester.tap(find.text('Scan'));
    await tester.pump();

    expect(find.text('Scanning is coming soon.'), findsOneWidget);
  });
}
