import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qout/app/router.dart';
import 'package:qout/core/env/app_env.dart';
import 'package:qout/core/photos/label_photo_picker.dart';
import 'package:qout/features/home/presentation/home_screen.dart';
import 'package:qout/features/label_eval/domain/inbox_photo.dart';
import 'package:qout/features/label_eval/presentation/label_eval_screen.dart';

import '../../../helpers/fake_label_eval.dart';
import '../../../helpers/pump_app.dart';

void main() {
  Future<void> openProfile(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('tab-profile')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Label OCR (dev)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // Clear of the floating navigation bar at the bottom.
    await tester.runAsync(
      () => Scrollable.ensureVisible(
        tester.element(find.text('Label OCR (dev)')),
        alignment: 0.5,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<FakeLabelEval> openScreen(
    WidgetTester tester, [
    FakeLabelEval? fake,
  ]) async {
    final value = fake ?? FakeLabelEval();
    await tester.pumpQoutApp(overrides: value.overrides);
    await openProfile(tester);
    await tester.tap(find.text('Label OCR (dev)'));
    await tester.pumpAndSettle();
    return value;
  }

  testWidgets('dev builds open it from the profile', (tester) async {
    await openScreen(tester);

    expect(find.byType(LabelEvalScreen), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('From gallery'), findsOneWidget);
  });

  for (final flavor in [AppFlavor.staging, AppFlavor.prod]) {
    testWidgets('${flavor.name} builds have neither the item nor the route', (
      tester,
    ) async {
      await tester.pumpQoutApp(flavor: flavor);
      await tester.tap(find.byKey(const ValueKey('tab-profile')));
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, -5000),
        5000,
      );
      await tester.pumpAndSettle();

      expect(find.text('Developer'), findsNothing);
      expect(find.text('Label OCR (dev)'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('tab-today')));
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

  group('inbox', () {
    const photo = InboxPhoto(path: '/fake/label-eval/inbox/6191.jpg');

    testWidgets('reads every photo and shows the ids saved', (tester) async {
      final fake = await openScreen(
        tester,
        FakeLabelEval(
          inbox: [
            photo,
            photo.copyWith(path: '/fake/inbox/6192.jpg'),
          ],
          texts: {
            '${photo.path}.small': 'a',
            '/fake/inbox/6192.jpg.small': 'b',
          },
        ),
      );

      await tester.tap(find.text('Read inbox'));
      await tester.pumpAndSettle();

      expect(fake.store.saved, hasLength(2));
      expect(find.text('Saved 2 labels: tn-001 to tn-002'), findsOneWidget);
    });

    testWidgets('shows progress; buttons disabled meanwhile', (tester) async {
      final fake = FakeLabelEval(
        inbox: [photo],
        texts: {'${photo.path}.small': 'a'},
      )..ocrGate = Completer<void>();
      await openScreen(tester, fake);

      await tester.tap(find.text('Read inbox'));
      await tester.pump();

      expect(find.text('Reading the inbox: 0 of 1'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Read inbox'),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      );
      expect(button.onPressed, isNull);

      fake.ocrGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Saved 1 labels: tn-001 to tn-001'), findsOneWidget);
    });

    testWidgets('an empty inbox says where to push photos', (tester) async {
      await openScreen(tester);

      await tester.tap(find.text('Read inbox'));
      await tester.pumpAndSettle();

      expect(find.textContaining('The inbox is empty.'), findsOneWidget);
    });
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
