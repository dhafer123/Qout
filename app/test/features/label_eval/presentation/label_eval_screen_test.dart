import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/env/app_env.dart';
import 'package:qout/core/photos/label_photo_picker.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/label_eval/presentation/label_eval_screen.dart';

import '../../../helpers/fake_label_eval.dart';
import '../../../helpers/pump_app.dart';

void main() {
  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
  }

  Future<FakeLabelEval> openScreen(
    WidgetTester tester, [
    FakeLabelEval? fake,
  ]) async {
    final value = fake ?? FakeLabelEval();
    await tester.pumpQoutApp(overrides: value.overrides);
    await openMenu(tester);
    await tester.tap(find.text('Label OCR (dev)'));
    await tester.pumpAndSettle();
    return value;
  }

  testWidgets('dev builds open it from the home menu', (tester) async {
    await openScreen(tester);

    expect(find.byType(LabelEvalScreen), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('From gallery'), findsOneWidget);
  });

  for (final flavor in [AppFlavor.staging, AppFlavor.prod]) {
    testWidgets('${flavor.name} builds have neither menu item nor route', (
      tester,
    ) async {
      await tester.pumpQoutApp(flavor: flavor);
      await openMenu(tester);

      expect(find.text('Label OCR (dev)'), findsNothing);
      await tester.tapAt(Offset.zero); // close the menu
      await tester.pumpAndSettle();

      unawaited(
        GoRouter.of(
          tester.element(find.byType(HomeScreen)),
        ).push(AppRoutes.labelOcr),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LabelEvalScreen), findsNothing);
    });
  }

  testWidgets('shows the saved id, folder and the text read', (tester) async {
    final fake = await openScreen(tester);

    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();

    expect(fake.picked, [PhotoSource.camera]);
    expect(find.text('Saved as tn-001'), findsOneWidget);
    expect(find.text('Folder: /fake/label-eval'), findsOneWidget);
    expect(find.text('Pour 100 g\nSel 1,5 g'), findsOneWidget);
  });

  testWidgets('from the gallery', (tester) async {
    final fake = await openScreen(tester);

    await tester.tap(find.text('From gallery'));
    await tester.pumpAndSettle();

    expect(fake.picked, [PhotoSource.gallery]);
    expect(find.text('Saved as tn-001'), findsOneWidget);
  });

  testWidgets('buttons are disabled while reading', (tester) async {
    final fake = FakeLabelEval()..ocrGate = Completer<void>();
    await openScreen(tester, fake);

    await tester.tap(find.text('Take photo'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    for (final label in ['Take photo', 'From gallery']) {
      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      );
      expect(button.onPressed, isNull, reason: label);
    }

    fake.ocrGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Saved as tn-001'), findsOneWidget);
  });

  testWidgets('no text read', (tester) async {
    await openScreen(
      tester,
      FakeLabelEval(texts: {'photo-1.jpg': ' \n'}),
    );

    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();

    expect(find.text('Saved as tn-001'), findsOneWidget);
    expect(find.text('ML Kit read no text in this photo.'), findsOneWidget);
  });

  testWidgets('a failure is shown', (tester) async {
    await openScreen(
      tester,
      FakeLabelEval(ocrError: Exception('ML Kit failed')),
    );

    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();

    expect(find.text('Not saved: Exception: ML Kit failed'), findsOneWidget);
  });
}
